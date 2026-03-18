const ROWS = 6;
const COLS = 7;

let state = {
  ok: true,
  board: Array.from({ length: ROWS }, () => Array(COLS).fill(0)),
  result: "ongoing",
  legalMoves: [],
  turn: "red",
};
let waiting = false;

const statusEl = document.getElementById("status");
const boardEl = document.getElementById("board");
const columnButtonsEl = document.getElementById("column-buttons");
const newGameButton = document.getElementById("new-game");

newGameButton.addEventListener("click", resetGame);

async function requestJson(url, options = {}) {
  const response = await fetch(url, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  const data = await response.json();
  if (!response.ok || !data.ok) {
    throw new Error(data.error || `Request failed: ${response.status}`);
  }
  return data;
}

function isGameOver() {
  return state.result !== "ongoing";
}

function setStatus(message) {
  statusEl.textContent = message;
}

function statusFromState() {
  if (isGameOver()) {
    if (state.result === "win_red") return "You win!";
    if (state.result === "win_yellow") return "Computer wins";
    return "Draw game";
  }
  return state.turn === "red" ? "Your turn" : "Computer turn";
}

function renderBoard() {
  boardEl.innerHTML = "";
  for (let r = 0; r < ROWS; r += 1) {
    for (let c = 0; c < COLS; c += 1) {
      const cell = document.createElement("div");
      cell.className = "cell";
      if (state.board[r][c] === 1) cell.classList.add("red");
      if (state.board[r][c] === 2) cell.classList.add("yellow");
      boardEl.appendChild(cell);
    }
  }
}

function renderColumnButtons() {
  columnButtonsEl.innerHTML = "";
  const legalMoves = new Set(state.legalMoves || []);

  for (let c = 0; c < COLS; c += 1) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "column-button";
    button.textContent = `↓ ${c + 1}`;
    button.disabled = waiting || isGameOver() || state.turn !== "red" || !legalMoves.has(c);
    button.addEventListener("click", () => handleHumanMove(c));
    columnButtonsEl.appendChild(button);
  }
}

function render() {
  setStatus(waiting ? "Computer thinking..." : statusFromState());
  renderColumnButtons();
  renderBoard();
}

async function resetGame() {
  waiting = true;
  render();
  try {
    state = await requestJson("/api/new", { method: "POST", body: "{}" });
  } catch (error) {
    setStatus(error.message);
  } finally {
    waiting = false;
    render();
  }
}

async function handleHumanMove(col) {
  if (waiting || isGameOver() || state.turn !== "red") return;
  waiting = true;
  render();
  try {
    state = await requestJson("/api/play", {
      method: "POST",
      body: JSON.stringify({ col }),
    });
  } catch (error) {
    setStatus(error.message);
  } finally {
    waiting = false;
    render();
  }
}

resetGame();
