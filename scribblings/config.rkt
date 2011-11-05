;; Copyright 2011 Ryan Culpepper
;; Released under the terms of the LGPL version 3 or later.
;; See the file COPYRIGHT for details.

#lang racket/base
(require scribble/manual
         scribble/eval
         racket/sandbox
         planet/version
         planet/scribble
         (for-label racket/base
                    racket/class
                    racket/contract))
(provide (all-defined-out)
         (all-from-out planet/scribble)
         (for-label (all-from-out racket/base)
                    (all-from-out racket/class)
                    (all-from-out racket/contract)))

(define (my-package-version)
  (format "~a.~a" (this-package-version-maj) (this-package-version-min)))

;; ----
#|
(define the-eval (make-base-eval))
(void
 (interaction-eval #:eval the-eval
                   (require racket/class))
 (interaction-eval #:eval the-eval
                   (define oauth2% (class object% (super-new))))
)

(define-syntax-rule (examples/results [example result] ...)
  (examples #:eval the-eval (eval:alts example result) ...))
(define-syntax-rule (my-interaction [example result] ...)
  (interaction #:eval the-eval (eval:alts example result) ...))
|#
