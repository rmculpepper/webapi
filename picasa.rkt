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
 - cache pages
 - support update album/image metadata
 - tags?
|#

(define picasa-scope "https://picasaweb.google.com/data/")

;; ============================================================

(define picasa<%>
  (interface ()
    list-albums     ;; -> (listof album<%>)
    find-album      ;; string [default] -> album<%>

    page            ;; -> sxml
    album-page      ;; string -> sxml

    create-album    ;; string -> album<%>
    delete-album    ;; string -> void
    ))

(define picasa-album<%>
  (interface ()
    valid?        ;; -> boolean
    page          ;; -> sxml
    delete        ;; -> void
    create-photo  ;; path-string string -> photo<%>
    ))

(define picasa-photo<%>
  (interface ()
    valid?  ;; -> boolean
    page    ;; -> sxml
    delete  ;; -> void
    ))

;; ============================================================

(define picasa%
  (class* object% (picasa<%>)
    (init-field oauth2)
    (super-new)

    ;; ==== Tables & Caches ====

    (field [album-cache
            (new child-cache%
                 (make-child (lambda (album-id aux)
                               (new picasa-album% (parent this) (album-id album-id)))))])

    ;; ==== List albums ====

    (define/public (list-albums #:who [who 'picasa:list-albums])
      (let* ([doc (page #:who who)]
             [album-ids ((lift-sxpath "//gphoto:id/text()" (xpath-nss 'gphoto)) doc)])
        (for/list ([album-id (in-list album-ids)]) (send album-cache intern album-id #f))))

    (define/public (find-album album-name [default not-given]
                               #:who [who 'picasa:find-album])
      (let ([entry (get-album-entry who album-name default)])
        (send album-cache intern (extract-album-id entry) #f)))

    (define/private (get-album-entry who album-name [default not-given])
      (let* ([doc (page #:who who)]
             [entries ((lift-sxpath "//atom:entry" (xpath-nss 'atom)) doc)]
             [entry (for/or ([entry (in-list entries)])
                      (and (equal? ((lift-sxpath "//atom:title/text()" (xpath-nss 'atom)) entry)
                                   (list album-name))
                           entry))])
        (cond [entry entry]
              [(eq? default not-given)
               (error who "album not found: ~e" album-name)]
              [(procedure? default) (default)]
              [else default])))

    (define/private (extract-album-id doc)
      (let ([link ((lift-sxpath "//gphoto:id/text()" (xpath-nss 'gphoto)) doc)])
        (car link)))

    ;; ==== User page ====

    (define/public (page #:who [who 'picasa:page])
      (get/url (url-for-user-page)
               #:headers (headers)
               #:handle read-sxml
               #:who who))

    (define/private (url-for-user-page)
      (format "https://picasaweb.google.com/data/feed/api/user/default"))

    ;; ==== Album page ====

    (define/public (album-page album-name)
      (let ([a (find-album album-name #:who 'picasa:album-page)])
        (send a page #:who 'picasa:album-page)))

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
      (post/url (url-for-create-album)
                #:headers (headers 'atom)
                #:data (srl:sxml->xml (create-album/doc title #:access access))
                #:handle (lambda (in)
                           (send album-cache intern (extract-album-id (read-sxml in)) #f))
                #:who who
                #:fail "album creation failed"))

    (define/private (url-for-create-album)
      (format "https://picasaweb.google.com/data/feed/api/user/default"))

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

    ;; ==== Delete album ====

    (define/public (delete-album album-name #:who [who 'picasa:delete-album])
      (let ([a (find-album album-name #:who who)])
        (send a delete #:who who)))

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
  (class* child% (picasa-album<%>)
    (init-field parent album-id)
    (inherit check-valid)
    (super-new)

    (field [photo-cache
            (new child-cache%
                 (make-child
                  (lambda (photo-id aux)
                    (new picasa-photo%
                         (user parent) (album this) (photo-id photo-id)))))])

    (define/override (invalidate!)
      (super invalidate!)
      (send photo-cache reset! null))

    (define/public (list-photos #:who [who 'picasa-album:list-photos])
      (check-valid who)
      (let* ([doc (page #:who who)]
             [photo-ids ((lift-sxpath "//atom:entry//gphoto:id/text()"
                                      (xpath-nss 'atom 'gphoto))
                         doc)])
        (for/list ([photo-id (in-list photo-ids)])
          (send photo-cache intern photo-id #f))))

    (define/public (page #:who [who 'picasa-album:page])
      (check-valid who)
      (get/url (url-for-album)
               #:headers (send parent headers)
               #:handle read-sxml
               #:who who))

    (define/public (delete #:who [who 'picasa-album:delete])
      (check-valid who)
      (delete/url (url-for-delete-album)
                  #:headers (cons "If-Match: *" (send parent headers))
                  #:handle void
                  #:who who)
      (send (get-field album-cache parent) eject! album-id))

    (define/public (create-photo image-path name
                                 #:who [who 'picasa-album:create-photo])
      (check-valid who)
      (post/url (url-for-create-photo)
                #:headers (let ([type (image-path->content-type image-path)])
                            (list* (format "Content-Type: ~a" type)
                                   (format "Slug: ~a" name)
                                   (send parent headers)))
                #:data (call-with-input-file image-path port->bytes)
                #:handle (lambda (in)
                           (send photo-cache intern
                                 (extract-photo-id (read-sxml in))
                                 #f))
                #:who who))

    (define/private (url-for-create-photo)
      (format "https://picasaweb.google.com/data/feed/api/user/default/albumid/~a"
              album-id))

    (define/private (image-path->content-type image-path)
      (cond [(regexp-match #rx"\\.png$" image-path) 'image/png]
            [else 'image/jpeg]))

    (define/private (extract-photo-id doc)
      (define link ((lift-sxpath "//gphoto:id/text()" (xpath-nss 'gphoto)) doc))
      (car link))

    ;; ----

    (define/private (url-for-album)
      (format "https://picasaweb.google.com/data/feed/api/user/default/albumid/~a"
              album-id))

    (define/private (url-for-delete-album)
      (format "https://picasaweb.google.com/data/entry/api/user/default/albumid/~a"
              album-id))
    ))

;; ============================================================

(define picasa-photo%
  (class* child% (picasa-photo<%>)
    (init-field user
                album
                photo-id)
    (inherit check-valid)
    (super-new)

    (define/public (page #:who [who 'picasa-photo:page])
      (check-valid who)
      ;; value of atom:icon ?
      (get/url (url-for-photo)
               #:headers (send user headers)
               #:handle read-sxml
               #:who who))

    (define/public (delete #:who [who 'picasa-photo:delete])
      (check-valid who)
      (delete/url (url-for-delete-photo)
                  #:headers (cons "If-Match: *" (send user headers))
                  #:handle void
                  #:who who
                  #:fail "photo deletion failed")
      (send (get-field photo-cache album) eject! photo-id))

    ;; ----

    (define/private (url-for-photo)
      (format "https://picasaweb.google.com/data/feed/api/user/default/albumid/~a/photoid/~a"
              (get-field album-id album)
              photo-id))

    (define/private (url-for-delete-photo)
      (format "https://picasaweb.google.com/data/entry/api/user/default/albumid/~a/photoid/~a"
              (get-field album-id album)
              photo-id))

    ))
