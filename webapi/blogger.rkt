;; Copyright 2011-2013 Ryan Culpepper
;; Released under the terms of the LGPL version 3 or later.
;; See the file COPYRIGHT for details.

#lang racket/base
(require racket/class
         racket/port
         net/url
         net/uri-codec
         "atom.rkt"
         "oauth2.rkt"
         "private/net.rkt"
         "private/has-atom.rkt"
         "private/sxml.rkt"
         sxml
         neil/html-writing1/main)
(provide blogger-scope
         blogger<%>
         blogger%
         blogger
         blogger-blog<%>
         blogger-blog%
         blogger-post<%>
         blogger-post%)

#|
Blogger
Reference: http://code.google.com/apis/blogger/docs/2.0/developers_guide_protocol.html
|#

(define blogger<%>
  (interface (atom-feed-resource<%>)
    list-blogs ;; -> (listof blogger-blog<%>)
    find-blog  ;; string -> blogger-blog<%>
    ;; no create-blog
    ))

(define blogger-blog<%>
  (interface (atom-feed-resource<%>)
    list-posts       ;; -> (listof blogger-post<%>)
    find-post        ;; string -> blogger-post<%>
    create-html-post ;; string (U path-string (listof SXML)) ... -> blogger-post<%>
    ;; no delete-blog
    ))

(define blogger-post<%>
  (interface (atom-resource<%>)
    get-html-contents ;; -> SXML
    update            ;; string/#f (U #f path-string (listof SXML)) -> void
    delete            ;; -> void
    ))

;; ============================================================

(define blogger-scope "https://www.blogger.com/feeds/")

;; ============================================================

(define (blogger #:oauth2 oauth2)
  (new blogger% (oauth2 oauth2)))

(define blogger%
  (class* atom-feed-resource% (blogger<%>)
    (init-field oauth2)
    (inherit list-children
             find-child-by-title)
    (super-new)

    ;; ==== Overrides ====

    (define/override (internal-get-atom #:who who)
      (get/url "https://www.blogger.com/feeds/default/blogs"
               #:headers (headers)
               #:handle read-sxml
               #:who who))

    (define/override (make-child atom)
      (new blogger-blog%
           (oauth2 oauth2)
           (parent this)
           (atom atom)))

    ;; ====

    (define/public (list-blogs #:who [who 'blogger:list-blogs])
      (list-children #:who who))

    (define/public (find-blog title
                              #:who [who 'blogger:find-blog])
      (find-child-by-title title #:who who))

    (define/public (headers [content-type #f])
      (append (case content-type
                ((atom) '("Content-Type: application/atom+xml"))
                ((xml)  '("Content-Type: application/xml"))
                (else null))
              '("GData-Version: 2")
              (send oauth2 headers)))
    ))

;; blogger-blog% represents one blog
(define blogger-blog%
  (class* atom-resource/parent+child% (blogger-blog<%>)
    (init-field oauth2)
    (inherit-field parent)
    (inherit get-atom
             list-children
             find-child-by-title
             intern)
    (super-new)

    ;; ==== Overrides ====

    (define/override (make-child atom)
      (new blogger-post%
           (parent this)
           (atom atom)))

    (define/override (internal-get-atom #:who who)
      (get/url (send (get-atom) get-link "http://schemas.google.com/g/2005#post")
               #:headers (headers)
               #:handle read-sxml
               #:who who))

    ;; ----

    (define/public (list-posts #:who [who 'blogger-blog:list-posts])
      (list-children #:who who))

    (define/public (find-post title
                              #:who [who 'blogger-blog:find-post])
      (find-child-by-title title #:who who))

    ;; ----

    (define/public (create-html-post title contents
                                     #:draft? [draft? #f]
                                     #:tags [tags null]
                                     #:who [who 'blogger-blog:create-html-post])
      ;; html is either literal list of strings or name of HTML file
      (let ([html (port/sxmls->html contents)])
        (post/url (send (get-atom) get-link "http://schemas.google.com/g/2005#post")
                  #:headers (headers 'atom)
                  #:data (let ([body (create-html-post/doc #f title html draft? tags)])
                           (srl:sxml->xml body))
                  #:handle (lambda (in) (intern (atom (read-sxml in))))
                  #:who who)))

    ;; ----

    (define/public (headers [content-type #f])
      (send parent headers content-type))

    ))

(define blogger-post%
  (class* atom-resource/parent+child% (blogger-post<%>)
    (inherit-field parent)
    (inherit get-atom
             check-valid
             invalidate!)
    (super-new)

    ;; ==== Overrides ====

    (define/override (internal-get-atom #:who who)
      (check-valid who)
      (get/url (send (get-atom) get-link "self")
               #:headers (send parent headers)
               #:handle read-sxml
               #:who who))

    ;; ----

    (define/public (get-html-contents #:who [who 'blogger-post:get-html-contents])
      (check-valid who)
      (let* ([doc (send (get-atom) get-sxml)]
             [contents
              ((lift-sxpath "/atom:content[@type='html']/text()" (xpath-nss 'atom)) doc)])
        (cond [(pair? contents) (car contents)]
              [else (error who "no html contents")])))

    (define/public (delete #:who [who 'blogger-post:delete])
      (check-valid who)
      (delete/url (send (get-atom) get-link "edit")
                  #:headers (send parent headers)
                  #:handle void
                  #:who who)
      (invalidate!))

    (define/public (update title contents
                           #:who [who 'blogger-post:update-html-contents])
      (check-valid who)
      (put/url (send (get-atom) get-link "edit")
               #:headers (list* (send parent headers 'atom))
               #:data (let* ([html (port/sxmls->html contents)]
                             [body (update-html-post/doc
                                    (send (get-atom #:reload? #t) get-raw-sxml)
                                    title
                                    html)])
                        (srl:sxml->xml body))
               #:handle port->string
               #:who who)
      (invalidate!))

    ))

(define (update-html-post/doc sxml new-title new-html)
  (pre-post-order sxml
                  (list (cons 'atom:content
                              (lambda current-content-elem
                                (if new-html
                                    `(atom:content (@ (type "html")) ,@new-html)
                                    current-content-elem)))
                        (cons 'atom:title
                              (lambda current-tag-elem
                                (if new-title
                                    `(atom:title ,new-title)
                                    current-tag-elem)))
                        (cons '*text*
                              (lambda (tag content)
                                content))
                        (cons '*default*
                              (lambda args args)))))

;; create-html-post/doc : string string (listof string boolean (U #f (listof string)) -> SXML
(define (create-html-post/doc id title html-body draft? tags)
  ;; Include the contents of html-file in doc as a *string*;
  ;; that way its markup gets escaped when atom xml is written.
  `(*TOP*
    (@ (*NAMESPACES*
        (atom "http://www.w3.org/2005/Atom")
        (app  "http://www.w3.org/2007/app")))
    (*PI* xml "version='1.0' encoding='UTF-8'")
    (atom:entry
     ,@(if id
           `((atom:id ,id))
           '())
     ,@(if title
           `((atom:title (@ (type "text")) ,title))
           '())
     (atom:content (@ (type "html")) ,@html-body)
     ,@(if tags
           (for/list ([tag (in-list tags)])
             `(atom:category (@ (scheme "http://www.blogger.com/atom/ns#")
                                (term ,tag))))
           '())
     ,@(cond [draft? '((app:control (app:draft "yes")))]
             [else '()]))))

;; port/sxmls->html : (U input-port (listof SXML)) -> string
(define (port/sxmls->html x)
  (cond [(input-port? x) (port->lines x)]
        [else (map xexp->html x)]))
