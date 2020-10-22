{-# LANGUAGE EmptyCase #-}
{-# LANGUAGE UndecidableInstances #-}

-- |
-- This includes the evaluators (evalTerm and evalElim),
-- the value application function (vapp) and
-- the substitution functions (substTerm and substElim).
module Juvix.Core.IR.Evaluator where

import qualified Data.IntMap as IntMap
import qualified Juvix.Core.IR.Typechecker.Types as TC
import qualified Juvix.Core.IR.Types as IR
import qualified Juvix.Core.IR.Types.Base as IR
import qualified Juvix.Core.Parameterisation as Param
import Juvix.Library

class HasWeak a where
  --
  weakBy' :: Natural -> IR.BoundVar -> a -> a
  default weakBy' ::
    (Generic a, GHasWeak (Rep a)) =>
    Natural ->
    IR.BoundVar ->
    a ->
    a
  weakBy' b i = to . gweakBy' b i . from

weakBy :: HasWeak a => Natural -> a -> a
weakBy b = weakBy' b 0

weak' :: HasWeak a => IR.BoundVar -> a -> a
weak' = weakBy' 1

weak :: HasWeak a => a -> a
weak = weak' 0

type AllWeak ext primTy primVal =
  ( IR.TermAll HasWeak ext primTy primVal,
    IR.ElimAll HasWeak ext primTy primVal
  )

instance AllWeak ext primTy primVal => HasWeak (IR.Term' ext primTy primVal) where
  weakBy' b i (IR.Star' u a) =
    IR.Star' u (weakBy' b i a)
  weakBy' b i (IR.PrimTy' p a) =
    IR.PrimTy' p (weakBy' b i a)
  weakBy' b i (IR.Prim' p a) =
    IR.Prim' p (weakBy' b i a)
  weakBy' b i (IR.Pi' π s t a) =
    IR.Pi' π (weakBy' b i s) (weakBy' b (succ i) t) (weakBy' b i a)
  weakBy' b i (IR.Lam' t a) =
    IR.Lam' (weakBy' b (succ i) t) (weakBy' b i a)
  weakBy' b i (IR.Sig' π s t a) =
    IR.Sig' π (weakBy' b i s) (weakBy' b (succ i) t) (weakBy' b i a)
  weakBy' b i (IR.Pair' s t a) =
    IR.Pair' (weakBy' b i s) (weakBy' b i t) (weakBy' b i a)
  weakBy' b i (IR.Let' π s t a) =
    IR.Let' π (weakBy' b i s) (weakBy' b (succ i) t) (weakBy' b i a)
  weakBy' b i (IR.Elim' f a) =
    IR.Elim' (weakBy' b i f) (weakBy' b i a)
  weakBy' b i (IR.TermX a) =
    IR.TermX (weakBy' b i a)

instance AllWeak ext primTy primVal => HasWeak (IR.Elim' ext primTy primVal) where
  weakBy' b i (IR.Bound' j a)
    | j >= i = IR.Bound' (j + b) a'
    | otherwise = IR.Bound' j a'
    where
      a' = weakBy' b i a
  weakBy' b i (IR.Free' x a) =
    IR.Free' x (weakBy' b i a)
  weakBy' b i (IR.App' s t a) =
    IR.App' (weakBy' b i s) (weakBy' b i t) (weakBy' b i a)
  weakBy' b i (IR.Ann' π s t l a) =
    IR.Ann' π (weakBy' b i s) (weakBy' b i t) l (weakBy' b i a)
  weakBy' b i (IR.ElimX a) =
    IR.ElimX (weakBy' b i a)

class HasWeak a => HasSubst ext primTy primVal a where
  substWith ::
    -- | How many bindings have been traversed so far
    IR.BoundVar ->
    -- | Variable to substitute
    IR.BoundVar ->
    -- | Expression to substitute with
    IR.Elim' ext primTy primVal ->
    a ->
    a
  default substWith ::
    (Generic a, GHasSubst ext primTy primVal (Rep a)) =>
    Natural ->
    IR.BoundVar ->
    IR.Elim' ext primTy primVal ->
    a ->
    a
  substWith b i e = to . gsubstWith b i e . from

subst' ::
  HasSubst ext primTy primVal a =>
  IR.BoundVar ->
  IR.Elim' ext primTy primVal ->
  a ->
  a
subst' = substWith 0

subst ::
  HasSubst ext primTy primVal a =>
  IR.Elim' ext primTy primVal ->
  a ->
  a
subst = subst' 0

type AllSubst ext primTy primVal =
  ( IR.TermAll (HasSubst ext primTy primVal) ext primTy primVal,
    IR.ElimAll (HasSubst ext primTy primVal) ext primTy primVal
  )

instance
  AllSubst ext primTy primVal =>
  HasSubst ext primTy primVal (IR.Term' ext primTy primVal)
  where
  substWith w i e (IR.Star' u a) =
    IR.Star' u (substWith w i e a)
  substWith w i e (IR.PrimTy' t a) =
    IR.PrimTy' t (substWith w i e a)
  substWith w i e (IR.Prim' p a) =
    IR.Prim' p (substWith w i e a)
  substWith w i e (IR.Pi' π s t a) =
    IR.Pi' π (substWith w i e s) (substWith (succ w) (succ i) e t) (substWith w i e a)
  substWith w i e (IR.Lam' t a) =
    IR.Lam' (substWith (succ w) (succ i) e t) (substWith w i e a)
  substWith w i e (IR.Sig' π s t a) =
    IR.Sig' π (substWith w i e s) (substWith (succ w) (succ i) e t) (substWith w i e a)
  substWith w i e (IR.Pair' s t a) =
    IR.Pair' (substWith w i e s) (substWith w i e t) (substWith w i e a)
  substWith w i e (IR.Let' π l b a) =
    IR.Let' π (substWith w i e l) (substWith (succ w) (succ i) e b) (substWith w i e a)
  substWith w i e (IR.Elim' t a) =
    IR.Elim' (substWith w i e t) (substWith w i e a)
  substWith w i e (IR.TermX a) =
    IR.TermX (substWith w i e a)

instance
  AllSubst ext primTy primVal =>
  HasSubst ext primTy primVal (IR.Elim' ext primTy primVal)
  where
  substWith w i e (IR.Bound' j a) =
    case compare j i of
      LT -> IR.Bound' j a'
      EQ -> weakBy w e
      GT -> IR.Bound' (pred j) a'
    where
      a' = substWith w i e a
  substWith w i e (IR.Free' x a) =
    IR.Free' x (substWith w i e a)
  substWith w i e (IR.App' f s a) =
    IR.App' (substWith w i e f) (substWith w i e s) (substWith w i e a)
  substWith w i e (IR.Ann' π s t l a) =
    IR.Ann' π (substWith w i e s) (substWith w i e t) l (substWith w i e a)
  substWith w i e (IR.ElimX a) =
    IR.ElimX (substWith w i e a)

class HasWeak a => HasPatSubst extT primTy primVal a where
  patSubst' ::
    TC.HasThrowTC' extV extT primTy primVal m =>
    -- | How many bindings have been traversed so far
    Natural ->
    -- | Mapping of pattern variables to matched subterms
    IR.PatternMap (IR.Elim' extT primTy primVal) ->
    a ->
    m a
  default patSubst' ::
    ( Generic a,
      GHasPatSubst extT primTy primVal (Rep a),
      TC.HasThrowTC' extV extT primTy primVal m
    ) =>
    Natural ->
    IR.PatternMap (IR.Elim' extT primTy primVal) ->
    a ->
    m a
  patSubst' b m = fmap to . gpatSubst' b m . from

patSubst ::
  ( HasPatSubst extT primTy primVal a,
    TC.HasThrowTC' extV extT primTy primVal m
  ) =>
  IR.PatternMap (IR.Elim' extT primTy primVal) ->
  a ->
  m a
patSubst = patSubst' 0

type AllPatSubst ext primTy primVal =
  ( IR.TermAll (HasPatSubst ext primTy primVal) ext primTy primVal,
    IR.ElimAll (HasPatSubst ext primTy primVal) ext primTy primVal
  )

instance
  AllPatSubst ext primTy primVal =>
  HasPatSubst ext primTy primVal (IR.Term' ext primTy primVal)
  where
  patSubst' b m (IR.Star' u a) =
    IR.Star' u <$> patSubst' b m a
  patSubst' b m (IR.PrimTy' t a) =
    IR.PrimTy' t <$> patSubst' b m a
  patSubst' b m (IR.Prim' p a) =
    IR.Prim' p <$> patSubst' b m a
  patSubst' b m (IR.Pi' π s t a) =
    IR.Pi' π <$> patSubst' b m s
      <*> patSubst' (succ b) m t
      <*> patSubst' b m a
  patSubst' b m (IR.Lam' t a) =
    IR.Lam' <$> patSubst' (succ b) m t
      <*> patSubst' b m a
  patSubst' b m (IR.Sig' π s t a) =
    IR.Sig' π <$> patSubst' b m s
      <*> patSubst' (succ b) m t
      <*> patSubst' b m a
  patSubst' b m (IR.Pair' s t a) =
    IR.Pair' <$> patSubst' b m s
      <*> patSubst' b m t
      <*> patSubst' b m a
  patSubst' b m (IR.Let' π l t a) =
    IR.Let' π <$> patSubst' b m l
      <*> patSubst' (succ b) m t
      <*> patSubst' b m a
  patSubst' b m (IR.Elim' e a) =
    IR.Elim' <$> patSubst' b m e
      <*> patSubst' b m a
  patSubst' b m (IR.TermX a) =
    IR.TermX <$> patSubst' b m a

instance
  AllPatSubst ext primTy primVal =>
  HasPatSubst ext primTy primVal (IR.Elim' ext primTy primVal)
  where
  patSubst' b m (IR.Bound' j a) =
    IR.Bound' j <$> patSubst' b m a
  patSubst' b m (IR.Free' (IR.Pattern x) _) =
    case IntMap.lookup x m of
      Nothing -> TC.throwTC $ TC.UnboundPatVar x
      Just e -> pure $ weakBy b e
  patSubst' b m (IR.Free' x a) =
    IR.Free' x <$> patSubst' b m a
  patSubst' b m (IR.App' f e a) =
    IR.App' <$> patSubst' b m f
      <*> patSubst' b m e
      <*> patSubst' b m a
  patSubst' b m (IR.Ann' π s t ℓ a) =
    IR.Ann' π <$> patSubst' b m s
      <*> patSubst' b m t
      <*> pure ℓ
      <*> patSubst' b m a
  patSubst' b m (IR.ElimX a) =
    IR.ElimX <$> patSubst' b m a

type AllWeakV ext primTy primVal =
  ( IR.ValueAll HasWeak ext primTy primVal,
    IR.NeutralAll HasWeak ext primTy primVal
  )

instance
  AllWeakV ext primTy primVal =>
  HasWeak (IR.Value' ext primTy primVal)
  where
  weakBy' b i (IR.VStar' n a) =
    IR.VStar' n (weakBy' b i a)
  weakBy' b i (IR.VPrimTy' p a) =
    IR.VPrimTy' p (weakBy' b i a)
  weakBy' b i (IR.VPi' π s t a) =
    IR.VPi' π (weakBy' b i s) (weakBy' b (succ i) t) (weakBy' b i a)
  weakBy' b i (IR.VLam' t a) =
    IR.VLam' (weakBy' b (succ i) t) (weakBy' b i a)
  weakBy' b i (IR.VSig' π s t a) =
    IR.VSig' π (weakBy' b i s) (weakBy' b (succ i) t) (weakBy' b i a)
  weakBy' b i (IR.VPair' s t a) =
    IR.VPair' (weakBy' b i s) (weakBy' b (succ i) t) (weakBy' b i a)
  weakBy' b i (IR.VNeutral' n a) =
    IR.VNeutral' (weakBy' b i n) (weakBy' b i a)
  weakBy' b i (IR.VPrim' p a) =
    IR.VPrim' p (weakBy' b i a)
  weakBy' b i (IR.ValueX a) =
    IR.ValueX (weakBy' b i a)

instance
  AllWeakV ext primTy primVal =>
  HasWeak (IR.Neutral' ext primTy primVal)
  where
  weakBy' b i (IR.NBound' j a)
    | j >= i = IR.NBound' (j + b) a'
    | otherwise = IR.NBound' j a'
    where
      a' = weakBy' b i a
  weakBy' b i (IR.NFree' x a) =
    IR.NFree' x (weakBy' b i a)
  weakBy' b i (IR.NApp' f s a) =
    IR.NApp' (weakBy' b i f) (weakBy' b i s) (weakBy' b i a)
  weakBy' b i (IR.NeutralX a) =
    IR.NeutralX (weakBy' b i a)

class HasWeak a => HasSubstV extV primTy primVal a where
  substVWith ::
    TC.HasThrowTC' extV extT primTy primVal m =>
    Param.Parameterisation primTy primVal ->
    Natural ->
    IR.BoundVar ->
    IR.Value' extV primTy primVal ->
    a ->
    m a
  default substVWith ::
    ( Generic a,
      GHasSubstV extV primTy primVal (Rep a),
      TC.HasThrowTC' extV extT primTy primVal m
    ) =>
    Param.Parameterisation primTy primVal ->
    Natural ->
    IR.BoundVar ->
    IR.Value' extV primTy primVal ->
    a ->
    m a
  substVWith p b i e = fmap to . gsubstVWith p b i e . from

substV' ::
  ( HasSubstV extV primTy primVal a,
    TC.HasThrowTC' extV extT primTy primVal m
  ) =>
  Param.Parameterisation primTy primVal ->
  IR.BoundVar ->
  IR.Value' extV primTy primVal ->
  a ->
  m a
substV' param = substVWith param 0

substV ::
  ( HasSubstV extV primTy primVal a,
    TC.HasThrowTC' extV extT primTy primVal m
  ) =>
  Param.Parameterisation primTy primVal ->
  IR.Value' extV primTy primVal ->
  a ->
  m a
substV param = substV' param 0

type AllSubstV extV primTy primVal =
  ( IR.ValueAll (HasSubstV extV primTy primVal) extV primTy primVal,
    IR.NeutralAll (HasSubstV extV primTy primVal) extV primTy primVal
  )

instance
  ( AllSubstV extV primTy primVal,
    Monoid (IR.XVNeutral extV primTy primVal),
    Monoid (IR.XVLam extV primTy primVal),
    Monoid (IR.XVPrim extV primTy primVal)
  ) =>
  HasSubstV extV primTy primVal (IR.Value' extV primTy primVal)
  where
  substVWith param w i e (IR.VStar' n a) =
    IR.VStar' n <$> substVWith param w i e a
  substVWith param w i e (IR.VPrimTy' p a) =
    IR.VPrimTy' p <$> substVWith param w i e a
  substVWith param w i e (IR.VPi' π s t a) =
    IR.VPi' π <$> substVWith param w i e s
      <*> substVWith param (succ w) (succ i) e t
      <*> substVWith param w i e a
  substVWith param w i e (IR.VLam' t a) =
    IR.VLam' <$> substVWith param (succ w) (succ i) e t
      <*> substVWith param w i e a
  substVWith param w i e (IR.VSig' π s t a) =
    IR.VSig' π <$> substVWith param w i e s
      <*> substVWith param (succ w) (succ i) e t
      <*> substVWith param w i e a
  substVWith param w i e (IR.VPair' s t a) =
    IR.VPair' <$> substVWith param w i e s
      <*> substVWith param w i e t
      <*> substVWith param w i e a
  substVWith param w i e (IR.VNeutral' n a) =
    substNeutralWith param w i e n a
  substVWith param w i e (IR.VPrim' p a) =
    IR.VPrim' p <$> substVWith param w i e a
  substVWith param w i e (IR.ValueX a) =
    IR.ValueX <$> substVWith param w i e a

substNeutralWith ::
  ( AllSubstV extV primTy primVal,
    TC.HasThrowTC' extV extT primTy primVal m,
    Monoid (IR.XVNeutral extV primTy primVal),
    Monoid (IR.XVLam extV primTy primVal),
    Monoid (IR.XVPrim extV primTy primVal)
  ) =>
  Param.Parameterisation primTy primVal ->
  Natural ->
  IR.BoundVar ->
  IR.Value' extV primTy primVal ->
  IR.Neutral' extV primTy primVal ->
  IR.XVNeutral extV primTy primVal ->
  m (IR.Value' extV primTy primVal) -- not Neutral'!!!
substNeutralWith param w i e (IR.NBound' j a) b = do
  a' <- substVWith param w i e a
  b' <- substVWith param w i e b
  pure $ case compare j i of
    LT -> IR.VNeutral' (IR.NBound' j a') b'
    EQ -> weakBy w e
    GT -> IR.VNeutral' (IR.NBound' (pred j) a') b'
substNeutralWith param w i e (IR.NFree' x a) b =
  IR.VNeutral' <$> (IR.NFree' x <$> substVWith param w i e a)
    <*> substVWith param w i e b
substNeutralWith param w i e (IR.NApp' f s a) _ =
  join $
    vapp param <$> substNeutralWith param w i e f mempty
      <*> substVWith param w i e s
      <*> substVWith param w i e a
substNeutralWith param w i e (IR.NeutralX a) b =
  IR.VNeutral' <$> (IR.NeutralX <$> substVWith param w i e a)
    <*> substVWith param w i e b

vapp ::
  ( AllSubstV extV primTy primVal,
    TC.HasThrowTC' extV extT primTy primVal m,
    Monoid (IR.XVNeutral extV primTy primVal),
    Monoid (IR.XVLam extV primTy primVal),
    Monoid (IR.XVPrim extV primTy primVal)
  ) =>
  Param.Parameterisation primTy primVal ->
  IR.Value' extV primTy primVal ->
  IR.Value' extV primTy primVal ->
  -- | the annotation to use if the result is another application node
  -- (if it isn't, then this annotation is unused)
  IR.XNApp extV primTy primVal ->
  m (IR.Value' extV primTy primVal)
vapp param (IR.VLam' t _) s _ =
  substV param s t
vapp _ (IR.VNeutral' f _) s b =
  pure $ IR.VNeutral' (IR.NApp' f s b) mempty
vapp param (IR.VPrim' p _) (IR.VPrim' q _) _
  | Just v <- Param.apply param p q =
    pure $ IR.VPrim' v mempty
vapp _ f x _ =
  TC.throwTC $ TC.CannotApply f x

type TermExtFun m ext primTy primVal =
  IR.TermX ext primTy primVal -> m (IR.Value primTy primVal)

type ElimExtFun m ext primTy primVal =
  IR.ElimX ext primTy primVal -> m (IR.Value primTy primVal)

type ExtFuns m ext primTy primVal =
  (TermExtFun m ext primTy primVal, ElimExtFun m ext primTy primVal)

rejectExts ::
  TC.HasThrowTC' IR.NoExt ext primTy primVal m =>
  ExtFuns m ext primTy primVal
rejectExts =
  ( TC.throwTC . TC.UnsupportedTermExt,
    TC.throwTC . TC.UnsupportedElimExt
  )

-- annotations are discarded
evalTermWith ::
  TC.HasThrowTC' IR.NoExt extT primTy primVal m =>
  ExtFuns m extT primTy primVal ->
  Param.Parameterisation primTy primVal ->
  IR.Term' extT primTy primVal ->
  m (IR.Value primTy primVal)
evalTermWith _ _ (IR.Star' u _) =
  pure $ IR.VStar u
evalTermWith _ _ (IR.PrimTy' p _) =
  pure $ IR.VPrimTy p
evalTermWith _ _ (IR.Prim' p _) =
  pure $ IR.VPrim p
evalTermWith exts param (IR.Pi' π s t _) =
  IR.VPi π <$> evalTermWith exts param s <*> evalTermWith exts param t
evalTermWith exts param (IR.Lam' t _) =
  IR.VLam <$> evalTermWith exts param t
evalTermWith exts param (IR.Sig' π s t _) =
  IR.VSig π <$> evalTermWith exts param s <*> evalTermWith exts param t
evalTermWith exts param (IR.Pair' s t _) =
  IR.VPair <$> evalTermWith exts param s <*> evalTermWith exts param t
evalTermWith exts param (IR.Let' _ l b _) = do
  l' <- evalElimWith exts param l
  b' <- evalTermWith exts param b
  substV param l' b'
evalTermWith exts param (IR.Elim' e _) =
  evalElimWith exts param e
evalTermWith (tExt, _) _ (IR.TermX a) =
  tExt a

evalElimWith ::
  TC.HasThrowTC' IR.NoExt extT primTy primVal m =>
  ExtFuns m extT primTy primVal ->
  Param.Parameterisation primTy primVal ->
  IR.Elim' extT primTy primVal ->
  m (IR.Value primTy primVal)
evalElimWith _ _ (IR.Bound' i _) =
  pure $ IR.VBound i
evalElimWith _ _ (IR.Free' x _) =
  pure $ IR.VFree x
evalElimWith exts param (IR.App' s t _) =
  join $
    vapp param <$> evalElimWith exts param s
      <*> evalTermWith exts param t
      <*> pure ()
evalElimWith exts param (IR.Ann' _ s _ _ _) =
  evalTermWith exts param s
evalElimWith (_, eExt) _ (IR.ElimX a) =
  eExt a

evalTerm ::
  TC.HasThrowTC' IR.NoExt extT primTy primVal m =>
  Param.Parameterisation primTy primVal ->
  IR.Term' extT primTy primVal ->
  m (IR.Value primTy primVal)
evalTerm = evalTermWith rejectExts

evalElim ::
  TC.HasThrowTC' IR.NoExt extT primTy primVal m =>
  Param.Parameterisation primTy primVal ->
  IR.Elim' extT primTy primVal ->
  m (IR.Value primTy primVal)
evalElim = evalElimWith rejectExts

class GHasWeak f where
  gweakBy' :: Natural -> IR.BoundVar -> f t -> f t

instance GHasWeak U1 where gweakBy' _ _ U1 = U1

instance GHasWeak V1 where gweakBy' _ _ v = case v of

instance (GHasWeak f, GHasWeak g) => GHasWeak (f :*: g) where
  gweakBy' b i (x :*: y) = gweakBy' b i x :*: gweakBy' b i y

instance (GHasWeak f, GHasWeak g) => GHasWeak (f :+: g) where
  gweakBy' b i (L1 x) = L1 (gweakBy' b i x)
  gweakBy' b i (R1 x) = R1 (gweakBy' b i x)

instance GHasWeak f => GHasWeak (M1 i t f) where
  gweakBy' b i (M1 x) = M1 (gweakBy' b i x)

instance HasWeak f => GHasWeak (K1 k f) where
  gweakBy' b i (K1 x) = K1 (weakBy' b i x)

instance HasWeak ()

instance HasWeak Void

instance (HasWeak a, HasWeak b) => HasWeak (a, b)

instance (HasWeak a, HasWeak b, HasWeak c) => HasWeak (a, b, c)

instance (HasWeak a, HasWeak b) => HasWeak (Either a b)

instance HasWeak a => HasWeak (Maybe a)

instance HasWeak a => HasWeak [a]

instance HasWeak Symbol where
  weakBy' _ _ x = x

class GHasWeak f => GHasSubst ext primTy primVal f where
  gsubstWith ::
    -- | How many bindings have been traversed so far
    Natural ->
    -- | Variable to substitute
    IR.BoundVar ->
    -- | Expression to substitute with
    IR.Elim' ext primTy primVal ->
    f t ->
    f t

instance GHasSubst ext primTy primVal U1 where gsubstWith _ _ _ U1 = U1

instance GHasSubst ext primTy primVal V1 where
  gsubstWith _ _ _ v = case v of

instance
  ( GHasSubst ext primTy primVal f,
    GHasSubst ext primTy primVal g
  ) =>
  GHasSubst ext primTy primVal (f :*: g)
  where
  gsubstWith b i e (x :*: y) = gsubstWith b i e x :*: gsubstWith b i e y

instance
  ( GHasSubst ext primTy primVal f,
    GHasSubst ext primTy primVal g
  ) =>
  GHasSubst ext primTy primVal (f :+: g)
  where
  gsubstWith b i e (L1 x) = L1 (gsubstWith b i e x)
  gsubstWith b i e (R1 x) = R1 (gsubstWith b i e x)

instance
  GHasSubst ext primTy primVal f =>
  GHasSubst ext primTy primVal (M1 i t f)
  where
  gsubstWith b i e (M1 x) = M1 (gsubstWith b i e x)

instance
  HasSubst ext primTy primVal f =>
  GHasSubst ext primTy primVal (K1 k f)
  where
  gsubstWith b i e (K1 x) = K1 (substWith b i e x)

instance HasSubst ext primTy primVal ()

instance HasSubst ext primTy primVal Void

instance
  ( HasSubst ext primTy primVal a,
    HasSubst ext primTy primVal b
  ) =>
  HasSubst ext primTy primVal (a, b)

instance
  ( HasSubst ext primTy primVal a,
    HasSubst ext primTy primVal b,
    HasSubst ext primTy primVal c
  ) =>
  HasSubst ext primTy primVal (a, b, c)

instance
  ( HasSubst ext primTy primVal a,
    HasSubst ext primTy primVal b
  ) =>
  HasSubst ext primTy primVal (Either a b)

instance
  HasSubst ext primTy primVal a =>
  HasSubst ext primTy primVal (Maybe a)

instance
  HasSubst ext primTy primVal a =>
  HasSubst ext primTy primVal [a]

instance HasSubst ext primTy primVal Symbol where
  substWith _ _ _ x = x

class GHasWeak f => GHasSubstV extV primTy primVal f where
  gsubstVWith ::
    TC.HasThrowTC' extV extT primTy primVal m =>
    Param.Parameterisation primTy primVal ->
    Natural ->
    IR.BoundVar ->
    IR.Value' extV primTy primVal ->
    f t ->
    m (f t)

instance GHasSubstV ext primTy primVal U1 where gsubstVWith _ _ _ _ U1 = pure U1

instance GHasSubstV ext primTy primVal V1 where
  gsubstVWith _ _ _ _ v = case v of

instance
  ( GHasSubstV ext primTy primVal f,
    GHasSubstV ext primTy primVal g
  ) =>
  GHasSubstV ext primTy primVal (f :*: g)
  where
  gsubstVWith p b i e (x :*: y) =
    (:*:) <$> gsubstVWith p b i e x
      <*> gsubstVWith p b i e y

instance
  ( GHasSubstV ext primTy primVal f,
    GHasSubstV ext primTy primVal g
  ) =>
  GHasSubstV ext primTy primVal (f :+: g)
  where
  gsubstVWith p b i e (L1 x) = L1 <$> gsubstVWith p b i e x
  gsubstVWith p b i e (R1 x) = R1 <$> gsubstVWith p b i e x

instance
  GHasSubstV ext primTy primVal f =>
  GHasSubstV ext primTy primVal (M1 i t f)
  where
  gsubstVWith p b i e (M1 x) = M1 <$> gsubstVWith p b i e x

instance
  HasSubstV ext primTy primVal f =>
  GHasSubstV ext primTy primVal (K1 k f)
  where
  gsubstVWith p b i e (K1 x) = K1 <$> substVWith p b i e x

instance HasSubstV ext primTy primVal ()

instance HasSubstV ext primTy primVal Void

instance
  ( HasSubstV ext primTy primVal a,
    HasSubstV ext primTy primVal b
  ) =>
  HasSubstV ext primTy primVal (a, b)

instance
  ( HasSubstV ext primTy primVal a,
    HasSubstV ext primTy primVal b,
    HasSubstV ext primTy primVal c
  ) =>
  HasSubstV ext primTy primVal (a, b, c)

instance
  ( HasSubstV ext primTy primVal a,
    HasSubstV ext primTy primVal b
  ) =>
  HasSubstV ext primTy primVal (Either a b)

instance
  HasSubstV ext primTy primVal a =>
  HasSubstV ext primTy primVal (Maybe a)

instance
  HasSubstV ext primTy primVal a =>
  HasSubstV ext primTy primVal [a]

instance HasSubstV ext primTy primVal Symbol where
  substVWith _ _ _ _ x = pure x

class GHasWeak f => GHasPatSubst extT primTy primVal f where
  gpatSubst' ::
    TC.HasThrowTC' extV extT primTy primVal m =>
    -- | How many bindings have been traversed so far
    Natural ->
    -- | Mapping of pattern variables to matched subterms
    IR.PatternMap (IR.Elim' extT primTy primVal) ->
    f t ->
    m (f t)

instance GHasPatSubst ext primTy primVal U1 where gpatSubst' _ _ U1 = pure U1

instance GHasPatSubst ext primTy primVal V1 where
  gpatSubst' _ _ v = case v of

instance
  ( GHasPatSubst ext primTy primVal f,
    GHasPatSubst ext primTy primVal g
  ) =>
  GHasPatSubst ext primTy primVal (f :*: g)
  where
  gpatSubst' b m (x :*: y) =
    (:*:) <$> gpatSubst' b m x
      <*> gpatSubst' b m y

instance
  ( GHasPatSubst ext primTy primVal f,
    GHasPatSubst ext primTy primVal g
  ) =>
  GHasPatSubst ext primTy primVal (f :+: g)
  where
  gpatSubst' b m (L1 x) = L1 <$> gpatSubst' b m x
  gpatSubst' b m (R1 x) = R1 <$> gpatSubst' b m x

instance
  GHasPatSubst ext primTy primVal f =>
  GHasPatSubst ext primTy primVal (M1 i t f)
  where
  gpatSubst' b m (M1 x) = M1 <$> gpatSubst' b m x

instance
  HasPatSubst ext primTy primVal f =>
  GHasPatSubst ext primTy primVal (K1 k f)
  where
  gpatSubst' b m (K1 x) = K1 <$> patSubst' b m x

instance HasPatSubst ext primTy primVal ()

instance HasPatSubst ext primTy primVal Void

instance
  ( HasPatSubst ext primTy primVal a,
    HasPatSubst ext primTy primVal b
  ) =>
  HasPatSubst ext primTy primVal (a, b)

instance
  ( HasPatSubst ext primTy primVal a,
    HasPatSubst ext primTy primVal b,
    HasPatSubst ext primTy primVal c
  ) =>
  HasPatSubst ext primTy primVal (a, b, c)

instance
  ( HasPatSubst ext primTy primVal a,
    HasPatSubst ext primTy primVal b
  ) =>
  HasPatSubst ext primTy primVal (Either a b)

instance
  HasPatSubst ext primTy primVal a =>
  HasPatSubst ext primTy primVal (Maybe a)

instance
  HasPatSubst ext primTy primVal a =>
  HasPatSubst ext primTy primVal [a]