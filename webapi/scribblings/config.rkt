;; Copyright 2011-2013 Ryan Culpepper
;; Released under the terms of the LGPL version 3 or later.
;; See the file COPYRIGHT for details.

#lang racket/base
(require scribble/manual
         scribble/eval
         (for-label racket/base
                    racket/class
                    racket/contract))
(provide (all-defined-out)
         (for-label (all-from-out racket/base)
                    (all-from-out racket/class)
                    (all-from-out racket/contract)))

;; ----

(define the-eval (make-base-eval))

(void
 (the-eval
  `(require racket/class
            webapi/oauth2)))

(define-syntax-rule (examples/results [example result] ...)
  (examples #:eval the-eval (eval:alts example result) ...))
(define-syntax-rule (my-interaction [example result] ...)
  (interaction #:eval the-eval (eval:alts example result) ...))
