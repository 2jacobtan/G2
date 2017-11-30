module GetNthTest where

import G2.Internals.Language
import TestUtils

data CList a = Cons a (CList a) | Nil

data Peano = Succ Peano | Zero

getNth :: CList Int -> Int -> Int
getNth (Cons x _)  0 = x 
getNth (Cons _ xs) n = getNth xs (n - 1)
getNth _      _ = -1

getNthErr :: CList a -> Int -> Maybe a 
getNthErr (Cons x _)  0 = Just x 
getNthErr (Cons _ xs) n = getNthErr xs (n - 1)
getNthErr _      _ = Nothing

toCList :: Expr -> CList Int
toCList (App (App (Data (DataCon (Name "Cons" _ _) _ _)) (Lit (LitInt x))) y) = Cons x (toCList y)
toCList _ = Nil

toCListGen :: Expr -> CList Expr
toCListGen (App (App (Data (DataCon (Name "Cons" _ _) _ _)) e) y) = Cons e (toCListGen y)
toCListGen _ = Nil

cListLength :: CList a -> Int
cListLength (Cons _ xs) = 1 + cListLength xs
cListLength Nil = 0

getNthTest :: [Expr] -> Bool
getNthTest [cl, Lit (LitInt i), Lit (LitInt a)] = getNth (toCList cl) i == a
getNthTest _ = False

getNthErrTest :: [Expr] -> Bool
getNthErrTest [cl, Lit (LitInt i), Lit (LitInt a)] = getNthErr (toCList cl) i == Just a
getNthErrTest [cl, Lit (LitInt i), Prim Error _] = getNthErr (toCList cl) i == Nothing
getNthErrTest _ = False

getNthErrGenTest :: [Expr] -> Bool
getNthErrGenTest [cl, Lit (LitInt i), Prim Error _] = getNthErr (toCListGen cl) i == Nothing
getNthErrGenTest [cl, Lit (LitInt i), e] =
    case getNthErr (toCListGen cl) i of
        Just e' -> e' `eqIgT` e
        Nothing -> False
getNthErrGenTest _ = False

getNthErrGenTest' :: [Expr] -> Bool
getNthErrGenTest' [cl, Lit (LitInt i), Prim Error _] = getNthErr (toCListGen cl) i == Nothing
getNthErrGenTest' [cl, Lit (LitInt i), e] =
    case getNthErr (toCListGen cl) i of
        Just e' -> e' `eqIgT` modify removePrimCon e
        Nothing -> False
getNthErrGenTest' _ = False

getNthErrors :: [Expr] -> Bool
getNthErrors [cl, Lit (LitInt i), Prim Error _] = getNthErr (toCListGen cl) i == Nothing
getNthErrors [cl, Lit (LitInt i), e] = False
getNthErrors _ = False

removePrimCon :: Expr -> Expr
removePrimCon (App (Data (PrimCon I)) l) = l
removePrimCon e = e

cfmapTest :: [Expr] -> Bool
cfmapTest [_, e, e'] = cListLength (toCListGen e) == cListLength (toCListGen e')
cfmapTest _ = False