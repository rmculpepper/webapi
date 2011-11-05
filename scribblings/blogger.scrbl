#lang scribble/doc
@(require scribble/manual
          scribble/eval
          scribble/struct
          racket/sandbox
          "config.rkt"
          (for-label (this-package-in oauth2 blogger)))

@title[#:tag "blogger"]{Blogger}

@(defmodule/this-package blogger)

This library supports a small subset of the
@hyperlink["http://code.google.com/apis/blogger/"]{Blogger
API}.

@definterface[blogger-user<%> ()]{

Represents a connection to Blogger for a particular user, namely the
one who approved the OAuth2 authorization request.

Obtain an instance via @racket[blogger-user].

@defmethod[(list-blogs)
           (listof (is-a?/c blogger<%>))]{
  Returns a list of blogs owned by the user.
}
@defmethod[(find-blog [blog-name string?]
                      [default any/c (lambda () (error ....))])
           (is-a?/c blogger<%>)]{
  Returns an object representing the blog named @racket[blog-named]
  owned by the user.
}
@defmethod[(page) @#,elem{SXML}]{
  Returns the user's Atom feed, which includes an entry for each blog
  the user owns.
}
}

@defproc[(blogger-user [#:oauth2 oauth2 (is-a?/c oauth2<%>)])
         (is-a?/c blogger-user<%>)]{
  Creates a @racket[blogger-user<%>] object representing the user who
  authorized @racket[oauth2]. The scopes of @racket[oauth2] must
  include @racket[blogger-scope].
}

@defthing[blogger-scope string?]{
  String representing the ``scope'' of Blogger resources.
}

@definterface[blogger<%> ()]{

Represents a single blog.

Obtain via @method[blogger-user<%> find-blog] or
@method[blogger-user<%> list-blogs].

@defmethod[(get-title) string?]{
  Returns the title of the blog.
}
@defmethod[(list-posts) (listof (is-a?/c blogger-post<%>))]{
  Returns a list of all posts contained by the blog.
}
@defmethod[(find-post [post-name string?]
                      [default any/c (lambda () (error ....))])
           (is-a?/c blogger-post<%>)]{
  Returns the post named @racket[post-name].
}
@defmethod[(page) @#,elem{SXML}]{
  Returns the blog's Atom feed, which includes metadata about the blog
  as well as entries for all of the blog's posts.
}
@defmethod[(create-html-post [title string?]
                             [html-file-or-contents (or/c path-string? (listof string?))]
                             [#:draft? draft? any/c #t]
                             [#:tags tags (listof string?) null])
           (is-a?/c blogger-post<%>)]{
  Creates a new blog post with the title @racket[title]. If
  @racket[html-file-or-contents] is a string or path, the contents of
  the file named @racket[html-file-or-contents] are used as the body
  of the post. If @racket[html-file-or-contents] is a list of strings,
  the strings themselves are used as the contents of the post.
}
}

@definterface[blogger-post<%> ()]{

Represents a blog post.

Obtain an instance via @method[blogger<%> list-posts] or
@method[blogger<%> find-post].

@defmethod[(get-title) string?]{
  Returns the post's title.
}
@defmethod[(page) @#,elem{SXML}]{
  Returns the post's feed, which contains its metadata and contents.
}
@defmethod[(delete) void?]{
  Deletes the post.
}
}
