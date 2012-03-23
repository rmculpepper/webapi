#lang scribble/doc
@(require scribble/manual
          scribble/eval
          scribble/struct
          racket/sandbox
          "config.rkt"
          (for-label (this-package-in atom-resource oauth2 picasa)))

@title[#:tag "picasa"]{Picasa Web Albums}

@(defmodule/this-package picasa)

This library supports a small subset of the
@hyperlink["http://code.google.com/apis/picasaweb/overview.html"]{Picasa
Web Albums API}. Creating and deleting albums and photos is supported,
but all access to metadata must be done by inspecting the resource's
Atom feed, and editing metadata is not currently supported at all.

@defproc[(picasa [#:oauth2 oauth2 (is-a?/c oauth2<%>)])
         (is-a?/c picasa<%>)]{
  Creates a @racket[picasa<%>] object for the albums of the user
  represented by @racket[oauth2]. The scopes of @racket[oauth2] must
  include @racket[picasa-scope].
}

@defthing[picasa-scope string?]{
  String representing the OAuth2 ``scope'' for Picasa Web Albums
  resources.
}

@definterface[picasa<%> (atom-feed-resource<%>)]{

Represents an authorized connection to the Picasa Web Albums of a
particular user, namely the one who approved the OAuth2 authorization
request.

Obtain an instance via @racket[picasa].

For a @racket[picasa<%>] instance, the @racket[atom-feed-resource<%>]
methods return @racket[picasa-album<%>] objects.

@defmethod[(list-albums)
           (listof (is-a?/c picasa-album<%>))]{
  List the albums owned by the user.
}
@defmethod[(find-album [album-name string?])
           (or/c (is-a?/c picasa-album<%>) #f)]{
  Return an album object representing the album named
  @racket[album-name]. If no such album exists, @racket[#f] is
  returned.
}
@defmethod[(create-album [album-name string?])
           (is-a?/c picasa-album<%>)]{
  Creates a new album named @racket[album-name].
}
}

@definterface[picasa-album<%> (atom-resource<%>)]{

Represents a Picasa Web Album. 

Obtain an instance via @method[picasa<%> list-albums],
@method[picasa<%> find-album], @method[picasa<%> create-album], or any
of the @racket[atom-feed-resource<%>] methods with a
@racket[picasa<%>] instance.

For a @racket[picasa-album<%>] instance, the
@racket[atom-feed-resource<%>] methods return @racket[picasa-photo<%>]
objects.

@defmethod[(list-photos)
           (listof (is-a?/c picasa-photo<%>))]{
  Lists the photos belonging to the album.
}
@defmethod[(find-photo [title string?])
           (or/c (is-a?/c picasa-photo<%>) #f)]{
  Finds a photo in the album with title @racket[title]. If no such
  photo exists, returns @racket[#f].
}
@defmethod[(create-photo [image-file path-string?]
                         [title string?])
           (is-a?/c picasa-photo<%>)]{
  Creates a new photo with the contents of @racket[image-file] and
  named @racket[title].
}
@defmethod[(delete) void?]{
  Deletes the album.
}
}

@definterface[picasa-photo<%> (atom-resource<%>)]{

Represents a photo in a Picasa Web Album.

Obtain an instance via @method[picasa-album<%> create-photo] or any of
the @racket[atom-feed-resource<%>] methods with a
@racket[picasa-album<%>] instance.

@defmethod[(get-content-link)
           (or/c string? #f)]{
  Gets a URL for externally linking to the photo. If no such URL
  exists, @racket[#f] is returned.
}
@defmethod[(delete) void?]{
  Deletes the photo.
}
}
