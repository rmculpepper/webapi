#lang racket/base
(require racket/class
         "../atom.rkt")
(provide (all-defined-out))

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

(define has-atom<%>
  (interface ()
    get-atom      ;; [...] -> atom<%>
    get-feed-atom ;; [...] -> atom<%>
    get-raw-atom  ;; [...] -> SXML
    internal-get-atom  ;; -> SXML
    update-atom-cache! ;; atom<%> -> void
    ))

(define has-atom/parent<%>
  (interface (has-atom<%>)
    make-child
    intern
    eject!
    reset!))

(define has-atom/child<%>
  (interface ()
    valid?
    check-valid
    invalidate!
    update!
    ))

;; ----

(define has-atom-mixin
  (mixin () (has-atom<%>)
    (init-field [atom #f])
    (super-new)

    (define/public (get-atom #:reload? [reload? #f]
                             #:who [who 'has-atom:get-atom])
      (cache! reload? #:need-feed? #f #:who who)
      atom)

    (define/public (get-feed-atom #:reload? [reload? #f]
                                  #:who [who 'has-atom:get-feed])
      (cache! reload? #:need-feed? #t #:who who)
      atom)

    (define/public (get-raw-atom #:reload? [reload? #f]
                                 #:who [who 'has-atom:get-raw-atom])
      (send (get-atom #:reload? reload? #:who who) get-sxml))

    (define/private (cache! reload? #:who who)
      (when (or reload? (not atom) (not (send atom is-feed?)))
        (update-atom-cache! (new atom% (sxml (internal-get-atom #:who who))))
        (void)))

    ;; Must override.
    (define/pubment (internal-get-atom #:who who)
      (inner (error who "not implemented") internal-get-atom #:who who))
    ;; May override.
    (define/public (update-atom-cache! new-atom)
      (set! atom new-atom))
    ))

;; ----

(define has-atom/parent-mixin
  (mixin (has-atom<%>) (has-atom/parent<%>)
    (field [table (make-hash)]) ;; key => child<%>
    (inherit get-atom
             get-feed-atom)
    (super-new)

    ;; make-child : key atom<%> -> has-atom/child<%>
    (define/public (make-child atom)
      (error 'has-atom/parent-mixin:make-child "not implemented"))

    (define/public (intern atom)
      (let* ([key (send atom get-id)]
             [v (hash-ref! table key (lambda () (list (make-child atom))))])
        (cond [(pair? v) (car v)]
              [else (begin0 v (send v update! atom))])))

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
                        #:when (not (hash-has-key? key=>atom-hash)))
               key)])
        (for ([key (in-list delenda)])
          (eject! key)))
      (for ([(key atom) (in-hash key=>atom-hash)])
        (intern atom)))

    ;; ----

    (define/public (list-children #:reload? [reload? #f]
                                  #:who [who 'has-atom/parent:list-children])
      ;; Can't just get out of table, because want in order
      (let* ([feed (get-feed-atom #:reload? reload? #:who who)])
        (for/list ([child (in-list (send feed get-entries))])
          (intern child))))

    (define/public (find-child-by-title title
                                        #:reload? [reload? #f]
                                        #:who [who 'has-atom/parent:find-child-by-title])
      (for/first ([child (in-list (list-children #:reload? reload? #:who who))]
                  #:when (equal? (send (send child get-atom) get-title) title))
        child))

    ))

(define has-atom/child-mixin
  (mixin (has-atom<%>) (has-atom/child<%>)
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
        (send parent eject (send (get-atom) get-id))))
    (define/public (update! new-aux) (void))
    ))

;; ----

(define has-atom% (has-atom-mixin object%))
(define has-atom/parent% (has-atom/parent-mixin has-atom%))
(define has-atom/child% (has-atom/child-mixin has-atom%))
(define has-atom/parent+child%
  (class (has-atom/child-mixin has-atom/parent%)
    (super-new)
    (inherit reset!)
    (define/override (invalidate!)
      (super invalidate!)
      (reset! null))))
