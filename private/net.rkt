#lang racket/base
(require racket/match
         openssl
         net/url
         net/url-connect)
(provide get/url
         head/url
         delete/url
         post/url
         put/url

         url-add-query
         form-headers)

;; Turn on verification on unix systems where ca-certificates.crt exists.
(define verifying-ssl-context
  (let ([ctx (ssl-make-client-context)])
    (case (system-type 'os)
      ((unix)
       (let ([root-ca-file "/etc/ssl/certs/ca-certificates.crt"])
         (when (file-exists? root-ca-file)
           (ssl-set-verify! ctx #t)
           (ssl-load-verify-root-certificates! ctx root-ca-file))))
      ((macosx)
       ;; FIXME: ???
       (void))
      ((windows)
       ;; FIXME: ???
       (void)))
    ctx))

#|
TODO: add redirect option like get-pure-port
|#

(define (do-method who url method data?
                   handle fail headers data ok-rx)
  (let* ([url (if (string? url) (string->url url) url)]
         [data (if (string? data) (string->bytes/utf-8 data) data)])
    (unless (equal? (url-scheme url) "https")
      (error who "insecure location (expected `https' scheme): ~e" (url->string url)))
    (call/input-url url
      (lambda (url)
        (parameterize ((current-https-protocol
                        (if (ssl-client-context? (current-https-protocol))
                            (current-https-protocol)
                            verifying-ssl-context)))
          (if data?
              (method url data headers)
              (method url headers))))
      (lambda (in)
        (let ([response-header (purify-port in)])
          (cond [(regexp-match? ok-rx response-header)
                 (handle in)]
                [else
                 (if (string? fail)
                     (error who "~a: ~e" fail
                            (read-line (open-input-string response-header) 'any))
                     (fail response-header in))]))))))

(define (get-code header)
  (cadr (regexp-match #rx"^HTTP/1\\.. ([0-9]*)" header)))

(define std-ok-rx #rx"^HTTP/1\\.. 20.")

;; TODO: add separate rx & handler for auth failures
;; so that clients can call refresh-token

;; ----

(define (mk-no-data-method method)
  (lambda (url
           #:headers [headers null]
           #:handle [handle void]
           #:who [who 'get-url]
           #:fail [fail "failed"]
           #:ok-rx [ok-rx std-ok-rx])
    (do-method who url method #f
               handle fail headers #f ok-rx)))

(define get/url (mk-no-data-method get-impure-port))
(define head/url (mk-no-data-method head-impure-port))
(define delete/url (mk-no-data-method delete-impure-port))

(define (mk-data-method method)
  (lambda (url
           #:headers [headers null]
           #:data [data #f]
           #:handle [handle void]
           #:who [who 'get-url]
           #:fail [fail "failed"]
           #:ok-rx [ok-rx std-ok-rx])
    (do-method who url method #t
               handle fail headers data ok-rx)))

(define post/url (mk-data-method post-impure-port))
(define put/url (mk-data-method put-impure-port))

;; ----

;; url-add-query : string/url alist -> url
(define (url-add-query base-url query-alist)
  (match (if (string? base-url) (string->url base-url) base-url)
    [(url scheme user host port path-abs? path query fragment)
     (let ([query (append query query-alist)])
       (url scheme user host port path-abs? path query fragment))]))

(define (form-headers)
  (list "Content-Type: application/x-www-form-urlencoded"))
