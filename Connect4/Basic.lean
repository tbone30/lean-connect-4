-- Connect4.Basic
-- Core types and board representation for Connect 4

import Mathlib.Data.Fin.Basic
import Mathlib.Data.Option.Basic

namespace Connect4

/-!
## Core Types
-/

/-- The two players -/
inductive Player : Type
  | Red   : Player
  | Yellow : Player
  deriving DecidableEq, Repr

/-- Swap whose turn it is -/
def Player.other : Player → Player
  | .Red    => .Yellow
  | .Yellow => .Red

@[simp] theorem Player.other_other (p : Player) : p.other.other = p := by
  cases p <;> rfl

/-!
## Board Representation

A Connect 4 board is 6 rows × 7 columns.
We represent it as a function from (row, col) to an optional player.
Row 0 is the BOTTOM of the board (pieces fall down).
-/

def rows : ℕ := 6
def cols : ℕ := 7

/-- A position on the board -/
abbrev Row := Fin rows
abbrev Col := Fin cols

/-- The board maps each cell to either empty or occupied by a player -/
def Board := Row → Col → Option Player

/-- The empty board -/
def Board.empty : Board := fun _ _ => none

instance : Repr Board where
  reprPrec b _ :=
    -- Print from top row (row 5) down to bottom (row 0)
    let rows := (List.range 6).reverse.map fun r =>
      let cells := (List.range 7).map fun c =>
        match b ⟨r, by omega⟩ ⟨c, by omega⟩ with
        | none        => "."
        | some .Red   => "R"
        | some .Yellow => "Y"
      String.intercalate " " cells
    Std.Format.text (String.intercalate "\n" rows)

/-!
## Game State
-/

/-- Full game state: the board plus whose turn it is -/
structure GameState where
  board  : Board
  turn   : Player
  moves  : ℕ  -- number of moves played so far
  deriving Repr

/-- Initial game state: empty board, Red goes first -/
def GameState.init : GameState where
  board := Board.empty
  turn  := .Red
  moves := 0

/-!
## Column Occupancy
-/

/-- How many pieces are in a given column (i.e., the height of the stack) -/
def colHeight (b : Board) (c : Col) : ℕ :=
  -- Count from bottom up how many cells are filled
  (List.range rows).foldl (fun acc r =>
    if b ⟨r, by omega⟩ c |>.isSome then acc + 1 else acc) 0

/-- A column is full if its height equals the number of rows -/
def colFull (b : Board) (c : Col) : Bool :=
  colHeight b c >= rows

/-- A column is a legal move if it is not full -/
def legalMove (b : Board) (c : Col) : Bool :=
  !colFull b c

/-- List of all legal moves in a position -/
def legalMoves (b : Board) : List Col :=
  (List.range cols).filterMap fun c =>
    let col : Col := ⟨c, by omega⟩
    if legalMove b col then some col else none

/-!
## Dropping a Piece
-/

/-- Drop a piece into column c for player p.
    Returns the new board, or none if the column is full. -/
def dropPiece (b : Board) (p : Player) (c : Col) : Option Board :=
  let h := colHeight b c
  if h < rows then
    let row : Row := ⟨h, by omega⟩
    some (fun r c' => if r = row ∧ c' = c then some p else b r c')
  else
    none

/-- Apply a move to a game state. Returns none if the move is illegal. -/
def GameState.applyMove (s : GameState) (c : Col) : Option GameState :=
  (dropPiece s.board s.turn c).map fun b' =>
    { board := b'
      turn  := s.turn.other
      moves := s.moves + 1 }

/-!
## Basic Lemmas
-/

/-- The empty board has height 0 in every column -/
@[simp]
theorem colHeight_empty (c : Col) : colHeight Board.empty c = 0 := by
  simp [colHeight, Board.empty]
  rfl

/-- The empty board has no full columns -/
@[simp]
theorem colFull_empty (c : Col) : colFull Board.empty c = false := by
  simp [colFull, colHeight_empty]

/-- Every column is a legal move on an empty board -/
theorem legalMove_empty (c : Col) : legalMove Board.empty c = true := by
  simp [legalMove, colFull_empty]

/-- The game can last at most rows * cols = 42 moves -/
theorem moves_le_42 (s : GameState) : s.moves ≤ rows * cols := by
  -- Each move fills one cell; there are only 42 cells
  sorry -- Requires inductive argument on game history

end Connect4
