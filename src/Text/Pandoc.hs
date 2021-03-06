{-
Copyright (C) 2006-2010 John MacFarlane <jgm@berkeley.edu>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-}

{- |
   Module      : Text.Pandoc
   Copyright   : Copyright (C) 2006-2010 John MacFarlane
   License     : GNU GPL, version 2 or above 

   Maintainer  : John MacFarlane <jgm@berkeley.edu>
   Stability   : alpha 
   Portability : portable

This helper module exports the main writers, readers, and data
structure definitions from the Pandoc libraries.

A typical application will chain together a reader and a writer
to convert strings from one format to another.  For example, the
following simple program will act as a filter converting markdown
fragments to reStructuredText, using reference-style links instead of
inline links:

> module Main where
> import Text.Pandoc
> -- include the following two lines only if you're using ghc < 6.12:
> import Prelude hiding (getContents, putStrLn)
> import System.IO.UTF8
>
> markdownToRST :: String -> String
> markdownToRST =
>   (writeRST defaultWriterOptions {writerReferenceLinks = True}) .
>   readMarkdown defaultParserState
> 
> main = getContents >>= putStrLn . markdownToRST

Note:  all of the readers assume that the input text has @'\n'@
line endings.  So if you get your input text from a web form,
you should remove @'\r'@ characters using @filter (/='\r')@.

-}

module Text.Pandoc
               ( 
               -- * Definitions
               module Text.Pandoc.Definition
               -- * Generics
               , module Text.Pandoc.Generic
               -- * Lists of readers and writers
               , readers
               , writers
               -- * Readers: converting /to/ Pandoc format
               , readMarkdown
               , readRST
               , readLaTeX
               , readHtml
               , readTextile
               , readNative
               -- * Parser state used in readers
               , ParserState (..)
               , defaultParserState
               , ParserContext (..)
               , QuoteContext (..)
               , KeyTable
               , NoteTable
               , HeaderType (..)
               -- * Writers: converting /from/ Pandoc format
               , writeNative
               , writeMarkdown
               , writePlain
               , writeRST
               , writeLaTeX
               , writeConTeXt
               , writeTexinfo
               , writeHtml
               , writeHtmlString
               , writeDocbook
               , writeOpenDocument
               , writeMan
               , writeMediaWiki
               , writeTextile
               , writeRTF
               , writeODT
               , writeEPUB
               , writeOrg
               -- * Writer options used in writers 
               , WriterOptions (..)
               , HTMLSlideVariant (..)
               , HTMLMathMethod (..)
               , CiteMethod (..)
               , defaultWriterOptions
               -- * Rendering templates and default templates
               , module Text.Pandoc.Templates
               -- * Version
               , pandocVersion
               -- * Miscellaneous
               , rtfEmbedImage
               , jsonFilter
             ) where

import Text.Pandoc.Definition
import Text.Pandoc.Generic
import Text.Pandoc.Readers.Markdown
import Text.Pandoc.Readers.RST
import Text.Pandoc.Readers.LaTeX
import Text.Pandoc.Readers.HTML
import Text.Pandoc.Readers.Textile
import Text.Pandoc.Readers.Native
import Text.Pandoc.Writers.Native
import Text.Pandoc.Writers.Markdown
import Text.Pandoc.Writers.RST 
import Text.Pandoc.Writers.LaTeX
import Text.Pandoc.Writers.ConTeXt
import Text.Pandoc.Writers.Texinfo
import Text.Pandoc.Writers.HTML
import Text.Pandoc.Writers.ODT
import Text.Pandoc.Writers.EPUB
import Text.Pandoc.Writers.Docbook
import Text.Pandoc.Writers.OpenDocument
import Text.Pandoc.Writers.Man
import Text.Pandoc.Writers.RTF 
import Text.Pandoc.Writers.MediaWiki
import Text.Pandoc.Writers.Textile
import Text.Pandoc.Writers.Org
import Text.Pandoc.Templates
import Text.Pandoc.Parsing
import Text.Pandoc.Shared
import Data.Version (showVersion)
import Text.JSON.Generic
import Paths_pandoc (version)

-- | Version number of pandoc library.
pandocVersion :: String
pandocVersion = showVersion version

-- | Association list of formats and readers.
readers :: [(String, ParserState -> String -> Pandoc)]
readers = [("native"       , \_ -> readNative)
          ,("json"         , \_ -> decodeJSON)
          ,("markdown"     , readMarkdown)
          ,("markdown+lhs" , \st ->
                             readMarkdown st{ stateLiterateHaskell = True})
          ,("rst"          , readRST)
          ,("rst+lhs"      , \st ->
                             readRST st{ stateLiterateHaskell = True})
          ,("textile"      , readTextile) -- TODO : textile+lhs 
          ,("html"         , readHtml)
          ,("latex"        , readLaTeX)
          ,("latex+lhs"    , \st ->
                             readLaTeX st{ stateLiterateHaskell = True})
          ]

-- | Association list of formats and writers (omitting the
-- binary writers, odt and epub).
writers :: [ ( String, WriterOptions -> Pandoc -> String ) ]
writers = [("native"       , writeNative)
          ,("json"         , \_ -> encodeJSON)
          ,("html"         , writeHtmlString)
          ,("html+lhs"     , \o ->
                             writeHtmlString o{ writerLiterateHaskell = True })
          ,("s5"           , writeHtmlString)
          ,("slidy"        , writeHtmlString)
          ,("dzslides"     , writeHtmlString)
          ,("docbook"      , writeDocbook)
          ,("opendocument" , writeOpenDocument)
          ,("latex"        , writeLaTeX)
          ,("latex+lhs"    , \o ->
                             writeLaTeX o{ writerLiterateHaskell = True })
          ,("context"      , writeConTeXt)
          ,("texinfo"      , writeTexinfo)
          ,("man"          , writeMan)
          ,("markdown"     , writeMarkdown)
          ,("markdown+lhs" , \o ->
                             writeMarkdown o{ writerLiterateHaskell = True })
          ,("plain"        , writePlain)
          ,("rst"          , writeRST)
          ,("rst+lhs"      , \o ->
                             writeRST o{ writerLiterateHaskell = True })
          ,("mediawiki"    , writeMediaWiki)
          ,("textile"      , writeTextile)
          ,("rtf"          , writeRTF)
          ,("org"          , writeOrg)
          ]

-- | Converts a transformation on the Pandoc AST into a function
-- that reads and writes a JSON-encoded string.  This is useful
-- for writing small scripts.
jsonFilter :: (Pandoc -> Pandoc) -> String -> String
jsonFilter f = encodeJSON . f . decodeJSON
