#lang scribble/doc
@(require scribble/manual
          scribble/eval
          scribble/struct
          racket/sandbox
          "config.rkt"
          (for-label (this-package-in atom)))

@title[#:tag "atom"]{Atom}

@(defmodule/this-package atom)

Many web services use the
@hyperlink["http://tools.ietf.org/html/rfc4287"]{Atom Syndication
Format}. This library provides utilities for manipulating Atom
documents.

An @racket[atom<%>] object represents an Atom document. Specifically,
an @racket[atom<%>] object is a thin, immutable wrapper around the
SXML representation of an Atom document; the wrapper object provides
methods for accessing some common Atom elements and attributes.

@definterface[atom<%> ()]{

Represents an Atom document. Obtain an instance via @racket[atom].

@defmethod[(is-feed?) boolean?]{
  Returns @racket[#t] if the Atom document is a @tt{feed} element,
  @racket[#f] if it is an @tt{entry} element. Note that the same
  resource can be represented in one context as a feed and in another
  as an entry.
}
@defmethod[(get-sxml) @#,elem{SXML}]{
  Returns the encapsulated SXML document.
}
@defmethod[(get-id) string?]{
  Returns the contents of the document's @tt{id} element.
}
@defmethod[(get-title) string?]{
  Returns the contents of the document's @tt{title} element.
}
@defmethod[(get-updated) string?]{
  Returns the contents of the document's @tt{updated} element (a
  timestamp in string form).
}
@defmethod[(get-link [rel string?]
                     [default any/c])
           string?]{
  Returns the value of the @tt{link} having relation (@tt{rel}
  attribute) @racket[rel]. If no such link is found, @racket[default]
  is applied if it is a procedure or returned otherwise.
}
@defmethod[(get-raw-link [rel string?]
                         [default any/c])
           @#,elem{SXML}]{
  Returns the @tt{link} element having relation (@tt{rel} attribute)
  @racket[rel]. If no such link is found, @racket[default] is applied
  if it is a procedure or returned otherwise.
}
@defmethod[(get-entries) (listof (is-a?/c atom<%>))]{
  If the document is a @tt{feed}, returns the list of its entries as
  @racket[atom<%>] objects. If the document is an @tt{entry}, returns
  @racket['()].
}
@defmethod[(get-raw-entries) (listof @#,elem{SXML})]{
  If the document is a @tt{feed}, returns the list of its @tt{entry}
  elements. If the document is an @tt{entry}, returns @racket['()].
}
@defmethod[(get-tag-value [tag symbol?]
                          [default any/c])
           string?]{
  Returns the text content of the (first) element named
  @racket[tag] among the immediate children of the Atom document's
  root element. If no such element exists, @racket[default] is applied
  if it is a procedure or returned otherwise.
}
}

@defproc[(atom [sxml @#,elem{SXML}])
         (is-a?/c atom<%>)]{
  Returns an @racket[atom<%>] object encapsulating the given Atom
  document.
}