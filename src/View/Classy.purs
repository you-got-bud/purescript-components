module View.Classy where

import React.Basic (JSX)

-- TODO: Add typed classnames
classy
  :: ({ className :: String, children :: Array JSX } -> JSX)
  -> String
  -> (Array JSX -> JSX)
classy element className children = element { className, children }