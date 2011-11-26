#lang racket/base
(require racket/class
         (planet clements/sxml2:1))
(provide (all-defined-out))

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
    get-sxml     ;; -> SXML
    get-id       ;; -> string
    get-title    ;; -> string
    get-updated  ;; -> string(date)
    get-link     ;; string -> string
    get-raw-link ;; string -> SXML
    get-entries  ;; -> (listof atom<%>)
    get-raw-entries ;; -> (listof SXML)
    get-tag-value;; symbol -> string/#f
    ))

(define atom%
  (class* object% (atom<%>)
    (init-field sxml)

    (define root
      (cond [(and (pair? sxml) (memq (car sxml) '(atom:feed atom:entry)))
             sxml]
            [else
             (car* ((sxpath '((*or* atom:feed atom:entry))) sxml))]))

    (unless root
      (error 'atom% "invalid Atom document: ~e" sxml))

    (super-new)

    (define/public (get-sxml) sxml)
    (define/public (get-id)
      (get1 'atom:id))
    (define/public (get-title)
      (get1 'atom:title))
    (define/public (get-updated)
      (get1 'atom:updated))
    (define/public (get-link rel)
      (car* ((sxpath `((atom:link (@ rel (equal? ,rel))) @ href *text*)) root))
      #|
      (let ([raw-link (get-raw-link rel)])
        (and raw-link
             (car* ((sxpath '(@ href *text*)) raw-link))))
      |#)
    (define/public (get-raw-link rel)
      (car* ((sxpath `((atom:link (@ rel (equal? ,rel))))) root))
      #|
      (car* ((node-join (sxml:child (ntype?? 'atom:link))
                        (sxml:filter (sxpath `(@ rel (equal? ,rel)))))
             root))
      |#)

    (define/public (get-entries)
      (for/list ([entry (in-list (get-raw-entries))])
        (new atom% (sxml entry))))

    (define/public (get-raw-entries)
      ((sxpath '(atom:entry)) root))

    (define/public (get-tag-value tag)
      (get1 tag))

    ;; ----

    (define/private (get1 tag)
      (car* ((sxpath `(,tag *text*)) root)))

    ))

(define (car* x)
  (and (pair? x) (car x)))

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
