//+------------------------------------------------------------------+
//| YorickSoS/Panel.mqh — premium dashboard overlay                  |
//+------------------------------------------------------------------+
#ifndef YORICKSOS_PANEL_MQH
#define YORICKSOS_PANEL_MQH

#include "Types.mqh"

#define YSS_PNL_PREFIX   "YSS_PNL_"
#define YSS_PNL_X        14
#define YSS_PNL_Y        22
#define YSS_PNL_PAD_X    12
#define YSS_PNL_PAD_Y    10
#define YSS_PNL_ROW      17
#define YSS_PNL_TITLE_H  22
#define YSS_PNL_WIDTH    392
#define YSS_PNL_ROWS     11

#define YSS_PNL_BG       C'18,16,22'
#define YSS_PNL_BORDER   C'62,58,72'
#define YSS_PNL_ACCENT   C'212,175,90'
#define YSS_PNL_TITLE    C'245,245,242'
#define YSS_PNL_MUTED    C'168,174,186'
#define YSS_PNL_IDLE     C'152,158,170'
#define YSS_PNL_WAIT     C'255,196,72'
#define YSS_PNL_TRADE    C'90,180,110'
#define YSS_PNL_SELL     C'180,60,70'

bool   g_yss_pnl_built = false;
string g_yss_pnl_fp    = "";

string YssPnlName(const string key)
  {
   return YSS_PNL_PREFIX + key;
  }

color YssPnlStateColor(const ENUM_YSS_STATE st)
  {
   if(st == YSS_WAIT_RETURN || st == YSS_WAIT_SLOW)
      return YSS_PNL_WAIT;
   if(st == YSS_IN_TRADE)
      return YSS_PNL_TRADE;
   return YSS_PNL_IDLE;
  }

void YssPnlRect(const string key,
                const int x, const int y,
                const int w, const int h,
                const color bg, const color border,
                const int zorder)
  {
   const string n = YssPnlName(key);
   if(!g_yss_pnl_built && ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_BACK, false);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, 1);
     }
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR, border);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, zorder);
  }

void YssPnlLabel(const string key,
                 const int x, const int y,
                 const string text,
                 const color clr,
                 const int size,
                 const bool bold)
  {
   const string n = YssPnlName(key);
   if(!g_yss_pnl_built && ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, false);
     }
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, n, OBJPROP_FONT, bold ? "Arial Bold" : "Consolas");
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, 20);
  }

void YssPanelRemove(void)
  {
   ObjectsDeleteAll(0, YSS_PNL_PREFIX);
   g_yss_pnl_built = false;
   g_yss_pnl_fp = "";
  }

string YssPx(const double v)
  {
   return DoubleToString(v, (int)SymbolInfoInteger(g_yss_cfg.symbol, SYMBOL_DIGITS));
  }

void YssPanelUpdate(void)
  {
   if(!YssShowUi())
      return;

   const SYssView v = g_yss_view;
   const SYssZone z = v.zone;

   color zoneClr = YSS_PNL_IDLE;
   string zoneTxt = "none";
   if(z.valid && z.dir > 0)
     {
      zoneTxt = "DEMAND  " + YssPx(z.zoneLow) + " - " + YssPx(z.zoneHigh);
      zoneClr = YSS_PNL_TRADE;
     }
   else if(z.valid && z.dir < 0)
     {
      zoneTxt = "SUPPLY  " + YssPx(z.zoneLow) + " - " + YssPx(z.zoneHigh);
      zoneClr = YSS_PNL_SELL;
     }

   const string bosTxt = (z.valid && z.hasBos ? "YES  " + TimeToString(z.bosTime, TIME_DATE) : "no");
   const color  bosClr = (z.valid && z.hasBos ? YSS_PNL_TRADE : YSS_PNL_MUTED);
   const string fvgTxt = (z.valid && z.hasFvg
                          ? "YES  " + YssPx(z.fvgBot) + " - " + YssPx(z.fvgTop)
                          : "no");
   const color  fvgClr = (z.valid && z.hasFvg ? YSS_PNL_TRADE : YSS_PNL_MUTED);

   string appTxt = YssApproachText(v.approach);
   color  appClr = YSS_PNL_MUTED;
   if(v.approach == YSS_APP_SLOW)
      appClr = YSS_PNL_TRADE;
   else if(v.approach == YSS_APP_SHARP)
      appClr = YSS_PNL_SELL;
   else if(v.approach == YSS_APP_MID)
      appClr = YSS_PNL_WAIT;

   string posTxt = "FLAT";
   color  posClr = YSS_PNL_MUTED;
   if(v.posDir > 0)
     {
      posTxt = "BUY  " + DoubleToString(v.posLots, 2) + "  SL " + YssPx(v.posSl)
               + "  " + DoubleToString(v.posProfit, 2);
      posClr = YSS_PNL_TRADE;
     }
   else if(v.posDir < 0)
     {
      posTxt = "SELL " + DoubleToString(v.posLots, 2) + "  SL " + YssPx(v.posSl)
               + "  " + DoubleToString(v.posProfit, 2);
      posClr = YSS_PNL_SELL;
     }

   const string fp = IntegerToString((int)v.state) + "|" + v.reason + "|" +
                     IntegerToString(z.dir) + "|" + DoubleToString(z.zoneHigh, 2) + "|" +
                     IntegerToString((int)v.approach) + "|" + IntegerToString(v.posDir) + "|" +
                     DoubleToString(v.posProfit, 2);
   if(g_yss_pnl_built && fp == g_yss_pnl_fp)
      return;
   g_yss_pnl_fp = fp;

   const int height = YSS_PNL_PAD_Y * 2 + YSS_PNL_TITLE_H + YSS_PNL_ROWS * YSS_PNL_ROW + 8;
   YssPnlRect("BG", YSS_PNL_X, YSS_PNL_Y, YSS_PNL_WIDTH, height,
              YSS_PNL_BG, YSS_PNL_BORDER, 8);
   YssPnlRect("ACCENT", YSS_PNL_X, YSS_PNL_Y, YSS_PNL_WIDTH, 3,
              YSS_PNL_ACCENT, YSS_PNL_ACCENT, 9);

   const int tx = YSS_PNL_X + YSS_PNL_PAD_X;
   int y = YSS_PNL_Y + YSS_PNL_PAD_Y + 4;

   YssPnlLabel("TITLE", tx, y, "YORICK SUPPLY OF SOULS", YSS_PNL_TITLE, 10, true);
   YssPnlLabel("TF", tx + 248, y,
               g_yss_cfg.symbol + "  " + YssTfText(g_yss_cfg.tf), YSS_PNL_ACCENT, 9, true);
   y += YSS_PNL_TITLE_H;

   YssPnlLabel("STATE", tx, y, "STATE     " + YssStateText(v.state),
               YssPnlStateColor(v.state), 9, true);
   y += YSS_PNL_ROW;
   YssPnlLabel("ZONE", tx, y, "ZONE      " + zoneTxt, zoneClr, 8, false);
   y += YSS_PNL_ROW;
   YssPnlLabel("BOS", tx, y, "BOS       " + bosTxt, bosClr, 8, false);
   y += YSS_PNL_ROW;
   YssPnlLabel("FVG", tx, y, "FVG       " + fvgTxt, fvgClr, 8, false);
   y += YSS_PNL_ROW;
   YssPnlLabel("APP", tx, y, "APPROACH  " + appTxt, appClr, 8, false);
   y += YSS_PNL_ROW;
   YssPnlLabel("POS", tx, y, "POS       " + posTxt, posClr, 8, false);
   y += YSS_PNL_ROW;
   YssPnlLabel("BAL", tx, y,
               "BAL       " + DoubleToString(v.balance, 2) +
               "  EQ " + DoubleToString(v.equity, 2),
               YSS_PNL_TITLE, 8, false);
   y += YSS_PNL_ROW;
   YssPnlLabel("RISK", tx, y,
               "RISK      " + DoubleToString(g_yss_cfg.riskPct, 1) + "%  $" +
               DoubleToString(v.riskMoney, 2) + "  next " +
               DoubleToString(v.nextLots, 2) + " lot",
               YSS_PNL_ACCENT, 8, false);
   y += YSS_PNL_ROW;
   YssPnlLabel("WHY", tx, y, "WHY       " + StringSubstr(v.reason, 0, 42),
               YSS_PNL_MUTED, 8, false);

   g_yss_pnl_built = true;
   ChartRedraw(0);
  }

#endif
//+------------------------------------------------------------------+
