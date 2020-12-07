{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE UndecidableInstances #-}

module Juvix.Core.IR.Types.Base where

import Data.Kind (Constraint)
import qualified Data.Map as Map
import Extensible
import Juvix.Library hiding (Pos)
import Juvix.Library.HashMap
import qualified Juvix.Library.NameSymbol as NameSymbol
import Juvix.Library.Usage

type Universe = Natural

type GlobalName = NameSymbol.T

type PatternVar = Int

-- | map from pattern variables to e.g. their types
type PatternMap = IntMap

type BoundVar = Natural

data Name
  = -- | Global variables are represented by name thus type string
    Global GlobalName
  | -- | Pattern variable, unique within a scope
    Pattern PatternVar
  deriving (Show, Eq, Generic, Data, NFData)

-- TODO: maybe global functions can have any usage? (for private defs)
data GlobalUsage = GZero | GOmega
  deriving (Show, Eq, Generic, Data, Bounded, Enum, NFData)

extensible
  [d|
    data Term primTy primVal
      = -- | (sort i) i th ordering of (closed) universe.
        Star Universe
      | -- | PrimTy primitive type
        PrimTy primTy
      | -- | primitive constant
        Prim primVal
      | -- | formation rule of the dependent function type PI.
        -- the Usage(π) tracks how many times x is used.
        Pi Usage (Term primTy primVal) (Term primTy primVal)
      | -- | LAM Introduction rule of PI.
        -- The abstracted variables usage is tracked with the Usage(π).
        Lam (Term primTy primVal)
      | -- | Dependent pair (Σ) type, with each half having its own usage
        Sig Usage (Term primTy primVal) (Term primTy primVal)
      | -- | Pair value
        Pair (Term primTy primVal) (Term primTy primVal)
      | -- | Let binder.
        -- the local definition is bound to de Bruijn index 0.
        Let Usage (Elim primTy primVal) (Term primTy primVal)
      | -- | Unit type.
        UnitTy
      | -- | Unit Value
        Unit
      | -- | CONV conversion rule. TODO make sure 0Γ ⊢ S≡T
        -- Elim is the constructor that embeds Elim to Term
        Elim (Elim primTy primVal)
      deriving (Eq, Show, Generic, Data, NFData)

    -- inferable terms
    data Elim primTy primVal
      = -- | Bound variables, in de Bruijn indices
        Bound BoundVar
      | -- | Free variables of type name (see above)
        Free Name
      | -- | elimination rule of PI (APP).
        App (Elim primTy primVal) (Term primTy primVal)
      | -- | Annotation with usage.
        Ann Usage (Term primTy primVal) (Term primTy primVal) Universe
      deriving (Eq, Show, Generic, Data, NFData)

    -- Values/types
    data Value primTy primVal
      = VStar Universe
      | VPrimTy primTy
      | VPi Usage (Value primTy primVal) (Value primTy primVal)
      | VLam (Value primTy primVal)
      | VSig Usage (Value primTy primVal) (Value primTy primVal)
      | VPair (Value primTy primVal) (Value primTy primVal)
      | VUnitTy
      | VUnit
      | VNeutral (Neutral primTy primVal)
      | VPrim primVal
      deriving (Eq, Show, Generic, Data, NFData)

    -- A neutral term is either a variable or an application of a neutral term
    -- to a value
    data Neutral primTy primVal
      = NBound BoundVar
      | NFree Name
      | NApp (Neutral primTy primVal) (Value primTy primVal)
      deriving (Eq, Show, Generic, Data, NFData)

    -- TODO absurd pattern
    data Pattern primTy primVal
      = PCon GlobalName [Pattern primTy primVal]
      | PPair (Pattern primTy primVal) (Pattern primTy primVal)
      | PUnit
      | PVar PatternVar
      | PDot (Term primTy primVal)
      | PPrim primVal
      deriving (Show, Eq, Generic, Data, NFData)
    |]

type GlobalAll (c :: * -> Constraint) ext primTy primVal =
  ( c primTy,
    c primVal,
    TermAll c ext primTy primVal,
    ElimAll c ext primTy primVal,
    ValueAll c ext primTy primVal,
    NeutralAll c ext primTy primVal,
    PatternAll c ext primTy primVal
  )

type GlobalAllWith (c :: * -> Constraint) ty ext primTy primVal =
  ( c (ty ext primTy primVal),
    c primTy,
    c primVal,
    TermAll c ext primTy primVal,
    ElimAll c ext primTy primVal,
    ValueAll c ext primTy primVal,
    NeutralAll c ext primTy primVal,
    PatternAll c ext primTy primVal
  )

data DatatypeWith ty ext primTy primVal
  = Datatype
      { dataName :: GlobalName,
        -- | the positivity of its parameters
        dataPos :: [Pos],
        -- | the type constructor's arguments/telescope
        dataArgs :: [DataArgWith ty ext primTy primVal],
        -- | the type constructor's target universe level
        dataLevel :: Natural,
        -- | the expression
        dataTy :: (Term' ext primTy primVal),
        -- the list of constructors.
        dataCons :: [DataConWith ty ext primTy primVal]
      }
  deriving (Generic)

type RawDatatype' = DatatypeWith Term'

type Datatype' = DatatypeWith Value'

deriving instance
  GlobalAllWith Show ty ext primTy primVal =>
  Show (DatatypeWith ty ext primTy primVal)

deriving instance
  GlobalAllWith Eq ty ext primTy primVal =>
  Eq (DatatypeWith ty ext primTy primVal)

deriving instance
  GlobalAllWith Show ty ext primTy primVal =>
  Show (SigDef ty ext primTy primVal)

deriving instance
  (Typeable ty, Data Pos, Data ext, GlobalAllWith Data ty ext primTy primVal) =>
  Data (DatatypeWith ty ext primTy primVal)

deriving instance
  (NFData Pos, GlobalAllWith NFData ty ext primTy primVal) =>
  NFData (DatatypeWith ty ext primTy primVal)

data DataArgWith ty ext primTy primVal
  = DataArg
      { argName :: GlobalName,
        argUsage :: Usage,
        argType :: ty ext primTy primVal,
        argIsParam :: Bool
      }
  deriving (Generic)

type RawDataArg' = DataArgWith Term'

type DataArg' = DataArgWith Value'

deriving instance
  GlobalAllWith Show ty ext primTy primVal =>
  Show (DataArgWith ty ext primTy primVal)

deriving instance
  GlobalAllWith Eq ty ext primTy primVal =>
  Eq (DataArgWith ty ext primTy primVal)

deriving instance
  (Typeable ty, Data ext, GlobalAllWith Data ty ext primTy primVal) =>
  Data (DataArgWith ty ext primTy primVal)

deriving instance
  GlobalAllWith NFData ty ext primTy primVal =>
  NFData (DataArgWith ty ext primTy primVal)

data DataConWith ty ext primTy primVal
  = DataCon
      { conName :: GlobalName,
        conType :: ty ext primTy primVal
      }
  deriving (Generic)

type RawDataCon' = DataConWith Term'

type DataCon' = DataConWith Value'

deriving instance
  GlobalAllWith Show ty ext primTy primVal =>
  Show (DataConWith ty ext primTy primVal)

deriving instance
  GlobalAllWith Eq ty ext primTy primVal =>
  Eq (DataConWith ty ext primTy primVal)

deriving instance
  (Typeable ty, Data ext, GlobalAllWith Data ty ext primTy primVal) =>
  Data (DataConWith ty ext primTy primVal)

deriving instance
  GlobalAllWith NFData ty ext primTy primVal =>
  NFData (DataConWith ty ext primTy primVal)

data FunctionWith ty ext primTy primVal
  = Function
      { funName :: GlobalName,
        funUsage :: GlobalUsage,
        funType :: ty ext primTy primVal,
        funClauses :: NonEmpty (FunClause' ty ext primTy primVal)
      }
  deriving (Generic)

type RawFunction' = FunctionWith Term'

type Function' = FunctionWith Value'

deriving instance
  GlobalAllWith Show ty ext primTy primVal =>
  Show (FunctionWith ty ext primTy primVal)

deriving instance
  GlobalAllWith Eq ty ext primTy primVal =>
  Eq (FunctionWith ty ext primTy primVal)

deriving instance
  (Typeable ty, Data ext, GlobalAllWith Data ty ext primTy primVal) =>
  Data (FunctionWith ty ext primTy primVal)

deriving instance
  GlobalAllWith NFData ty ext primTy primVal =>
  NFData (FunctionWith ty ext primTy primVal)

data FunClause' ty ext primTy primVal
  = -- | Clause has been labelled as unreachable by the coverage checker.
    --   @Nothing@ means coverage checker has not run yet (clause may be unreachable).
    --   @Just False@ means clause is not unreachable.
    --   @Just True@ means clause is unreachable.
    FunClause
      { -- | @Δ@: The types of the pattern variables in dependency order.
        -- , namedClausePats :: NAPs (Using Name instead atm)
        -- ^ @Δ ⊢ ps@.  The de Bruijn indices refer to @Δ@.
        clauseTel :: [DataArgWith ty ext primTy primVal],
        namedClausePats :: [Pattern' ext primTy primVal], --TODO [SplitPattern]

        -- | @Just v@ with @Δ ⊢ v@ for a regular clause, or @Nothing@ for an
        --   absurd one.
        clauseBody :: Maybe (Term' ext primTy primVal),
        -- | @Δ ⊢ t@.  The type of the rhs under @clauseTel@.
        clauseType :: Maybe (Value' ext primTy primVal),
        -- | Clause has been labelled as CATCHALL.
        -- , clauseRecursive   :: Maybe Bool TODO add this when termination checking
        -- ^ @clauseBody@ contains recursive calls; computed by termination checker.
        --   @Nothing@ means that termination checker has not run yet,
        --   or that @clauseBody@ contains meta-variables;
        --   these could be filled with recursive calls later!
        --   @Just False@ means definitely no recursive call.
        --   @Just True@ means definitely a recursive call.
        clauseCatchall :: Bool,
        clauseUnreachable :: Maybe Bool
      }
  deriving (Generic)

data AbstractWith ty ext primTy primVal
  = Abstract
      { absName :: GlobalName,
        absUsage :: GlobalUsage,
        absType :: ty ext primTy primVal
      }
  deriving (Generic)

type RawAbstract' = AbstractWith Term'

type Abstract' = AbstractWith Value'

deriving instance
  GlobalAllWith Show ty ext primTy primVal =>
  Show (AbstractWith ty ext primTy primVal)

deriving instance
  GlobalAllWith Eq ty ext primTy primVal =>
  Eq (AbstractWith ty ext primTy primVal)

deriving instance
  (Typeable ty, Data ext, GlobalAllWith Data ty ext primTy primVal) =>
  Data (AbstractWith ty ext primTy primVal)

deriving instance
  GlobalAllWith NFData ty ext primTy primVal =>
  NFData (AbstractWith ty ext primTy primVal)

data GlobalWith ty ext primTy primVal
  = GDatatype (DatatypeWith ty ext primTy primVal)
  | GDataCon (DataConWith ty ext primTy primVal)
  | GFunction (FunctionWith ty ext primTy primVal)
  | GAbstract (AbstractWith ty ext primTy primVal)
  deriving (Generic)

type RawGlobal' = GlobalWith Term'

type Global' = GlobalWith Value'

deriving instance
  GlobalAllWith Show ty ext primTy primVal =>
  Show (GlobalWith ty ext primTy primVal)

deriving instance
  GlobalAllWith Eq ty ext primTy primVal =>
  Eq (GlobalWith ty ext primTy primVal)

deriving instance
  GlobalAllWith Show ty ext primTy primVal =>
  Show (FunClause' ty ext primTy primVal)

deriving instance
  GlobalAllWith Eq ty ext primTy primVal =>
  Eq (FunClause' ty ext primTy primVal)

deriving instance
  ( Typeable ty,
    Data ext,
    GlobalAllWith Data ty ext primTy primVal
  ) =>
  Data (FunClause' ty ext primTy primVal)

deriving instance
  GlobalAllWith NFData ty ext primTy primVal =>
  NFData (FunClause' ty ext primTy primVal)

deriving instance
  (Typeable ty, Data ext, Data Pos, GlobalAllWith Data ty ext primTy primVal) =>
  Data (GlobalWith ty ext primTy primVal)

deriving instance
  (NFData Pos, GlobalAllWith NFData ty ext primTy primVal) =>
  NFData (GlobalWith ty ext primTy primVal)

type GlobalsWith ty ext primTy primVal =
  HashMap GlobalName (GlobalWith ty ext primTy primVal)

type RawGlobals' ext primTy primVal =
  GlobalsWith Term' ext primTy primVal

type Globals' ext primTy primVal =
  GlobalsWith Value' ext primTy primVal

type Signature ty ext primTy primVal = Map.Map Name (SigDef ty ext primTy primVal)

-- Return type of all type-checking functions.
-- state monad for global signature
type TypeCheck ty ext primTy primVal a = StateT (Signature ty ext primTy primVal) IO a

-- A signature is a mapping of constants to its info
data SigDef ty ext primTy primVal
  = -- function constant to its type, clauses, whether it's type checked
    FunSig (Value' ext primTy primVal) [NonEmpty (FunClause' ty ext primTy primVal)] Bool
  | ConSig (Value' ext primTy primVal) -- constructor constant to its type
        -- data type constant to # parameters, positivity of parameters, type
  | DataSig Int [Pos] (Value' ext primTy primVal)

data Pos -- positivity
  = SPos
  | NSPos
  deriving (Eq, Show)
