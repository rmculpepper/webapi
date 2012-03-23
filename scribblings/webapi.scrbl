#lang scribble/doc
@(require scribble/manual
          scribble/struct
          scribble/eval
          "config.rkt")

@title[#:version (my-package-version)]{webapi: Web APIs}
@author[@author+email["Ryan Culpepper" "ryanc@racket-lang.org"]]

This package provides rudimentary implementations of a few web APIs.

@bold{Development} Development of this library is hosted by
@hyperlink["http://github.com"]{GitHub} at the following project page:

@centered{@url{https://github.com/rmculpepper/webapi}}

@bold{Copying} This program is free software: you can redistribute
it and/or modify it under the terms of the
@hyperlink["http://www.gnu.org/licenses/lgpl.html"]{GNU Lesser General
Public License} as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License and GNU Lesser General Public License for more
details.

@include-section["atom.scrbl"]
@include-section["oauth2.scrbl"]
@include-section["blogger.scrbl"]
@include-section["picasa.scrbl"]

@close-eval[the-eval]
