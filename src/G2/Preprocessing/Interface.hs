{-# LANGUAGE FlexibleContexts #-}

module G2.Preprocessing.Interface where

import G2.Language
import G2.Preprocessing.AdjustTypes
import G2.Preprocessing.NameCleaner

runPreprocessing :: (ASTContainer t Expr, ASTContainer t Type, Named t) => State t -> Bindings -> (State t, Bindings)
runPreprocessing s b = cleanNames (adjustTypes s) b
