-- Hides the warnings about deriving 
{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE TemplateHaskell #-}

module G2.QuasiQuotes.G2Rep ( G2Rep (..)
                            , derivingG2Rep ) where

import G2.QuasiQuotes.Internals.G2Rep

$(derivingG2Rep ''Int)
$(derivingG2Rep ''[])