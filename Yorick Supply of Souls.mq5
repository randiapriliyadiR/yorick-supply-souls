//+------------------------------------------------------------------+
//|                                      Yorick Supply of Souls.mq5  |
//|                                                 Randi Apriliyadi |
//|        https://github.com/randiapriliyadiR/yorick-supply-souls |
//+------------------------------------------------------------------+
//| Gather the flock. Mark the graves. Let the souls return.         |
//+------------------------------------------------------------------+
#property copyright "Randi Apriliyadi"
#property link      "https://github.com/randiapriliyadiR/yorick-supply-souls"
#property version   "1.11"
#property strict
#property description "Yorick Supply of Souls — gold shepherd, light chart load + tester path"

// Bundle overlays from this project folder (no MQL5/Indicators copy required).
#resource "Indicators\\Yorick Structure.ex5"
#resource "Indicators\\Yorick FVG.ex5"
#resource "Indicators\\Yorick Zones.ex5"

#include "Include/YorickSoS/Types.mqh"
#include "Include/YorickSoS/Risk.mqh"
#include "Include/YorickSoS/Orders.mqh"
#include "Include/YorickSoS/Engine.mqh"
#include "Include/YorickSoS/ChartView.mqh"
#include "Include/YorickSoS/Panel.mqh"

input group "=== Flock ==="
input string           InpSymbol          = "XAUUSD";   // Grave market filter (substring ok)
input ENUM_TIMEFRAMES  InpTF              = PERIOD_M5;  // Chart / tick clock
input ENUM_TIMEFRAMES  InpTrendTF         = PERIOD_H4;  // Major trend (video 2 gate)
input string           InpZoneTFs         = "M5,M15"; // Entry zone TFs (comma-separated, max 4)
input bool             InpOnePosPerTf     = false;    // true=1 pos per entry TF; false=1 pos global
input double           InpRiskPct         = 0.5;        // Fixed soul budget when quality mode OFF
input ENUM_YSS_QMODE   InpQualityMode     = YSS_QMODE_OFF; // OFF | A soft FVG/BOS | C extras
input double           InpRiskMinPct      = 0.5;        // Score 0 → this % (quality mode)
input double           InpRiskMaxPct      = 2.0;        // Score max → this % (quality mode)
input ulong            InpMagic           = 26082603;   // Identity stamp
input ulong            InpDeviation       = 50;         // Slippage allowance (points)
input int              InpMaxSpreadPoints = 0;          // Max fog / spread (0 = off)

input group "=== Souls ==="
input int    InpAtrPeriod       = 14;       // Breath period
input double InpImpulseAtrMult  = 1.25;     // Surge length (ATR)
input double InpBodyAtrMult     = 0.65;     // Surge body (ATR)
input int    InpSwingStrength   = 3;        // Structure bars
input int    InpLookback        = 200;      // Grave scan depth (bars)
input int    InpMaxImpulseBars  = 15;       // Max surge bars
input bool   InpRequireBos      = true;     // Structure gate (hard when quality risk OFF)
input bool   InpRequireFvg      = true;     // Gap gate (hard when quality risk OFF)
input bool   InpRequireSlow     = true;     // Gentle return gate
input double InpSlowMaxAtr      = 0.7;      // Gentle: max bar breath (Pro-tuned)
input double InpSharpAtr        = 1.2;      // Sharp: reject bar breath
input int    InpMinApproachBars = 2;        // Min return bars
input double InpSlZoneMult      = 2.0;      // Grave buffer (× zone depth; 2.0 tuned on real ticks)

input group "=== Structure filters (video 2) ==="
input bool   InpRequireTrend    = true;     // Demand in uptrend, supply in downtrend
input bool   InpTrendOnZoneTf   = false;    // true=HH/HL on entry TF; false=use Trend TF (H4)
input bool   InpRequireMinRr     = false;    // Skip if reward/risk too low (OFF = usable frequency)
input double InpMinRiskReward   = 2.5;      // Minimum TP distance vs SL (R)
input bool   InpUseAtrRegime    = true;     // Skip if trend-TF ATR >> its mean
input int    InpAtrRegimeBars   = 50;       // ATR mean lookback (closed bars)
input double InpAtrRegimeMult   = 1.5;      // Skip when ATR > mult × mean

input group "=== Grave Guard ==="
input bool   InpUseGuard        = true;     // BEP + trail (lock soul after touch)
input double InpBeTriggerR      = 0.5;      // Move SL to BEP after this many R
input double InpTrailStartR     = 0.5;      // Start trail after this many R
input double InpTrailDistR      = 0.5;      // Trail distance (R behind best)

input group "=== Debug (commission sim) ==="
input bool   InpSimCommission      = false; // Strategy Tester only (ignored live)
input double InpCommissionPerLot   = 3.5;   // USD per lot per side (Exness Raw ≈ 3.5)

bool YssSymbolAllowed(void)
  {
   if(InpSymbol == "")
      return true;
   return (StringFind(_Symbol, InpSymbol) >= 0);
  }

bool YssNewBar(void)
  {
   const datetime t = iTime(_Symbol, g_yss_cfg.tf, 0);
   if(t == 0)
      return false;
   if(t == g_yss_lastBar)
      return false;
   g_yss_lastBar = t;
   return true;
  }

void YssRelease(void)
  {
   YssReleaseZoneAtr();
   if(g_hStruct != INVALID_HANDLE)
      IndicatorRelease(g_hStruct);
   if(g_hFvg != INVALID_HANDLE)
      IndicatorRelease(g_hFvg);
   if(g_hZones != INVALID_HANDLE)
      IndicatorRelease(g_hZones);
   g_hStruct = INVALID_HANDLE;
   g_hFvg = INVALID_HANDLE;
   g_hZones = INVALID_HANDLE;
  }

int OnInit()
  {
   if(!YssSymbolAllowed())
     {
      Print("YSS: symbol mismatch, chart=", _Symbol, " expected=", InpSymbol);
      return(INIT_FAILED);
     }
   if(StringLen(InpZoneTFs) <= 0)
      return(INIT_PARAMETERS_INCORRECT);
   if(InpRiskPct <= 0.0 || InpRiskMinPct <= 0.0 || InpRiskMaxPct < InpRiskMinPct ||
      InpAtrPeriod < 1 || InpImpulseAtrMult <= 0.0 ||
      InpBodyAtrMult <= 0.0 || InpSwingStrength < 1 || InpLookback < 30 ||
      InpMaxImpulseBars < 2 || InpSlZoneMult < 1.0 || InpMinApproachBars < 1 ||
      InpBeTriggerR <= 0.0 || InpTrailStartR <= 0.0 || InpTrailDistR <= 0.0 ||
      InpMinRiskReward <= 0.0 || InpCommissionPerLot < 0.0 ||
      InpAtrRegimeBars < 5 || InpAtrRegimeMult <= 1.0)
      return(INIT_PARAMETERS_INCORRECT);

   g_yss_cfg.symbol          = _Symbol;
   g_yss_cfg.tf              = YssResolveTf(InpTF);
   g_yss_cfg.trendTf         = YssResolveTf(InpTrendTF);
   g_yss_cfg.riskPct         = InpRiskPct;
   g_yss_cfg.riskMinPct      = InpRiskMinPct;
   g_yss_cfg.riskMaxPct      = InpRiskMaxPct;
   g_yss_cfg.qualityMode     = InpQualityMode;
   g_yss_cfg.magic           = InpMagic;
   g_yss_cfg.deviation       = InpDeviation;
   g_yss_cfg.maxSpreadPoints = InpMaxSpreadPoints;
   g_yss_cfg.atrPeriod       = InpAtrPeriod;
   g_yss_cfg.impulseAtrMult  = InpImpulseAtrMult;
   g_yss_cfg.bodyAtrMult     = InpBodyAtrMult;
   g_yss_cfg.swingStrength   = InpSwingStrength;
   g_yss_cfg.lookback        = InpLookback;
   g_yss_cfg.maxImpulseBars  = InpMaxImpulseBars;
   g_yss_cfg.requireBos      = InpRequireBos;
   g_yss_cfg.requireFvg      = InpRequireFvg;
   g_yss_cfg.requireSlow     = InpRequireSlow;
   g_yss_cfg.slowMaxAtr      = InpSlowMaxAtr;
   g_yss_cfg.sharpAtr        = InpSharpAtr;
   g_yss_cfg.minApproachBars = InpMinApproachBars;
   g_yss_cfg.slZoneMult      = InpSlZoneMult;
   g_yss_cfg.requireTrend    = InpRequireTrend;
   g_yss_cfg.trendOnZoneTf   = InpTrendOnZoneTf;
   g_yss_cfg.requireMinRr    = InpRequireMinRr;
   g_yss_cfg.minRiskReward   = InpMinRiskReward;
   g_yss_cfg.useAtrRegime    = InpUseAtrRegime;
   g_yss_cfg.atrRegimeBars   = InpAtrRegimeBars;
   g_yss_cfg.atrRegimeMult   = InpAtrRegimeMult;
   g_yss_cfg.useGuard        = InpUseGuard;
   g_yss_cfg.beTriggerR      = InpBeTriggerR;
   g_yss_cfg.trailStartR     = InpTrailStartR;
   g_yss_cfg.trailDistR      = InpTrailDistR;
   g_yss_cfg.simCommission   = InpSimCommission;
   g_yss_cfg.commissionPerLot = InpCommissionPerLot;
   g_yss_cfg.onePosPerTf     = InpOnePosPerTf;

   YssZonesResetAll();
   g_yss_needScan = true;
   g_yss_atrNow = 0.0;
   g_yss_posTicket = 0;
   g_yss_inTrade = false;
   g_yss_openCount = 0;
   g_yss_uiReady = false;
   g_yss_uiPhase = 0;
   g_yss_commissionPaid = 0.0;
   YssGuardReset();
   ZeroMemory(g_yss_view);
   g_yss_view.reason = "idle";

   g_yss_lastBar = 0;

   if(!YssInitZoneTfsFromString(InpZoneTFs, InpAtrPeriod))
     {
      Print("YSS: zone TF init failed (InpZoneTFs='", InpZoneTFs, "', max ", YSS_MAX_ZONE_TFS, ")");
      YssRelease();
      return(INIT_FAILED);
     }

   if(g_hAtrTrend != INVALID_HANDLE)
     {
      IndicatorRelease(g_hAtrTrend);
      g_hAtrTrend = INVALID_HANDLE;
     }
   g_hAtrTrend = iATR(g_yss_cfg.symbol, g_yss_cfg.trendTf, g_yss_cfg.atrPeriod);
   if(g_hAtrTrend == INVALID_HANDLE)
     {
      Print("YSS: trend ATR handle failed tf=", EnumToString(g_yss_cfg.trendTf));
      YssRelease();
      return(INIT_FAILED);
     }

   if(InpUseAtrRegime)
      Print("YSS: ATR regime ON — skip if ", YssTfText(g_yss_cfg.trendTf),
            " ATR > ", DoubleToString(InpAtrRegimeMult, 2), "× mean(",
            IntegerToString(InpAtrRegimeBars), ")");

   if(InpOnePosPerTf)
     {
      const long mm = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
      if(mm != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && mm != ACCOUNT_MARGIN_MODE_EXCHANGE)
         Print("YSS: OnePosPerTf needs hedging account; netting will merge same-symbol positions");
      Print("YSS: position mode = 1 per entry TF (", YssZoneTfsText(), ")");
     }
   else
      Print("YSS: position mode = 1 global for all entry TFs");

   if(InpQualityMode == YSS_QMODE_A)
      Print("YSS: quality A — soft FVG/BOS score → risk ",
            DoubleToString(InpRiskMinPct, 2), "%..", DoubleToString(InpRiskMaxPct, 2), "%");
   else if(InpQualityMode == YSS_QMODE_C)
      Print("YSS: quality C — hard FVG/BOS; impulse+pure-slow extras → risk ",
            DoubleToString(InpRiskMinPct, 2), "%..", DoubleToString(InpRiskMaxPct, 2), "%");
   else
      Print("YSS: fixed risk ", DoubleToString(InpRiskPct, 2), "% (FVG/BOS hard gates)");

   if(YssCommissionActive())
      Print("YSS: tester commission sim ON — $",
            DoubleToString(InpCommissionPerLot, 2), "/lot/side (round-trip baked into SL/TP)");
   else if(InpSimCommission && InpCommissionPerLot > 0.0)
      Print("YSS: commission sim skipped (live chart — broker already charges)");

   YssOrdersInit(InpMagic, InpDeviation);

   if(YssShowUi())
      EventSetMillisecondTimer(1);
   return(INIT_SUCCEEDED);
  }

void YssCreateOverlays(void)
  {
   if(!YssShowUi())
      return;
   if(g_hStruct == INVALID_HANDLE)
      g_hStruct = iCustom(_Symbol, g_yss_cfg.tf, "::Indicators\\Yorick Structure",
                          InpSwingStrength, InpLookback);
   if(g_hFvg == INVALID_HANDLE)
      g_hFvg = iCustom(_Symbol, g_yss_cfg.tf, "::Indicators\\Yorick FVG", InpLookback);
   if(g_hZones == INVALID_HANDLE)
      g_hZones = iCustom(_Symbol, g_yss_cfg.tf, "::Indicators\\Yorick Zones",
                         InpAtrPeriod, InpImpulseAtrMult, InpBodyAtrMult,
                         InpSwingStrength, InpLookback, InpMaxImpulseBars,
                         InpRequireBos, InpRequireFvg, InpSlZoneMult);
   if(g_hStruct == INVALID_HANDLE || g_hFvg == INVALID_HANDLE || g_hZones == INVALID_HANDLE)
      Print("YSS: overlay handle failed struct=", g_hStruct,
            " fvg=", g_hFvg, " zones=", g_hZones);
   YssChartAttach();
  }

void OnTimer()
  {
   if(!YssShowUi())
     {
      EventKillTimer();
      return;
     }
   if(g_yss_uiPhase == 0)
     {
      YssFillView(g_yss_atrNow, g_yss_inTrade, g_yss_posTicket);
      YssPanelUpdate();
      g_yss_uiPhase = 1;
      return;
     }
   EventKillTimer();
   YssCreateOverlays();
   g_yss_uiReady = true;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   YssPanelRemove();
   YssChartDetach();
   YssRelease();
  }

void OnTick()
  {
   if(!YssSymbolAllowed())
      return;

   const bool newBar = YssNewBar();
   YssEngineStep(newBar);

   if(!YssShowUi())
      return;

   static uint lastUi = 0;
   const uint now = GetTickCount();
   if(!newBar && (now - lastUi) < 250)
      return;
   lastUi = now;

   YssFillView(g_yss_atrNow, g_yss_inTrade, g_yss_posTicket);
   if(g_yss_inTrade && g_yss_posTicket != 0 && PositionSelectByTicket(g_yss_posTicket))
     {
      g_yss_view.posProfit = PositionGetDouble(POSITION_PROFIT)
                             + PositionGetDouble(POSITION_SWAP);
      g_yss_view.posSl     = PositionGetDouble(POSITION_SL);
      g_yss_view.posTp     = PositionGetDouble(POSITION_TP);
      g_yss_view.posLots   = PositionGetDouble(POSITION_VOLUME);
      g_yss_view.posDir    = YssPosDir(g_yss_posTicket);
      g_yss_view.balance   = AccountInfoDouble(ACCOUNT_BALANCE);
      g_yss_view.equity    = AccountInfoDouble(ACCOUNT_EQUITY);
     }
   YssChartLevels(g_yss_view.posSl, g_yss_view.posTp, g_yss_view.posDir);
   YssPanelUpdate();
  }
//+------------------------------------------------------------------+
