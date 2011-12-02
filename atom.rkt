#lang racket/base
(require racket/class
         (planet clements/sxml2:1)
         "private/sxml.rkt")
(provide atom<%>
         atom)

#|
Atom 1.0
Reference: http://tools.ietf.org/html/rfc4287

Goals:
 1) read-only access to Atom documents
 2) creation of new Atom documents
 3) modification ("patching"?) of existing Atom documents

Unlike some other classes in this library, atom% instances are not
interned, no parent link, etc.
|#

(define atom<%>
  ;; comprises atom-feed<%>, atom-entry<%>
  (interface ()
    is-feed?     ;; -> boolean
    get-sxml     ;; -> SXML
    get-raw-sxml ;; -> SXML
    get-id       ;; -> string
    get-title    ;; -> string
    get-updated  ;; -> string(date)
    get-link     ;; string [default] -> string
    get-raw-link ;; string [default] -> SXML
    get-entries  ;; -> (listof atom<%>)
    get-raw-entries ;; -> (listof SXML)
    get-tag-value   ;; symbol [default] -> string/#f
    ))

(define atom%
  (class* object% (atom<%>)
    (init-field sxml)

    (define root
      (cond [(and (pair? sxml) (memq (car sxml) '(atom:feed atom:entry))) sxml]
            [else (car* ((sxpath '((*or* atom:feed atom:entry))) sxml))]))
    (unless root (error 'atom% "invalid Atom document: ~e" sxml))

    (super-new)

    (define/public (is-feed?)
      (eq? 'atom:feed (sxml:element-name root)))

    (define/public (get-sxml) root)
    (define/public (get-raw-sxml) sxml)
    (define/public (get-id)
      (get1 'atom:get-id 'atom:id))
    (define/public (get-title)
      (get1 'atom:get-title 'atom:title))
    (define/public (get-updated)
      (get1 'atom:get-updated 'atom:updated))
    (define/public (get-link rel [default not-given])
      (let ([result ((sxpath `((atom:link (@ rel (equal? ,rel))) @ href *text*)) root)])
        (cond [(pair? result) (car result)]
              [else (do-default default (error 'atom:get-link "link ~s not found" rel))])))
    (define/public (get-raw-link rel [default not-given])
      (let ([result ((sxpath `((atom:link (@ rel (equal? ,rel))))) root)])
        (cond [(pair? result) (car result)]
              [else (do-default default (error 'atom:get-raw-link "link ~s not found" rel))])))

    (define/public (get-entries)
      (for/list ([entry (in-list (get-raw-entries))])
        (new atom% (sxml entry))))

    (define/public (get-raw-entries)
      ((sxpath '(atom:entry)) root))

    (define/public (get-tag-value tag [default not-given])
      (get1 'atom:get-tag-value tag default))

    ;; ----

    (define/private (get1 who tag [default not-given])
      (let ([result ((sxpath `(,tag *text*)) root)])
        (cond [(pair? result) (car result)]
              [else (do-default default (error who "element `~a' not found" tag))])))

    ))

(define (car* x)
  (and (pair? x) (car x)))

(define (atom sxml)
  (new atom% (sxml sxml)))

#|
  atomFeed =
      element atom:feed {
         atomCommonAttributes,
         (& atomId
          & atomTitle
          & atomUpdated
          & atomAuthor*        ;; >=1 unless all entries have author
          & atomCategory*
          & atomContributor*
          & atomGenerator?
          & atomIcon?
          & atomLink*
          & atomLogo?
          & atomRights?
          & atomSubtitle?
          & extensionElement*),
         atomEntry*  ;; order not significant
      }

   atomEntry =
      element atom:entry {
         atomCommonAttributes,
         (& atomId
          & atomTitle
          & atomUpdated
          & atomAuthor*
          & atomCategory*
          & atomContent?
          & atomContributor*
          & atomLink*
          & atomPublished?
          & atomRights?
          & atomSource?
          & atomSummary?
          & extensionElement*)
      }
|#
