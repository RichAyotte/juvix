{-# LANGUAGE NamedFieldPuns     #-}
{-# LANGUAGE StandaloneDeriving #-}

module Juvix.Interaction where

import           Control.Monad.State.Strict
import           Data.Graph.Inductive
import qualified Data.Map.Strict            as Map
import qualified Data.Set                   as Set
import           Prelude                    (error)
import           Protolude                  hiding (State, link, reduce,
                                             runState)

data PortType = Prim
              | Aux1
              | Aux2
              | Aux3
              | Aux4
              | Aux5
              deriving (Ord,Eq, Show)

data NumPort = Port PortType Node
             | FreePort
             deriving Show

data EdgeInfo = Edge (Node, PortType) (Node, PortType) deriving Show

-- Eventually turn this into a GADΤ with more info?
data Lang where
  Con :: Lang
  Dup :: Lang
  Era :: Lang

deriving instance Show Lang

-- Leave these as GADTs for now!
data Primary where
  Primary :: Node → Primary
  Free    :: Primary

deriving instance Show Primary

data Auxiliary = Auxiliary Node
               | FreeNode
               deriving Show

-- eventually turn this into a nice Class representation to easily extend!
data ProperPort
  = Construct {prim :: Primary, aux1 :: Auxiliary, aux2 :: Auxiliary}
  | Duplicate {prim :: Primary, aux1 :: Auxiliary, aux2 :: Auxiliary}
  | Erase     {prim :: Primary}
  deriving (Show)

-- Rewrite REL into tagless final, so we aren't memory
-- wasting on this silly tag, just pass in the function!
-- | REL: a type that displays whether we are linking from an old node or just adding a new link
data REL a = Link a
           | ReLink Node PortType
           deriving (Show)

-- | Type for specifying how one wants to link nodes
data Relink
  = RELAuxiliary2 { node       :: Node
                  , primary    :: REL NumPort
                  , auxiliary1 :: REL NumPort
                  , auxiliary2 :: REL NumPort }
  | RELAuxiliary1 { node :: Node, primary :: REL NumPort, auxiliary1 :: REL NumPort }
  | RELAuxiliary0 { node :: Node, primary :: REL NumPort }
  deriving (Show)

type Net = Gr Lang EdgeInfo

-- | StateInfo Stores diagnostic data on how much memory a particular graph reduction uses
data StateInfo = Info { memoryAllocated  :: Integer
                      , sequentalSteps   :: Integer
                      , parallelSteps    :: Integer
                      , biggestGraphSize :: Integer
                      , currentGraphSize :: Integer
                      } deriving (Show)

sequentalStep ∷ MonadState StateInfo m ⇒ m ()
sequentalStep = modify' (\c -> c {sequentalSteps = sequentalSteps c + 1})

incGraphSizeStep :: MonadState StateInfo m ⇒ Integer → m ()
incGraphSizeStep n = do
  Info memAlloced seqStep parallelSteps largestGraph currGraph <- get
  let memoryAllocated | n > 0 = memAlloced + n
                      | otherwise = memAlloced
      currentGraphSize = n + currGraph
      biggestGraphSize = max currentGraphSize largestGraph
      sequentalSteps = succ seqStep
  put Info {memoryAllocated, currentGraphSize, biggestGraphSize, sequentalSteps, parallelSteps}

-- Graph to more typed construction-------------------------------------------------------
aux0FromGraph ∷ (Primary → ProperPort) → Net → Node → Maybe ProperPort
aux0FromGraph constructor graph num =
  foldr f (constructor Free) . lneighbors' <$> fst (match num graph)
  where
    f (Edge (n1, n1port) (n2, n2port), _) con
      | n1 == num && Prim == n1port = con {prim = Primary n2}
      | n2 == num && Prim == n2port = con {prim = Primary n1}
    f _ con = con

aux2FromGraph ∷
     (Primary → Auxiliary → Auxiliary → ProperPort)
  → Net
  → Node
  → Maybe ProperPort
aux2FromGraph constructor graph num =
  foldr f (constructor Free FreeNode FreeNode) . lneighbors' <$> fst (match num graph)
  where
    f (Edge (n1, n1port) (n2, n2port), _) con
      | n1 == num = conv (n2, n1port) con
      | n2 == num = conv (n1, n2port) con
      | otherwise = con
    conv (n,Prim) con = con {prim = Primary n}
    conv (n,Aux1) con = con {aux1 = Auxiliary n}
    conv (n,Aux2) con = con {aux2 = Auxiliary n}
    conv (_,_) con    = con

-- extra work that could maybe be avoided by doing this else where?
isBothPrimary ∷ Graph gr ⇒ gr a EdgeInfo → Node → Bool
isBothPrimary net node =
  null
  $ filter (\ (Edge (_, p) (_, p')) -> p == Prim && p' == Prim)
  $ fmap fst
  $ lneighbors net node

conFromGraph ∷ Net → Node → Maybe ProperPort
conFromGraph = aux2FromGraph Construct

dupFromGraph ∷ Net → Node → Maybe ProperPort
dupFromGraph = aux2FromGraph Duplicate

eraFromGraph ∷ Net → Node → Maybe ProperPort
eraFromGraph = aux0FromGraph Erase

-- a bit of extra repeat work in this function!
langToProperPort ∷ Net → Node → Maybe ProperPort
langToProperPort graph n = do
  context <- fst (match n graph)
  case snd (labNode' context) of
    Con -> conFromGraph graph n
    Dup -> dupFromGraph graph n
    Era -> eraFromGraph graph n

-- Graph manipulation ----------------------------------------------------------
runNet ∷ (Net → State StateInfo a) → Net → (a, StateInfo)
runNet f net = runState (f net) (Info netSize 0 0 netSize netSize)
  where
    netSize = toInteger (length (nodes net))
-- Manipulation functions ------------------------------------------------------

linkHelper :: Net -> REL NumPort -> PortType -> Node -> Net
linkHelper net rel nodeType node =
  case rel of
    Link (Port portType node1) -> link net (node, nodeType) (node1, portType)
    Link FreePort              -> net
    ReLink oldNode oldPort     -> relink net (oldNode, oldPort) (node, nodeType)

linkAll ∷ Net → Relink → Net
linkAll net (RELAuxiliary0 {primary, node}) =
  linkHelper net primary Prim node
linkAll net (RELAuxiliary1 {primary, node, auxiliary1}) =
  linkHelper (linkHelper net primary Prim node) auxiliary1 Aux1 node
linkAll net (RELAuxiliary2 {primary, node, auxiliary1, auxiliary2}) =
  foldr (\ (typ,nodeType) net -> linkHelper net typ nodeType node)
        net
        [(primary, Prim), (auxiliary1, Aux1), (auxiliary2, Aux2)]


link ∷ Net → (Node, PortType) → (Node, PortType) → Net
link net (node1, port1) (node2, port2) =
  insEdge (node1, node2, Edge (node1, port1) (node2, port2)) net

-- post condition, must delete the old node passed after the set of transitions are done!
relink ∷ Net → (Node, PortType) → (Node, PortType) → Net
relink net (oldNode, port) new@(newNode, _newPort) =
  case findEdge net oldNode port of
    Just relink@(nodeToRelink, _) -> insEdge (nodeToRelink, newNode, Edge relink new) net
    Nothing                       -> net -- The port was really free to begin with!

-- | rewire is used to wire two auxiliary nodes together
-- when the main nodes annihilate each other
rewire ∷ Net → (PortType, Auxiliary) → (PortType, Auxiliary) → Net
rewire net (pa, (Auxiliary a)) (pb, (Auxiliary b)) = link net (a, pa) (b, pb)
rewire net _ _                                     = net

newNode ∷ DynGraph gr ⇒ gr a b → a → (Node, gr a b)
newNode graph lang = (succ maxNum, insNode (succ maxNum, lang) graph)
  where
    (_,maxNum) = nodeRange graph

deleteRewire ∷ [Node] → [Node] → Net → Net
deleteRewire oldNodesToDelete newNodes net = delNodes oldNodesToDelete dealWithConflict
  where
    newNodeSet           = Set.fromList newNodes
    neighbors            = fst <$> (oldNodesToDelete >>= lneighbors net)
    conflictingNeighbors = findConflict newNodeSet neighbors
    dealWithConflict     = foldr (\ (t1, t2) net -> link net t1 t2) net conflictingNeighbors

auxToPrimary :: Auxiliary -> Primary
auxToPrimary (Auxiliary node) = Primary node
auxToPrimary FreeNode         = Free

findConflict ∷ Set.Set Node → [EdgeInfo] → [((Node, PortType), (Node, PortType))]
findConflict nodes neighbors  = Set.toList (foldr f mempty neighbors)
  where
    f (Edge t1 t2@(_,_)) xs
      | Map.member t1 makeMap && Map.member t2 makeMap =
        Set.insert ((makeMap Map.! t2), (makeMap Map.! t1)) xs
      | otherwise = xs
    makeMap = foldr f mempty neighbors
      where
        f (Edge t1@(n1,_) t2@(n2,_)) hash
          | Set.member n1 nodes = Map.insert t2 t1 hash
          | Set.member n2 nodes = Map.insert t1 t2 hash
          | otherwise           = hash

-- Precond, node must exist in the net with the respective port
findEdge ∷ Net → Node → PortType → Maybe (Node, PortType)
findEdge net node port = fmap other $ headMay $ filter f $ lneighbors net node
  where
    f (Edge t1 t2, _)
      | t1 == (node, port) = True
      | t2 == (node, port) = True
      | otherwise          = False
    other (Edge t1 t2, _)
      | t1 == (node, port) = t2
      | t2 == (node, port) = t1
      | otherwise          = error "doesn't happen"

-- Utility functions -----------------------------------------------------------
untilNothingNTimesM ∷ Monad m ⇒ (t → m (Maybe t)) → t → Int → m t
untilNothingNTimesM f a n
  | n <= 0  = pure a
  | otherwise = do
      v <- f a
      case v of
        Nothing -> pure a
        Just a  -> untilNothingNTimesM f a (pred n)

untilNothing ∷ (t → Maybe t) → t → t
untilNothing f a = case f a of
  Nothing -> a
  Just a  -> untilNothing f a