const money = (n) => {
  if (n == null || Number.isNaN(n)) return "—";
  const abs = Math.abs(n);
  const opts = abs >= 1000 ? { maximumFractionDigits: 0 } : { maximumFractionDigits: 2 };
  const s = n.toLocaleString("en-US", opts);
  return (n > 0 ? "+$" : n < 0 ? "-$" : "$") + s.replace("-", "");
};
const pct = (n) => (n == null ? "—" : n.toFixed(1) + "%");
const byId = (id) => DATA.reports.find((r) => r.id === id);
let DATA = null;
let chart1 = null;
let chartCompare = null;
let riskFilter = 1;

async function boot() {
  const res = await fetch("./data/reports.json");
  DATA = await res.json();
  document.getElementById("side-version").textContent = "v" + DATA.version;
  document.getElementById("pill-range").textContent = DATA.range;
  const shipped = byId("YorickSoS_M5_200_R1p0_be05_tr05");
  const endBal = shipped.deposit + shipped.net;
  const hero = document.getElementById("hero-end");
  hero.textContent = money(endBal).replace("+", "");
  hero.className = "account-bal pos";
  document.getElementById("hero-meta").textContent =
    shipped.symbol + " · " + shipped.period + " · deposit $" + shipped.deposit + " · risk " + shipped.risk + "% · " + DATA.range;
  renderHeroMetrics(shipped);
  renderVs("vs-1pct", byId("YorickSoS_M5_200_R1p0_off"), byId("YorickSoS_M5_200_R1p0_be05_tr05"));
  renderVs("vs-2pct", byId("YorickSoS_M5_200_R2p0_off"), byId("YorickSoS_M5_200_R2p0_be05_tr05"));
  renderChart1pct();
  renderCompare();
  renderHistory();
  wireNav();
  wireTabs();
  document.getElementById("search").addEventListener("input", renderHistory);
}

function metricCard(label, value, sub, cls) {
  return '<div class="metric"><div class="label">' + label + '</div><div class="value ' + (cls || "") + '">' + value + '</div><div class="sub">' + (sub || "") + "</div></div>";
}

function renderHeroMetrics(r) {
  document.getElementById("hero-metrics").innerHTML = [
    metricCard("Net profit", money(r.net), "Shipped 1% + Guard 0.5R", r.net >= 0 ? "pos" : "neg"),
    metricCard("Profit factor", r.profitFactor.toFixed(2), "Higher is better", "pos"),
    metricCard("Equity DD", pct(r.equityDdPct), r.equityDd || "", "neg"),
    metricCard("Trades", r.trades.toLocaleString("en-US"), r.winRate || "")
  ].join("");
}

function renderVs(elId, off, on) {
  document.getElementById(elId).innerHTML =
    '<div class="vs-card"><div class="k">Guard OFF</div><div class="v ' + (off.net >= 0 ? "pos" : "neg") + '">' + money(off.net) + '</div><div class="s">PF ' + off.profitFactor.toFixed(2) + " · DD " + pct(off.equityDdPct) + "</div></div>" +
    '<div class="vs-card winner"><div class="k">Guard 0.5R ★</div><div class="v ' + (on.net >= 0 ? "pos" : "neg") + '">' + money(on.net) + '</div><div class="s">PF ' + on.profitFactor.toFixed(2) + " · DD " + pct(on.equityDdPct) + "</div></div>";
}

function m5Presets(risk) {
  const order = ["off", "be05_tr05", "be075_tr075", "be1_tr1", "be15_tr1", "be2_tr1"];
  const tag = risk === 1 ? "R1p0" : "R2p0";
  return order.map((p) => byId("YorickSoS_M5_200_" + tag + "_" + p)).filter(Boolean);
}

function shortGuard(r) {
  if (String(r.guard) === "false") return "OFF";
  if (String(r.guard) === "true") return r.be + "R / " + r.trailDist + "R";
  return "—";
}

function renderChart1pct() {
  const rows = m5Presets(1);
  const ctx = document.getElementById("chart-1pct");
  if (chart1) chart1.destroy();
  chart1 = new Chart(ctx, {
    type: "bar",
    data: {
      labels: rows.map((r) => shortGuard(r)),
      datasets: [{
        label: "Net profit ($)",
        data: rows.map((r) => r.net),
        backgroundColor: rows.map((r) => (r.shipped ? "rgba(212,168,75,0.85)" : "rgba(47,206,138,0.55)")),
        borderRadius: 8
      }]
    },
    options: {
      responsive: true,
      plugins: { legend: { display: false }, tooltip: { callbacks: { label: (c) => money(c.raw) } } },
      scales: {
        x: { ticks: { color: "#8b97ab" }, grid: { color: "rgba(255,255,255,0.04)" } },
        y: { ticks: { color: "#8b97ab", callback: (v) => "$" + Number(v).toLocaleString("en-US") }, grid: { color: "rgba(255,255,255,0.06)" } }
      }
    }
  });
}

function renderCompare() {
  const rows = m5Presets(riskFilter);
  document.getElementById("compare-metrics").innerHTML = [
    metricCard("Best net", money(Math.max(...rows.map((r) => r.net))), "Risk " + riskFilter + "%", "pos"),
    metricCard("Best PF", Math.max(...rows.map((r) => r.profitFactor)).toFixed(2), "Across presets", "pos"),
    metricCard("Lowest DD", pct(Math.min(...rows.map((r) => r.equityDdPct))), "Equity max", "neg"),
    metricCard("Shipped", shortGuard(rows.find((r) => r.shipped) || rows[1]), "Default Grave Guard")
  ].join("");
  const ctx = document.getElementById("chart-compare");
  if (chartCompare) chartCompare.destroy();
  chartCompare = new Chart(ctx, {
    type: "bar",
    data: {
      labels: rows.map((r) => shortGuard(r)),
      datasets: [
        { label: "Net ($)", data: rows.map((r) => r.net), backgroundColor: "rgba(212,168,75,0.75)", borderRadius: 8, yAxisID: "y" },
        { label: "Equity DD %", data: rows.map((r) => r.equityDdPct), backgroundColor: "rgba(255,92,108,0.55)", borderRadius: 8, yAxisID: "y1" }
      ]
    },
    options: {
      responsive: true,
      interaction: { mode: "index", intersect: false },
      plugins: { legend: { labels: { color: "#8b97ab" } } },
      scales: {
        x: { ticks: { color: "#8b97ab" }, grid: { display: false } },
        y: { position: "left", ticks: { color: "#d4a84b", callback: (v) => "$" + Number(v).toLocaleString("en-US") }, grid: { color: "rgba(255,255,255,0.05)" } },
        y1: { position: "right", ticks: { color: "#ff5c6c", callback: (v) => v + "%" }, grid: { drawOnChartArea: false } }
      }
    }
  });
  document.getElementById("compare-table").innerHTML = rows.map((r) =>
    '<tr class="' + (r.shipped ? "shipped" : "") + '"><td>' + r.label + "</td><td>" + shortGuard(r) + '</td><td class="' + (r.net >= 0 ? "pos" : "neg") + '">' + money(r.net) + "</td><td>" + r.profitFactor.toFixed(2) + "</td><td>" + pct(r.equityDdPct) + "</td><td>" + r.trades.toLocaleString("en-US") + "</td></tr>"
  ).join("");
}

function renderHistory() {
  const q = (document.getElementById("search").value || "").toLowerCase();
  const rows = DATA.reports.filter((r) => !q || (r.label + " " + r.id).toLowerCase().includes(q));
  document.getElementById("history-table").innerHTML = rows.map((r) =>
    '<tr class="' + (r.shipped ? "shipped" : "") + '"><td>' + r.label + "</td><td>" + r.period + "</td><td>$" + Number(r.deposit).toLocaleString("en-US") + "</td><td>" + r.risk + "%</td><td>" + shortGuard(r) + '</td><td class="' + (r.net >= 0 ? "pos" : "neg") + '">' + money(r.net) + "</td><td>" + Number(r.profitFactor).toFixed(2) + "</td><td>" + pct(r.equityDdPct) + "</td><td>" + Number(r.trades).toLocaleString("en-US") + "</td></tr>"
  ).join("");
}

function wireNav() {
  const titles = {
    overview: ["Overview", "Shipped stand · XAUUSD M5 · Grave Guard"],
    compare: ["Guard Lab", "Compare BEP / trail presets on M5 $200"],
    history: ["All Reports", "Full lab dump from Strategy Tester summaries"]
  };
  document.querySelectorAll(".nav-item").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".nav-item").forEach((b) => b.classList.remove("active"));
      document.querySelectorAll(".view").forEach((v) => v.classList.remove("active"));
      btn.classList.add("active");
      const view = btn.dataset.view;
      document.getElementById("view-" + view).classList.add("active");
      document.getElementById("page-title").textContent = titles[view][0];
      document.getElementById("page-sub").textContent = titles[view][1];
    });
  });
}

function wireTabs() {
  document.querySelectorAll("#risk-tabs .tab").forEach((tab) => {
    tab.addEventListener("click", () => {
      document.querySelectorAll("#risk-tabs .tab").forEach((t) => t.classList.remove("active"));
      tab.classList.add("active");
      riskFilter = Number(tab.dataset.risk);
      renderCompare();
    });
  });
}

boot().catch((err) => {
  document.body.innerHTML = '<pre style="color:#ff5c6c;padding:24px">Failed to load reports.json\n' + err + "</pre>";
});