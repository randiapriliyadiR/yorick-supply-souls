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
const byId = (id) => DATA.reports.find((r) => r.id === id);

let DATA = null;
let chart = null;
let risk = 1;
let period = "M5";

function shortGuard(r) {
  if (String(r.guard) === "false") return "OFF";
  if (String(r.guard) === "n/a" || r.guard === "") return "TP only";
  if (String(r.guard) === "true") return r.be + "R trail " + r.trailDist + "R";
  return "\u2014";
}

function isBestRow(r) {
  if (period === "M5") return !!r.shipped || !!r.bestM5;
  return !!r.bestD1 || r.id === "YorickSoS_XAUUSD_D1_tuned";
}

function m5(riskN) {
  const tag = riskN === 1 ? "R1p0" : "R2p0";
  return ["off", "be05_tr05", "be075_tr075", "be1_tr1", "be15_tr1", "be2_tr1"]
    .map((p) => byId("YorickSoS_M5_200_" + tag + "_" + p))
    .filter(Boolean);
}

function d1() {
  return [
    "YorickSoS_XAUUSD_D1_tuned",
    "YorickSoS_guard_off",
    "YorickSoS_guard_be05_tr05",
    "YorickSoS_guard_be075_tr075",
    "YorickSoS_guard_be1_tr1",
    "YorickSoS_guard_be15_tr1",
    "YorickSoS_guard_be2_tr1"
  ]
    .map(byId)
    .filter(Boolean);
}

function bestStand() {
  if (period === "M5") return byId("YorickSoS_M5_200_R1p0_be05_tr05");
  return byId("YorickSoS_XAUUSD_D1_tuned");
}

function vcard(k, r, best) {
  return (
    '<div class="vcard' +
    (best ? " best" : "") +
    '"><div class="k">' +
    k +
    '</div><div class="v ' +
    (r.net >= 0 ? "up" : "down") +
    '">' +
    money(r.net) +
    '</div><div class="s">PF ' +
    Number(r.profitFactor).toFixed(2) +
    " \u00b7 DD " +
    pct(r.equityDdPct) +
    "</div></div>"
  );
}

function renderVerdict() {
  const deck = document.getElementById("verdict-deck");
  const grid = document.getElementById("verdict-grid");

  if (period === "M5") {
    deck.innerHTML =
      "On the hard M5 / $200 sample, <strong>Grave Guard at 0.5R</strong> beat TP-only on net, profit factor, and drawdown. Slower guards (1R+) were worse. Defaults ship M5 + Guard ON.";
    const off1 = byId("YorickSoS_M5_200_R1p0_off");
    const on1 = byId("YorickSoS_M5_200_R1p0_be05_tr05");
    const off2 = byId("YorickSoS_M5_200_R2p0_off");
    const on2 = byId("YorickSoS_M5_200_R2p0_be05_tr05");
    grid.innerHTML =
      vcard("Without guard \u00b7 1%", off1, false) +
      vcard("Best \u00b7 Guard 0.5R \u00b7 1%", on1, true) +
      vcard("Without guard \u00b7 2%", off2, false) +
      vcard("Best \u00b7 Guard 0.5R \u00b7 2%", on2, true);
    return;
  }

  deck.innerHTML =
    "On D1 / $100k, <strong>TP-only</strong> is the best lab stand. Grave Guard that helped M5 cut D1 winners \u2014 OFF beats 0.5R; tighter trails were worse.";
  const tuned = byId("YorickSoS_XAUUSD_D1_tuned");
  const off = byId("YorickSoS_guard_off");
  const g05 = byId("YorickSoS_guard_be05_tr05");
  const g2 = byId("YorickSoS_guard_be2_tr1");
  grid.innerHTML =
    vcard("Best \u00b7 TP only", tuned, true) +
    vcard("Guard OFF", off, false) +
    vcard("Guard 0.5R (M5 recipe)", g05, false) +
    vcard("Guard 2R", g2, false);
}

function renderShipped() {
  const s = bestStand();
  const title = document.getElementById("shipped-title");
  const note = document.getElementById("shipped-note");

  if (period === "M5") {
    title.textContent = "Best stand \u00b7 M5 shipped";
    note.textContent =
      "Ending balance below is deposit + net on this sample. 2% M5 nets compound aggressively \u2014 use them to rank presets, not as a live forecast.";
  } else {
    title.textContent = "Best stand \u00b7 D1 lab";
    note.textContent =
      "EA defaults still ship M5 + Guard ON. This D1 TP-only row is the strongest daily sample in the ledger \u2014 not the live default.";
  }

  document.getElementById("shipped-meta").textContent =
    s.symbol +
    " " +
    s.period +
    " \u00b7 deposit $" +
    s.deposit.toLocaleString("en-US") +
    " \u00b7 risk " +
    s.risk +
    "% \u00b7 " +
    DATA.range +
    " \u00b7 " +
    DATA.model +
    " \u00b7 " +
    DATA.broker;

  const end = s.deposit + s.net;
  document.getElementById("shipped-stats").innerHTML = [
    ["Net profit", money(s.net), s.net >= 0 ? "up" : "down"],
    ["Ending balance", "$" + end.toLocaleString("en-US", { maximumFractionDigits: 0 }), "up"],
    ["Profit factor", Number(s.profitFactor).toFixed(2), ""],
    ["Equity drawdown", pct(s.equityDdPct), "down"],
    ["Trades", Number(s.trades).toLocaleString("en-US"), ""],
    [
      "Win rate",
      (s.winRate || "").replace(/^\d+\s*\(/, "").replace(/\)$/, "") || "\u2014",
      ""
    ]
  ]
    .map(
      (row) =>
        "<div><dt>" +
        row[0] +
        '</dt><dd class="' +
        row[2] +
        '">' +
        row[1] +
        "</dd></div>"
    )
    .join("");
}

function renderGuard() {
  const riskSeg = document.getElementById("risk-seg");
  const deck = document.getElementById("guard-deck");
  const rows = period === "M5" ? m5(risk) : d1();

  if (period === "M5") {
    riskSeg.hidden = false;
    deck.textContent =
      "Same soul inputs on XAUUSD M5, deposit $200. Switch risk to see how BEP / trail distance changes the march.";
  } else {
    riskSeg.hidden = true;
    deck.textContent =
      "Same soul inputs on XAUUSD D1, deposit $100k, risk 2%. TP-only leads; the M5 Guard 0.5R recipe is weaker here.";
  }

  const ctx = document.getElementById("chart-guard");
  if (chart) chart.destroy();
  chart = new Chart(ctx, {
    type: "bar",
    data: {
      labels: rows.map((r) => {
        if (String(r.guard) === "false") return "OFF";
        if (String(r.guard) === "n/a" || !r.be) return "TP";
        return r.be + "R";
      }),
      datasets: [
        {
          data: rows.map((r) => r.net),
          backgroundColor: rows.map((r) =>
            isBestRow(r) ? "rgba(201,162,39,0.9)" : "rgba(111,191,138,0.55)"
          ),
          borderWidth: 0
        }
      ]
    },
    options: {
      responsive: true,
      plugins: {
        legend: { display: false },
        tooltip: { callbacks: { label: (c) => money(c.raw) } }
      },
      scales: {
        x: { ticks: { color: "#a8987c" }, grid: { display: false } },
        y: {
          ticks: {
            color: "#a8987c",
            callback: (v) => "$" + Number(v).toLocaleString("en-US")
          },
          grid: { color: "rgba(232,210,160,0.08)" }
        }
      }
    }
  });

  document.getElementById("guard-body").innerHTML = rows
    .map(
      (r) =>
        '<tr class="' +
        (isBestRow(r) ? "shipped" : "") +
        '"><td>' +
        shortGuard(r) +
        '</td><td class="' +
        (r.net >= 0 ? "up" : "down") +
        '">' +
        money(r.net) +
        "</td><td>" +
        Number(r.profitFactor).toFixed(2) +
        "</td><td>" +
        pct(r.equityDdPct) +
        "</td><td>" +
        Number(r.trades).toLocaleString("en-US") +
        "</td></tr>"
    )
    .join("");
}

function renderLedger() {
  const q = (document.getElementById("q").value || "").toLowerCase();
  document.getElementById("ledger-deck").textContent =
    "Stands for " + period + " currently published with this page.";
  const rows = DATA.reports.filter(
    (r) =>
      r.period === period &&
      (!q || (r.label + " " + r.id).toLowerCase().includes(q))
  );
  document.getElementById("ledger-body").innerHTML = rows
    .map(
      (r) =>
        '<tr class="' +
        (isBestRow(r) ? "shipped" : "") +
        '"><td>' +
        r.label +
        "</td><td>" +
        r.period +
        "</td><td>$" +
        Number(r.deposit).toLocaleString("en-US") +
        "</td><td>" +
        r.risk +
        "%</td><td>" +
        shortGuard(r) +
        '</td><td class="' +
        (r.net >= 0 ? "up" : "down") +
        '">' +
        money(r.net) +
        "</td><td>" +
        Number(r.profitFactor).toFixed(2) +
        "</td><td>" +
        pct(r.equityDdPct) +
        "</td><td>" +
        Number(r.trades).toLocaleString("en-US") +
        "</td></tr>"
    )
    .join("");
}

function renderAll() {
  renderVerdict();
  renderShipped();
  renderGuard();
  renderLedger();
}

async function boot() {
  DATA = await (await fetch("./data/reports.json")).json();
  document.getElementById("ver").textContent = DATA.version;
  period = DATA.defaultPeriod || "M5";

  document.querySelectorAll("#tf-seg .seg-btn").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.tf === period);
    btn.addEventListener("click", () => {
      document.querySelectorAll("#tf-seg .seg-btn").forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      period = btn.dataset.tf;
      renderAll();
    });
  });

  document.querySelectorAll("#risk-seg .seg-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll("#risk-seg .seg-btn").forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      risk = Number(btn.dataset.risk);
      renderGuard();
    });
  });

  document.getElementById("q").addEventListener("input", renderLedger);
  renderAll();
}

boot().catch((e) => {
  document.body.innerHTML =
    "<pre style='padding:2rem;color:#d86b5c'>Failed to load data\\n" + e + "</pre>";
});