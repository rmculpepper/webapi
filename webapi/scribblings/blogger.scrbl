#lang scribble/doc
@(require scribble/manual
          scribble/eval
          scribble/struct
          "config.rkt"
          (for-label webapi/atom-resource
                     webapi/oauth2
                     webapi/blogger))

@title[#:tag "blogger"]{Blogger}

@defmodule[webapi/blogger]

This library supports a small subset of the
@hyperlink["http://code.google.com/apis/blogger/"]{Blogger
API}.

@defproc[(blogger [#:oauth2 oauth2 (is-a?/c oauth2<%>)])
         (is-a?/c blogger<%>)]{
  Creates a @racket[blogger<%>] object representing the user who
  authorized @racket[oauth2]. The scopes of @racket[oauth2] must
  include @racket[blogger-scope].
}

@defthing[blogger-scope string?]{
  String representing the ``scope'' of Blogger resources.
}

@definterface[blogger<%> (atom-feed-resource<%>)]{

Represents a connection to Blogger for a particular user, namely the
one who approved the OAuth2 authorization request.

Obtain an instance via @racket[blogger].

For a @racket[blogger<%>] instance, the @racket[atom-feed-resource<%>]
methods return @racket[blogger-blog<%>] objects.

@defmethod[(list-blogs)
           (listof (is-a?/c blogger<%>))]{
  Returns a list of blogs owned by the user.
}
@defmethod[(find-blog [title string?])
           (or/c (is-a?/c blogger<%>) #f)]{
  Returns an object representing the blog named @racket[title]
  owned by the user.
}
}

@definterface[blogger-blog<%> (atom-feed-resource<%>)]{

Represents a single blog.

Obtain an instance via @method[blogger<%> find-blog],
@method[blogger<%> list-blogs], or any of the
@racket[atom-feed-resource<%>] methods with a @racket[blogger<%>]
instance.

@defmethod[(list-posts)
           (listof (is-a?/c blogger-post<%>))]{
  Returns a list of all posts contained by the blog.
}
@defmethod[(find-post [title string?])
           (or/c (is-a?/c blogger-post<%>) #f)]{
  Returns the post named @racket[title].
}
@defmethod[(create-html-post [title string?]
                             [html (or/c input-port? (listof @#,elem{SXML}))]
                             [#:draft? draft? any/c #t]
                             [#:tags tags (listof string?) null])
           (is-a?/c blogger-post<%>)]{
  Creates a new blog post with the title @racket[title]. If
  @racket[html] is an input port, the contents of the port is used as
  the body of the post. Otherwise, it is interpreted as HTML expressed
  as a list of SXML elements.
}
}

@definterface[blogger-post<%> (atom-resource<%>)]{

Represents a blog post.

Obtain an instance via @method[blogger-blog<%> list-posts],
@method[blogger-blog<%> find-post], or any of the
@racket[atom-feed-resource<%>] methods with a @racket[blogger-blog<%>]
instance.

@defmethod[(delete) void?]{
  Deletes the post.
}
}
