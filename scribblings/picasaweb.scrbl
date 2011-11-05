#lang scribble/doc
@(require scribble/manual
          scribble/eval
          scribble/struct
          racket/sandbox
          "config.rkt"
          (for-label (this-package-in oauth2 picasaweb)))

@title[#:tag "picasaweb"]{Picasa Web Albums}

@(defmodule/this-package picasaweb)

This library supports a small subset of the
@hyperlink["http://code.google.com/apis/picasaweb/overview.html"]{Picasa
Web Albums API}. Creating and deleting albums and photos is supported,
but all access to metadata must be done by inspecting the resource's
Atom feed, and editing metadata is not currently supported.

@definterface[picasaweb<%> ()]{

Represents a connection to the Picasa Web Albums of a particular user
ID and an OAuth2 authorization.

Obtain an instance via @racket[picasaweb].

@defmethod[(list-albums)
           (listof (is-a?/c picasaweb-album<%>))]{
  List the albums owned by the connection's user ID.
}
@defmethod[(find-album [album-name string?]
                       [default any/c (lambda () (error ....))])
           (is-a?/c picasaweb-album<%>)]{
  Return an album object representing the album named
  @racket[album-name]. If no such album exists, @racket[default] is
  called, if it's a function, or returned otherwise.
}
@defmethod[(page) @#,elem{SXML}]{
  Retrieves the user's Atom feed, which includes descriptions of all
  of the user's albums.
}
@defmethod[(create-album [album-name string?])
           (is-a?/c picasaweb-album<%>)]{

  Creates a new album named @racket[album-name].
}
}

@definterface[picasaweb-album<%> ()]{

Represents a Picasa Web Album. 

Obtain an instance via @method[picasaweb<%> list-albums],
@method[picasaweb<%> find-album], or @method[picasaweb<%>
create-album].

@defmethod[(page) @#,elem{SXML}]{
  Retrieves the album's Atom feed, which includes metadata about the
  album as well as entries for all of the photos it contains.
}
@defmethod[(delete) void?]{
  Deletes the album.
}
@defmethod[(create-photo [image-file path-string?]
                         [name string?])
           (is-a?/c picasaweb-photo<%>)]{
  Creates a new photo with the contents of @racket[image-file] and
  named @racket[name].
}
}

@definterface[picasaweb-photo<%> ()]{

Represents a photo in a Picasa Web Album.

Obtain via @method[picasaweb-album<%> create-photo].

@defmethod[(page) @#,elem{SXML}]{
  Retrieves the photo's Atom feed, which includes metadata about the
  photo.
}
@defmethod[(delete) void?]{
  Deletes the photo.
}
}
