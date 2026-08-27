//+------------------------------------------------------------------+
//|                                      Yorick Supply of Souls.mq5  |
//|                                                 Randi Apriliyadi |
//|        https://github.com/randiapriliyadiR/yorick-supply-souls |
//+------------------------------------------------------------------+
//| Gather the flock. Mark the graves. Let the souls return.         |
//+------------------------------------------------------------------+
#property copyright "Randi Apriliyadi"
#property link      "https://github.com/randiapriliyadiR/yorick-supply-souls"
#property version   "1.05"
#property strict
#property description "Yorick Supply of Souls — M5 gold shepherd, tuned 2% soul budget + grave guard"

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
input ENUM_TIMEFRAMES  InpTF              = PERIOD_M5;  // Shepherd timeframe
input double           InpRiskPct         = 2.0;        // Soul budget (% of balance)
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
input bool   InpRequireBos      = true;     // Structure gate
input bool   InpRequireFvg      = true;     // Gap gate
input bool   InpRequireSlow     = false;    // Gentle return gate
input double InpSlowMaxAtr      = 0.8;      // Gentle: max bar breath
input double InpSharpAtr        = 1.2;      // Sharp: reject bar breath
input int    InpMinApproachBars = 2;        // Min return bars
input double InpSlZoneMult      = 2.5;      // Grave buffer (× zone depth)

input group "=== Grave Guard ==="
input bool   InpUseGuard        = true;     // BEP + trail (lock soul after touch)
input double InpBeTriggerR      = 0.5;      // Move SL to BEP after this many R
input double InpTrailStartR     = 0.5;      // Start trail after this many R
input double InpTrailDistR      = 0.5;      // Trail distance (R behind best)

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
   if(g_hAtr != INVALID_HANDLE)
      IndicatorRelease(g_hAtr);
   if(g_hStruct != INVALID_HANDLE)
      IndicatorRelease(g_hStruct);
   if(g_hFvg != INVALID_HANDLE)
      IndicatorRelease(g_hFvg);
   if(g_hZones != INVALID_HANDLE)
      IndicatorRelease(g_hZones);
   g_hAtr = INVALID_HANDLE;
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
   if(InpRiskPct <= 0.0 || InpAtrPeriod < 1 || InpImpulseAtrMult <= 0.0 ||
      InpBodyAtrMult <= 0.0 || InpSwingStrength < 1 || InpLookback < 30 ||
      InpMaxImpulseBars < 2 || InpSlZoneMult < 1.0 || InpMinApproachBars < 1 ||
      InpBeTriggerR <= 0.0 || InpTrailStartR <= 0.0 || InpTrailDistR <= 0.0)
      return(INIT_PARAMETERS_INCORRECT);

   g_yss_cfg.symbol          = _Symbol;
   g_yss_cfg.tf              = YssResolveTf(InpTF);
   g_yss_cfg.riskPct         = InpRiskPct;
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
   g_yss_cfg.useGuard        = InpUseGuard;
   g_yss_cfg.beTriggerR      = InpBeTriggerR;
   g_yss_cfg.trailStartR     = InpTrailStartR;
   g_yss_cfg.trailDistR      = InpTrailDistR;

   g_yss_zoneCount = 0;
   g_yss_usedCount = 0;
   YssGuardReset();
   ZeroMemory(g_yss_view);
   g_yss_view.reason = "idle";

   g_hAtr = iATR(_Symbol, g_yss_cfg.tf, InpAtrPeriod);
   g_hStruct = iCustom(_Symbol, g_yss_cfg.tf, "::Indicators\\Yorick Structure",
                       InpSwingStrength, InpLookback);
   g_hFvg = iCustom(_Symbol, g_yss_cfg.tf, "::Indicators\\Yorick FVG", InpLookback);
   g_hZones = iCustom(_Symbol, g_yss_cfg.tf, "::Indicators\\Yorick Zones",
                      InpAtrPeriod, InpImpulseAtrMult, InpBodyAtrMult,
                      InpSwingStrength, InpLookback, InpMaxImpulseBars,
                      InpRequireBos, InpRequireFvg, InpSlZoneMult);

   if(g_hAtr == INVALID_HANDLE)
     {
      Print("YSS: ATR handle failed");
      YssRelease();
      return(INIT_FAILED);
     }
   if(g_hStruct == INVALID_HANDLE || g_hFvg == INVALID_HANDLE || g_hZones == INVALID_HANDLE)
      Print("YSS: overlay handle failed struct=", g_hStruct,
            " fvg=", g_hFvg, " zones=", g_hZones);

   YssOrdersInit(InpMagic, InpDeviation);
   g_yss_lastBar = 0;

   YssChartAttach();
   YssPanelUpdate();
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
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

   ulong ticket = 0;
   const bool inTrade = YssSelectPosition(_Symbol, InpMagic, ticket);
   if(inTrade && PositionSelectByTicket(ticket))
     {
      g_yss_view.posProfit = PositionGetDouble(POSITION_PROFIT)
                             + PositionGetDouble(POSITION_SWAP);
      g_yss_view.posSl     = PositionGetDouble(POSITION_SL);
      g_yss_view.posTp     = PositionGetDouble(POSITION_TP);
      g_yss_view.posLots   = PositionGetDouble(POSITION_VOLUME);
      g_yss_view.posDir    = YssPosDir(ticket);
      g_yss_view.balance   = AccountInfoDouble(ACCOUNT_BALANCE);
      g_yss_view.equity    = AccountInfoDouble(ACCOUNT_EQUITY);
     }
   YssChartLevels(g_yss_view.posSl, g_yss_view.posTp, g_yss_view.posDir);
   YssPanelUpdate();
  }
//+------------------------------------------------------------------+
