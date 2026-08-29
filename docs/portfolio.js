/** Shared-wallet portfolio merge (rescale B). */
(function (global) {
  function round2(n) {
    return Math.round(n * 100) / 100;
  }

  function monthIdFromClose(closeTime) {
    const m = String(closeTime || "").match(/^(\d{4})\.(\d{2})/);
    return m ? m[1] + "-" + m[2] : "unknown";
  }

  /**
   * @param {number} deposit
   * @param {Array<{legId:string,id:*,closeTime:string,profit:number,balance:number}>} trades
   */
  function mergeLegs(deposit, trades) {
    const byLeg = new Map();
    for (const t of trades) {
      if (!byLeg.has(t.legId)) byLeg.set(t.legId, []);
      byLeg.get(t.legId).push(t);
    }
    for (const [, list] of byLeg) {
      list.sort((a, b) => {
        const c = String(a.closeTime).localeCompare(String(b.closeTime));
        if (c !== 0) return c;
        return String(a.id).localeCompare(String(b.id), undefined, { numeric: true });
      });
    }

    const soloBefore = new Map();
    for (const [legId, list] of byLeg) {
      let prev = deposit;
      for (const t of list) {
        const key = legId + "|" + t.closeTime + "|" + t.id;
        soloBefore.set(key, prev);
        // Reconstruct from PnL so scale≡1 on a single leg even if file balances drift
        prev = Math.round((prev + Number(t.profit)) * 100) / 100;
      }
    }

    const ordered = trades.slice().sort((a, b) => {
      const c = String(a.closeTime).localeCompare(String(b.closeTime));
      if (c !== 0) return c;
      const l = String(a.legId).localeCompare(String(b.legId));
      if (l !== 0) return l;
      return String(a.id).localeCompare(String(b.id), undefined, { numeric: true });
    });

    let shared = deposit;
    let peak = deposit;
    let maxDdMoney = 0;
    let maxDdPct = 0;
    let grossWin = 0;
    let grossLoss = 0;
    let wins = 0;
    const merged = [];
    const equity = [];
    const monthNet = new Map();
    const monthCounts = new Map();
    let bestWin = null;
    let worstLoss = null;
    let dailyWorst = null;
    const dayPnl = new Map();

    for (const t of ordered) {
      const key = t.legId + "|" + t.closeTime + "|" + t.id;
      const before = soloBefore.get(key);
      const scale = before > 0 ? shared / before : 1;
      const pnl = round2(Number(t.profit) * scale);
      shared = round2(shared + pnl);
      if (shared > peak) peak = shared;
      const dd = peak - shared;
      if (dd > maxDdMoney) {
        maxDdMoney = dd;
        maxDdPct = peak > 0 ? (100 * dd) / peak : 0;
      }
      if (pnl > 0) {
        grossWin += pnl;
        wins += 1;
      } else if (pnl < 0) {
        grossLoss += -pnl;
      }

      const ym = monthIdFromClose(t.closeTime);
      monthNet.set(ym, round2((monthNet.get(ym) || 0) + pnl));
      monthCounts.set(ym, (monthCounts.get(ym) || 0) + 1);

      const day = String(t.closeTime || "").slice(0, 10);
      dayPnl.set(day, round2((dayPnl.get(day) || 0) + pnl));

      const row = Object.assign({}, t, {
        profit: pnl,
        balance: shared,
        scale: Math.round(scale * 1e6) / 1e6,
        soloProfit: Number(t.profit),
      });
      merged.push(row);
      equity.push({ t: t.closeTime, b: shared });
      if (!bestWin || pnl > bestWin.profit) bestWin = row;
      if (!worstLoss || pnl < worstLoss.profit) worstLoss = row;
    }

    for (const [day, net] of dayPnl) {
      if (net >= 0) continue;
      if (!dailyWorst || net < dailyWorst.net) dailyWorst = { day: day, net: net };
    }

    const n = merged.length;
    const pf =
      grossLoss > 0 ? round2(grossWin / grossLoss) : grossWin > 0 ? 999 : 0;
    const wr = n > 0 ? Math.round((10000 * wins) / n) / 100 : 0;
    const net = round2(shared - deposit);
    const months = [];
    for (const [id, netM] of [...monthNet.entries()].sort()) {
      months.push({ id: id, net: netM, trades: monthCounts.get(id) || 0 });
    }

    return {
      deposit: deposit,
      net: net,
      returnPct: deposit > 0 ? Math.round((1000 * net) / deposit) / 10 : 0,
      profitFactor: pf,
      equityDdMoney: round2(maxDdMoney),
      equityDdPct: round2(maxDdPct),
      trades: n,
      wins: wins,
      winRate: wins + " (" + wr + "%)",
      ending: shared,
      equityPoints: equity,
      months: months,
      tradesList: merged,
      bestWin: bestWin,
      worstLoss: worstLoss,
      dailyDdMoney: dailyWorst ? Math.abs(dailyWorst.net) : 0,
      dailyDdPct:
        dailyWorst && peak > 0
          ? round2((100 * Math.abs(dailyWorst.net)) / peak)
          : 0,
    };
  }

  global.YssPortfolio = { mergeLegs: mergeLegs, monthIdFromClose: monthIdFromClose };
})(typeof window !== "undefined" ? window : globalThis);
