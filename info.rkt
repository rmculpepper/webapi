;; Copyright 2011 Ryan Culpepper
;; Released under the terms of the LGPL version 3 or later.
;; See the file COPYRIGHT for details.

#lang setup/infotab

(define name "webapi")
;; (define compile-omit-paths '("tests"))
(define scribblings '(("scribblings/webapi.scrbl" (multi-page))))

(define blurb
  '("Rudimentary implementations of a few web APIs, "
    "including OAuth2, PicasaWeb, and Blogger."))
(define categories '(io net xml))
(define can-be-loaded-with 'all)
;;(define primary-file "main.rkt")
(define required-core-version "5.1")
(define repositories '("4.x"))

(define release-notes
  '("Initial release."))
