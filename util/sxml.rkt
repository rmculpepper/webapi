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
    (app . "http://www.w3.org/2007/app")
    (gphoto . "http://schemas.google.com/photos/2007")))

(define (xpath-nss . nss)
  (map cons nss (map symbol->string nss)))

(define-syntax-rule (lift-sxpath arg ...)
  (begin-lifted (sxpath arg ...)))

(define not-given (gensym 'not-given))

;; -- Atom utils --

(provide atom:get-id
         atom:get-title
         atom:get-edit-link
         atom:get-self-link
         atom:get-link/rel)

(define (car* x) (and (pair? x) (car x)))
(define (atom:get-id doc)
  (car* ((lift-sxpath "/atom:id/text()" (xpath-nss 'atom)) doc)))
(define (atom:get-title doc)
  (car* ((lift-sxpath "/atom:title/text()" (xpath-nss 'atom)) doc)))
(define (atom:get-edit-link doc)
  (car* ((lift-sxpath "/atom:link[@rel='edit']/@href/text()" (xpath-nss 'atom)) doc)))
(define (atom:get-self-link doc)
  (car* ((lift-sxpath "/atom:link[@rel='self']/@href/text()" (xpath-nss 'atom)) doc)))

(define (atom:get-link/rel rel doc)
  (car* ((sxpath (format "/atom:link[@rel='~a']/@href/text()" rel) (xpath-nss 'atom)) doc)))
