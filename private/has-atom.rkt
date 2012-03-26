;; Copyright 2011-2012 Ryan Culpepper
;; Released under the terms of the LGPL version 3 or later.
;; See the file COPYRIGHT for details.

#lang racket/base
(require racket/class
         "../atom.rkt")
(provide (all-defined-out))

#|
;; Bug in mixin form causes problems...
(define-local-member-name
  internal-get-atom
  update-atom-cache!
  make-child
  intern
  eject!
  reset!
  valid?
  check-valid
  invalidate!
  update!)
|#

(define atom-resource<%>
  (interface ()
    get-atom      ;; [...] -> atom<%>
    get-feed-atom ;; [...] -> atom<%>
    get-atom-sxml ;; [...] -> SXML
    ;; ----
    get-id
    get-title
    ;; ----
    internal-get-atom  ;; -> SXML
    update-atom-cache! ;; atom<%> -> void
    ))

(define atom-feed-resource<%>
  (interface (atom-resource<%>)
    list-children
    find-children-by-title
    find-child-by-title
    find-child-by-id
    ;; ----
    make-child
    intern
    eject!
    reset!))

(define atom-resource/child<%>
  (interface ()
    valid?
    check-valid
    invalidate!
    update!
    ))

;; ----

(define atom-resource-mixin
  (mixin () (atom-resource<%>)
    (init-field [(atom* atom) #f])
    (super-new)

    (define/public (get-atom #:reload? [reload? #f]
                             #:who [who 'atom-resource:get-atom])
      (cache! reload? #:need-feed? #f #:who who)
      atom*)

    (define/public (get-feed-atom #:reload? [reload? #f]
                                  #:who [who 'atom-resource:get-feed])
      (cache! reload? #:need-feed? #t #:who who)
      atom*)

    (define/public (get-atom-sxml #:reload? [reload? #f]
                                  #:who [who 'atom-resource:get-atom-sxml])
      (send (get-atom #:reload? reload? #:who who) get-sxml))

    (define/public (get-id #:who [who 'atom-resource:get-id])
      (send (get-atom #:who who) get-id))

    (define/public (get-title #:who [who 'atom-resource:get-title])
      (send (get-atom #:who who) get-title))

    (define/private (cache! reload? #:need-feed? need-feed? #:who who)
      (when (or reload? (not atom*)
                (and need-feed? (not (send atom* is-feed?))))
        (update-atom-cache! (atom (internal-get-atom #:who who)))
        (void)))

    ;; Must override.
    (define/public (internal-get-atom #:who who)
      (error who "not implemented"))
    ;; May override.
    (define/public (update-atom-cache! new-atom)
      (set! atom* new-atom))
    ))

;; ----

(define atom-feed-resource-mixin
  (mixin (atom-resource<%>) (atom-feed-resource<%>)
    (field [table (make-hash)]) ;; id => child<%>
    (inherit get-atom
             get-feed-atom)
    (super-new)

    ;; make-child : atom<%> -> atom-resource/child<%>
    (define/public (make-child atom)
      (error 'atom-feed-resource-mixin:make-child "not implemented"))

    (define/public (intern atom)
      (let* ([key (send atom get-id)]
             [v (hash-ref! table key #f)])
        (cond [v (begin (send v update! atom) v)]
              [else (let ([v (make-child atom)])
                      (hash-set! table key v)
                      v)])))

    (define/public (eject! key)
      (let ([child (hash-ref table key #f)])
        (when child
          (send child invalidate!)
          (hash-remove! table key))))

    (define/override (update-atom-cache! a)
      (super update-atom-cache! a)
      (when (send a is-feed?) ;; FIXME: ???
        (reset! (for/hash ([child (in-list (send a get-entries))])
                  (values (send a get-id) a)))))

    (define/public (reset! key=>atom-hash)
      (let ([delenda
             (for/list ([key (in-hash-keys table)]
                        #:when (not (hash-has-key? key=>atom-hash key)))
               key)])
        (for ([key (in-list delenda)])
          (eject! key)))
      (for ([(key atom) (in-hash key=>atom-hash)])
        (intern atom)))

    ;; ----

    (define/public (list-children #:reload? [reload? #f]
                                  #:who [who 'atom-feed-resource:list-children])
      ;; Can't just get out of table, because want in order
      (let* ([feed (get-feed-atom #:reload? reload? #:who who)])
        (for/list ([child (in-list (send feed get-entries))])
          (intern child))))

    (define/public (find-children-by-title title
                                           #:reload? [reload? #f]
                                           #:who [who 'atom-feed-resource:find-children-by-title])
      (for/list ([child (in-list (list-children #:reload? reload? #:who who))]
                 #:when (equal? (send (send child get-atom) get-title) title))
        child))

    (define/public (find-child-by-title title
                                        #:reload? [reload? #f]
                                        #:who [who 'atom-feed-resource:find-child-by-title])
      (for/first ([child (in-list (find-children-by-title title #:reload? reload? #:who who))])
        child))

    (define/public (find-child-by-id id
                                     #:reload? [reload? #f]
                                     #:who [who 'atom-feed-resource:find-child-by-id])
      (for/first ([child (in-list (list-children #:reload? reload? #:who who))]
                  #:when (equal? id (send child get-id)))
        child))

    ))

(define atom-resource/child-mixin
  (mixin (atom-resource<%>) (atom-resource/child<%>)
    (init-field parent)
    (define is-valid? #t)
    (inherit get-atom)
    (super-new)

    (define/public (valid?) is-valid?)
    (define/public (check-valid who)
      (unless (valid?) (error who "no longer valid")))
    (define/public (invalidate!)
      (when is-valid?
        (set! is-valid? #f)
        (send parent eject! (send (get-atom) get-id))))
    (define/public (update! new-aux) (void))
    ))

;; ----

(define atom-resource% (atom-resource-mixin object%))
(define atom-feed-resource% (atom-feed-resource-mixin atom-resource%))
(define atom-resource/child% (atom-resource/child-mixin atom-resource%))
(define atom-resource/parent+child%
  (class (atom-resource/child-mixin atom-feed-resource%)
    (super-new)
    (inherit reset!)
    (define/override (invalidate!)
      (super invalidate!)
      (reset! #hash()))))
