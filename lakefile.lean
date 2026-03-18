import Lake
open Lake DSL

package "connect4" where
  version := v!"0.1.0"

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "master"

lean_lib «Connect4» where
  roots := #[`Connect4]
