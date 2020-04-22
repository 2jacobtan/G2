module G2.Liquid.Inference.Interface ( inferenceCheck
                                     , inference) where

import G2.Config.Config as G2
import qualified G2.Initialization.Types as IT
import G2.Interface hiding (violated)
import G2.Language.CallGraph
import qualified G2.Language.ExprEnv as E
import G2.Language.Naming
import G2.Language.Support
import G2.Language.Syntax
import G2.Liquid.AddTyVars
import G2.Liquid.Inference.Config
import G2.Liquid.Inference.FuncConstraint as FC
import G2.Liquid.Inference.G2Calls
import G2.Liquid.Inference.PolyRef
import G2.Liquid.Inference.Sygus
import G2.Liquid.Inference.GeneratedSpecs
import G2.Liquid.Inference.Verify
import G2.Liquid.Interface
import G2.Liquid.Types
import G2.Translation

import Language.Haskell.Liquid.Types as LH

import Control.Monad
import Control.Monad.Extra
import Control.Monad.IO.Class 
import Data.Either
import qualified Data.HashSet as S
import Data.List
import Data.Maybe
import qualified Data.Text as T

import qualified Language.Fixpoint.Types.Config as FP

-- Run inference, with an extra, final check of correctness at the end.
-- Assuming inference is working correctly, this check should neve fail.
inferenceCheck :: InferenceConfig -> G2.Config -> [FilePath] -> [FilePath] -> [FilePath] -> IO (Either [CounterExample] GeneratedSpecs)
inferenceCheck infconfig config proj fp lhlibs = do
    (ghci, lhconfig) <- getGHCI infconfig config proj fp lhlibs
    res <- inference' infconfig config lhconfig ghci proj fp lhlibs
    case res of
        Right gs -> do
            check_res <- checkGSCorrect infconfig lhconfig ghci gs
            case check_res of
                Safe -> return res
                _ -> error "inferenceCheck: Check failed"
        _ -> return res

inference :: InferenceConfig -> G2.Config -> [FilePath] -> [FilePath] -> [FilePath] -> IO (Either [CounterExample] GeneratedSpecs)
inference infconfig config proj fp lhlibs = do
    -- Initialize LiquidHaskell
    (ghci, lhconfig) <- getGHCI infconfig config proj fp lhlibs
    inference' infconfig config lhconfig ghci proj fp lhlibs

inference' :: InferenceConfig -> G2.Config -> LH.Config -> [GhcInfo] -> [FilePath] -> [FilePath] -> [FilePath] -> IO (Either [CounterExample] GeneratedSpecs)
inference' infconfig config lhconfig ghci proj fp lhlibs = do
    mapM (print . gsQualifiers . spec) ghci

    -- Initialize G2
    let g2config = config { mode = Liquid
                          , steps = 2000 }
        transConfig = simplTranslationConfig { simpl = False }
    exg2@(main_mod, _) <- translateLoaded proj fp lhlibs transConfig g2config

    let simp_s = initSimpleState (snd exg2)
        (g2config', infconfig') = adjustConfig main_mod simp_s g2config infconfig ghci

        lrs = createStateForInference simp_s g2config' ghci

        eenv = expr_env . state . lr_state $ lrs

        nls = filter (not . null)
            . map (filter (\(Name _ m _ _) -> m == fst exg2)) 
            . nameLevels
            . getCallGraph $ eenv

    putStrLn $ "cg = " ++ show (filter (\(Name _ m _ _) -> m == fst exg2) . functions $ getCallGraph eenv)
    putStrLn $ "nls = " ++ show nls

    let configs = Configs { g2_config = g2config', lh_config = lhconfig, inf_config = infconfig'}
        prog = newProgress

        infL = inferenceL 0 ghci (fst exg2) lrs nls WorkDown emptyGS emptyFC []

    inf <-  runConfigs (runProgresser infL prog) configs
    case inf of
        CEx cex -> return $ Left cex
        GS gs -> return $ Right gs
        FCs _ _ _ -> error "inference: Unhandled Func Constraints"

getGHCI :: InferenceConfig -> G2.Config -> [FilePath] -> [FilePath] -> [FilePath] -> IO ([GhcInfo], LH.Config)
getGHCI infconfig config proj fp lhlibs = do
    lhconfig <- defLHConfig proj lhlibs
    let lhconfig' = lhconfig { pruneUnsorted = True
                             -- Block qualifiers being auto-generated by LH
                             , maxParams = if keep_quals infconfig then maxParams lhconfig else 0
                             , eliminate = if keep_quals infconfig then eliminate lhconfig else FP.All
                             , higherorderqs = False
                             , scrapeImports = False
                             , scrapeInternals = False
                             , scrapeUsedImports = False }
    ghci <- ghcInfos Nothing lhconfig' fp
    return (ghci, lhconfig)

data InferenceRes = CEx [CounterExample]
                  | FCs FuncConstraints RisingFuncConstraints GeneratedSpecs
                  | GS GeneratedSpecs
                  deriving (Show)

data WorkingDir = WorkDown | WorkUp deriving (Eq, Show, Read)

-- When we try to synthesize a specification for a function that we have already found a specification for,
-- we have to return to when we originally synthesized that specification.  We pass the newly aquired
-- FuncConstraints as RisignFuncConstraints
type RisingFuncConstraints = FuncConstraints

type Level = Int
type NameLevels = [[Name]]

inferenceL :: (ProgresserM m, InfConfigM m, MonadIO m) =>  Level -> [GhcInfo] -> Maybe T.Text -> LiquidReadyState
           -> NameLevels -> WorkingDir -> GeneratedSpecs -> FuncConstraints -> [Name] -> m InferenceRes
inferenceL level ghci m_modname lrs nls wd gs fc try_to_synth = do
    liftIO $ putStrLn $ "---\ninference' level " ++ show level
    liftIO . putStrLn $ "at_level = " ++ show (case nls of (h:_) -> Just h; _ -> Nothing)
    liftIO . putStrLn $ "working dir = " ++ show wd
    liftIO . putStrLn $ "try_to_synth = "  ++ show try_to_synth
    liftIO . putStrLn $ "fc =\n" ++ printFCs fc
    liftIO . putStrLn $ "gs =\n" ++ show gs
    liftIO . putStrLn $ "in ghci specs = " ++ show (concatMap (map fst) $ map (gsTySigs . spec) ghci)
    liftIO . putStrLn $ "nls = " ++ show nls

    let ignore = concat nls

    res <- tryHardToVerifyIgnoring ghci gs ignore

    liftIO $ putStrLn "After res"

    case res of
        Right new_gs
            | (_:nls') <- nls -> do
                liftIO $ putStrLn "---\nFound good GS"
                let ghci' = addSpecsToGhcInfos ghci new_gs
                
                raiseFCs level ghci m_modname lrs nls
                    =<< inferenceL (level + 1) ghci' m_modname lrs nls' WorkDown new_gs fc []
            | otherwise -> return $ GS new_gs
        Left bad -> do
            ref <- refineUnsafe ghci m_modname lrs wd gs bad

            -- If we got repeated assertions, increase the search depth
            -- case any (\n -> lookupAssertGS n gs == lookupAssertGS n synth_gs) try_to_synth of
            --     True -> mapM_ (incrMaxCExM . nameTuple) bad
            --     False -> return ()

            case ref of
                Left cex -> return $ CEx cex
                Right (new_fc, wd')  -> do
                    liftIO $ putStrLn "---\nNew FuncConstraints"
                    liftIO . putStrLn $ "new_fc =\n" ++ printFCs new_fc
                    let pre_solved = notAppropFCs (concat nls) new_fc
                    case nullFC pre_solved of
                        False -> do
                            liftIO . putStrLn $ "---\nreturning FuncConstraints from level " ++ show level
                            liftIO . putStrLn $ "pre_solved =\n" ++ printFCs pre_solved

                            let new_fc' = adjustOldFC new_fc pre_solved
                                fc' = adjustOldFC fc pre_solved
                            return $ FCs fc' new_fc' gs
                        True -> do
                            let fc' = adjustOldFC fc new_fc
                                merged_fc = unionFC fc' new_fc

                            liftIO $ putStrLn "---\nTrue Branch"

                            rel_funcs <- relFuncs nls new_fc

                            synth_gs <- synthesize ghci lrs gs merged_fc rel_funcs
                            increaseProgressing new_fc gs synth_gs rel_funcs
                            
                            inferenceL level ghci m_modname lrs nls wd' synth_gs merged_fc rel_funcs

raiseFCs :: (ProgresserM m, InfConfigM m, MonadIO m) =>  Level -> [GhcInfo] -> Maybe T.Text -> LiquidReadyState
         -> NameLevels -> InferenceRes -> m InferenceRes
raiseFCs level ghci m_modname lrs nls lev@(FCs fc new_fc gs) = do
    liftIO . putStrLn $ "---\nMoving up to level " ++ show level 
    liftIO . putStrLn $ "in ghci specs = " ++ show (concatMap (map fst) $ map (gsTySigs . spec) ghci)
    liftIO . putStrLn $ "new_fc =\n" ++ printFCs new_fc
    let
        -- If we have new FuncConstraints, we need to resynthesize,
        -- but otherwise we can just keep the exisiting specifications
        -- cons_on = map (funcName . constraint) $ toListFC new_fc
    rel_funcs <- relFuncs nls new_fc

    if nullFC (notAppropFCs (concat nls) new_fc)
        then do
            let merge_fc = unionFC fc new_fc
            synth_gs <- synthesize ghci lrs gs merge_fc rel_funcs
            increaseProgressing new_fc gs synth_gs rel_funcs
            inferenceL level ghci m_modname lrs nls WorkUp synth_gs merge_fc rel_funcs
        else return lev
raiseFCs _ _ _ _ _ lev = do
    liftIO $ putStrLn "---\nReturn lev"
    return lev

refineUnsafe :: (ProgresserM m, InfConfigM m, MonadIO m) => [GhcInfo] -> Maybe T.Text -> LiquidReadyState
             -> WorkingDir -> GeneratedSpecs
             -> [Name] -> m (Either [CounterExample] (FuncConstraints, WorkingDir))
refineUnsafe ghci m_modname lrs wd gs bad = do
    liftIO . putStrLn $ "refineUnsafe " ++ show bad
    liftIO $ print wd
    let merged_se_ghci = addSpecsToGhcInfos ghci gs

    liftIO $ putStrLn "gsTySigs"
    liftIO $ mapM_ (print . gsTySigs . spec) merged_se_ghci

    let bad' = nub $ map nameOcc bad

    res <- mapM (genNewConstraints merged_se_ghci m_modname lrs) bad'

    liftIO . putStrLn $ "length res = " ++ show (length res)
    liftIO . putStrLn $ "res"
    liftIO . printCE $ concat res
    let res' = concat res

    -- Check if we already have specs for any of the functions
    wd' <- adjustWorkingDir res' wd

    -- Either converts counterexamples to FuncConstraints, or returns them as errors to
    -- show to the user.
    new_fc <- checkNewConstraints ghci lrs wd' res'

    case new_fc of
        Left cex -> return $ Left cex
        Right new_fc' -> do
            return $ Right (new_fc', wd')
              
adjustOldFC :: FuncConstraints -- ^ Old FuncConstraints
            -> FuncConstraints -- ^ New FuncConstraints
            -> FuncConstraints
adjustOldFC old_fc new_fc =
    let
        constrained = map (funcName . constraint) $ toListFC new_fc
    in
    mapMaybeFC
        (\c -> case modification c of
                    SwitchImplies ns
                        | ns `intersect` constrained /= [] ->
                            Just $ c { bool_rel = BRImplies }
                    Delete ns
                        | ns `intersect` constrained /= [] -> Nothing
                    _ -> Just c) old_fc

appropFCs :: [Name] -> FuncConstraints -> FuncConstraints
appropFCs potential =
    let
        nm_potential = map nameTuple potential
    in
    filterFC (flip elem nm_potential . nameTuple . funcName . constraint)

notAppropFCs :: [Name] -> FuncConstraints -> FuncConstraints
notAppropFCs potential =
    let
        nm_potential = map nameTuple potential
    in
    filterFC (flip notElem nm_potential . nameTuple . funcName . constraint)

createStateForInference :: SimpleState -> G2.Config -> [GhcInfo] -> LiquidReadyState
createStateForInference simp_s config ghci =
    let
        (simp_s', ph_tyvars) = if add_tyvars config
                                then fmap Just $ addTyVarsEEnvTEnv simp_s
                                else (simp_s, Nothing)
        (s, b) = initStateFromSimpleState simp_s' True 
                    (\_ ng _ _ _ _ -> (Prim Undefined TyBottom, [], [], ng))
                    (E.higherOrderExprs . IT.expr_env)
                    config
    in
    createLiquidReadyState s b ghci ph_tyvars config


genNewConstraints :: (ProgresserM m, InfConfigM m, MonadIO m) => [GhcInfo] -> Maybe T.Text -> LiquidReadyState -> T.Text -> m [CounterExample]
genNewConstraints ghci m lrs n = do
    liftIO . putStrLn $ "Generating constraints for " ++ T.unpack n
    ((exec_res, _), i) <- runLHInferenceCore n m lrs ghci
    return $ map (lhStateToCE i) exec_res

checkNewConstraints :: (InfConfigM m, MonadIO m) => [GhcInfo] -> LiquidReadyState -> WorkingDir -> [CounterExample] -> m (Either [CounterExample] FuncConstraints)
checkNewConstraints ghci lrs wd cexs = do
    g2config <- g2ConfigM
    infconfig <- infConfigM
    res <- mapM (cexsToFuncConstraints lrs ghci wd) cexs
    case lefts res of
        res'@(_:_) -> return . Left $ res'
        _ -> return . Right . filterErrors . unionsFC . rights $ res

genMeasureExs :: (InfConfigM m, MonadIO m) => LiquidReadyState -> [GhcInfo] -> FuncConstraints -> m MeasureExs
genMeasureExs lrs ghci fcs =
    let
        es = concatMap (\fc ->
                    let
                        cons = constraint fc
                        ex_poly = concat . concatMap extractValues . concatMap extractExprPolyBound $ returns cons:arguments cons
                    in
                    returns cons:arguments cons ++ ex_poly
                ) (toListFC fcs)
    in
    evalMeasures lrs ghci es

increaseProgressing :: ProgresserM m => FuncConstraints -> GeneratedSpecs -> GeneratedSpecs -> [Name] -> m ()
increaseProgressing fc gs synth_gs synthed = do
    -- If we got repeated assertions, increase the search depth
    case any (\n -> lookupAssertGS n gs == lookupAssertGS n synth_gs) synthed of
        True -> mapM_ (incrMaxCExM . nameTuple) (map generated_by $ toListFC fc)
        False -> return ()


synthesize :: (InfConfigM m, MonadIO m) => [GhcInfo] -> LiquidReadyState
            -> GeneratedSpecs -> FuncConstraints -> [Name] -> m GeneratedSpecs
synthesize ghci lrs gs fc for_funcs = do
    -- Only consider functions in the modules that we have access to.
    liftIO $ putStrLn "Before genMeasureExs"
    meas_ex <- genMeasureExs lrs ghci fc
    liftIO $ putStrLn "After genMeasureExs"
    foldM (synthesize' ghci lrs meas_ex fc) gs $ nub for_funcs

synthesize' :: (InfConfigM m, MonadIO m) => [GhcInfo] -> LiquidReadyState -> MeasureExs -> FuncConstraints -> GeneratedSpecs -> Name -> m GeneratedSpecs
synthesize' ghci lrs meas_ex fc gs n = do
    spec_qual <- refSynth ghci lrs meas_ex fc n

    case spec_qual of
        Just (new_spec, new_qual) -> do
            -- We ASSUME postconditions, and ASSERT preconditions.  This ensures
            -- that our precondition is satisified by the caller, and the postcondition
            -- is strong enough to allow verifying the caller
            let gs' = insertAssertGS n new_spec gs

            return $ foldr insertQualifier gs' new_qual
        Nothing -> return gs

-- | Converts counterexamples into constraints that the refinements must allow for, or rule out.
cexsToFuncConstraints :: InfConfigM m => LiquidReadyState -> [GhcInfo] -> WorkingDir -> CounterExample -> m (Either CounterExample FuncConstraints)
cexsToFuncConstraints _ _ _ (DirectCounter dfc fcs@(_:_)) = do
    infconfig <- infConfigM
    let fcs' = filter (\fc -> abstractedMod fc `S.member` modules infconfig) fcs

    real_cons <- mapMaybeM (mkRealFCFromAbstracted imp (funcName dfc)) fcs'
    abs_cons <- mapMaybeM (mkAbstractFCFromAbstracted del (funcName dfc)) fcs'

    if not . null $ fcs'
        then return . Right . insertsFC $ real_cons ++ abs_cons
        else error "cexsToFuncConstraints: unhandled 1"
    where
        imp _ = SwitchImplies [funcName dfc]
        del _ = Delete [funcName dfc]
cexsToFuncConstraints _ _ _ (CallsCounter dfc cfc fcs@(_:_)) = do
    infconfig <- infConfigM
    let fcs' = filter (\fc -> abstractedMod fc `S.member` modules infconfig) fcs

    callee_cons <- mkRealFCFromAbstracted imp (funcName dfc) cfc
    real_cons <- mapMaybeM (mkRealFCFromAbstracted imp (funcName dfc)) fcs'
    abs_cons <- mapMaybeM (mkAbstractFCFromAbstracted del (funcName dfc)) fcs'

    if not . null $ fcs' 
        then return . Right . insertsFC
                            $ maybeToList callee_cons ++ real_cons ++ abs_cons
        else error "cexsToFuncConstraints: Should be unreachable! Non-refinable function abstracted!"
    where
        imp n = SwitchImplies $ funcName dfc:delete n ns
        del _ = Delete $ [funcName dfc, funcName $ abstract cfc] ++ ns

        ns = nub $ map (funcName . abstract) fcs
cexsToFuncConstraints lrs ghci _ cex@(DirectCounter fc []) = do
    let Name n m _ _ = funcName fc
    infconfig <- infConfigM
    case (n, m) `S.member` pre_refined infconfig of
        False ->
            return . Right . insertsFC $
                                [FC { polarity = if notRetError fc then Pos else Neg
                                    , generated_by = funcName fc
                                    , violated = Post
                                    , modification = SwitchImplies [funcName fc]
                                    , bool_rel = BRImplies
                                    , constraint = fc} ]
        True -> return . Left $ cex
cexsToFuncConstraints lrs ghci wd cex@(CallsCounter caller_fc called_fc []) = do
    caller_pr <- hasUserSpec (funcName caller_fc)
    called_pr <- hasUserSpec (funcName $ real called_fc)

    case (caller_pr, called_pr) of
        (True, True) -> return .  Left $ cex
        (False, True) ->  return . Right . insertsFC $
                                                  [FC { polarity = Neg
                                                      , generated_by = funcName caller_fc
                                                      , violated = Pre
                                                      , modification = None -- [funcName called_fc]
                                                      , bool_rel = BRImplies 
                                                      , constraint = caller_fc } ]
        (True, False) -> return . Right . insertsFC $
                                                 [FC { polarity = if notRetError (real called_fc) then Pos else Neg
                                                     , generated_by = funcName caller_fc
                                                     , violated = Pre
                                                     , modification = None -- [funcName caller_fc]
                                                     , bool_rel = if notRetError (real called_fc) then BRAnd else BRImplies
                                                     , constraint = real called_fc } ]
        (False, False)
            | wd == WorkUp -> 
                           return . Right . insertsFC $
                                                    [ FC { polarity = Neg
                                                         , generated_by = funcName caller_fc
                                                         , violated = Pre
                                                         , modification = Delete [funcName $ real called_fc]
                                                         , bool_rel = BRImplies
                                                         , constraint = caller_fc {returns = Prim Error TyBottom} }
                                                         , FC { polarity = if notRetError caller_fc then Pos else Neg
                                                              , generated_by = funcName caller_fc
                                                              , violated = Pre
                                                              , modification = None
                                                              , bool_rel = BRImplies
                                                              , constraint = caller_fc }  ]
            | otherwise -> return . Right . insertsFC $
                                                   [FC { polarity = if notRetError (real called_fc) then Pos else Neg
                                                       , generated_by = funcName caller_fc
                                                       , violated = Pre
                                                       , modification = SwitchImplies [funcName caller_fc]
                                                       , bool_rel = if notRetError (real called_fc) then BRAnd else BRImplies
                                                       , constraint = real called_fc } ]

mkRealFCFromAbstracted :: InfConfigM m => (Name -> Modification) -> Name -> Abstracted -> m (Maybe FuncConstraint)
mkRealFCFromAbstracted md gb ce = do
    let fc = real ce
    user_def <- hasUserSpec $ funcName fc

    if not (hits_lib_err_in_real ce) && not user_def
        then
            return . Just $ FC { polarity = if notRetError fc then Pos else Neg
                               , generated_by = gb
                               , violated = Post
                               , modification = md (funcName fc)
                               , bool_rel = if notRetError fc then BRAnd else BRImplies
                               , constraint = fc }
        else return Nothing 

-- | If the real fc returns an error, we know that our precondition has to be
-- strengthened to block the input.
-- Thus, creating an abstract counterexample would be (at best) redundant.
mkAbstractFCFromAbstracted :: InfConfigM m => (Name -> Modification) -> Name -> Abstracted -> m (Maybe FuncConstraint)
mkAbstractFCFromAbstracted md gb ce = do
    let fc = abstract ce
    user_def <- hasUserSpec $ funcName fc

    if (notRetError (real ce) || hits_lib_err_in_real ce) && not user_def
        then
            return . Just $ FC { polarity = Neg
                               , generated_by = gb
                               , violated = Post
                               , modification = md (funcName fc)
                               , bool_rel = BRImplies
                               , constraint = fc } 
        else return Nothing

adjustWorkingDir :: InfConfigM m => [CounterExample] -> WorkingDir -> m WorkingDir
adjustWorkingDir cexs wd = do
    let
        callers = mapMaybe getDirectCaller cexs
        called = mapMaybe getDirectCalled cexs

    caller_pr <- anyM (hasUserSpec . funcName) callers
    called_pr <- anyM (hasUserSpec . funcName) called
    
    case (caller_pr, called_pr) of
        (True, False) -> return WorkDown
        (False, True) -> return WorkUp
        (_, _)
            | any (isError . returns ) called -> return WorkUp
            | otherwise -> return wd
    where
        isError (Prim Error _) = True
        isError _ = False

hasUserSpec :: InfConfigM m => Name -> m Bool
hasUserSpec (Name n m _ _) = do
    infconfig <- infConfigM
    return $ (n, m) `S.member` pre_refined infconfig

getDirectCaller :: CounterExample -> Maybe FuncCall
getDirectCaller (CallsCounter f _ []) = Just f
getDirectCaller _ = Nothing

getDirectCalled :: CounterExample -> Maybe FuncCall
getDirectCalled (CallsCounter _ f []) = Just (abstract f)
getDirectCalled _ = Nothing

notRetError :: FuncCall -> Bool
notRetError (FuncCall { returns = Prim Error _ }) = False
notRetError _ = True

insertsFC :: [FuncConstraint] -> FuncConstraints
insertsFC = foldr insertFC emptyFC

abstractedMod :: Abstracted -> Maybe T.Text
abstractedMod = nameModule . funcName . abstract

filterErrors :: FuncConstraints -> FuncConstraints
filterErrors = filterFC filterErrors'

filterErrors' :: FuncConstraint -> Bool
filterErrors' fc =
    let
        c = constraint fc

        as = not . any isError $ arguments c
    in
    as
    where
        isError (Prim Error _) = True
        isError _ = False


relFuncs :: InfConfigM m => NameLevels -> FuncConstraints -> m [Name]
relFuncs nls fc = do
    let immed_rel_fc = case nls of
                            (nl:_) -> appropFCs nl fc
                            _ -> emptyFC

    infconfig <- infConfigM
    return 
       . filter (\(Name _ m _ _) -> m `S.member` (modules infconfig))
       . nubBy (\n1 n2 -> nameOcc n1 == nameOcc n2)
       . map (funcName . constraint)
       . toListFC $ immed_rel_fc
