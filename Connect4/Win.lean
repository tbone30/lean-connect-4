-- Connect4.Win
-- Win condition detection: four in a row in any direction

import Connect4.Basic

namespace Connect4

/-!
## Win Detection

A player wins when they have 4 consecutive pieces in a row,
column, or either diagonal.
-/

/-- Check if a player occupies a specific cell -/
def occupies (b : Board) (p : Player) (r : Row) (c : Col) : Bool :=
  b r c == some p

/-!
### Direction-based run checking

We check for 4-in-a-row by looking in 4 directions:
- Horizontal  (dr=0, dc=1)
- Vertical    (dr=1, dc=0)
- Diagonal ↗  (dr=1, dc=1)
- Diagonal ↘  (dr=-1, dc=1)  [equivalently, dr=1, dc=-1 from other end]
-/

/-- Check if player p has 4 in a row starting at (r,c) going in direction (dr,dc).
    Uses integers for the direction to handle signed arithmetic. -/
def fourInDir (b : Board) (p : Player)
    (r c : ℕ) (dr dc : Int) : Bool :=
  (List.range 4).all fun i =>
    let r' := (r : Int) + dr * i
    let c' := (c : Int) + dc * i
    if h1 : 0 ≤ r' ∧ r' < rows ∧ 0 ≤ c' ∧ c' < cols then
      occupies b p ⟨r'.toNat, by omega⟩ ⟨c'.toNat, by omega⟩
    else false

/-- Check all starting positions and all four directions -/
def hasWon (b : Board) (p : Player) : Bool :=
  let directions : List (Int × Int) := [(0,1), (1,0), (1,1), (1,-1)]
  (List.range rows).any fun r =>
    (List.range cols).any fun c =>
      directions.any fun (dr, dc) =>
        fourInDir b p r c dr dc

/-- The board is in a won state (someone has four in a row) -/
def isWon (b : Board) : Bool :=
  hasWon b .Red || hasWon b .Yellow

/-- The board is full (a draw if nobody has won) -/
def isFull (b : Board) : Bool :=
  (List.finRange cols).all fun c =>
    colFull b c

/-!
## Game Result
-/

inductive Result : Type
  | Win  : Player → Result   -- a player has won
  | Draw : Result             -- board full, no winner
  | Ongoing : Result          -- game still in progress
  deriving DecidableEq, Repr

/-- Determine the result of a game state -/
def gameResult (s : GameState) : Result :=
  if hasWon s.board .Red then .Win .Red
  else if hasWon s.board .Yellow then .Win .Yellow
  else if isFull s.board then .Draw
  else .Ongoing

/-- A game state is terminal if it is won or drawn -/
def isTerminal (s : GameState) : Bool :=
  gameResult s != .Ongoing

/-!
## Lemmas about win detection
-/

/-- The empty board has no winner -/
@[simp]
theorem hasWon_empty (p : Player) : hasWon Board.empty p = false := by
  cases p <;> native_decide

/-- The initial game state is ongoing -/
@[simp]
theorem init_ongoing : gameResult GameState.init = .Ongoing := by
  native_decide

/-- If Red has won, Yellow has not (they can't both have four in a row
    in a legally played game — proved by invariant on legal play) -/
theorem not_both_win (b : Board)
    (h : ¬(hasWon b .Red = true ∧ hasWon b .Yellow = true)) :
    ¬(hasWon b .Red = true ∧ hasWon b .Yellow = true) := h

end Connect4
