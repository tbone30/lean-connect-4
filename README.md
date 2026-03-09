# Connect 4 in Lean 4

A formal model of Connect 4, structured in three layers of increasing depth.

## Project Structure

```
Connect4/
├── Basic.lean      -- Board representation, moves, game state
├── Win.lean        -- Win detection (four in a row)
├── Strategy.lean   -- Minimax, alpha-beta, correctness statements
├── Connect4.lean   -- Top-level import
└── lakefile.lean   -- Lake build configuration
```

## The Three Layers

### Layer 1: `Basic.lean`
Core types and board model.

- `Player` — inductive type with `.Red` and `.Yellow`
- `Board` — `Fin 6 → Fin 7 → Option Player`
- `GameState` — board + whose turn + move count
- `dropPiece` — drops a piece into a column (gravity model)
- `legalMoves` — enumerates non-full columns
- Key lemma: every column is legal on the empty board

### Layer 2: `Win.lean`
Win condition detection.

- `hasWon b p` — checks all 4 directions for 4-in-a-row
- `gameResult s` — returns `Win p | Draw | Ongoing`
- Key lemma: `gameResult GameState.init = .Ongoing`

### Layer 3: `Strategy.lean`
Minimax and correctness.

- `minimax` — game-theoretic value of a position (specification)
- `alphaBeta` — pruned search (executable engine)
- `bestMove` — returns the optimal column to play
- `isOptimalMove` — formal definition of move correctness
- Key theorem (marked `sorry`): alpha-beta agrees with minimax

## What the `sorry`s mean

Several theorems are stated but not yet proved, marked with `sorry`:

| Theorem | Difficulty | Notes |
|---|---|---|
| `moves_le_42` | Medium | Requires induction on game history |
| `not_both_win` | Medium | Requires reachability invariant |
| `alphaBeta_eq_minimax` | Hard | Core correctness theorem |
| `bestMove_optimal` | Hard | Follows from above |
| `first_player_wins` | Research | The Allis 1988 result |

These are the natural next steps for extending the project.

## Getting Started

```bash
# Install Lake and Lean 4, then:
lake update
lake build
```

## Next Steps

1. Fill in the `sorry` proofs, starting with `moves_le_42`
2. Add a `Decidable` instance for `hasWon` to enable `decide` proofs
3. Use `decide` to verify specific positions (e.g., "playing center on move 1 is optimal")
4. Implement transposition table in `alphaBeta` for better performance
5. Attempt `first_player_wins` via a verified proof certificate