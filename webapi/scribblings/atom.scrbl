#lang scribble/doc
@(require scribble/manual
          scribble/eval
          scribble/struct
          "config.rkt"
          (for-label webapi/atom webapi/atom-resource))

@title[#:tag "atom"]{Atom Documents and Resources}

Many web services use the
@hyperlink["http://tools.ietf.org/html/rfc4287"]{Atom Syndication
Format}. This library provides utilities for manipulating Atom
documents and resources represented with Atom documents.

@section{Atom Documents}

@defmodule[webapi/atom]

An Atom document is represented by an @racket[atom<%>]
object. Specifically, an @racket[atom<%>] object is a thin, immutable
wrapper around the SXML representation of an Atom document. The
wrapper object provides methods for accessing some common Atom
elements and attributes, but most nontrivial operations must be done
on the underlying SXML.

@defproc[(atom [sxml @#,elem{SXML}])
         (is-a?/c atom<%>)]{
  Returns an @racket[atom<%>] object encapsulating the given Atom
  document.
}

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
                     [default any/c (lambda () (error ....))])
           string?]{
  Returns the value of the @tt{link} having relation (@tt{rel}
  attribute) @racket[rel]. If no such link is found, @racket[default]
  is applied if it is a procedure or returned otherwise.
}
@defmethod[(get-raw-link [rel string?]
                         [default any/c (lambda () (error ....))])
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

@section{Atom Resources}

@defmodule[webapi/atom-resource]

An @racket[atom-resource<%>] object represents a resource (such as a
blog or photo album) that is represented and manipulated via Atom
documents.

@definterface[atom-resource<%> ()]{

Represents an Atom-backed resource. Consult the documentation for
specific web services for information on obtaining instances.

@defmethod[(get-atom [#:reload? reload? any/c #f])
           (is-a?/c atom<%>)]{

  Gets the Atom document describing the resource. If @racket[reload?]
  is false, a cached version may be used (but the cached version may
  be out-of-date); otherwise, the document is refetched from the
  server. 

  Many resources have descriptions both as Atom feeds and Atom
  entries. The @method[atom-resource<%> get-atom] method may return
  either one, depending on which is cached. See also
  @method[atom-resource<%> get-feed-atom].
}
@defmethod[(get-feed-atom [#:reload? reload? any/c #f])
           (is-a?/c atom<%>)]{
  Like @method[atom-resource<%> get-atom], but always gets the Atom
  feed describing the resource, if one exists.
}                          
@defmethod[(get-atom-sxml [#:reload? reload? any/c #f])
           @#,elem{SXML}]{
  Gets the SXML of the resource's Atom description.
}
@defmethod[(get-id) string?]{
  Gets the id of the resource's Atom description.
}
@defmethod[(get-title) string?]{
  Gets the title of the resource's Atom description.
}
}

@definterface[atom-feed-resource<%> (atom-resource<%>)]{

Represents a resource backed by an Atom feed. Consult the
documentation for specific web services for information on obtaining
instances.

@defmethod[(list-children [#:reload reload? any/c #f])
           (listof (is-a?/c atom-resource<%>))]{

  Returns a list of the resource's entries.
}
@defmethod[(find-children-by-title [title string?]
                                   [#:reload? reload? any/c #f])
           (listof (is-a?/c atom-resource<%>))]{

  Returns a list of the resource's entries having the
  title @racket[title]. (Titles are not required to be unique.)
}
@defmethod[(find-child-by-title [title string?]
                                [#:reload? reload? any/c #f])
           (or/c (is-a?/c atom-resource<%>) #f)]{

  Returns the resource's first entry having the title
  @racket[title]. If no such entry exists, @racket[#f] is returned.
}
@defmethod[(find-child-by-id [id string?]
                             [#:reload? reload? any/c #f])
           (or/c (is-a?/c atom-resource<%>) #f)]{

  Returns the resource's entry having the identifier @racket[id]. If
  no such entry exists, @racket[#f] is returned.
}
}
