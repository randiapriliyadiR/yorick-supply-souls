const money = (n) => {
  if (n == null || Number.isNaN(n)) return "\u2014";
  const abs = Math.abs(n);
  const opts = abs >= 1000 ? { maximumFractionDigits: 0 } : { maximumFractionDigits: 2 };
  const s = Math.abs(n).toLocaleString("en-US", opts);
  if (n > 0) return "+$" + s;
  if (n < 0) return "-$" + s;
  return "$" + s;
};
const moneyShort = (n) => {
  if (n == null || Number.isNaN(n)) return "\u2014";
  const abs = Math.abs(n);
  let body;
  if (abs >= 10000) body = Math.round(abs / 1000) + "k";
  else if (abs >= 1000) body = (abs / 1000).toFixed(1).replace(/\.0$/, "") + "k";
  else body = Math.round(abs).toString();
  if (n > 0) return "+$" + body;
  if (n < 0) return "-$" + body;
  return "$0";
};
const pct = (n) => (n == null ? "\u2014" : n.toFixed(1) + "%");

function monthKey(m) {
  return typeof m === "string" ? m : m && m.id ? m.id : "";
}
function monthNet(m) {
  if (m == null || typeof m === "string") return null;
  return typeof m.net === "number" ? m.net : null;
}

let DATA = null;
let standId = "mtf_200";
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
  const raw = data.months || [];
  const sparse = raw.map((m) => {
    if (typeof m === "string") return { id: m, net: null, trades: null };
    return {
      id: m.id || m.month || "",
      net: typeof m.net === "number" ? m.net : null,
      trades: typeof m.trades === "number" ? m.trades : null,
    };
  });
  return fillAllMonths(sparse, s.from, s.to);
}

async function loadMonthTrades(s, yyyyMm) {
  const id = monthKey(yyyyMm);
  const key = s.id + "/" + id;
  if (monthCache.has(key)) return monthCache.get(key);
  const url = "./data/" + s.tradesDir + "/" + id + ".json";
  try {
    const res = await fetch(url);
    if (!res.ok) {
      monthCache.set(key, []);
      return [];
    }
    const data = await res.json();
    const trades = data.trades || [];
    monthCache.set(key, trades);
    return trades;
  } catch (e) {
    monthCache.set(key, []);
    return [];
  }
}

function toYearMonth(raw) {
  if (!raw) return null;
  const s = String(raw).trim();
  let m = s.match(/^(\d{4})[.\-](\d{2})/);
  if (m) return m[1] + "-" + m[2];
  m = s.match(/^(\d{4})(\d{2})$/);
  if (m) return m[1] + "-" + m[2];
  return null;
}

function fillAllMonths(sparse, fromRaw, toRaw) {
  const byId = new Map();
  for (const m of sparse) {
    if (m && m.id) byId.set(m.id, m);
  }
  let start = toYearMonth(fromRaw);
  let end = toYearMonth(toRaw);
  if (!start || !end) {
    const ids = sparse.map((m) => m.id).filter(Boolean).sort();
    if (!ids.length) return sparse;
    start = start || ids[0];
    end = end || ids[ids.length - 1];
  }
  const out = [];
  let [y, mo] = start.split("-").map(Number);
  const [ey, emo] = end.split("-").map(Number);
  while (y < ey || (y === ey && mo <= emo)) {
    const id = y + "-" + String(mo).padStart(2, "0");
    if (byId.has(id)) out.push(byId.get(id));
    else out.push({ id: id, net: 0, trades: 0 });
    mo += 1;
    if (mo > 12) {
      mo = 1;
      y += 1;
    }
  }
  return out;
}

function extremeCard(kind, trade) {
  if (!trade) {
    return (
      '<article class="extreme-card">' +
      '<p class="extreme-k">' +
      kind +
      '</p><p class="mute">\u2014</p></article>'
    );
  }
  const cls = trade.profit >= 0 ? "up" : "down";
  return (
    '<article class="extreme-card">' +
    '<p class="extreme-k">' +
    kind +
    '</p>' +
    '<p class="extreme-v ' +
    cls +
    '">' +
    money(trade.profit) +
    "</p>" +
    '<p class="extreme-m">' +
    (trade.side || "") +
    " \u00b7 " +
    Number(trade.volume).toLocaleString("en-US") +
    " lots</p>" +
    '<p class="extreme-m">' +
    (trade.closeTime || "") +
    "</p>" +
    '<p class="extreme-m">#' +
    trade.id +
    "</p>" +
    "</article>"
  );
}

function renderOverview() {
  const s = stand();
  const ver = document.getElementById("ver");
  if (ver) ver.textContent = DATA.version;

  document.getElementById("stand-meta").textContent =
    (s.label || s.id) +
    " \u00b7 " +
    s.symbol +
    " " +
    s.period +
    " \u00b7 deposit $" +
    Number(s.deposit).toLocaleString("en-US") +
    " \u00b7 risk " +
    s.risk +
    "% \u00b7 guard " +
    (s.guard || "\u2014") +
    " \u00b7 " +
    (s.from || "") +
    " \u2192 " +
    (s.to || "") +
    " \u00b7 " +
    (s.model || "");

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
  ];

  document.getElementById("overview-stats").innerHTML = rows
    .map(
      ([k, v, cls]) =>
        '<div class="stat-item"><dt>' +
        k +
        '</dt><dd class="' +
        cls +
        '">' +
        v +
        "</dd></div>"
    )
    .join("");

  const extremes = document.getElementById("overview-extremes");
  if (extremes) {
    extremes.innerHTML =
      extremeCard("Largest profit", s.bestWin) +
      extremeCard("Largest loss", s.worstLoss);
  }
  document.querySelectorAll("#tf-seg .seg-btn").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.stand === standId);
  });
}

function parseMt5Time(t) {
  const m = String(t).match(
    /^(\d{4})\.(\d{2})\.(\d{2})(?:\s+(\d{2}):(\d{2})(?::(\d{2}))?)?/
  );
  if (!m) return null;
  return Date.UTC(
    Number(m[1]),
    Number(m[2]) - 1,
    Number(m[3]),
    Number(m[4] || 0),
    Number(m[5] || 0),
    Number(m[6] || 0)
  );
}

function formatChartDay(ms) {
  const d = new Date(ms);
  const y = d.getUTCFullYear();
  const mo = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return y + "-" + mo + "-" + day;
}

/** One point per UTC day (last balance that day), timed on real calendar axis. */
function toTimeSeries(points) {
  const byDay = new Map();
  for (const p of points) {
    const ms = parseMt5Time(p.t);
    if (ms == null || p.b == null) continue;
    const day = Math.floor(ms / 86400000) * 86400000;
    byDay.set(day, { x: day, y: Number(p.b), t: p.t });
  }
  return Array.from(byDay.values()).sort((a, b) => a.x - b.x);
}

function yearTickValues(minMs, maxMs) {
  const ticks = [];
  let y = new Date(minMs).getUTCFullYear();
  const endY = new Date(maxMs).getUTCFullYear();
  // Always include start of each calendar year in range
  for (; y <= endY; y++) {
    const jan1 = Date.UTC(y, 0, 1);
    if (jan1 >= minMs && jan1 <= maxMs) ticks.push(jan1);
  }
  if (!ticks.length || ticks[0] > minMs) ticks.unshift(minMs);
  if (ticks[ticks.length - 1] < maxMs) ticks.push(maxMs);
  return ticks;
}

function parseMt5Time(t) {
  const m = String(t).match(
    /^(\d{4})\.(\d{2})\.(\d{2})(?:\s+(\d{2}):(\d{2})(?::(\d{2}))?)?/
  );
  if (!m) return null;
  return Date.UTC(
    Number(m[1]),
    Number(m[2]) - 1,
    Number(m[3]),
    Number(m[4] || 0),
    Number(m[5] || 0),
    Number(m[6] || 0)
  );
}

function formatChartDay(ms) {
  const d = new Date(ms);
  const y = d.getUTCFullYear();
  const mo = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return y + "-" + mo + "-" + day;
}

/** One point per UTC day (last balance that day), timed on real calendar axis. */
function toTimeSeries(points) {
  const byDay = new Map();
  for (const p of points) {
    const ms = parseMt5Time(p.t);
    if (ms == null || p.b == null) continue;
    const day = Math.floor(ms / 86400000) * 86400000;
    byDay.set(day, { x: day, y: Number(p.b), t: p.t });
  }
  return Array.from(byDay.values()).sort((a, b) => a.x - b.x);
}

function yearTickValues(minMs, maxMs) {
  const ticks = [];
  let y = new Date(minMs).getUTCFullYear();
  const endY = new Date(maxMs).getUTCFullYear();
  for (; y <= endY; y++) {
    const jan1 = Date.UTC(y, 0, 1);
    if (jan1 >= minMs && jan1 <= maxMs) ticks.push(jan1);
  }
  if (!ticks.length || ticks[0] > minMs) ticks.unshift(minMs);
  if (ticks[ticks.length - 1] < maxMs) ticks.push(maxMs);
  return ticks;
}

function renderChart(points) {
  const ctx = document.getElementById("chart-balance");
  if (!ctx || typeof Chart === "undefined") return;

  const series = toTimeSeries(points);
  if (!series.length) {
    if (equityChart) equityChart.destroy();
    equityChart = null;
    return;
  }

  const minX = series[0].x;
  const maxX = series[series.length - 1].x;
  const minY = Math.min(...series.map((p) => p.y));
  const maxY = Math.max(...series.map((p) => p.y));
  const useLog = minY > 0 && maxY / minY >= 40;

  if (equityChart) equityChart.destroy();
  equityChart = new Chart(ctx, {
    type: "line",
    data: {
      datasets: [
        {
          data: series,
          borderColor: "rgba(201,162,39,0.95)",
          backgroundColor: "rgba(201,162,39,0.12)",
          borderWidth: 1.75,
          pointRadius: 0,
          pointHoverRadius: 4,
          fill: true,
          tension: 0.05,
          parsing: false,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            title: (items) => {
              const raw = items[0] && items[0].raw;
              return raw ? formatChartDay(raw.x) : "";
            },
            label: (c) => money(c.parsed.y),
          },
        },
      },
      scales: {
        x: {
          type: "linear",
          min: minX,
          max: maxX,
          afterBuildTicks: (axis) => {
            axis.ticks = yearTickValues(minX, maxX).map((v) => ({ value: v }));
          },
          ticks: {
            color: "#a8987c",
            autoSkip: false,
            maxRotation: 0,
            callback: (v) => {
              const d = new Date(v);
              if (d.getUTCMonth() === 0 && d.getUTCDate() === 1) {
                return String(d.getUTCFullYear());
              }
              return formatChartDay(v).slice(0, 7);
            },
          },
          grid: { color: "rgba(232,210,160,0.10)" },
        },
        y: {
          type: useLog ? "logarithmic" : "linear",
          ticks: {
            color: "#a8987c",
            callback: (v) => {
              const n = Number(v);
              if (!Number.isFinite(n)) return "";
              return (
                "$" +
                n.toLocaleString("en-US", {
                  maximumFractionDigits: n >= 1000 ? 0 : 2,
                })
              );
            },
          },
          grid: { color: "rgba(232,210,160,0.08)" },
        },
      },
    },
  });

  const note = document.getElementById("chart-note");
  if (note) {
    note.textContent = useLog
      ? "X = calendar time (even years). Y = log scale so early balance moves stay visible."
      : "X = calendar time (even years), not trade count.";
  }
}
const MONTH_COLS = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
];

function renderCalendar() {
  const label = document.getElementById("cal-label");
  const grid = document.getElementById("cal-grid");
  const prev = document.getElementById("cal-prev");
  const next = document.getElementById("cal-next");
  const current = monthKey(months[monthIdx]);

  if (label) label.textContent = current || "\u2014";
  if (prev) prev.disabled = monthIdx <= 0;
  if (next) next.disabled = monthIdx >= months.length - 1;

  if (!grid) return;
  if (!months.length) {
    grid.innerHTML = "";
    return;
  }

  const byId = new Map();
  months.forEach((m, i) => byId.set(monthKey(m), { m, i }));

  const years = [];
  const seen = new Set();
  months.forEach((m) => {
    const y = Number(monthKey(m).slice(0, 4));
    if (!Number.isFinite(y) || seen.has(y)) return;
    seen.add(y);
    years.push(y);
  });
  years.sort((a, b) => a - b);

  const parts = ['<div class="cal-corner" aria-hidden="true"></div>'];
  MONTH_COLS.forEach((name) => {
    parts.push('<div class="cal-hd">' + name + "</div>");
  });

  years.forEach((year) => {
    parts.push('<div class="cal-year">' + year + "</div>");
    for (let mo = 1; mo <= 12; mo++) {
      const id = year + "-" + String(mo).padStart(2, "0");
      const hit = byId.get(id);
      if (!hit) {
        parts.push('<div class="cal-cell ghost" aria-hidden="true"></div>');
        continue;
      }
      const { m, i } = hit;
      const net = monthNet(m);
      const active = i === monthIdx ? " active" : "";
      let tone = " empty";
      if (net != null) {
        if (net > 0) tone = " profit";
        else if (net < 0) tone = " loss";
        else tone = " flat";
      }
      const totalHtml =
        net == null
          ? ""
          : '<span class="cal-total">' + moneyShort(net) + "</span>";
      const countHtml =
        m && typeof m.trades === "number"
          ? '<span class="cal-count">' +
            m.trades +
            (m.trades === 1 ? " trade" : " trades") +
            "</span>"
          : "";
      const emptyCls = m && m.trades === 0 ? " empty" : " has";
      parts.push(
        '<button type="button" class="cal-cell' +
          emptyCls +
          tone +
          active +
          '" data-month-idx="' +
          i +
          '" title="' +
          id +
          '">' +
          totalHtml +
          countHtml +
          "</button>"
      );
    }
  });

  grid.innerHTML = parts.join("");
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


function openHistoryModal() {
  const modal = document.getElementById("history-modal");
  if (!modal) return;
  const title = document.getElementById("history-modal-title");
  if (title) {
    title.textContent =
      "Trade history \u00b7 " + (monthKey(months[monthIdx]) || standId);
  }
  modal.hidden = false;
  modal.setAttribute("aria-hidden", "false");
  document.body.classList.add("modal-open");
}

function closeHistoryModal() {
  const modal = document.getElementById("history-modal");
  if (!modal) return;
  modal.hidden = true;
  modal.setAttribute("aria-hidden", "true");
  document.body.classList.remove("modal-open");
}
async function setStand(id) {
  standId = id || "mtf_200";
  months = await loadMonths(stand());
  monthIdx = Math.max(0, months.length - 1);
  page = 0;
  selectedTradeId = null;
  renderOverview();
  const points = await loadEquity(stand());
  renderChart(points);
  await setMonthByIndex(monthIdx);
}

async function setMonthByIndex(i, openModal) {
  if (!months.length) {
    monthTrades = [];
    renderCalendar();
    renderTradeList();
    renderTradeDetail(null);
    closeHistoryModal();
    return;
  }
  monthIdx = Math.max(0, Math.min(i, months.length - 1));
  page = 0;
  selectedTradeId = null;
  monthTrades = await loadMonthTrades(stand(), months[monthIdx]);
  renderCalendar();
  renderTradeList();
  renderTradeDetail(null);
  if (openModal) openHistoryModal();
  else {
    const title = document.getElementById("history-modal-title");
    if (title) {
      title.textContent =
        "Trade history \u00b7 " + (monthKey(months[monthIdx]) || standId);
    }
  }
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
    setMonthByIndex(Number(btn.dataset.monthIdx), true);
  });

  document.getElementById("history-modal")?.addEventListener("click", (e) => {
    if (e.target.closest("[data-close-modal]")) closeHistoryModal();
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") closeHistoryModal();
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
  standId = DATA.defaultStand || "mtf_200";
  wireEvents();
  await setStand(standId);
}

boot().catch((e) => {
  document.body.insertAdjacentHTML(
    "afterbegin",
    '<p style="padding:2rem;color:#d86b5c">Failed to load data: ' + e + "</p>"
  );
});