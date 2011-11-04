#lang racket/base
(require (only-in mzlib/etc begin-lifted)
         (planet clements/sxml2:1))
(provide read-sxml
         namespace-names
         xpath-nss
         lift-sxpath
         not-given)

(define (read-sxml in) (ssax:xml->sxml in namespace-names))

(define namespace-names
  '((atom . "http://www.w3.org/2005/Atom")
    (gphoto . "http://schemas.google.com/photos/2007")))

(define (xpath-nss . nss)
  (map cons nss (map symbol->string nss)))

(define-syntax-rule (lift-sxpath arg ...)
  (begin-lifted (sxpath arg ...)))

(define not-given (gensym 'not-given))
