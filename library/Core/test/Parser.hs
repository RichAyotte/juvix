module Parser where

import Juvix.Core.HR
import qualified Juvix.Core.Parameterisations.Naturals as Nat
import qualified Juvix.Core.Parameterisations.Unit as Unit
import Juvix.Core.Types
import Juvix.Library
import qualified Juvix.Library.Usage as Usage
import qualified Test.Tasty as T
import qualified Test.Tasty.HUnit as T
import Prelude (String)

-- | Term parser unit test generator. TODO: does it make sense for it to be Nat.Ty?
shouldParse :: String -> Term Nat.Ty Nat.Val -> T.TestTree
shouldParse str parsed =
  T.testCase (show str <> " should parse as " <> show parsed) $
    Just parsed T.@=? parseString str

parseString :: String -> Maybe (Term Nat.Ty Nat.Val)
parseString = generateParser Nat.t

-- | Primitive parser unit test generator.
shouldParsePrim ::
  forall primTy primVal.
  (Show primTy, Eq primTy, Show primVal, Eq primVal) =>
  Parameterisation primTy primVal ->
  String ->
  Term primTy primVal ->
  T.TestTree
shouldParsePrim param str parsed =
  T.testCase (show str <> " should parse as " <> show parsed) $
    Just parsed T.@=? parseStringPrim param str

parseStringPrim ::
  forall primTy primVal.
  Parameterisation primTy primVal ->
  String ->
  Maybe (Term primTy primVal)
parseStringPrim = generateParser

coreParser :: T.TestTree
coreParser =
  T.testGroup
    "Core parser"
    [ shouldParse "* 0" (Star 0),
      shouldParse "(* 1)" (Star 1),
      shouldParsePrim Nat.t "Nat" (PrimTy Nat.Ty),
      shouldParsePrim Unit.t "Unit" (PrimTy Unit.Ty),
      shouldParsePrim Unit.t "tt" (Prim Unit.Val),
      shouldParse "[Π] 1 A * 0 * 0" (Pi one "A" (Star 0) (Star 0)),
      shouldParse "\\x -> x" (Lam "x" (Elim (Var "x"))),
      shouldParse "\\x -> y" (Lam "x" (Elim (Var "y"))),
      shouldParse "\\x -> \\y -> x" (Lam "x" (Lam "y" (Elim (Var "x")))),
      shouldParse
        "\\x -> \\y -> x y"
        (Lam "x" (Lam "y" (Elim (App (Var "x") (Elim (Var "y")))))),
      shouldParse "3" (Prim (Nat.Val 3)),
      shouldParse "xyz" (Elim (Var "xyz")),
      shouldParse "fun var" (Elim (App (Var "fun") (Elim (Var "var")))),
      shouldParse "(fun var)" (Elim (App (Var "fun") (Elim (Var "var")))),
      shouldParse "@ (* 0) : w (* 0) | 0" (Elim (Ann Usage.Omega (Star 0) (Star 0) 0)),
      shouldParse
        "@ (\\x -> x) : w (* 0) | 0"
        (Elim (Ann Usage.Omega (Lam "x" (Elim (Var "x"))) (Star 0) 0)),
      shouldParse
        "(@ (\\x -> x) : w (* 0) | 0)"
        (Elim (Ann Usage.Omega (Lam "x" (Elim (Var "x"))) (Star 0) 0)),
      shouldParse
        "(@ (\\x -> x) : w (* 0) | 0) y"
        (Elim (App (Ann Usage.Omega (Lam "x" (Elim (Var "x"))) (Star 0) 0) (Elim (Var "y")))),
      shouldParse "[Σ] 1 A * 0 A" (Sig one "A" (Star 0) (Elim (Var "A"))),
      shouldParse "[add, add]" (Pair (Prim Nat.Add) (Prim Nat.Add)),
      shouldParse
        "[add, [add, add]]"
        (Pair (Prim Nat.Add) (Pair (Prim Nat.Add) (Prim Nat.Add))),
      shouldParse "(2)" (Prim (Nat.Val 2)),
      shouldParse "add" (Prim Nat.Add)
    ]
