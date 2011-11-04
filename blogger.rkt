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
Blogger
Reference: http://code.google.com/apis/blogger/docs/2.0/developers_guide_protocol.html
|#

(define blogger-scope "http://www.blogger.com/feeds/")

;; ============================================================

;; blogger-user% represents a profile-id, which may own many blogs
(define blogger-user%
  (class* object% (#| blogger-user<%> |#)
    (init-field oauth2
                profile-id)
    (super-new)

    (field [blog-cache
            (new child-cache%
                 (make-child
                  (lambda (blog-id title)
                    (new blogger%
                         (oauth2 oauth2)
                         (profile this)
                         (blog-id blog-id)
                         (title title)))))])

    (define/public (get-oauth2) oauth2)
    (define/public (get-profile-id) profile-id)

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
        (define get-link
          (lift-sxpath "//atom:link[@rel='self']/@href/text()" (xpath-nss 'atom)))
        (define get-title
          (lift-sxpath "//atom:title/text()" (xpath-nss 'atom)))
        (for/list ([entry (in-list entries)])
          (let* ([link (car (get-link entry))]
                 [title (car (get-title entry))]
                 [blog-id (cadr (regexp-match #rx"/feeds/[^/]*/blogs/([^/]*)" link))])
            (send blog-cache intern blog-id title)))))

    (define/public (page #:who [who 'blogger-user:page])
      (get/url (url-for-blog-list profile-id)
               #:headers (headers)
               #:handle read-sxml
               #:who who))

    (define/private (url-for-blog-list profile-id)
      (format "http://www.blogger.com/feeds/~a/blogs" profile-id))

    (define/public (headers [content-type #f])
      (append (case content-type
                ((atom) '("Content-Type: application/atom+xml"))
                (else null))
              '("GData-Version: 2")
              (send oauth2 headers)))
    ))

;; blogger% represents one blog associated with a profile-id
(define blogger%
  (class* object% (#| blogger<%> |#)
    (init-field oauth2
                profile
                blog-id
                title)
    (super-new)

    (define/public (get-blog-id) blog-id)
    (define/public (get-title) title)
    (define/public (valid?) #t)
    (define/public (update! aux) (void))

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
      (post/url (url-for-post)
                #:headers (headers 'atom)
                #:data (let ([body (create-html-post/doc title html draft? tags)])
                         (srl:sxml->xml body))
                #:handle read-sxml
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

    (define/private (url-for-post)
      (format "http://www.blogger.com/feeds/~a/posts/default" blog-id))

    ;; ----

    (define/public (headers [content-type #f])
      (send profile headers content-type))

    ))
