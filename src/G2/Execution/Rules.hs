{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Reduction Rules for Stack Execution Semantics
module G2.Execution.Rules
  ( module G2.Execution.RuleTypes
  , Rule (..)
  , ReduceResult
  , EvaluateResult
  , isExecValueForm
  , liftLetBinds
  , reduceNoConstraintChecks
  , resultsToState
  , stdReduce
  , stdReduceBase
  , stdReduceEvaluate
  , reduceLam
  ) where

import G2.Execution.NormalForms
import G2.Execution.PrimitiveEval
import G2.Execution.RuleTypes
import G2.Language
import qualified G2.Language.PathConds as PC
import qualified G2.Language.Stack as S
import qualified G2.Language.ExprEnv as E
import qualified G2.Language.KnownValues as KV
import G2.Solver.Interface
import G2.Solver.Language hiding (Assert)

import Control.Monad
import Data.Maybe

exprRenames :: ASTContainer m Expr => [(Name, Name)] -> m -> m
exprRenames n a = foldr (\(old, new) -> renameExpr old new) a n

-- | Inject binds into the eenv. The LHS of the [(Id, Expr)] are treated as
-- seed values for the names.
liftBinds :: [(Id, Expr)] -> E.ExprEnv -> Expr -> NameGen ->
             (E.ExprEnv, Expr, NameGen, [Name])
liftBinds binds eenv expr ngen = (eenv', expr', ngen', news)
  where
    (bindsLHS, bindsRHS) = unzip binds

    olds = map (idName) bindsLHS
    (news, ngen') = freshSeededNames olds ngen
    expr' = exprRenames (zip olds news) expr
    bindsLHS' = exprRenames (zip olds news) bindsLHS

    binds' = zip bindsLHS' bindsRHS

    eenv' = E.insertExprs (zip news (map snd binds')) eenv


liftCaseBinds :: [(Id, Expr)] -> Expr -> Expr
liftCaseBinds [] expr = expr
liftCaseBinds ((b, e):xs) expr = liftCaseBinds xs $ replaceASTs (Var b) e expr

-- Due to recursion, Let bindings have to rename the RHS of the bindings
liftLetBinds :: [(Id, Expr)] -> E.ExprEnv -> Expr -> NameGen ->
             (E.ExprEnv, Expr, NameGen, [Name])
liftLetBinds binds eenv expr ngen = (eenv', expr', ngen', news)
  where
    olds = map (idName . fst) binds
    (news, ngen') = freshSeededNames olds ngen
    expr' = exprRenames (zip olds news) expr
    binds' = exprRenames (zip olds news) binds

    eenv' = E.insertExprs (zip news (map snd binds')) eenv

-- | `DataCon` `Alt`s.
dataAlts :: [Alt] -> [(DataCon, [Id], Expr)]
dataAlts alts = [(dcon, ps, aexpr) | Alt (DataAlt dcon ps) aexpr <- alts]

-- | `Lit` `Alt`s.
litAlts :: [Alt] -> [(Lit, Expr)]
litAlts alts = [(lit, aexpr) | Alt (LitAlt lit) aexpr <- alts]

-- | DEFAULT `Alt`s.
defaultAlts :: [Alt] -> [Alt]
defaultAlts alts = [a | a @ (Alt Default _) <- alts]

-- | Match data constructor based `Alt`s.
matchDataAlts :: DataCon -> [Alt] -> [Alt]
matchDataAlts (DataCon n _) alts =
  [a | a @ (Alt (DataAlt (DataCon n' _) _) _) <- alts, n == n']

-- | Match literal constructor based `Alt`s.
matchLitAlts :: Lit -> [Alt] -> [Alt]
matchLitAlts lit alts = [a | a @ (Alt (LitAlt alit) _) <- alts, lit == alit]

-- | Lift positive datacon `State`s from symbolic alt matching. This in
-- part involves erasing all of the parameters from the environment by rename
-- their occurrence in the aexpr to something fresh.
liftSymDataAlt :: E.ExprEnv -> Expr -> NameGen -> Id -> [(DataCon, [Id], Expr)] -> [EvaluateResult]
liftSymDataAlt eenv mexpr ngen cvar = map (liftSymDataAlt' eenv mexpr ngen cvar)

liftSymDataAlt' :: E.ExprEnv -> Expr -> NameGen -> Id -> (DataCon, [Id], Expr) -> EvaluateResult
liftSymDataAlt' eenv mexpr ngen cvar (dcon, params, aexpr) = res
  where

    -- Make sure that the parameters do not conflict in their symbolic reps.
    olds = map idName params
    -- [ChildrenNames]
    -- Optimization
    -- We use the same names repeatedly for the children of the same ADT
    -- Haskell is purely functional, so this is OK!  The children can't change
    -- Then, in the constraint solver, we can consider fewer constraints at once
    -- (see note [AltCond] in Language/PathConds.hs) 
    (news, ngen') = case exprInCasts mexpr of
        (Var (Id n _)) -> childrenNames n olds ngen
        _ -> freshSeededNames olds ngen

    newparams = map (uncurry Id) $ zip news (map typeOf params)

    -- Condition that was matched.
    cond = AltCond (DataAlt dcon newparams) mexpr True

    -- (news, ngen') = freshSeededNames olds ngen

    --Update the expr environment
    newIds = map (\(Id _ t, n) -> (n, Id n t)) (zip params news)
    eenv' = foldr (uncurry E.insertSymbolic) eenv newIds

    (cond', aexpr') = exprRenames (zip olds news) (cond, aexpr)

    -- Now do a round of rename for binding the cvar.
    binds = [(cvar, mexpr)]
    aexpr'' = liftCaseBinds binds aexpr'
    res = ( eenv'
          , CurrExpr Evaluate aexpr''
          , [cond']
          , ngen'
          , Nothing)

liftSymLitAlt :: E.ExprEnv -> Expr -> NameGen -> Id -> [(Lit, Expr)] -> [EvaluateResult]
liftSymLitAlt eenv mexpr ngen cvar = map (liftSymLitAlt' eenv mexpr ngen cvar)

-- | Lift literal alts found in symbolic case matching.
liftSymLitAlt' :: E.ExprEnv -> Expr -> NameGen -> Id -> (Lit, Expr) -> EvaluateResult
liftSymLitAlt' eenv mexpr ngen cvar (lit, aexpr) = res
  where
    -- Condition that was matched.
    cond = AltCond (LitAlt lit) mexpr True
    -- Bind the cvar.
    binds = [(cvar, Lit lit)]
    aexpr' = liftCaseBinds binds aexpr
    res = ( eenv
          , CurrExpr Evaluate aexpr'
          , [cond]
          , ngen
          , Nothing)

liftSymDefAlt :: E.ExprEnv -> Expr -> NameGen ->  Id -> [Alt] -> [EvaluateResult]
liftSymDefAlt eenv mexpr ngen cvar as =
    let
        aexpr = defAltExpr as
    in
    case aexpr of
        Just aexpr' -> liftSymDefAlt' eenv mexpr aexpr' ngen cvar as
        _ -> []

liftSymDefAlt' :: E.ExprEnv -> Expr -> Expr -> NameGen ->  Id -> [Alt] -> [EvaluateResult]
liftSymDefAlt' eenv mexpr aexpr ngen cvar as =
    let
        conds = mapMaybe (liftSymDefAltPCs mexpr) (map altMatch as)

        binds = [(cvar, mexpr)]
        aexpr' = liftCaseBinds binds aexpr
    in
    [( eenv
     , CurrExpr Evaluate aexpr'
     , conds
     , ngen
     , Nothing)]

defAltExpr :: [Alt] -> Maybe Expr
defAltExpr [] = Nothing
defAltExpr (Alt Default e:_) = Just e
defAltExpr (_:xs) = defAltExpr xs

liftSymDefAltPCs :: Expr -> AltMatch -> Maybe PathCond
liftSymDefAltPCs mexpr (DataAlt dc _) = Just $ ConsCond dc mexpr False
liftSymDefAltPCs mexpr lit@(LitAlt _) = Just $ AltCond lit mexpr False
liftSymDefAltPCs _ Default = Nothing

-- | Trace the type contained in an expression of type TYPE.
traceIdType :: Id -> E.ExprEnv -> Maybe Type
traceIdType (Id n ty) eenv =
  if (not . hasTYPE) ty then
    Just ty
  else
    case E.lookup n eenv of
      Nothing -> Nothing
      Just (Type res) -> Just res
      Just _ -> traceIdType (Id n ty) eenv

-- | Remove everything from an [Expr] that are actually Types.
removeTypes :: [Expr] -> E.ExprEnv -> [Expr]
removeTypes ((Type _):es) eenv = removeTypes es eenv
removeTypes ((Var (Id n ty)):es) eenv = case E.lookup n eenv of
    Just (Type _) -> removeTypes es eenv
    _ -> (Var (Id n ty)) : removeTypes es eenv
removeTypes (e:es) eenv = e : removeTypes es eenv
removeTypes [] _ = []
  
repeatedLookup :: Expr -> ExprEnv -> Expr
repeatedLookup v@(Var (Id n _)) eenv
    | E.isSymbolic n eenv = v
    | otherwise = 
        case E.lookup n eenv of
          Just v'@(Var _) -> repeatedLookup v' eenv
          Just e -> e
          Nothing -> v
repeatedLookup e _ = e

lookupForPrim :: Expr -> ExprEnv -> Expr
lookupForPrim v@(Var (Id _ _)) eenv = repeatedLookup v eenv
lookupForPrim (App e e') eenv = App (lookupForPrim e eenv) (lookupForPrim e' eenv)
lookupForPrim e _ = e

-- | Function for performing rule reductions based on stack based evaluation
-- semantics with heap memoization.

-- | Result of a Evaluate reduction.
type ReduceResult t = (E.ExprEnv, CurrExpr, [Constraint], [Assertion], Maybe FuncCall, NameGen, S.Stack Frame, [Id], [Expr], t)

reduceNoConstraintChecks :: (State t -> (Rule, [ReduceResult t])) -> State t -> [State t]
reduceNoConstraintChecks red s =
    let
        (rule, res) = red s
    in
    map (resultToState s rule) res

resultsToState :: Solver solver => solver -> Rule -> State t -> [ReduceResult t] -> IO [State t]
resultsToState _ _ _ [] = return []
resultsToState con rule s@(State {known_values = kv}) (red@(_, _, pc, asserts, ais, _, _, _, _, _):xs)
    | not (null pc) = do
            -- Optimization
            -- We replace the path_conds with only those that are directly
            -- affected by the new path constraints
            -- This allows for more efficient solving, and in some cases may
            -- change an Unknown into a SAT or UNSAT
            -- Switching which of the following two lines is commented turns this on/off
            -- let s'' = s'
            let rel_pc = PC.relevant (known_values s) pc (path_conds s')

            res <- check con s rel_pc

            if res == SAT then
                return . (:) s' =<< resultsToState con rule s xs
            else
                resultsToState con rule s xs
    | not (null asserts) && not (true_assert s) = do
        let assertS = s' { path_conds = foldr (PC.insert kv) (path_conds s') asserts, true_assert = True, assert_ids = ais }
        let assertSRel = PC.relevant kv asserts (path_conds assertS)

        let negAsserts = map PC.negatePC asserts
        
        let negAssertS = s' {path_conds = foldr (PC.insert kv) (path_conds s') negAsserts}
        let negAssertSRel = PC.relevant kv negAsserts (path_conds negAssertS)

        let potentialS = [(assertS, assertSRel), (negAssertS, negAssertSRel)]

        finalS <- filterM (\(s_, pc_) -> return . isSat =<< check con s_ pc_) potentialS
        let finalS' = map fst finalS

        return . (++) finalS' =<< resultsToState con rule s xs
    | otherwise = return . (:) s' =<< resultsToState con rule s xs
    where
        !s' = resultToState s rule red

{-# INLINE resultToState #-}
resultToState :: State t -> Rule -> ReduceResult t -> State t
resultToState s r (eenv, cexpr, pc, _, _, ng, st, is, non_red_pc, tv) =
    s {
        expr_env = eenv
      , curr_expr = cexpr
      , path_conds = foldr (PC.insert (known_values s)) (path_conds s) $ pc
      , non_red_path_conds = non_red_path_conds s ++ non_red_pc
      , name_gen = ng
      , exec_stack = st
      , symbolic_ids = symbolic_ids s ++ is
      , rules = r:rules s
      , track = tv }

-- | stdReduce
-- Interprets Haskell with no special semantics.
stdReduce :: State t -> (Rule, [ReduceResult t])
stdReduce = stdReduceBase (const Nothing)

stdReduceBase :: (State t -> Maybe (Rule, [ReduceResult t])) -> State t -> (Rule, [ReduceResult t])
stdReduceBase redEx s@State { exec_stack = estk
                              , expr_env = eenv
                              , type_env = tenv
                              , curr_expr = cexpr
                              , name_gen = ngen
                              , known_values = kv
                              , type_classes = tc
                              , track = tr
                              }
  | isExecValueFormDisNonRedPC s=
      (RuleIdentity, [(eenv, cexpr, [], [], Nothing, ngen, estk, [], [], tr)])
      -- (RuleIdentity, [(eenv, cexpr, [], [], ngen, estk)])
  | CurrExpr Evaluate expr <- cexpr
  , (Prim Error _):_ <- unApp expr
  , Just (UpdateFrame n, estk') <- S.pop estk =
      let
          eenv' = E.insert n expr eenv
      in
      (RulePrimError, [(eenv', CurrExpr Evaluate (Prim Error TyBottom), [], [], Nothing, ngen, estk', [], [], tr)])
  -- We treat trying to evalute Error in an assertion as a violation of the assertion
  | CurrExpr Evaluate expr <- cexpr
  , (Prim Error _):_ <- unApp expr
  , Just (AssertFrame is _, estk') <- S.pop estk =
      let
          false = Data $ mkDCFalse kv tenv
      in
      (RulePrimError, [(eenv, CurrExpr Evaluate (Prim Error TyBottom), [], [ExtCond false False], is, ngen, estk', [], [], tr)])
  | CurrExpr Evaluate expr <- cexpr
  , (Prim Error _):_ <- unApp expr
  , Just (_, estk') <- S.pop estk =
      (RulePrimError, [(eenv, CurrExpr Evaluate (Prim Error TyBottom), [], [], Nothing, ngen, estk', [], [], tr)])
  | CurrExpr Evaluate expr@(App _ _) <- cexpr
  , (Prim Error _):_ <- unApp expr =
      (RulePrimError, [(eenv, CurrExpr Return (Prim Error TyBottom), [], [], Nothing, ngen, estk, [], [], tr)])
  -- TODO: This is kinda a hack... we need better handling of Prims overall
  | CurrExpr Evaluate (App (App (Prim BindFunc TyUnknown) (Var i1)) v2) <- cexpr =
    (RuleReturnCAssert,
      [( E.insert (idName i1) v2 eenv
       , CurrExpr Return (mkTrue kv tenv)
       , []
       , []
       , Nothing
       , ngen
       , estk
       , []
       , []
       , tr)])
  | CurrExpr Evaluate expr <- cexpr
  , isExprValueForm eenv expr =
      -- Our current thing is a value form, which means we can return it.
      (RuleEvalVal, [(eenv, CurrExpr Return expr, [], [], Nothing, ngen, estk, [],  [], tr) ])

  | Just red <- redEx s = red

  | CurrExpr Evaluate (NonDet es) <- cexpr =
      (RuleNonDet, map (\e -> (eenv, CurrExpr Evaluate e, [], [], Nothing, ngen, estk, [], [], tr)) es)

  | CurrExpr Evaluate (SymGen t) <- cexpr =
      let
          (n, ngen') = freshSeededString "symG" ngen
          i = Id n t

          eenv' = E.insertSymbolic n i eenv
      in
      (RuleSymGen, [(eenv', CurrExpr Evaluate (Var i), [], [], Nothing, ngen', estk, [i], [], tr)])


  | CurrExpr Evaluate expr <- cexpr =
      let (rule, eval_results) = stdReduceEvaluate eenv expr tenv kv ngen
          states = map (\(eenv', cexpr', paths', ngen', f) ->
                        ( eenv'
                        , cexpr'
                        , paths'
                        , []
                        , Nothing
                        , ngen'
                        , maybe estk (\f' -> S.push f' estk) f
                        , []
                        , []
                        , tr))
                       eval_results
      in (rule, states)

  | CurrExpr Return expr <- cexpr
  , Just (CurrExprFrame fexpr, estk') <- S.pop estk =
      let cond = ExtCond expr True
      in
         (RuleReturnCurrExprFr, [(eenv, fexpr, [cond], [], Nothing, ngen, estk', [], [], tr)])

  | CurrExpr Return expr <- cexpr
  , Just (AssumeFrame fexpr, estk') <- S.pop estk =
      let cond = ExtCond expr True
      in
         (RuleReturnCAssume, [(eenv, CurrExpr Evaluate fexpr, [cond], [], Nothing, ngen, estk', [], [], tr)])

  | CurrExpr Return expr <- cexpr
  , Just (AssertFrame is fexpr, estk') <- S.pop estk =
      let cond = ExtCond expr False
      in
         (RuleReturnCAssert, [(eenv, CurrExpr Evaluate fexpr, [], [cond], is, ngen, estk', [], [], tr)])

  | CurrExpr Return expr <- cexpr
  , Just (frm, _) <- S.pop estk
  , not (isApplyFrame frm)
  , (Var (Id f idt):_) <- unApp expr
  , E.isSymbolic f eenv
  , t <- typeOf expr
  , isTyFun idt
  , not (isTyFun t) 
  , Just eq_tc <- concreteSatStructEq kv tc t =
    let
      (new_sym, ngen') = freshSeededString "sym" ngen
      new_sym_id = Id new_sym t

      s_eq_f = KV.structEqFunc kv

      nrpc_e = mkApp $ 
                     [ Var (Id s_eq_f TyUnknown)
                     , Type t
                     , eq_tc
                     , Var new_sym_id
                     , expr ]
    in
    (RuleReturnReplaceSymbFunc, 
      [( E.insertSymbolic new_sym new_sym_id eenv
      , CurrExpr Return (Var new_sym_id)
      , []
      , []
      , Nothing
      , ngen'
      , estk
      , [new_sym_id]
      , [nrpc_e]
      , tr)])

  | CurrExpr Return expr <- cexpr
  , Just (f, estk') <- S.pop estk =
      let (rule, (eenv', cexpr', ngen', nr_pc)) = reduceEReturn eenv expr ngen f
      in
        (rule, [(eenv', cexpr', [], [], Nothing, ngen', estk', [], nr_pc, tr)])

  | otherwise = (RuleError, [(eenv, cexpr, [], [], Nothing, ngen, estk, [], [], tr)])

-- | Result of a Evaluate reduction.
type EvaluateResult = (E.ExprEnv, CurrExpr, [Constraint], NameGen, Maybe Frame)

-- The semantics differ a bit from SSTG a bit, namely in what is and is not
-- returned from the heap. In SSTG, you return either literals or pointers.
-- The distinction is less clear here. For now :)
stdReduceEvaluate ::  E.ExprEnv -> Expr -> TypeEnv -> KnownValues -> NameGen -> (Rule, [EvaluateResult])
stdReduceEvaluate eenv (Var v) _ _ ngen = case E.lookup (idName v) eenv of
    Just expr ->
      -- If the target in our environment is already a value form, we do not
      -- need to push additional redirects for updating later on.
      -- If our variable is not in value form, we first push the
      -- current name of the variable onto the stack and evaluate the
      -- expression that it points to. After the evaluation,
      -- we pop the stack to add a redirection pointer into the heap.
      let
          (r, frame) = if isExprValueForm eenv expr 
                       then ( RuleEvalVarVal (idName v), Nothing) 
                       else ( RuleEvalVarNonVal (idName v)
                            , Just $ UpdateFrame (idName v))
      in
      ( r
      , [( eenv
         , CurrExpr Evaluate expr
         , []
         , ngen
         , frame)])
    Nothing -> error "stdReduceEvaluate: lookup was Nothing"

stdReduceEvaluate eenv (App fexpr aexpr) tenv kv ngen =
    -- Push application RHS onto the stack. This is essentially the same as the
    -- original STG rules, but we pretend that every function is (appropriately)
    -- single argument. However one problem is that eenv sharing has a redundant
    -- representation because long `App` chains will all share the same eenv.
    -- However given actual lazy evaluations within Haskell, all the
    -- `ExecExprEnv`s at each frame would really be stored in a single
    -- location on the actual Haskell heap during execution.
    case unApp (App fexpr aexpr) of
        ((Prim prim ty):ar) ->
            let
                ar' = map (flip lookupForPrim eenv) ar
                appP = mkApp (Prim prim ty : ar')
                exP = evalPrims kv tenv appP
            in
            ( RuleEvalPrimToNorm
                , [( eenv
                   , CurrExpr Return exP
                   , []
                   , ngen
                   , Nothing)])
        _ ->
            let frame = ApplyFrame aexpr
            in ( RuleEvalApp aexpr
               , [( eenv
                  , CurrExpr Evaluate fexpr
                  , []
                  , ngen
                  , Just frame)])
stdReduceEvaluate eenv (Let binds expr) _ _ ngen =
    -- Lift all the let bindings into the environment and continue with eenv
    -- and continue with evaluation of the let expression.
    let (eenv', expr', ngen', news) = liftLetBinds binds eenv expr ngen
    in ( RuleEvalLet news
       , [( eenv'
          , CurrExpr Evaluate expr'
          , []
          , ngen'
          , Nothing)])

stdReduceEvaluate eenv (Case mexpr cvar alts) _ _ ngen =
    reduceCase eenv mexpr cvar alts ngen

stdReduceEvaluate eenv cast@(Cast e coer) _ _ ngen =
    let
        (cast', ngen') = splitCast ngen cast

        frame = CastFrame coer
    in
    case cast /= cast' of
        True ->
            (RuleEvalCastSplit, [( eenv
                                 , CurrExpr Evaluate $ simplifyCasts cast'
                                 , []
                                 , ngen'
                                 , Nothing)])
        False ->
           (RuleEvalCast, [( eenv
                          , CurrExpr Evaluate $ simplifyCasts e
                          , []
                          , ngen
                          , Just frame)])

stdReduceEvaluate eenv (Assume _ pre lexpr) _ _ ngen =
    let frame = AssumeFrame lexpr
    in (RuleEvalAssume, [( eenv
                         , CurrExpr Evaluate pre
                         , []
                         , ngen
                         , Just frame)])
stdReduceEvaluate eenv (Assert is pre lexpr) _ _ ngen =
    let frame = AssertFrame is lexpr
    in (RuleEvalAssert, [( eenv
                         , CurrExpr Evaluate pre
                         , []
                         , ngen
                         , Just frame)])

stdReduceEvaluate eenv c _ _ ngen =
    (RuleError, [(eenv, CurrExpr Evaluate c, [], ngen, Nothing)])

-- | Handle the Case forms of Evaluate.
reduceCase :: E.ExprEnv -> Expr -> Id -> [Alt] -> NameGen -> (Rule, [EvaluateResult])
reduceCase eenv mexpr bind alts ngen
  -- Is the current expression able to match with a literal based `Alt`? If
  -- so, we do the cvar binding, and proceed with evaluation of the body.
  | (Lit lit) <- unsafeElimCast mexpr
  , (Alt (LitAlt _) expr):_ <- matchLitAlts lit alts =
      let 
          binds = [(bind, Lit lit)]
          expr' = liftCaseBinds binds expr
      in ( RuleEvalCaseLit
         , [( eenv
            , CurrExpr Evaluate expr'
            , []
            , ngen
            , Nothing)])

  -- Is the current expression able to match a data consturctor based `Alt`?
  -- If so, then we bind all the parameters to the appropriate arguments and
  -- proceed with the evaluation of the `Alt`'s expression. We also make sure
  -- to perform the cvar binding.
  -- We unwrap the outermost cast from the mexpr.  It must be being cast
  -- to the DataCon type, so this is safe, and needed for our pattern matching.
  -- We do not want to remove casting from any of the arguments since this could
  -- mess up there types later
  | (Data dcon):ar <- unApp $ exprInCasts mexpr
  , (DataCon _ _) <- dcon
  , ar' <- removeTypes ar eenv
  , (Alt (DataAlt _ params) expr):_ <- matchDataAlts dcon alts
  , length params == length ar' =
      let
          dbind = [(bind, mexpr)]
          expr' = liftCaseBinds dbind expr
          pbinds = zip params ar'
          (eenv', expr'', ngen', news) = liftBinds pbinds eenv expr' ngen
      in 
         ( RuleEvalCaseData news
         , [( eenv'
            , CurrExpr Evaluate expr''
            , []
            , ngen'
            , Nothing)] )

  -- We are not able to match any constructor but don't have a symbolic variable?
  -- We hit a DEFAULT instead.
  -- We perform the cvar binding and proceed with the alt
  -- expression.
  | (Data _):_ <- unApp $ unsafeElimCast mexpr
  , (Alt _ expr):_ <- defaultAlts alts =
      let 
          binds = [(bind, mexpr)]
          expr' = liftCaseBinds binds expr
      in ( RuleEvalCaseDefault
         , [( eenv
            , CurrExpr Evaluate expr'
            , []
            , ngen
            , Nothing)])

  -- If we are pointing to something in expr value form, that is not addressed
  -- by some previous case, we handle it by branching on every `Alt`, and adding
  -- path constraints.
  | isExprValueForm eenv mexpr
  , dalts <- dataAlts alts
  , lalts <- litAlts alts
  , defs <- defaultAlts alts
  , (length dalts + length lalts + length defs) > 0 =
      let
          dsts_cs = liftSymDataAlt eenv mexpr ngen bind dalts
          lsts_cs = liftSymLitAlt eenv mexpr ngen bind lalts
          def_sts = liftSymDefAlt eenv mexpr ngen bind alts
      in
      (RuleEvalCaseSym, dsts_cs ++ lsts_cs ++ def_sts)

  -- Case evaluation also uses the stack in graph reduction based evaluation
  -- semantics. The case's binding variable and alts are pushed onto the stack
  -- as a `CaseFrame` along with their appropriate `ExecExprEnv`. However this
  -- is only done when the matching expression is NOT in value form. Value
  -- forms should be handled by other RuleEvalCase* rules.
  | not (isExprValueForm eenv mexpr) =
      let frame = CaseFrame bind alts
      in ( RuleEvalCaseNonVal
         , [( eenv
            , CurrExpr Evaluate mexpr
            , []
            , ngen
            , Just frame)])

  | otherwise = error $ "reduceCase: bad case passed in\n" ++ show mexpr ++ "\n" ++ show alts

-- | Result of a Return reduction.
type EReturnResult = (E.ExprEnv, CurrExpr, NameGen, [Expr])

-- | Handle the Return states.
reduceEReturn :: E.ExprEnv -> Expr -> NameGen -> Frame -> (Rule, EReturnResult)
reduceEReturn eenv cexpr ngen frm
-- We are returning something and the first thing that we have on the stack
-- is an `UpdateFrame`, this means that we add a redirection pointer to the
-- `ExecExprEnv`, and continue with execution. This is the equivalent of
-- performing memoization on values that we have seen.
  | (Var (Id name ty)) <- cexpr
  , (UpdateFrame frm_name) <- frm =
    ( RuleReturnEUpdateVar frm_name
    , ( E.redirect frm_name name eenv
      , CurrExpr Return (Var $ Id name ty)
      , ngen
      , []))

-- If the variable we are returning does not have a `Var` in it at the
-- immediate top level, then we have to insert it into the `ExecExprEnv`
-- directly.
  | (UpdateFrame frm_name) <- frm =
  ( RuleReturnEUpdateNonVar frm_name
  , ( E.insert frm_name cexpr eenv
    , CurrExpr Return cexpr
    , ngen
    , []))

-- In the event that we are returning and we have a `CaseFrame` waiting for
-- us at the top of the stack, we would simply inject it into the case
-- expression. We do some assumptions here about the form of expressions!
  | (CaseFrame cvar alts) <- frm =
    ( RuleReturnECase
    , ( eenv
      , CurrExpr Evaluate (Case cexpr cvar alts)
      , ngen
      , []))

-- If we have a `CastFrame` at the top of the stack, we know to recast
-- the Current Expression.
  | (CastFrame (t1 :~ t2)) <- frm =
    ( RuleReturnCast
    , ( eenv
      , CurrExpr Evaluate $ simplifyCasts $ Cast cexpr (t1 :~ t2)
      , ngen
      , []))

  | (Lam _ _ _) <- cexpr =
    let
        (r, rr, _) = reduceLam eenv cexpr ngen frm
    in
    (r, rr)

-- When we return symbolic values on an `ApplyFrame`, introduce new name
-- mappings in the eenv to form this long symbolic normal form chain.
-- reduceEReturn eenv c@(Var v) ngen (ApplyFrame aexpr) =
--   if not (E.isSymbolic (idName v) eenv)
--     then (RuleError, (eenv, CurrExpr Return c, ngen))
--     else let (sname, ngen') = freshSeededName (idName v) ngen
--              sym_app = App (Var v) aexpr
--              svar = Id sname (mkTyApp (typeOf v) (typeOf aexpr))
--          in ( RuleReturnEApplySym
--             , ( E.insert sname sym_app eenv
--               , CurrExpr Return (Var svar)
--               , ngen'))
  | (ApplyFrame aexpr) <- frm =
  case unApp cexpr of
      (Prim _ _):_ ->  
          ( RuleReturnEApplySym
          , ( eenv
            , CurrExpr Evaluate (App cexpr aexpr)
            , ngen
            , []))
      (Data _):_ ->
          ( RuleReturnEApplyData
          , ( eenv
            , CurrExpr Evaluate (App cexpr aexpr)
            , ngen
            , []))
      (Var (Id n _)):_ ->
          if E.isSymbolic n eenv
              then (RuleReturnAppSymbFunc, (eenv, CurrExpr Return (App cexpr aexpr), ngen, []))
              else (RuleError, (eenv, CurrExpr Return cexpr, ngen, []))
      _ -> (RuleError, (eenv, CurrExpr Return cexpr, ngen, []))

  | otherwise = (RuleError, (eenv, CurrExpr Return cexpr, ngen, []))

isApplyFrame :: Frame -> Bool
isApplyFrame (ApplyFrame _) = True
isApplyFrame _ = False

reduceLam :: ExprEnv -> Expr -> NameGen -> Frame -> (Rule, EReturnResult, [Name])
  -- In the event that our Lam parameter is a type variable, we have to handle
-- it by retyping.
reduceLam eenv (Lam _ b@(Id n t) lexpr) ngen (ApplyFrame (Var i@(Id n' TYPE)))
  | hasTYPE t =
      let aty = case traceIdType i eenv of
                      Just ty -> ty
                      Nothing -> error $ "unable to trace: " ++ show n'
          binds = [(Id n aty, Type aty)]
          lexpr' = retype b aty lexpr
          (eenv', lexpr'', ngen', news) = liftBinds binds eenv lexpr' ngen
      in ( RuleReturnEApplyLamType news
         , ( eenv'
           , CurrExpr Evaluate lexpr''
           , ngen'
           , [])
         , news)

reduceLam eenv (Lam _ b@(Id n _) lexpr) ngen (ApplyFrame taexpr)
  | Type aexpr <- taexpr =
      let aty = aexpr
          binds = [(Id n aty, taexpr)]
          lexpr' = retype b aty lexpr
          (eenv', lexpr'', ngen', news) = liftBinds binds eenv lexpr' ngen
      in ( RuleReturnEApplyLamType news
         , ( eenv'
           , CurrExpr Evaluate lexpr''
           , ngen'
           , [])
         , news)

-- When we have an `ApplyFrame` on the top of the stack, things might get a
-- bit tricky, since we need to make sure that the thing we end up returning
-- is appropriately a value. In the case of `Lam`, we need to perform
-- application, and then go into the expression body.
-- reduceEReturn eenv (Lam b lexpr) ngen (ApplyFrame aexpr) =
  | otherwise =
        let binds = [(b, taexpr)]
            (eenv', lexpr', ngen', news) = liftBinds binds eenv lexpr ngen
        in ( RuleReturnEApplyLamExpr news
           , ( eenv'
             , CurrExpr Evaluate lexpr'
             , ngen'
             , [])
           , news)
reduceLam _ _ _ _ = error "Bad expr in reduceLam"
