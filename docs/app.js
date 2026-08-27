const money = (n) => {
  if (n == null || Number.isNaN(n)) return "\u2014";
  const abs = Math.abs(n);
  const opts = abs >= 1000 ? { maximumFractionDigits: 0 } : { maximumFractionDigits: 2 };
  const s = Math.abs(n).toLocaleString("en-US", opts);
  if (n > 0) return "+$" + s;
  if (n < 0) return "-$" + s;
  return "$" + s;
};
const pct = (n) => (n == null ? "\u2014" : n.toFixed(1) + "%");

let DATA = null;
let standId = "m5_best";
let equityChart = null;
let months = [];
let monthIdx = 0;
let monthTrades = [];
let page = 0;
const PAGE_SIZE = 25;
let selectedTradeId = null;
const monthCache = new Map();

function stand() {
  return DATA.stands.find((s) => s.id === standId);
}

async function loadStands() {
  DATA = await (await fetch("./data/stands.json")).json();
}

async function loadEquity(s) {
  const data = await (await fetch("./data/" + s.equity)).json();
  return data.points || [];
}

async function loadMonths(s) {
  const data = await (await fetch("./data/" + s.months)).json();
  return data.months || [];
}

async function loadMonthTrades(s, yyyyMm) {
  const key = s.id + "/" + yyyyMm;
  if (monthCache.has(key)) return monthCache.get(key);
  const url = "./data/" + s.tradesDir + "/" + yyyyMm + ".json";
  const data = await (await fetch(url)).json();
  const trades = data.trades || [];
  monthCache.set(key, trades);
  return trades;
}

function renderOverview() {
  const s = stand();
  const ver = document.getElementById("ver");
  if (ver) ver.textContent = DATA.version;

  document.getElementById("stand-meta").textContent =
    s.symbol +
    " \u00b7 " +
    s.period +
    " \u00b7 deposit $" +
    Number(s.deposit).toLocaleString("en-US") +
    " \u00b7 risk " +
    s.risk +
    "% \u00b7 " +
    (s.from || "") +
    " \u2192 " +
    (s.to || "") +
    " \u00b7 " +
    (s.model || "") +
    " \u00b7 " +
    (s.broker || "");

  const end = s.deposit + s.net;
  const rows = [
    ["Net profit", money(s.net), s.net >= 0 ? "up" : "down"],
    [
      "Ending balance",
      "$" + end.toLocaleString("en-US", { maximumFractionDigits: 0 }),
      "up",
    ],
    ["Profit factor", Number(s.profitFactor).toFixed(2), ""],
    ["Equity drawdown", pct(s.equityDdPct), "down"],
    ["Trades", Number(s.trades).toLocaleString("en-US"), ""],
    ["Win rate", s.winRate || "\u2014", ""],
    ["Guard", s.guard || "\u2014", ""],
    ["Label", s.label || "\u2014", ""],
  ];

  document.getElementById("overview-stats").innerHTML = rows
    .map(
      ([k, v, cls]) =>
        "<div><dt>" +
        k +
        '</dt><dd class="' +
        cls +
        '">' +
        v +
        "</dd></div>"
    )
    .join("");

  document.querySelectorAll("#tf-seg .seg-btn").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.stand === standId);
  });
}

function renderChart(points) {
  const ctx = document.getElementById("chart-balance");
  if (!ctx || typeof Chart === "undefined") return;

  const labels = points.map((p) => p.t);
  const values = points.map((p) => p.b);

  if (equityChart) equityChart.destroy();
  equityChart = new Chart(ctx, {
    type: "line",
    data: {
      labels,
      datasets: [
        {
          data: values,
          borderColor: "rgba(201,162,39,0.95)",
          backgroundColor: "rgba(201,162,39,0.12)",
          borderWidth: 1.5,
          pointRadius: 0,
          pointHoverRadius: 3,
          fill: true,
          tension: 0.15,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: (c) => money(c.raw),
          },
        },
      },
      scales: {
        x: {
          ticks: {
            color: "#a8987c",
            maxTicksLimit: 8,
            callback: function (val, i) {
              const label = this.getLabelForValue(val);
              return i % Math.ceil(labels.length / 8) === 0
                ? String(label).slice(0, 10)
                : "";
            },
          },
          grid: { display: false },
        },
        y: {
          ticks: {
            color: "#a8987c",
            callback: (v) =>
              "$" + Number(v).toLocaleString("en-US", { maximumFractionDigits: 0 }),
          },
          grid: { color: "rgba(232,210,160,0.08)" },
        },
      },
    },
  });
}

function renderCalendar() {
  const label = document.getElementById("cal-label");
  const grid = document.getElementById("cal-grid");
  const prev = document.getElementById("cal-prev");
  const next = document.getElementById("cal-next");
  const current = months[monthIdx] || "";

  if (label) label.textContent = current || "\u2014";
  if (prev) prev.disabled = monthIdx <= 0;
  if (next) next.disabled = monthIdx >= months.length - 1;

  if (!grid) return;
  grid.innerHTML = months
    .map((m, i) => {
      const active = i === monthIdx ? " active" : "";
      return (
        '<button type="button" class="cal-cell has' +
        active +
        '" data-month-idx="' +
        i +
        '">' +
        m +
        "</button>"
      );
    })
    .join("");
}

function renderTradeList() {
  const tbody = document.getElementById("trade-list");
  const pageLabel = document.getElementById("page-label");
  const prev = document.getElementById("page-prev");
  const next = document.getElementById("page-next");
  const totalPages = Math.max(1, Math.ceil(monthTrades.length / PAGE_SIZE));
  if (page >= totalPages) page = totalPages - 1;
  if (page < 0) page = 0;

  const start = page * PAGE_SIZE;
  const slice = monthTrades.slice(start, start + PAGE_SIZE);

  if (pageLabel) {
    pageLabel.textContent =
      monthTrades.length === 0
        ? "0 trades"
        : "Page " +
          (page + 1) +
          " / " +
          totalPages +
          " \u00b7 " +
          monthTrades.length +
          " trades";
  }
  if (prev) prev.disabled = page <= 0;
  if (next) next.disabled = page >= totalPages - 1 || monthTrades.length === 0;

  if (!tbody) return;
  tbody.innerHTML = slice
    .map((t) => {
      const active = String(t.id) === String(selectedTradeId) ? " active" : "";
      const plCls = t.profit >= 0 ? "up" : "down";
      return (
        '<tr class="' +
        active.trim() +
        '" data-trade-id="' +
        t.id +
        '">' +
        "<td>" +
        (t.closeTime || "") +
        "</td>" +
        "<td>" +
        (t.side || "") +
        "</td>" +
        "<td>" +
        Number(t.volume).toLocaleString("en-US") +
        "</td>" +
        '<td class="' +
        plCls +
        '">' +
        money(t.profit) +
        "</td>" +
        "<td>$" +
        Number(t.balance).toLocaleString("en-US", { maximumFractionDigits: 0 }) +
        "</td>" +
        "</tr>"
      );
    })
    .join("");
}

function renderTradeDetail(trade) {
  const el = document.getElementById("trade-detail");
  if (!el) return;
  if (!trade) {
    el.innerHTML = '<p class="mute">Select a trade</p>';
    return;
  }

  const rows = [
    ["Ticket", trade.id],
    ["Side", trade.side],
    ["Lots", Number(trade.volume).toLocaleString("en-US")],
    ["Open", trade.openTime],
    ["Close", trade.closeTime],
    ["Open price", Number(trade.openPrice).toLocaleString("en-US")],
    ["Close price", Number(trade.closePrice).toLocaleString("en-US")],
    ["P/L", money(trade.profit)],
    [
      "Balance",
      "$" + Number(trade.balance).toLocaleString("en-US", { maximumFractionDigits: 2 }),
    ],
  ];
  if (trade.commission != null) rows.push(["Commission", money(trade.commission)]);
  if (trade.swap != null) rows.push(["Swap", money(trade.swap)]);
  if (trade.comment) rows.push(["Comment", trade.comment]);

  el.innerHTML =
    "<h3>Trade " +
    trade.id +
    "</h3><dl>" +
    rows
      .map(([k, v]) => "<dt>" + k + "</dt><dd>" + v + "</dd>")
      .join("") +
    "</dl>";
}

async function setStand(id) {
  standId = id || "m5_best";
  months = await loadMonths(stand());
  monthIdx = Math.max(0, months.length - 1);
  page = 0;
  selectedTradeId = null;
  renderOverview();
  const points = await loadEquity(stand());
  renderChart(points);
  await setMonthByIndex(monthIdx);
}

async function setMonthByIndex(i) {
  if (!months.length) {
    monthTrades = [];
    renderCalendar();
    renderTradeList();
    renderTradeDetail(null);
    return;
  }
  monthIdx = Math.max(0, Math.min(i, months.length - 1));
  page = 0;
  selectedTradeId = null;
  monthTrades = await loadMonthTrades(stand(), months[monthIdx]);
  renderCalendar();
  renderTradeList();
  renderTradeDetail(null);
}

function wireEvents() {
  document.querySelectorAll("#tf-seg .seg-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      setStand(btn.dataset.stand);
    });
  });

  document.getElementById("cal-prev")?.addEventListener("click", () => {
    setMonthByIndex(monthIdx - 1);
  });
  document.getElementById("cal-next")?.addEventListener("click", () => {
    setMonthByIndex(monthIdx + 1);
  });

  document.getElementById("cal-grid")?.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-month-idx]");
    if (!btn) return;
    setMonthByIndex(Number(btn.dataset.monthIdx));
  });

  document.getElementById("trade-list")?.addEventListener("click", (e) => {
    const row = e.target.closest("tr[data-trade-id]");
    if (!row) return;
    selectedTradeId = row.dataset.tradeId;
    const trade = monthTrades.find((t) => String(t.id) === String(selectedTradeId));
    renderTradeList();
    renderTradeDetail(trade || null);
  });

  document.getElementById("page-prev")?.addEventListener("click", () => {
    if (page <= 0) return;
    page -= 1;
    renderTradeList();
  });
  document.getElementById("page-next")?.addEventListener("click", () => {
    const totalPages = Math.max(1, Math.ceil(monthTrades.length / PAGE_SIZE));
    if (page >= totalPages - 1) return;
    page += 1;
    renderTradeList();
  });
}

async function boot() {
  await loadStands();
  standId = DATA.defaultStand || "m5_best";
  wireEvents();
  await setStand(standId);
}

boot().catch((e) => {
  document.body.insertAdjacentHTML(
    "afterbegin",
    '<p style="padding:2rem;color:#d86b5c">Failed to load data: ' + e + "</p>"
  );
});