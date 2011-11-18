#lang scribble/doc
@(require scribble/manual
          scribble/eval
          scribble/struct
          racket/sandbox
          "config.rkt"
          (for-label (this-package-in oauth2 picasa)))

@title[#:tag "picasa"]{Picasa Web Albums}

@(defmodule/this-package picasa)

This library supports a small subset of the
@hyperlink["http://code.google.com/apis/picasaweb/overview.html"]{Picasa
Web Albums API}. Creating and deleting albums and photos is supported,
but all access to metadata must be done by inspecting the resource's
Atom feed, and editing metadata is not currently supported at all.

@definterface[picasa<%> ()]{

Represents an authorized connection to the Picasa Web Albums of a
particular user.

Obtain an instance via @racket[picasa].

@defmethod[(list-albums)
           (listof (is-a?/c picasa-album<%>))]{
  List the albums owned by the user.
}
@defmethod[(find-album [album-name string?]
                       [default any/c (lambda () (error ....))])
           (is-a?/c picasa-album<%>)]{
  Return an album object representing the album named
  @racket[album-name]. If no such album exists, @racket[default] is
  called, if it's a function, or returned otherwise.
}
@defmethod[(page) @#,elem{SXML}]{
  Retrieves the user's Atom feed, which includes descriptions of all
  of the user's albums.
}
@defmethod[(create-album [album-name string?])
           (is-a?/c picasa-album<%>)]{
  Creates a new album named @racket[album-name].
}
}

@defproc[(picasa [#:oauth2 oauth2 (is-a?/c oauth2<%>)])
         (is-a?/c picasa<%>)]{
  Creates a @racket[picasa<%>] object for the albums of the user
  represented by @racket[oauth2], which must have been with
  @racket[picasa-scope] in its list of scopes.
}

@defthing[picasa-scope string?]{
  String representing the OAuth2 ``scope'' for Picasa Web Albums
  resources.
}

@definterface[picasa-album<%> ()]{

Represents a Picasa Web Album. 

Obtain an instance via @method[picasa<%> list-albums],
@method[picasa<%> find-album], or @method[picasa<%>
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
           (is-a?/c picasa-photo<%>)]{
  Creates a new photo with the contents of @racket[image-file] and
  named @racket[name].
}
}

@definterface[picasa-photo<%> ()]{

Represents a photo in a Picasa Web Album.

Obtain via @method[picasa-album<%> create-photo].

@defmethod[(page) @#,elem{SXML}]{
  Retrieves the photo's Atom feed, which includes metadata about the
  photo.
}
@defmethod[(delete) void?]{
  Deletes the photo.
}
}
