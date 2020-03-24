module G2.Language.CallGraph ( CallGraph
                             , getCallGraph
                             , calls
                             , calledBy ) where

import qualified G2.Language.ExprEnv as E
import G2.Language.Naming
import G2.Language.Syntax

import Data.Graph
import qualified Data.HashMap.Lazy as M


data CallGraph = CallGraph { graph :: Graph
                           , nfv :: Vertex -> ((), Name, [Name])
                           , vert :: Name -> Maybe Vertex}

getCallGraph :: E.ExprEnv -> CallGraph
getCallGraph eenv =
    let
        funcs = E.keys eenv
    
        (g, nfv', vert') = graphFromEdges
            . map (\(n, e) -> 
                        let
                            calls = filter (\n -> n `elem` funcs) . map idName $ varIds e
                        in
                        ((), n, calls)) $ E.toList eenv
    in
    CallGraph g nfv' vert'

nodeName :: CallGraph -> Vertex -> Name
nodeName g v = (\(_, n, _) -> n) $ nfv g v

calls :: Name -> CallGraph -> Maybe [Name]
calls n g = fmap (\(_, _, ns) -> ns) . fmap (nfv g) $ vert g n

calledBy :: Name -> CallGraph -> [Name]
calledBy n g = map fst
             . filter ((==) n . snd)
             . map (\(v1, v2) -> (nodeName g v1, nodeName g v2)) $ edges (graph g)