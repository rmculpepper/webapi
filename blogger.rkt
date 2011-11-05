#lang racket/base
(require racket/class
         racket/port
         net/url
         net/uri-codec
         "oauth2.rkt"
         "util/net.rkt"
         "util/child-cache.rkt"
         "util/sxml.rkt"
         (planet clements/sxml2:1))
(provide blogger-scope
         blogger-user<%>
         blogger-user%
         blogger-user
         blogger<%>
         blogger%
         blogger-post<%>
         blogger-post%)

#|
Blogger
Reference: http://code.google.com/apis/blogger/docs/2.0/developers_guide_protocol.html
|#

(define blogger-user<%>
  (interface ()
    find-blog ;; string [default] -> blogger<%>
    list-blogs ;; -> (listof blogger<%>)
    page ;; -> SXML
    ))

(define blogger<%>
  (interface ()
    page ;; -> SXML
    create-html-post ;; string (U path-string (listof string)) ... -> SXML
    ))

(define blogger-post<%>
  (interface ()
    page ;; -> SXML
    ))

;; ============================================================

(define blogger-scope "http://www.blogger.com/feeds/")

;; ============================================================

(define (blogger-user #:oauth2 oauth2)
  (new blogger-user% (oauth2 oauth2)))

(define blogger-user%
  (class* object% (blogger-user<%>)
    (init-field oauth2)
    (super-new)

    (field [blog-cache
            (new child-cache%
                 (make-child
                  (lambda (blog-id entry)
                    (new blogger%
                         (oauth2 oauth2)
                         (profile this)
                         (blog-id blog-id)
                         (entry entry)))))])

    (define/public (get-oauth2) oauth2)

    (define/public (find-blog blog-name [default not-given]
                              #:who [who 'blogger-user:find-blog])
      (let* ([blogs (list-blogs #:who who)]
             [blog (for/or ([blog (in-list blogs)])
                     (and (equal? (send blog get-title) blog-name) blog))])
        (cond [blog blog]
              [(eq? default not-given)
               (error who "blog not found: ~e" blog-name)]
              [(procedure? default) (default)]
              [else default])))

    (define/public (list-blogs #:who [who 'blogger-user:list-blogs])
      (let* ([doc (page #:who who)]
             [entries ((lift-sxpath "//atom:entry" (xpath-nss 'atom)) doc)])
        (for/list ([entry (in-list entries)])
          (let* ([link (atom:get-self-link entry)]
                 [blog-id (cadr (regexp-match #rx"/feeds/[^/]*/blogs/([^/]*)" link))])
            (send blog-cache intern blog-id entry)))))

    (define/public (page #:who [who 'blogger-user:page])
      (get/url (url-for-blog-list)
               #:headers (headers)
               #:handle read-sxml
               #:who who))

    (define/private (url-for-blog-list)
      (format "http://www.blogger.com/feeds/default/blogs"))

    (define/public (headers [content-type #f])
      (append (case content-type
                ((atom) '("Content-Type: application/atom+xml"))
                (else null))
              '("GData-Version: 2")
              (send oauth2 headers)))
    ))

;; blogger% represents one blog
(define blogger%
  (class* child% (blogger<%>)
    (init-field oauth2
                profile
                blog-id
                entry)
    (super-new)

    (field [post-cache
            (new child-cache%
                 (make-child
                  (lambda (post-id entry)
                    (new blogger-post% (parent this) (post-id post-id) (entry entry)))))])

    (define/public (get-blog-id) blog-id)
    (define/public (get-title) (atom:get-title entry))

    (define/override (update! new-entry)
      (super update! new-entry)
      (set! entry new-entry))

    ;; ----

    (define/public (list-posts #:who [who 'blogger:list-posts])
      (let* ([doc (page #:who who)]
             [entries ((lift-sxpath "//atom:entry" (xpath-nss 'atom)) doc)])
        (for/list ([entry (in-list entries)])
          (let* ([post-id (atom:get-id entry)])
            (send post-cache intern post-id entry)))))

    (define/public (find-post post-title
                              [default not-given]
                              #:who [who 'blogger:find-post])
      (let* ([posts (list-posts #:who who)]
             [post (for/or ([post (in-list posts)])
                     (and (equal? (send post get-title) post-title) post))])
        (cond [post post]
              [(eq? default not-given)
               (error who "post not found: ~e" post-title)]
              [(procedure? default) (default)]
              [else default])))

    ;; ----

    (define/public (page #:who [who 'blogger:page])
      (get/url (url-for-page)
               #:headers (headers)
               #:handle read-sxml
               #:who who))

    (define/private (url-for-page)
      (format "http://www.blogger.com/feeds/~a/posts/default" blog-id))

    ;; ----

    (define/public (create-html-post title html
                                     #:draft? [draft? #f]
                                     #:tags [tags null]
                                     #:who [who 'blogger:create-html-post])
      ;; html is either literal list of strings or name of HTML file
      (post/url (url-for-create-post)
                #:headers (headers 'atom)
                #:data (let ([body (create-html-post/doc title html draft? tags)])
                         (srl:sxml->xml body))
                #:handle (lambda (in)
                           (let ([entry (read-sxml in)])
                             (send post-cache intern
                                   (atom:get-id entry)
                                   entry)))
                #:who who))

    (define/private (create-html-post/doc title html draft? tags)
      ;; Include the contents of html-file in doc as a *string*;
      ;; that way its markup gets escaped when atom xml is written.
      (let ([body
             (cond [(list? html) html]
                   [else (list (call-with-input-file html port->string))])])
        `(*TOP*
          (@ (*NAMESPACES*
              (atom "http://www.w3.org/2005/Atom")
              (app  "http://www.w3.org/2007/app")))
          (*PI* xml "version='1.0' encoding='UTF-8'")
          (atom:entry
           (atom:title (@ (type "text")) ,title)
           (atom:content (@ (type "html")) ,@body)
           ,@(for/list ([tag (in-list tags)])
               `(atom:category (@ (scheme "http://www.blogger.com/atom/ns#")
                                  (term ,tag))))
           ,@(cond [draft? '((app:control (app:draft "yes")))]
                   [else '()])))))

    (define/private (url-for-create-post)
      (atom:get-link/rel "http://schemas.google.com/g/2005#post" entry))

    ;; ----

    (define/public (headers [content-type #f])
      (send profile headers content-type))

    ))

(define blogger-post%
  (class* child% (blogger-post<%>)
    (init-field parent
                post-id
                entry)
    (inherit check-valid)
    (super-new)

    (define/override (update! new-entry)
      (super update! new-entry)
      (set! entry new-entry))

    (define/public (get-title) (atom:get-title entry))
    (define/public (get-edit-link) (atom:get-edit-link entry))
    (define/public (get-self-link) (atom:get-self-link entry))

    (define/public (page #:who [who 'blogger-post:page])
      (check-valid who)
      (get/url (get-self-link)
               #:headers (send parent headers)
               #:handle read-sxml
               #:who who))

    (define/public (get-html-contents #:who [who 'blogger-post:get-html-contents])
      (check-valid who)
      (let* ([doc (page #:who who)]
             [contents
              ((lift-sxpath "/atom:entry/atom:content[@type='html']" (xpath-nss 'atom)) doc)])
        (cond [(pair? contents)
               ((lift-sxpath "/text()" (xpath-nss 'atom)) (car contents))]
              [else (error who "no html contents")])))

    (define/public (delete #:who [who 'blogger-post:delete])
      (check-valid who)
      (delete/url (get-edit-link)
                  #:headers (send parent headers)
                  #:handle void
                  #:who who)
      (send (get-field post-cache parent) eject! post-id))

    ))
