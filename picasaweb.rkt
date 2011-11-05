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
(provide (all-defined-out))

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

(define picasaweb-scope "https://picasaweb.google.com/data/")

;; ============================================================

(define picasaweb<%>
  (interface ()
    list-albums     ;; -> (listof album<%>)
    find-album      ;; string [default] -> album<%>

    page            ;; -> sxml
    album-page      ;; string -> sxml

    create-album    ;; string -> album<%>
    delete-album    ;; string -> void
    ))

(define picasaweb-album<%>
  (interface ()
    valid?        ;; -> boolean
    page          ;; -> sxml
    delete        ;; -> void
    create-photo  ;; path-string string -> picasaweb-photo<%>
    ))

(define picasaweb-photo<%>
  (interface ()
    valid?  ;; -> boolean
    page    ;; -> sxml
    delete  ;; -> void
    ))

;; ============================================================

(define picasaweb%
  (class* object% (picasaweb<%>)
    (init-field oauth2
                user-id)
    (super-new)

    ;; ==== Tables & Caches ====

    (field [album-cache
            (new child-cache%
                 (make-child (lambda (album-id aux)
                               (new picasaweb-album% (parent this) (album-id album-id)))))])

    ;; ==== List albums ====

    (define/public (list-albums #:who [who 'picasaweb:list-albums])
      (let* ([doc (page #:who who)]
             [album-ids ((lift-sxpath "//gphoto:id/text()" (xpath-nss 'gphoto)) doc)])
        (for/list ([album-id (in-list album-ids)]) (send album-cache intern album-id #f))))

    (define/public (find-album album-name [default not-given]
                               #:who [who 'picasaweb:find-album])
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

    (define/public (page #:who [who 'picasaweb:page])
      (get/url (url-for-user-page user-id)
               #:headers (headers)
               #:handle read-sxml
               #:who who))

    (define/private (url-for-user-page user-id)
      (format "https://picasaweb.google.com/data/feed/api/user/~a" user-id))

    ;; ==== Album page ====

    (define/public (album-page album-name)
      (let ([a (find-album album-name #:who 'picasaweb:album-page)])
        (send a page #:who 'picasaweb:album-page)))

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
                                 #:who [who 'picasaweb:create-album])
      (post/url (url-for-create-album user-id)
                #:headers (headers 'atom)
                #:data (srl:sxml->xml (create-album/doc title #:access access))
                #:handle (lambda (in)
                           (send album-cache intern (extract-album-id (read-sxml in)) #f))
                #:who who
                #:fail "album creation failed"))

    (define/private (url-for-create-album)
      (format "https://picasaweb.google.com/data/feed/api/user/~a" user-id))

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

    (define/public (delete-album album-name #:who [who 'picasaweb:delete-album])
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

;; ============================================================

(define picasaweb-album%
  (class* object% (picasaweb-album<%> child<%>)
    (init-field parent album-id)
    (super-new)

    (field [photo-cache
            (new child-cache%
                 (make-child
                  (lambda (photo-id aux)
                    (new picasaweb-photo%
                         (user parent) (album this) (photo-id photo-id)))))])

    (define is-valid? #t)
    (define/public (valid?) is-valid?)
    (define/public (invalidate!)
      (set! is-valid? #f)
      (send photo-cache reset! null))
    (define/private (check-valid who)
      (unless is-valid? (error who "album is no longer valid")))
    (define/public (update! aux) (void))

    (define/public (list-photos #:who [who 'picasaweb-album:list-photos])
      (let* ([doc (page #:who who)]
             [photo-ids ((lift-sxpath "//atom:entry//gphoto:id/text()"
                                      (xpath-nss 'atom 'gphoto))
                         doc)])
        (for/list ([photo-id (in-list photo-ids)])
          (send photo-cache intern photo-id #f))))

    (define/public (page #:who [who 'picasaweb-album:page])
      (check-valid who)
      (get/url (url-for-album)
               #:headers (send parent headers)
               #:handle read-sxml
               #:who who))

    (define/public (delete #:who [who 'picasaweb-album:delete])
      (check-valid 'picasaweb-album:delete)
      (delete/url (url-for-delete-album)
                  #:headers (cons "If-Match: *" (send parent headers))
                  #:handle void
                  #:who who
                  #:fail "album deletion failed")
      (send (get-field album-cache parent) eject album-id))

    (define/public (create-photo image-path name)
      (check-valid 'picasaweb-album:create-photo)
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
                #:who 'picasaweb:create-photo))

    (define/private (url-for-create-photo)
      (format "https://picasaweb.google.com/data/feed/api/user/~a/albumid/~a"
              (get-field user-id parent) album-id))

    (define/private (image-path->content-type image-path)
      (cond [(regexp-match #rx"\\.png$" image-path) 'image/png]
            [else 'image/jpeg]))

    (define/private (extract-photo-id doc)
      (define link ((lift-sxpath "//gphoto:id/text()" (xpath-nss 'gphoto)) doc))
      (car link))

    ;; ----

    (define/private (url-for-album)
      (format "https://picasaweb.google.com/data/feed/api/user/~a/albumid/~a"
              (get-field user-id parent) album-id))

    (define/private (url-for-delete-album)
      (format "https://picasaweb.google.com/data/entry/api/user/~a/albumid/~a"
              (get-field user-id parent) album-id))

    ))

;; ============================================================

(define picasaweb-photo%
  (class* object% (picasaweb-photo<%> child<%>)
    (init-field user
                album
                photo-id)
    (super-new)

    (define is-valid? #t)
    (define/public (valid?) is-valid?)
    (define/public (invalidate!) (set! is-valid? #f))
    (define/private (check-valid who)
      (unless is-valid? (error who "photo is no longer valid")))
    (define/public (update! aux) (void))

    (define/public (page #:who [who 'picasaweb-photo:page])
      (check-valid who)
      ;; value of atom:icon ?
      (get/url (url-for-photo)
               #:headers (send user headers)
               #:handle read-sxml
               #:who who))

    (define/public (delete #:who [who 'picasaweb-photo:delete])
      (check-valid who)
      (delete/url (url-for-delete-photo)
                  #:headers (cons "If-Match: *" (send user headers))
                  #:handle void
                  #:who who
                  #:fail "photo deletion failed")
      (send (get-field photo-cache album) eject! photo-id))

    ;; ----

    (define/private (url-for-photo)
      (format "https://picasaweb.google.com/data/feed/api/user/~a/albumid/~a/photoid/~a"
              (get-field user-id user)
              (get-field album-id album)
              photo-id))

    (define/private (url-for-delete-photo)
      (format "https://picasaweb.google.com/data/entry/api/user/~a/albumid/~a/photoid/~a"
              (get-field user-id user)
              (get-field album-id album)
              photo-id))

    ))
