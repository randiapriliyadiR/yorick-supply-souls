//+------------------------------------------------------------------+
//| YorickSoS/Series.mqh — cached OHLC (avoids iHigh/iLow storms)    |
//+------------------------------------------------------------------+
#ifndef YORICKSOS_SERIES_MQH
#define YORICKSOS_SERIES_MQH

double   g_yss_so[];
double   g_yss_sh[];
double   g_yss_sl[];
double   g_yss_sc[];
datetime g_yss_st[];
int      g_yss_sn     = 0;
datetime g_yss_sBar0  = 0;
string   g_yss_sSym   = "";
ENUM_TIMEFRAMES g_yss_sTf = PERIOD_CURRENT;

ENUM_TIMEFRAMES YssSeriesTf(const ENUM_TIMEFRAMES tf)
  {
   if(tf == PERIOD_CURRENT)
      return (ENUM_TIMEFRAMES)Period();
   return tf;
  }

bool YssSeriesLoad(const string symbol, const ENUM_TIMEFRAMES tf, const int need)
  {
   if(need < 8 || symbol == "")
      return false;
   const ENUM_TIMEFRAMES rtf = YssSeriesTf(tf);
   const datetime t0 = iTime(symbol, rtf, 0);
   if(g_yss_sn >= need && g_yss_sBar0 == t0 && g_yss_sSym == symbol && g_yss_sTf == rtf)
      return true;

   ArraySetAsSeries(g_yss_so, true);
   ArraySetAsSeries(g_yss_sh, true);
   ArraySetAsSeries(g_yss_sl, true);
   ArraySetAsSeries(g_yss_sc, true);
   ArraySetAsSeries(g_yss_st, true);

   const int nO = CopyOpen(symbol, rtf, 0, need, g_yss_so);
   const int nH = CopyHigh(symbol, rtf, 0, need, g_yss_sh);
   const int nL = CopyLow(symbol, rtf, 0, need, g_yss_sl);
   const int nC = CopyClose(symbol, rtf, 0, need, g_yss_sc);
   const int nT = CopyTime(symbol, rtf, 0, need, g_yss_st);
   const int n  = (int)MathMin(nO, MathMin(nH, MathMin(nL, MathMin(nC, nT))));
   if(n < 8)
     {
      g_yss_sn = 0;
      return false;
     }
   g_yss_sn    = n;
   g_yss_sBar0 = t0;
   g_yss_sSym  = symbol;
   g_yss_sTf   = rtf;
   return true;
  }

bool YssSeriesHit(const string symbol, const ENUM_TIMEFRAMES tf, const int s)
  {
   return (s >= 0 && s < g_yss_sn && g_yss_sSym == symbol && g_yss_sTf == YssSeriesTf(tf));
  }

double YssO(const string symbol, const ENUM_TIMEFRAMES tf, const int s)
  {
   if(YssSeriesHit(symbol, tf, s))
      return g_yss_so[s];
   return iOpen(symbol, tf, s);
  }

double YssH(const string symbol, const ENUM_TIMEFRAMES tf, const int s)
  {
   if(YssSeriesHit(symbol, tf, s))
      return g_yss_sh[s];
   return iHigh(symbol, tf, s);
  }

double YssL(const string symbol, const ENUM_TIMEFRAMES tf, const int s)
  {
   if(YssSeriesHit(symbol, tf, s))
      return g_yss_sl[s];
   return iLow(symbol, tf, s);
  }

double YssC(const string symbol, const ENUM_TIMEFRAMES tf, const int s)
  {
   if(YssSeriesHit(symbol, tf, s))
      return g_yss_sc[s];
   return iClose(symbol, tf, s);
  }

datetime YssT(const string symbol, const ENUM_TIMEFRAMES tf, const int s)
  {
   if(YssSeriesHit(symbol, tf, s))
      return g_yss_st[s];
   return iTime(symbol, tf, s);
  }

int YssShiftOf(const string symbol, const ENUM_TIMEFRAMES tf, const datetime when)
  {
   if(when <= 0)
      return -1;
   if(g_yss_sSym == symbol && g_yss_sTf == YssSeriesTf(tf) && g_yss_sn > 0)
     {
      for(int i = 0; i < g_yss_sn; i++)
        {
         if(g_yss_st[i] == when)
            return i;
        }
     }
   return iBarShift(symbol, tf, when, true);
  }

#endif
//+------------------------------------------------------------------+