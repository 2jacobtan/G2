module Main where

import System.Environment

import Data.List
import qualified Data.Map as M
import Data.Tuple

import Data.Maybe

import G2.Lib.Printers

import G2.Internals.Interface
import G2.Internals.Language
import G2.Internals.Translation
import G2.Internals.Execution
import G2.Internals.SMT

main :: IO ()
main = do
    putStrLn "Compiles!!!"
    (proj:src:prims:entry:tail_args) <- getArgs

    --Get args
    let n_val = nVal tail_args
    let m_assume = mAssume tail_args
    let m_assert = mAssert tail_args

    (binds, tycons) <- translation proj src prims

    -- mapM_ (putStrLn . show) binds

    -- putStrLn $ "typechecks? " ++ (show $ fint .:: poly1)

    -- print binds

    let init_state = initState binds tycons m_assume m_assert entry

    -- putStrLn $ mkStateStr init_state

    hhp <- getZ3ProcessHandles

    in_out <- run smt2 hhp n_val init_state

    putStrLn "----------------\n----------------"

    mapM_ (\(st, rs, inArg, ex) -> do
            let funcCall = mkExprHaskell 
                         . foldl (\a a' -> App a a') (Var $ Id (Name entry Nothing 0) TyBottom) $ inArg

            -- mapM_ (print) rs
            -- putStrLn $ pprExecStateStr st

            -- print inArg
            -- print ex

            let funcOut = mkExprHaskell $ ex

            putStrLn $ funcCall ++ " = " ++ funcOut
        ) in_out

    putStrLn "End"
    
mArg :: String -> [String] -> (String -> a) -> a -> a
mArg s args f d = case elemIndex s args of
               Nothing -> d
               Just i -> if i >= length args
                              then error ("Invalid use of " ++ s)
                              else f (args !! (i + 1))

nVal :: [String] -> Int
nVal args = mArg "--n" args read 500

mAssume :: [String] -> Maybe String
mAssume args = mArg "--assume" args Just Nothing

mAssert :: [String] -> Maybe String
mAssert args = mArg "--assert" args Just Nothing

