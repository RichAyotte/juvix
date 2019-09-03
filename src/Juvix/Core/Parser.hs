module Juvix.Core.Parser where

import           Data.Functor.Identity
import           Juvix.Core.MainLang
import           Prelude
import           Text.Parsec
import           Text.ParserCombinators.Parsec
import           Text.ParserCombinators.Parsec.Language
import qualified Text.ParserCombinators.Parsec.Token    as Token

languageDef :: GenLanguageDef String u Data.Functor.Identity.Identity
languageDef =
  emptyDef
    { Token.commentStart = "/*"
    , Token.commentEnd = "*/"
    , Token.commentLine = "//"
    , Token.identStart = letter
    , Token.identLetter = alphaNum
    , Token.reservedNames =
        [ "*" --sort
        , "[Π]" --function type
        , "[π]" --dependent multiplicative conjunction type
        , "/\\" --dependent additive conjunction type
        , "\\/" --non-dependent multiplicative disjunction type
        , "Bound" --Bound var
        , "Free"
        , "Local"
        , "Quote"
        , "Global" --Free var
        , "w" --Omega
        , "App" --application
        , "VStar" --Values
        , "VNats"
        , "VPi"
        , "VPm"
        , "VPa"
        , "VNPm"
        , "VLam"
        , "VNeutral"
        , "VNat"
        , "NFree" --Neutral
        , "NApp"
        ]
    , Token.reservedOpNames = ["Conv", "\\", ":", "cType"]
    }

lexer :: Token.GenTokenParser String u Data.Functor.Identity.Identity
lexer = Token.makeTokenParser languageDef
     -- These are parsers for what their names signify

identifier :: Parser String
identifier = Token.identifier lexer

reserved :: String -> Parser ()
reserved = Token.reserved lexer

reservedOp :: String -> Parser ()
reservedOp = Token.reservedOp lexer

parens :: Parser a -> Parser a
parens = Token.parens lexer -- parses surrounding parenthesis, and what is inside them

natural :: Parser Integer
natural = Token.natural lexer

whiteSpace :: Parser ()
whiteSpace = Token.whiteSpace lexer

natw :: Parser NatAndw
natw =
  do reserved "w"
     return Omega
     <|> do
    n <- natural
    return $ SNat (fromInteger n)

sortTerm :: Parser CTerm
sortTerm = do
  reserved "*"
  n <- natural
  return $ Star (fromInteger n)

piTerm :: Parser CTerm
piTerm = do
  reserved "[Π]"
  pi <- natw
  input <- ctermOnly
  func <- ctermOnly
  return $ Pi pi input func

pmTerm :: Parser CTerm
pmTerm = do
  reserved "[π]"
  pm <- natw
  input <- ctermOnly
  func <- ctermOnly
  return $ Pm pm input func

paTerm :: Parser CTerm
paTerm = do
  reserved "/\\"
  pa <- natw
  input <- ctermOnly
  func <- ctermOnly
  return $ Pa pa input func

npmTerm :: Parser CTerm
npmTerm = do
  reserved "\\/"
  fst <- ctermOnly
  snd <- ctermOnly
  return $ NPm fst snd

lamTerm :: Parser CTerm
lamTerm = do
  reservedOp "\\"
  pi <- natw
  func <- ctermOnly
  return $ Lam pi func

convTerm :: Parser CTerm
convTerm = do
  reservedOp "Conv"
  termToConvert <- iterm
  return $ Conv termToConvert

boundTerm :: Parser ITerm
boundTerm = do
  reserved "Bound"
  index <- natural
  return $ Bound (fromInteger index)

--Parser for the global free variable name
gName :: Parser String
gName = parens gName <|> identifier

--Parser for Name data type
localTerm :: Parser Name
localTerm = do
  reserved "Local"
  index <- natural
  return $ Local (fromInteger index)

quoteTerm :: Parser Name
quoteTerm = do
  reserved "Quote"
  index <- natural
  return $ Quote (fromInteger index)

globalTerm :: Parser Name
globalTerm = do
  reserved "Global"
  gname <- gName
  return $ Global gname

pName :: Parser Name
pName = localTerm <|> quoteTerm <|> globalTerm

freeTerm :: Parser ITerm
freeTerm = do
  reserved "Free"
  fname <- pName
  return $ Free fname

appTerm :: Parser ITerm
appTerm = do
  reserved "App"
  func <- iterm
  var <- ctermOnly
  eof
  return $ App func var

annTerm :: Parser ITerm
annTerm = do
  pi <- natw
  term <- ctermOnly
  reservedOp ":"
  ann <- ctermOnly
  eof
  return $ Ann pi term ann

parseWhole :: Parser a -> Parser a
parseWhole p = do
  whiteSpace
  t <- p
  whiteSpace
  eof
  return t

cterm :: Parser CTerm
cterm =
  parens cterm <|> sortTerm <|> piTerm <|> pmTerm <|> paTerm <|> npmTerm <|>
  lamTerm <|>
  convTerm <|>
  ctermOnly

iterm :: Parser ITerm
iterm = parens iterm <|> boundTerm <|> freeTerm <|> appTerm <|> annTerm

cOriTerm :: Parser (Either ITerm CTerm)
cOriTerm = Text.Parsec.try (Left <$> iterm) <|> (Right <$> cterm)

ctermOnly :: Parser CTerm
ctermOnly = do
  anyTerm <- cOriTerm
  return
    (case anyTerm of
       Left i  -> (Conv i)
       Right c -> c)

vStar :: Parser Value
vStar = do
  reserved "VStar"
  i <- natural
  return VStar i

vNats :: Parser Value
vNats = do
  reserved "VNats"
  return VNats

{-
vPi :: Parser Value
vPi = do
  reserved "VPi"
  usage <- natw
  var <- pValue
  func <-
-}
neutral :: Parser Neutral
neutral =
  do reserved "NFree"
     freeName <- name
     return NFree freeName
     <|> do
    reserved "NApp"
    var <- neutral
    func <- pValue
    return NApp var func

vNeutral :: Parser Value
vNeutral = do
  reserved "VNeutral"

pValue :: Parser Value
pValue = vStar <|> vNats <|> vLam <|> vNeutral <|> vNat

-- <|> vPi <|> vPm <|> vPa <|> vNpm
pAnnotation :: Parser Annotation --Annotation = (NatAndw, Value)
pAnnotation = do
  usage <- natw
  Parsec.spaces
  typeValue <- pValue
  return (usage, typeValue)

pContext :: Parser Context --Context = [(Name, Annotation)]
pContext = do
  varName <- pName
  Parsec.spaces
  varAnn <- pAnnotation
  return (varName, varAnn)

--Parses type checker input
pCType :: Parser Either String ()
pCType = do
  reservedOp "cType"
  index <- natural
  context <- pContext
  cterm <- ctermOnly
  return 
    case cType index context cterm of
      Left msg -> return putStr msg
      Right _ -> return _

parseString :: Parser a -> String -> Maybe a
parseString p str =
  case parse p "" str of
    Left _  -> Nothing
    Right r -> Just r
