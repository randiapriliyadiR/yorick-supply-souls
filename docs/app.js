const money = (n) => {
  if (n == null || Number.isNaN(n)) return "—";
  const abs = Math.abs(n);
  const opts = abs >= 1000 ? { maximumFractionDigits: 0 } : { maximumFractionDigits: 2 };
  const s = Math.abs(n).toLocaleString("en-US", opts);
  if (n > 0) return "+$" + s;
  if (n < 0) return "-$" + s;
  return "$" + s;
};
const pct = (n) => (n == null ? "—" : n.toFixed(1) + "%");
const byId = (id) => DATA.reports.find((r) => r.id === id);

let DATA = null;
let chart = null;
let risk = 1;

function shortGuard(r) {
  if (String(r.guard) === "false") return "OFF";
  if (String(r.guard) === "true") return r.be + "R trail " + r.trailDist + "R";
  return "—";
}

function m5(riskN) {
  const tag = riskN === 1 ? "R1p0" : "R2p0";
  return ["off", "be05_tr05", "be075_tr075", "be1_tr1", "be15_tr1", "be2_tr1"]
    .map((p) => byId("YorickSoS_M5_200_" + tag + "_" + p))
    .filter(Boolean);
}

async function boot() {
  DATA = await (await fetch("./data/reports.json")).json();
  document.getElementById("ver").textContent = DATA.version;

  const off1 = byId("YorickSoS_M5_200_R1p0_off");
  const on1 = byId("YorickSoS_M5_200_R1p0_be05_tr05");
  document.getElementById("verdict-grid").innerHTML =
    '<div class="vcard"><div class="k">Without guard · 1%</div><div class="v ' + (off1.net >= 0 ? "up" : "down") + '">' + money(off1.net) + '</div><div class="s">PF ' + off1.profitFactor.toFixed(2) + " · DD " + pct(off1.equityDdPct) + "</div></div>" +
    '<div class="vcard best"><div class="k">Shipped guard 0.5R · 1%</div><div class="v ' + (on1.net >= 0 ? "up" : "down") + '">' + money(on1.net) + '</div><div class="s">PF ' + on1.profitFactor.toFixed(2) + " · DD " + pct(on1.equityDdPct) + "</div></div>" +
    '<div class="vcard"><div class="k">Without guard · 2%</div><div class="v up">' + money(byId("YorickSoS_M5_200_R2p0_off").net) + '</div><div class="s">PF 1.10 · DD 33.1%</div></div>' +
    '<div class="vcard best"><div class="k">Shipped guard 0.5R · 2%</div><div class="v up">' + money(byId("YorickSoS_M5_200_R2p0_be05_tr05").net) + '</div><div class="s">PF 1.34 · DD 19.2%</div></div>';

  const s = on1;
  document.getElementById("shipped-meta").textContent =
    s.symbol + " " + s.period + " · deposit $" + s.deposit + " · risk " + s.risk + "% · " + DATA.range + " · " + DATA.model + " · " + DATA.broker;
  const end = s.deposit + s.net;
  document.getElementById("shipped-stats").innerHTML = [
    ["Net profit", money(s.net), s.net >= 0 ? "up" : "down"],
    ["Ending balance", "$" + end.toLocaleString("en-US", { maximumFractionDigits: 0 }), "up"],
    ["Profit factor", s.profitFactor.toFixed(2), ""],
    ["Equity drawdown", pct(s.equityDdPct), "down"],
    ["Trades", s.trades.toLocaleString("en-US"), ""],
    ["Win rate", (s.winRate || "").replace(/^\d+\s*\(/, "").replace(/\)$/, "") || "—", ""]
  ].map((row) => "<div><dt>" + row[0] + '</dt><dd class="' + row[2] + '">' + row[1] + "</dd></div>").join("");

  renderGuard();
  renderLedger();

  document.querySelectorAll("#risk-seg .seg-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll("#risk-seg .seg-btn").forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      risk = Number(btn.dataset.risk);
      renderGuard();
    });
  });
  document.getElementById("q").addEventListener("input", renderLedger);
}

function renderGuard() {
  const rows = m5(risk);
  const ctx = document.getElementById("chart-guard");
  if (chart) chart.destroy();
  chart = new Chart(ctx, {
    type: "bar",
    data: {
      labels: rows.map((r) => (String(r.guard) === "false" ? "OFF" : r.be + "R")),
      datasets: [{
        data: rows.map((r) => r.net),
        backgroundColor: rows.map((r) => (r.shipped ? "rgba(201,162,39,0.9)" : "rgba(111,191,138,0.55)")),
        borderWidth: 0
      }]
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
          ticks: { color: "#a8987c", callback: (v) => "$" + Number(v).toLocaleString("en-US") },
          grid: { color: "rgba(232,210,160,0.08)" }
        }
      }
    }
  });

  document.getElementById("guard-body").innerHTML = rows.map((r) =>
    '<tr class="' + (r.shipped ? "shipped" : "") + '"><td>' + shortGuard(r) + '</td><td class="' + (r.net >= 0 ? "up" : "down") + '">' + money(r.net) + "</td><td>" + r.profitFactor.toFixed(2) + "</td><td>" + pct(r.equityDdPct) + "</td><td>" + r.trades.toLocaleString("en-US") + "</td></tr>"
  ).join("");
}

function renderLedger() {
  const q = (document.getElementById("q").value || "").toLowerCase();
  const rows = DATA.reports.filter((r) => !q || (r.label + " " + r.id).toLowerCase().includes(q));
  document.getElementById("ledger-body").innerHTML = rows.map((r) =>
    '<tr class="' + (r.shipped ? "shipped" : "") + '"><td>' + r.label + "</td><td>" + r.period + "</td><td>$" + Number(r.deposit).toLocaleString("en-US") + "</td><td>" + r.risk + "%</td><td>" + shortGuard(r) + '</td><td class="' + (r.net >= 0 ? "up" : "down") + '">' + money(r.net) + "</td><td>" + Number(r.profitFactor).toFixed(2) + "</td><td>" + pct(r.equityDdPct) + "</td><td>" + Number(r.trades).toLocaleString("en-US") + "</td></tr>"
  ).join("");
}

boot().catch((e) => {
  document.body.innerHTML = "<pre style='padding:2rem;color:#d86b5c'>Failed to load data\\n" + e + "</pre>";
});