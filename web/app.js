const ROWS = 6;
const COLS = 7;
const HUMAN = 1;
const AI = 2;

let board = createEmptyBoard();
let gameOver = false;
let playerTurn = true;

const statusEl = document.getElementById("status");
const boardEl = document.getElementById("board");
const columnButtonsEl = document.getElementById("column-buttons");
const newGameButton = document.getElementById("new-game");

newGameButton.addEventListener("click", resetGame);

function createEmptyBoard() {
  return Array.from({ length: ROWS }, () => Array(COLS).fill(0));
}

function resetGame() {
  board = createEmptyBoard();
  gameOver = false;
  playerTurn = true;
  render();
  setStatus("Your turn");
}

function setStatus(message) {
  statusEl.textContent = message;
}

function getLegalMoves(state) {
  const legal = [];
  for (let c = 0; c < COLS; c += 1) {
    if (state[ROWS - 1][c] === 0) {
      legal.push(c);
    }
  }
  return legal;
}

function dropPiece(state, col, player) {
  for (let r = 0; r < ROWS; r += 1) {
    if (state[r][col] === 0) {
      state[r][col] = player;
      return r;
    }
  }
  return -1;
}

function cloneBoard(state) {
  return state.map((row) => [...row]);
}

function isBoardFull(state) {
  return getLegalMoves(state).length === 0;
}

function checkWin(state, player) {
  for (let r = 0; r < ROWS; r += 1) {
    for (let c = 0; c < COLS; c += 1) {
      if (state[r][c] !== player) continue;

      if (
        c + 3 < COLS &&
        state[r][c + 1] === player &&
        state[r][c + 2] === player &&
        state[r][c + 3] === player
      ) {
        return true;
      }

      if (
        r + 3 < ROWS &&
        state[r + 1][c] === player &&
        state[r + 2][c] === player &&
        state[r + 3][c] === player
      ) {
        return true;
      }

      if (
        r + 3 < ROWS &&
        c + 3 < COLS &&
        state[r + 1][c + 1] === player &&
        state[r + 2][c + 2] === player &&
        state[r + 3][c + 3] === player
      ) {
        return true;
      }

      if (
        r + 3 < ROWS &&
        c - 3 >= 0 &&
        state[r + 1][c - 1] === player &&
        state[r + 2][c - 2] === player &&
        state[r + 3][c - 3] === player
      ) {
        return true;
      }
    }
  }
  return false;
}

function evaluateWindow(windowValues, maximizingPlayer) {
  const opp = maximizingPlayer === AI ? HUMAN : AI;
  const ownCount = windowValues.filter((v) => v === maximizingPlayer).length;
  const oppCount = windowValues.filter((v) => v === opp).length;
  const emptyCount = windowValues.filter((v) => v === 0).length;

  if (ownCount === 4) return 1000;
  if (ownCount === 3 && emptyCount === 1) return 12;
  if (ownCount === 2 && emptyCount === 2) return 3;
  if (oppCount === 3 && emptyCount === 1) return -14;
  if (oppCount === 4) return -1000;
  return 0;
}

function scorePosition(state, maximizingPlayer) {
  let score = 0;

  const centerCol = Math.floor(COLS / 2);
  let centerCount = 0;
  for (let r = 0; r < ROWS; r += 1) {
    if (state[r][centerCol] === maximizingPlayer) centerCount += 1;
  }
  score += centerCount * 2;

  for (let r = 0; r < ROWS; r += 1) {
    for (let c = 0; c < COLS - 3; c += 1) {
      score += evaluateWindow(
        [state[r][c], state[r][c + 1], state[r][c + 2], state[r][c + 3]],
        maximizingPlayer
      );
    }
  }

  for (let c = 0; c < COLS; c += 1) {
    for (let r = 0; r < ROWS - 3; r += 1) {
      score += evaluateWindow(
        [state[r][c], state[r + 1][c], state[r + 2][c], state[r + 3][c]],
        maximizingPlayer
      );
    }
  }

  for (let r = 0; r < ROWS - 3; r += 1) {
    for (let c = 0; c < COLS - 3; c += 1) {
      score += evaluateWindow(
        [
          state[r][c],
          state[r + 1][c + 1],
          state[r + 2][c + 2],
          state[r + 3][c + 3],
        ],
        maximizingPlayer
      );
    }
  }

  for (let r = 0; r < ROWS - 3; r += 1) {
    for (let c = 3; c < COLS; c += 1) {
      score += evaluateWindow(
        [
          state[r][c],
          state[r + 1][c - 1],
          state[r + 2][c - 2],
          state[r + 3][c - 3],
        ],
        maximizingPlayer
      );
    }
  }

  return score;
}

function minimax(state, depth, alpha, beta, maximizing) {
  const legalMoves = getLegalMoves(state);
  const aiWin = checkWin(state, AI);
  const humanWin = checkWin(state, HUMAN);

  if (aiWin) return { score: 1_000_000, col: null };
  if (humanWin) return { score: -1_000_000, col: null };
  if (depth === 0 || legalMoves.length === 0) {
    return { score: scorePosition(state, AI), col: null };
  }

  const preferredOrder = [3, 2, 4, 1, 5, 0, 6].filter((c) =>
    legalMoves.includes(c)
  );

  if (maximizing) {
    let value = -Infinity;
    let bestCol = preferredOrder[0];
    for (const col of preferredOrder) {
      const next = cloneBoard(state);
      dropPiece(next, col, AI);
      const result = minimax(next, depth - 1, alpha, beta, false);
      if (result.score > value) {
        value = result.score;
        bestCol = col;
      }
      alpha = Math.max(alpha, value);
      if (alpha >= beta) break;
    }
    return { score: value, col: bestCol };
  }

  let value = Infinity;
  let bestCol = preferredOrder[0];
  for (const col of preferredOrder) {
    const next = cloneBoard(state);
    dropPiece(next, col, HUMAN);
    const result = minimax(next, depth - 1, alpha, beta, true);
    if (result.score < value) {
      value = result.score;
      bestCol = col;
    }
    beta = Math.min(beta, value);
    if (alpha >= beta) break;
  }
  return { score: value, col: bestCol };
}

function endGame(message) {
  gameOver = true;
  setStatus(message);
  render();
}

function handleHumanMove(col) {
  if (!playerTurn || gameOver) return;

  const row = dropPiece(board, col, HUMAN);
  if (row === -1) return;

  if (checkWin(board, HUMAN)) {
    endGame("You win!");
    return;
  }

  if (isBoardFull(board)) {
    endGame("Draw game");
    return;
  }

  playerTurn = false;
  setStatus("Computer thinking...");
  render();

  setTimeout(() => {
    const { col: aiCol } = minimax(board, 5, -Infinity, Infinity, true);
    if (aiCol == null) {
      endGame("Draw game");
      return;
    }

    dropPiece(board, aiCol, AI);

    if (checkWin(board, AI)) {
      endGame("Computer wins");
      return;
    }

    if (isBoardFull(board)) {
      endGame("Draw game");
      return;
    }

    playerTurn = true;
    setStatus("Your turn");
    render();
  }, 120);
}

function renderBoard() {
  boardEl.innerHTML = "";
  for (let r = ROWS - 1; r >= 0; r -= 1) {
    for (let c = 0; c < COLS; c += 1) {
      const cell = document.createElement("div");
      cell.className = "cell";
      if (board[r][c] === HUMAN) cell.classList.add("red");
      if (board[r][c] === AI) cell.classList.add("yellow");
      boardEl.appendChild(cell);
    }
  }
}

function renderColumnButtons() {
  columnButtonsEl.innerHTML = "";
  const legalMoves = new Set(getLegalMoves(board));

  for (let c = 0; c < COLS; c += 1) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "column-button";
    button.textContent = `↓ ${c + 1}`;
    button.disabled = gameOver || !playerTurn || !legalMoves.has(c);
    button.addEventListener("click", () => handleHumanMove(c));
    columnButtonsEl.appendChild(button);
  }
}

function render() {
  renderColumnButtons();
  renderBoard();
}

resetGame();
