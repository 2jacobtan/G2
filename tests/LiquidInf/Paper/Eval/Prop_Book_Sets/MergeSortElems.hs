{-@ LIQUID "--no-termination" @-}

module MergeSortElems (mergeSort) where

import Data.Set

{-@ type ListS a S = {v:[a] | listElts v = S} @-}
{-@ type ListEq a X = ListS a {listElts X}    @-}
{-@ type ListEmp a = ListS a {Set_empty 0} @-}

{-@ mergeSort :: (Ord a) => xs:[a] -> ListEq a xs @-}
mergeSort :: Ord a => [a] -> [a]
mergeSort []  = []
mergeSort [x] = [x]
mergeSort xs  = merge (mergeSort ys) (mergeSort zs)
  where
   (ys, zs)   = halve mid xs
   mid        = length xs `div` 2

-- {-@ merge :: xs:[a] -> ys:[a] -> { r:[a] | Set_cup (listElts xs) (listElts ys) == listElts r } @-}
merge [] ys          = ys
merge xs []          = xs
merge (x:xs) (y:ys)
  | x <= y           = x : merge xs (y:ys)
  | otherwise        = y : merge (x:xs) ys

-- {-@ halve            :: Int -> xs:[a] -> {t:([a], [a]) | Set_cup (listElts (fst t)) (listElts (snd t)) == listElts xs} @-}
halve            :: Int -> [a] -> ([a], [a])
halve 0 xs       = ([], xs)
halve n (x:y:zs) = (x:xs, y:ys) where (xs, ys) = halve (n-1) zs
halve _ xs       = ([], xs)

-- {-@ elts :: (Ord a) => xs:[a] -> { ys:Set a | listElts xs == ys } @-}
elts        :: (Ord a) => [a] -> Set a
elts []     = empty
elts (x:xs) = singleton x `union` elts xs

-- {-@ append :: xs:[a] -> ys:[a] -> { zs:[a] | Set_cup (listElts xs) (listElts ys) == listElts zs } @-}
append []     ys = ys
append (x:xs) ys = x : append xs ys