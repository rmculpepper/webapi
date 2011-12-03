#lang racket/base
(require "private/oauth2.rkt"
         "private/unstable-lazy-require.rkt")
(provide oauth2-auth-server<%>
         oauth2-auth-server

         oauth2-client<%>
         oauth2-client

         oauth2<%>
         oauth2%
         oauth2/auth-code
         oauth2/refresh-token

         google-auth-server)

(lazy-require
 ["private/oauth2-web.rkt"
  (oauth2/request-auth-code/browser)])

(provide oauth2/request-auth-code/browser)
