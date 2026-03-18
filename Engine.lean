import Connect4
import Lean.Data.Json

open Lean

namespace Connect4

def playerToNat : Player → Nat
  | .Red => 1
  | .Yellow => 2

def cellToNat : Option Player → Nat
  | none => 0
  | some p => playerToNat p

def resultToString : Result → String
  | .Ongoing => "ongoing"
  | .Draw => "draw"
  | .Win .Red => "win_red"
  | .Win .Yellow => "win_yellow"

def turnToString : Player → String
  | .Red => "red"
  | .Yellow => "yellow"

def boardToRows (b : Board) : List (List Nat) :=
  (List.finRange rows).reverse.map fun r =>
    (List.finRange cols).map fun c => cellToNat (b r c)

def mkCol (n : Nat) : Option Col :=
  if h : n < cols then some ⟨n, h⟩ else none

def applyMoves (s : GameState) : List Nat → Nat → Except String GameState
  | [], _ => .ok s
  | m :: ms, ply =>
    match mkCol m with
    | none => .error s!"invalid column {m} at ply {ply}"
    | some c =>
      match s.applyMove c with
      | none => .error s!"illegal move {m} at ply {ply}"
      | some s' => applyMoves s' ms (ply + 1)

def stateJson (s : GameState) (depthOverride : Option Nat) : Json :=
  let result := gameResult s
  let legal : List Nat := (legalMoves s.board).map (·.val)
  let remainingDepth := rows * cols - s.moves
  let searchDepth :=
    match depthOverride with
    | some d => min d remainingDepth
    | none => remainingDepth
  let best : Option Nat :=
    match result with
    | .Ongoing =>
      match s.turn with
      | .Yellow => (bestMove s searchDepth).map (·.val)
      | .Red => none
    | _ => none
  Json.mkObj
    [ ("ok", toJson true)
    , ("board", toJson (boardToRows s.board))
    , ("turn", toJson (turnToString s.turn))
    , ("moves", toJson s.moves)
    , ("result", toJson (resultToString result))
    , ("legalMoves", toJson legal)
    , ("bestMove", toJson best)
    , ("searchDepth", toJson searchDepth)
    ]

def errorJson (msg : String) : Json :=
  Json.mkObj
    [ ("ok", toJson false)
    , ("error", toJson msg)
    ]

def parseMoves (args : List String) : Except String (List Nat) :=
  args.foldr
    (fun s acc =>
      match s.toNat?, acc with
      | some n, .ok ns => .ok (n :: ns)
      | none, _ => .error s!"invalid move argument: {s}"
      | _, .error e => .error e)
    (.ok [])

def parseArgs : List String → Option Nat → Except String (Option Nat × List Nat)
  | [], depth => .ok (depth, [])
  | "--depth" :: d :: rest, none =>
    match d.toNat? with
    | some n =>
      match parseArgs rest (some n) with
      | .ok (depth', moves) => .ok (depth', moves)
      | .error e => .error e
    | none => .error s!"invalid --depth value: {d}"
  | "--depth" :: _ :: _, some _ => .error "--depth specified more than once"
  | "--depth" :: [], _ => .error "missing value after --depth"
  | s :: rest, depth =>
    match s.toNat? with
    | some n =>
      match parseArgs rest depth with
      | .ok (depth', moves) => .ok (depth', n :: moves)
      | .error e => .error e
    | none => .error s!"invalid move argument: {s}"

def engineMain (args : List String) : IO UInt32 := do
  let outJson :=
    match parseArgs args none with
    | .error e => errorJson e
    | .ok (depthOverride, moves) =>
      match applyMoves GameState.init moves 0 with
      | .error e => errorJson e
      | .ok s => stateJson s depthOverride
  IO.println outJson.compress
  pure 0

end Connect4

def main (args : List String) : IO UInt32 :=
  Connect4.engineMain args
