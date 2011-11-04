#lang racket/base
(require racket/class
         racket/string
         net/url
         net/uri-codec
         "util/net.rkt"
         (planet neil/json-parsing:1))
(provide oauth2-auth-server<%>
         oauth2-auth-server
         oauth2-get-auth-url

         oauth2-client<%>
         oauth2-client

         oauth2<%>
         oauth2%
         oauth2/auth-code
         oauth2/refresh-token

         google-auth-server)

#|
Based on working draft: http://tools.ietf.org/html/draft-ietf-oauth-v2-16
Draft expires 11/20/2011.

"Tested" with Google oauth2 service; may or may not work with others yet.

The draft recommends using Basic Authentication for client
credentials, but we only support sending client_secret in query.
|#

;; ============================================================

(define oauth2-auth-server<%>
  ;; Corresponds to "authorization server" in draft
  ;; Also speaks for "resource owner" (grants initial auth-code)
  ;; - for google, effectively the same; may need to split in future
  (interface ()
    ;; Corresponds to "Authorization Endpoint" in draft section 2.1
    get-auth-url  ; -> url/string

    ;; Corresponds to "Token Endpoint" in draft section 2.2 (??)
    get-token-url ; -> url/string
    ))

(define oauth2-client<%>
  ;; Corresponds to "client" in draft
  (interface ()
    get-id     ;; -> string
    get-secret ;; -> string
    ))

(define oauth2<%>
  (interface ()
    get-client        ;; -> oauth2-client<%>
    get-client-id     ;; -> string
    get-scopes        ;; -> (listof string)
    get-access-token  ;; [boolean] -> string/#f
    refresh-token!    ;; -> void
    headers           ;; -> (listof string)
    ))

;; ============================================================

(define OOB-uri "urn:ietf:wg:oauth:2.0:oob")

;; ============================================================

(define oauth2-auth-server%
  (class* object% (oauth2-auth-server<%>)
    (init-field auth-url
                token-url)
    (super-new)
    (define/public (get-auth-url) auth-url)
    (define/public (get-token-url) token-url)))

(define (oauth2-auth-server #:auth-url auth-url
                            #:token-url token-url)
  (new oauth2-auth-server% (auth-url auth-url) (token-url token-url)))

#|
OAuth2 for Google
Reference: http://code.google.com/apis/accounts/docs/OAuth2.html

 - When your access token expires, our API endpoints will respond
   with HTTP 401 Unauthorized.
|#

(define google-auth-server
  (oauth2-auth-server #:auth-url "https://accounts.google.com/o/oauth2/auth"
                      #:token-url "https://accounts.google.com/o/oauth2/token"))

;; ============================================================

(define (oauth2-get-auth-url #:auth-server auth-server
                             #:client client
                             #:scopes scopes
                             #:redirect-uri [redirect-uri OOB-uri]
                             #:state [state #f])
  (url->string
   (url-add-query (send auth-server get-auth-url)
                  `((response_type . "code")
                    (client_id . ,(send client get-id))
                    (redirect_uri . ,redirect-uri)
                    (scope . ,(string-join scopes " "))
                    (state . ,(or state ""))))))

;; ============================================================

(define oauth2-client%
  (class* object% (oauth2-client<%>)
    (init-field id secret)
    (super-new)
    (define/public (get-id) id)
    (define/public (get-secret) secret)))

(define (oauth2-client #:id id #:secret secret)
  (new oauth2-client% (id id) (secret secret)))

;; ============================================================

(define oauth2%
  (class* object% (oauth2<%>)
    (init-field client
                auth-server
                [re-acquire-callback #f])
    (field [scopes null]
           [token-type #f]
           [access-token #f]
           [refresh-token #f]
           [expiration +inf.0])
    (super-new)

    #|
    Several modes:
     - start with access token, no re-acquire on expiration
     - acquire both access and refresh tokens from auth-key
       when access token expires, re-acquire using refresh token
     - start with previously-acquired refresh token
       get access token when needed using refresh token
     - acquire only access token using auth-key,
       no re-acquire on expiration
     - acquire only access token via response-owner-authorization
       ("implicit grant"), re-acquire same way

    This code makes the following assumptions:
     - if we have a refresh token, we use it
     - otherwise, if a re-acquire-callback is given, we use it

    The re-acquire-callback can be used to prompt a web interaction,
    for example.
    |#

    ;; ----

    (define/public (get-auth-server) auth-server)
    (define/public (get-client) client)
    (define/public (get-client-id) (send client get-id))
    (define/public (get-scopes) scopes)

    (define/public (get-access-token #:re-acquire? [re-acquire? #t]
                                     #:who [who 'oauth2:get-access-token])
      (cond [(< (current-inexact-milliseconds) expiration)
             access-token]
            [re-acquire?
             (re-acquire-token! #:who who)
             access-token]
            [else #f]))

    (define/public (re-acquire-token! #:who [who 'oauth2:re-acquire-token!])
      (cond [refresh-token
             (refresh-token! #:who who)]
            [re-acquire-callback
             (re-acquire-callback this)]
            [else
             (error who "access token expired; no method of re-acquiring access")]))

    (define/public (acquire-token/auth-code! auth-code
                                             #:redirect-uri [redirect-uri OOB-uri]
                                             #:who [who 'oauth2:acquire-token/auth-code!])
      (let* ([now (current-inexact-milliseconds)]
             [json (acquire-token/auth-code/json #:auth-code auth-code
                                                 #:redirect-uri redirect-uri)])
        (reset-from-json! who now json)))

    (define/public (refresh-token! #:who [who 'oauth2:refresh-token!])
      (unless refresh-token (error who "refresh-token not available"))
      (let* ([now (current-inexact-milliseconds)]
             [json (refresh-token/json #:who who)])
        (reset-from-json! who now json)))

    ;; ----

    (define/public (acquire-token/auth-code/json #:auth-code auth-code
                                                 #:redirect-uri redirect-uri
                                                 #:who [who 'oauth2:acquire-token/auth-code/json])
      (post/url (send auth-server get-token-url)
                #:headers (form-headers)
                #:data (body/acquire-token #:auth-code auth-code
                                           #:redirect-uri redirect-uri)
                #:handle json->sjson
                ;; FIXME: add #:fail arg that reads json error response
                #:who who))

    (define/public (body/acquire-token #:auth-code auth-code
                                       #:redirect-uri redirect-uri)
      (alist->form-urlencoded
       `((grant_type . "authorization_code")
         (client_id . ,(send client get-id))
         (client_secret . ,(send client get-secret))
         (code . ,auth-code)
         (redirect_uri . ,redirect-uri))))

    (define/public (refresh-token/json #:who [who 'oauth2:refresh-token/json])
      (post/url (send auth-server get-token-url)
                #:headers (form-headers)
                #:data (body/refresh-token)
                #:handle json->sjson
                ;; FIXME: add #:fail arg that reads json error response
                #:who who))

    (define/public (body/refresh-token)
      (alist->form-urlencoded
       `((grant_type . "refresh_token")
         (client_id . ,(send client get-id))
         (client_secret . ,(send client get-secret))
         (refresh_token . ,refresh-token)
         #| (scopes . ,(string-join scopes " ")) |#)))

    #|
    On success, requests return JSON
    doc as hasheq containing the following fields:
      - access_token : the token
      - token_type : eg, "Bearer"
      - expires_in (optional) : number of seconds
      - refresh_token (optional)
      - scope : space-separated, only if scope granted narrower than requested
    |#

    (define/public (reset-from-json! who now json)
      (let* ([new-access-token (hash-ref json 'access_token)]
             [new-token-type (hash-ref json 'token_type)]
             [new-refresh-token (hash-ref json 'refresh_token #f)]
             [new-scope (hash-ref json 'scope "")]
             [new-expires-in (hash-ref json 'expires_in +inf.0)])
        (unless (string-ci=? new-token-type "Bearer")
          (error who "unsupported token type: ~e" new-token-type))
        (set! access-token new-access-token)
        (set! token-type new-token-type)
        (when new-refresh-token
          (set! refresh-token new-refresh-token))
        (set! expiration (+ now (* 1000 new-expires-in)))
        (unless (equal? new-scope "")
          (set! scopes (regexp-split #rx" +" new-scope)))
        (void)))

    ;; ----

    (define/public (headers)
      (list (format "Authorization: Bearer ~a" (get-access-token))))
    ))

;; ----

(define (oauth2/auth-code auth-server client auth-code
                          #:redirect-uri [redirect-uri OOB-uri])
  (let ([oauth2 (new oauth2% (auth-server auth-server) (client client))])
    (send oauth2 acquire-token/auth-code!
          auth-code
          #:redirect-uri redirect-uri
          #:who 'oauth2/auth-code)
    oauth2))

(define (oauth2/refresh-token auth-server client refresh-token
                              #:redirect-uri [redirect-uri OOB-uri])
  (let ([oauth2 (new oauth2% (auth-server auth-server) (client client))])
    (set-field! refresh-token oauth2 refresh-token)
    (send oauth2 refresh-token! #:who 'oauth2/refresh-token)
    oauth2))
