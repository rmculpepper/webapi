#lang racket/base
(require racket/class)
(provide child-cache%
         child<%>)

(define child<%>
  (interface ()
    valid?
    invalidate!
    update!
    ))

(define child-cache%
  (class object%
    (init-field make-child) ;; key aux-data -> child<%>
    (define table (make-hash)) ;; key => child<%>
    (super-new)

    (define/public (intern key aux)
      (hash-ref! table key (lambda () (make-child key aux))))

    (define/public (eject! key)
      (let ([child (hash-ref table key #f)])
        (when child
          (send child invalidate!)
          (hash-remove! table key))))

    (define/public (reset! key=>aux-hash)
      (let ([delenda
             (for/list ([key (in-hash-keys table)]
                        #:when (not (hash-has-key? key=>aux-hash)))
               key)])
        (for ([key (in-list delenda)])
          (eject! key)))
      (for ([(key aux) (in-hash key=>aux-hash)])
        (intern key aux)))
    ))
