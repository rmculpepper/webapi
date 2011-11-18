#lang racket/base
(require racket/class
         (planet clements/sxml2:1))

#|
Atom 1.0
Reference: http://tools.ietf.org/html/rfc4287

Goals:
 1) read-only access to Atom documents
 2) creation of new Atom documents
 3) modification ("patching"?) of existing Atom documents
|#

(define xml%
  (class object%
    (init-field sxml)
    (super-new)

    (define/public (get-children/tag tag)
      (filter (lambda (c) (pair? c) (eq? tag (car c)))
              (cdr sxml)))

    (define/public (get-child/tag tag #:who who)
      (let ([cs (get-children/tag tag)])
        (and (pair? cs) (car cs))))
    ))

(define atom<%>
  ;; comprises atom-feed<%>, atom-entry<%>
  (interface ()
    get-sxml ;; -> SXML

    get-id       ;; -> string
    get-title    ;; -> string
    get-updated  ;; -> string(date)
    get-link     ;; string -> string
    get-raw-link ;; string -> SXML
    ))

(define atom%
  (class* object% (atom<%>)
    (init sxml)
    (define-values (root-tag attrs children)
      (match sxml
        [(list* tag (cons '@ attrs) children)
         (values tag attrs children)]
        [(list* tag children)
         (values tag null children)]))
    (super-new)

    (define/public (get-id)
      (get1 'atom:id #:who who))
    (define/public (get-title)
      (get1 'atom:title #:who who))
    (define/public (get-updated)
      (get1 'atom:updated #:who who))
    (define/public (get-link rel)
      ...)
    (define/public (get-raw-link rel)
      ...)

    (define/private (get1 tag #:who who)
      ...)

    ))

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
