import Connect4

namespace Connect4

def c0 : Col := ⟨0, by decide⟩
def c1 : Col := ⟨1, by decide⟩
def c2 : Col := ⟨2, by decide⟩
def c3 : Col := ⟨3, by decide⟩
def c6 : Col := ⟨6, by decide⟩

def playMoves (s : GameState) (moves : List Col) : Option GameState :=
  moves.foldl (fun acc c => acc.bind (fun st => st.applyMove c)) (some s)

example : gameResult GameState.init = .Ongoing := by
  simp

example : (legalMoves GameState.init.board).length = cols := by
  native_decide

example : Player.other (Player.other .Red) = .Red := by
  simp

/-- Red wins horizontally on the bottom row with this move sequence. -/
def redHorizontalWin : Option GameState :=
  playMoves GameState.init [c0, c6, c1, c6, c2, c6, c3]

example : redHorizontalWin.isSome = true := by
  native_decide

example : redHorizontalWin.map gameResult = some (.Win .Red) := by
  native_decide

/-- Seventh move into one column is illegal (column capacity is 6). -/
def overfillColumn : Option GameState :=
  playMoves GameState.init [c0, c0, c0, c0, c0, c0, c0]

example : overfillColumn = none := by
  native_decide

#eval redHorizontalWin.map gameResult
#eval overfillColumn

end Connect4
