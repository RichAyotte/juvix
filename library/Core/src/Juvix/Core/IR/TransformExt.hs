{-# LANGUAGE ViewPatterns #-}

-- | Transformations between different extensions.
module Juvix.Core.IR.TransformExt where

import Data.Coerce
import Juvix.Core.IR.Types (Elim, NoExt, Term)
import Juvix.Core.IR.Types.Base
import Juvix.Library hiding (Coerce)

data ExtTransformTEF f ext1 ext2 primTy primVal
  = ExtTransformTEF
      { etfStar :: XStar ext1 primTy primVal -> f (XStar ext2 primTy primVal),
        etfPrimTy :: XPrimTy ext1 primTy primVal -> f (XPrimTy ext2 primTy primVal),
        etfPrim :: XPrim ext1 primTy primVal -> f (XPrim ext2 primTy primVal),
        etfPi :: XPi ext1 primTy primVal -> f (XPi ext2 primTy primVal),
        etfLam :: XLam ext1 primTy primVal -> f (XLam ext2 primTy primVal),
        etfSig :: XSig ext1 primTy primVal -> f (XSig ext2 primTy primVal),
        etfPair :: XPair ext1 primTy primVal -> f (XPair ext2 primTy primVal),
        etfUnitTy :: XUnitTy ext1 primTy primVal -> f (XUnitTy ext2 primTy primVal),
        etfUnit :: XUnit ext1 primTy primVal -> f (XUnit ext2 primTy primVal),
        etfLet :: XLet ext1 primTy primVal -> f (XLet ext2 primTy primVal),
        etfElim :: XElim ext1 primTy primVal -> f (XElim ext2 primTy primVal),
        etfBound :: XBound ext1 primTy primVal -> f (XBound ext2 primTy primVal),
        etfFree :: XFree ext1 primTy primVal -> f (XFree ext2 primTy primVal),
        etfApp :: XApp ext1 primTy primVal -> f (XApp ext2 primTy primVal),
        etfAnn :: XAnn ext1 primTy primVal -> f (XAnn ext2 primTy primVal),
        etfTermX :: TermX ext1 primTy primVal -> f (TermX ext2 primTy primVal),
        etfElimX :: ElimX ext1 primTy primVal -> f (ElimX ext2 primTy primVal)
      }

type ExtTransformTE = ExtTransformTEF Identity

pattern Coerce :: Coercible a b => a -> b
pattern Coerce f <-
  (coerce -> f)
  where
    Coerce f = coerce f

pattern ExtTransformTE ::
  (XStar ext1 primTy primVal -> XStar ext2 primTy primVal) ->
  (XPrimTy ext1 primTy primVal -> XPrimTy ext2 primTy primVal) ->
  (XPrim ext1 primTy primVal -> XPrim ext2 primTy primVal) ->
  (XPi ext1 primTy primVal -> XPi ext2 primTy primVal) ->
  (XLam ext1 primTy primVal -> XLam ext2 primTy primVal) ->
  (XSig ext1 primTy primVal -> XSig ext2 primTy primVal) ->
  (XPair ext1 primTy primVal -> XPair ext2 primTy primVal) ->
  (XUnitTy ext1 primTy primVal -> XUnitTy ext2 primTy primVal) ->
  (XUnit ext1 primTy primVal -> XUnit ext2 primTy primVal) ->
  (XLet ext1 primTy primVal -> XLet ext2 primTy primVal) ->
  (XElim ext1 primTy primVal -> XElim ext2 primTy primVal) ->
  (XBound ext1 primTy primVal -> XBound ext2 primTy primVal) ->
  (XFree ext1 primTy primVal -> XFree ext2 primTy primVal) ->
  (XApp ext1 primTy primVal -> XApp ext2 primTy primVal) ->
  (XAnn ext1 primTy primVal -> XAnn ext2 primTy primVal) ->
  (TermX ext1 primTy primVal -> TermX ext2 primTy primVal) ->
  (ElimX ext1 primTy primVal -> ElimX ext2 primTy primVal) ->
  ExtTransformTE ext1 ext2 primTy primVal
pattern ExtTransformTE
  { etStar,
    etPrimTy,
    etPrim,
    etPi,
    etLam,
    etSig,
    etPair,
    etUnitTy,
    etUnit,
    etLet,
    etElim,
    etBound,
    etFree,
    etApp,
    etAnn,
    etTermX,
    etElimX
  } =
  ExtTransformTEF
    { etfStar = Coerce etStar,
      etfPrimTy = Coerce etPrimTy,
      etfPrim = Coerce etPrim,
      etfPi = Coerce etPi,
      etfLam = Coerce etLam,
      etfSig = Coerce etSig,
      etfUnitTy = Coerce etUnitTy,
      etfUnit = Coerce etUnit,
      etfPair = Coerce etPair,
      etfLet = Coerce etLet,
      etfElim = Coerce etElim,
      etfBound = Coerce etBound,
      etfFree = Coerce etFree,
      etfApp = Coerce etApp,
      etfAnn = Coerce etAnn,
      etfTermX = Coerce etTermX,
      etfElimX = Coerce etElimX
    }

extTransformTF ::
  Applicative f =>
  ExtTransformTEF f ext1 ext2 primTy primVal ->
  Term' ext1 primTy primVal ->
  f (Term' ext2 primTy primVal)
extTransformTF fs (Star' i e) = Star' i <$> etfStar fs e
extTransformTF fs (PrimTy' k e) = PrimTy' k <$> etfPrimTy fs e
extTransformTF fs (Prim' k e) = Prim' k <$> etfPrim fs e
extTransformTF fs (Pi' π s t e) =
  Pi' π <$> extTransformTF fs s <*> extTransformTF fs t <*> etfPi fs e
extTransformTF fs (Lam' t e) = Lam' <$> extTransformTF fs t <*> etfLam fs e
extTransformTF fs (Sig' π s t e) =
  Sig' π <$> extTransformTF fs s <*> extTransformTF fs t <*> etfSig fs e
extTransformTF fs (Pair' s t e) =
  Pair' <$> extTransformTF fs s <*> extTransformTF fs t <*> etfPair fs e
extTransformTF fs (UnitTy' e) =
  UnitTy' <$> etfUnitTy fs e
extTransformTF fs (Unit' e) =
  Unit' <$> etfUnit fs e
extTransformTF fs (Let' π l b e) =
  Let' π <$> extTransformEF fs l <*> extTransformTF fs b <*> etfLet fs e
extTransformTF fs (Elim' f e) = Elim' <$> extTransformEF fs f <*> etfElim fs e
extTransformTF fs (TermX e) = TermX <$> etfTermX fs e

extTransformT ::
  ExtTransformTE ext1 ext2 primTy primVal ->
  Term' ext1 primTy primVal ->
  Term' ext2 primTy primVal
extTransformT fs t = runIdentity $ extTransformTF fs t

extTransformEF ::
  Applicative f =>
  ExtTransformTEF f ext1 ext2 primTy primVal ->
  Elim' ext1 primTy primVal ->
  f (Elim' ext2 primTy primVal)
extTransformEF fs (Bound' x e) = Bound' x <$> etfBound fs e
extTransformEF fs (Free' x e) = Free' x <$> etfFree fs e
extTransformEF fs (App' f s e) =
  App' <$> extTransformEF fs f
    <*> extTransformTF fs s
    <*> etfApp fs e
extTransformEF fs (Ann' π s t ℓ e) =
  Ann' π <$> extTransformTF fs s
    <*> extTransformTF fs t
    <*> pure ℓ
    <*> etfAnn fs e
extTransformEF fs (ElimX e) = ElimX <$> etfElimX fs e

extTransformE ::
  ExtTransformTE ext1 ext2 primTy primVal ->
  Elim' ext1 primTy primVal ->
  Elim' ext2 primTy primVal
extTransformE fs t = runIdentity $ extTransformEF fs t

forgetter ::
  ( TermX ext primTy primVal ~ Void,
    ElimX ext primTy primVal ~ Void
  ) =>
  ExtTransformTE ext NoExt primTy primVal
forgetter =
  ExtTransformTE
    { etStar = const (),
      etPrimTy = const (),
      etPrim = const (),
      etPi = const (),
      etSig = const (),
      etPair = const (),
      etUnitTy = const (),
      etUnit = const (),
      etLam = const (),
      etLet = const (),
      etElim = const (),
      etBound = const (),
      etFree = const (),
      etApp = const (),
      etAnn = const (),
      etTermX = absurd,
      etElimX = absurd
    }

extForgetT ::
  ( TermX ext primTy primVal ~ Void,
    ElimX ext primTy primVal ~ Void
  ) =>
  Term' ext primTy primVal ->
  Term primTy primVal
extForgetT = extTransformT forgetter

extForgetE ::
  ( TermX ext primTy primVal ~ Void,
    ElimX ext primTy primVal ~ Void
  ) =>
  Elim' ext primTy primVal ->
  Elim primTy primVal
extForgetE = extTransformE forgetter

compose ::
  Monad f =>
  ExtTransformTEF f ext2 ext3 primTy primVal ->
  ExtTransformTEF f ext1 ext2 primTy primVal ->
  ExtTransformTEF f ext1 ext3 primTy primVal
compose fs gs =
  ExtTransformTEF
    { etfStar = etfStar fs <=< etfStar gs,
      etfPrimTy = etfPrimTy fs <=< etfPrimTy gs,
      etfPrim = etfPrim fs <=< etfPrim gs,
      etfPi = etfPi fs <=< etfPi gs,
      etfSig = etfSig fs <=< etfSig gs,
      etfPair = etfPair fs <=< etfPair gs,
      etfUnitTy = etfUnitTy fs <=< etfUnitTy gs,
      etfUnit = etfUnit fs <=< etfUnit gs,
      etfLam = etfLam fs <=< etfLam gs,
      etfLet = etfLet fs <=< etfLet gs,
      etfElim = etfElim fs <=< etfElim gs,
      etfBound = etfBound fs <=< etfBound gs,
      etfFree = etfFree fs <=< etfFree gs,
      etfApp = etfApp fs <=< etfApp gs,
      etfAnn = etfAnn fs <=< etfAnn gs,
      etfTermX = etfTermX fs <=< etfTermX gs,
      etfElimX = etfElimX fs <=< etfElimX gs
    }
