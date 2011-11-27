#lang racket/base
(require racket/class
         racket/port
         net/url
         net/uri-codec
         "atom.rkt"
         "oauth2.rkt"
         "util/net.rkt"
         "util/has-atom.rkt"
         "util/sxml.rkt"
         (planet clements/sxml2:1))
(provide picasa-scope
         picasa<%>
         picasa-album<%>
         picasa-photo<%>
         picasa)

#|
Reference:
http://code.google.com/apis/picasaweb/docs/2.0/developers_guide_protocol.html
|#

#|
TODO
 - support update album/image metadata
 - tags?
|#

(define picasa-scope "https://picasaweb.google.com/data/")

;; ============================================================

(define picasa<%>
  (interface (has-atom<%>)
    list-albums     ;; -> (listof album<%>)
    find-album      ;; string [default] -> album<%>
    create-album    ;; string -> album<%>
    ))

(define picasa-album<%>
  (interface (has-atom<%>)
    list-photos   ;; -> (listof photo<%>)
    find-photo    ;; string -> photo<%>
    delete        ;; -> void
    create-photo  ;; path-string string -> photo<%>
    ))

(define picasa-photo<%>
  (interface (has-atom<%>)
    delete  ;; -> void
    ))

;; ============================================================

(define picasa%
  (class* has-atom/parent% (picasa<%>)
    (init-field oauth2)
    (inherit get-atom
             list-children
             find-child-by-title
             intern)
    (super-new)

    ;; ==== Overrides ====

    (define/override (make-child atom)
      (new picasa-album% (parent this) (atom atom)))

    (define/override (internal-get-atom #:who who)
      (get/url "https://picasaweb.google.com/data/feed/api/user/default"
               #:headers (headers)
               #:handle read-sxml
               #:who who))

    ;; ==== List albums ====

    (define/public (list-albums #:reload? [reload? #f]
                                #:who [who 'picasa:list-albums])
      (list-children #:reload? reload? #:who who))

    (define/public (find-album album-name
                               #:reload? [reload? #f]
                               #:who [who 'picasa:find-album])
      (find-child-by-title album-name #:reload? reload? #:who who))

    ;; ==== Create album ====

    #|
    ** regarding access/visibility:

    The api docs claim that there are only two access modes: public
    and private. But the web site has three: public, private,
    and "limited", which means the album isn't listed, but its contents
    can be linked to publicly---useful for blogs, etc.

    I think this is what Steve Yegge was ranting about.

    For now, create as public. If you want, go change it via web interface.
    |#

    (define/public (create-album title
                                 #:access [access "public"]
                                 #:who [who 'picasa:create-album])
      (post/url (send (get-atom) get-link "http://schemas.google.com/g/2005#post")
                #:headers (headers 'atom)
                #:data (srl:sxml->xml (create-album/doc title #:access access))
                #:handle (lambda (in) (intern (new atom% (sxml (read-sxml in)))))
                #:who who
                #:fail "album creation failed"))

    (define/private (create-album/doc title
                                      #:access [access "public"])
      `(*TOP*
        (@ (*NAMESPACES*
            (atom "http://www.w3.org/2005/Atom")
            (gphoto "http://schemas.google.com/photos/2007")))
        (*PI* xml "version='1.0' encoding='UTF-8'")
        (atom:entry
         (atom:title (@ (type "text")) ,title)
         (atom:summary (@ (type "text")) "")
         (gphoto:access ,access)
         (atom:category (@ (scheme "http://schemas.google.com/g/2005#kind")
                           (term   "http://schemas.google.com/photos/2007#album"))))))

    ;; ========================================

    (define/public (headers [content-type #f])
      (append (case content-type
                ((atom) '("Content-Type: application/atom+xml"))
                (else null))
              '("GData-Version: 2")
              (send oauth2 headers)))

    ))

(define (picasa #:oauth2 oauth2)
  (new picasa% (oauth2 oauth2)))

;; ============================================================

(define picasa-album%
  (class* has-atom/parent+child% (picasa-album<%>)
    (inherit-field parent)
    (inherit get-atom
             get-feed-atom
             list-children
             find-child-by-title
             intern
             reset!
             check-valid
             invalidate!)
    (super-new)

    ;; ==== Overrides ====

    (define/override (make-child atom)
      (new picasa-photo% (parent this) (atom atom)))

    (define/override (internal-get-atom #:who who)
      (check-valid who)
      (get/url (send (get-atom) get-link "self") ;; or #feed?
               #:headers (send parent headers)
               #:handle read-sxml
               #:who who))

    ;; ====

    (define/public (list-photos #:reload? [reload? #f]
                                #:who [who 'picasa-album:list-photos])
      (check-valid who)
      (list-children #:reload? reload? #:who who))

    (define/public (find-photo photo-title
                               #:reload? [reload? #f]
                               #:who [who 'picasa-album:find-photo])
      (check-valid who)
      (find-child-by-title photo-title #:reload? reload? #:who who))

    (define/public (delete #:who [who 'picasa-album:delete])
      (check-valid who)
      (delete/url (send (get-atom) get-link "edit")
                  #:headers (cons "If-Match: *" (send parent headers))
                  #:handle void
                  #:who who)
      (invalidate!))

    (define/public (create-photo image-path name
                                 #:who [who 'picasa-album:create-photo])
      (check-valid who)
      (post/url (send (get-atom) get-link "edit")
                #:headers (let ([type (image-path->content-type image-path)])
                            (list* (format "Content-Type: ~a" type)
                                   (format "Slug: ~a" name)
                                   (headers)))
                #:data (call-with-input-file image-path port->bytes)
                #:handle (lambda (in) (intern (read-sxml in)))
                #:who who))

    (define/private (image-path->content-type image-path)
      (cond [(regexp-match #rx"\\.png$" image-path) 'image/png]
            [else 'image/jpeg]))

    (define/public (headers [content-type #f])
      (send parent headers content-type))
    ))

;; ============================================================

(define picasa-photo%
  (class* has-atom/child% (picasa-photo<%>)
    (inherit-field parent)
    (inherit get-atom
             check-valid
             invalidate!)
    (super-new)

    ;; ==== Overrides ====

    (define/override (internal-get-atom #:who who)
      (check-valid who)
      ;; value of atom:icon ?
      (get/url (send (get-atom) get-link "self")
               #:headers (send parent headers)
               #:handle read-sxml
               #:who who))

    ;; ====

    (define/public (delete #:who [who 'picasa-photo:delete])
      (check-valid who)
      (delete/url (send (get-atom) get-link "edit")
                  #:headers (cons "If-Match: *" (send parent headers))
                  #:handle void
                  #:who who
                  #:fail "photo deletion failed")
      (invalidate!))
    ))
