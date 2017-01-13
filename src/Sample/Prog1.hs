module G2.Sample.Prog1 where

import G2.Core.Language

import qualified Data.Map as M

leaf = ("Leaf", 1, TyConApp "Tree" [], [TyConApp "Int" []])
node = ("Node", 2, TyConApp "Tree" [], [TyConApp "Tree" [], TyConApp "Tree" []])

t_decls = [("Tree", TyAlg "Tree" [leaf, node])]

t_env = M.fromList t_decls

simple_btree_1 = App (App (DCon node)
                          (App (DCon leaf) (Const (CInt 1) TyInt)))
                     (App (DCon leaf) (Const (CInt 2) TyInt))

simple_btree_2 = App (DCon leaf) (Const (CInt 3) TyInt)

comp_tree = App (App (DCon node) simple_btree_1) simple_btree_2

mkbtree a b c = App (App (DCon node)
                         (App (App (DCon node)
                                   (App (DCon leaf) a))
                              (App (DCon leaf) b)))
                    (App (DCon leaf) c)

test1 = (Case (mkbtree (Var "a" TyInt) (Var "b" TyInt) (Var "c" TyInt))
              [((node, ["a", "b"]),
                      Case (Var "a" (TyConApp "Tree" []))
                           [((node, ["a", "b"]), Var "b" (TyConApp "Tree" []))
                           ,((leaf, ["a"]), Var "a" (TyConApp "Tree" []))]
                           (TyConApp "Tree" []))
              ,((leaf, ["a"]), Var "a" TyInt)]
              (TyConApp "Tree" []))

test2 = Case (App (App (Var "a" (TyFun TyInt (TyFun TyInt (TyConApp "Tree" [])))) (Var "b" TyInt)) (Var "c" TyInt))
             [((node, ["a", "b"]), Var "a" (TyConApp "Tree" []))
             ,((leaf, ["a"]), Var "a" TyInt)]
             (TyConApp "Tree" [])

e_decls = [("test1", test1)
          ,("test2", test2)]
e_env = M.fromList e_decls

