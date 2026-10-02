//+------------------------------------------------------------------+
//|                               Gold_M5_Trend_BOS_Corrected.mq5    |
//|                                  Copyright 2026, AI Collaborator |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property strict
#property version "5.20"
#include <Trade/Trade.mqh>
CTrade trade;

input string SymbolName="";
input double Lot=0.03;              
input double RiskReward=1.5;        
input double SL_ATR_Mult=1.5;       
input double TrailStartUSD=10.0;    
input double TrailLockUSD=2.0;      
input int Magic=30102026;
input int LookbackM5=15;            
input int RetestBarsM1=12;          
input double RetestToleranceATR=0.4;
input double MinBreakoutATR=0.3;    

string S; 
datetime lastbar_m5=0; 
int hATR_M5, hATR_M1;
int pending_dir = 0, age_m1 = 0; 
double breakout_level = 0;

double GetBuffer(int h, int b, int s)
{
   double a[];
   ArraySetAsSeries(a, true);
   if(CopyBuffer(h, b, s, 1, a) != 1) return EMPTY_VALUE;
   return a[0];
}

bool NewBarM5()
{
   datetime t = iTime(S, PERIOD_M5, 0);
   if(t != lastbar_m5)
   {
      lastbar_m5 = t;
      return true;
   }
   return false;
}

bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket && PositionGetString(POSITION_SYMBOL) == S && (int)PositionGetInteger(POSITION_MAGIC) == Magic)
         return true;
   }
   return false;
}

int CheckM5TrendBOS(double &lv)
{
   double c = iClose(S, PERIOD_M5, 1);
   double atr_m5 = GetBuffer(hATR_M5, 0, 1);
   if(atr_m5 <= 0) return 0;
   
   double hi = -DBL_MAX, lo = DBL_MAX;
   for(int i = 2; i < LookbackM5 + 2; i++)
   {
      hi = MathMax(hi, iHigh(S, PERIOD_M5, i));
      lo = MathMin(lo, iLow(S, PERIOD_M5, i));
   }
   
   // كسر القمة صعوداً -> اتجاه صاعد (بحث عن شراء فقط)
   if(c > hi + (atr_m5 * MinBreakoutATR))
   { 
      lv = hi; 
      return 1;   
   }
   // كسر القاع هبوطاً -> اتجاه هابط (بحث عن بيع فقط)
   if(c < lo - (atr_m5 * MinBreakoutATR))
   { 
      lv = lo; 
      return -1;  
   }
   
   return 0; 
}

int OnInit()
{
   S = (SymbolName == "" ? _Symbol : SymbolName);
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(50);
   trade.SetTypeFillingBySymbol(S);
   
   hATR_M5 = iATR(S, PERIOD_M5, 14);
   hATR_M1 = iATR(S, PERIOD_M1, 14);
   if(hATR_M5 == INVALID_HANDLE || hATR_M1 == INVALID_HANDLE) return INIT_FAILED;
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int r)
{
   IndicatorRelease(hATR_M5);
   IndicatorRelease(hATR_M1);
}

void ManageProtection()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!ticket || PositionGetString(POSITION_SYMBOL) != S || (int)PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit < TrailStartUSD) continue;
      
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double old_sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      MqlTick tick;
      if(!SymbolInfoTick(S, tick)) continue;
      
      double min_stops = (double)SymbolInfoInteger(S, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(S, SYMBOL_POINT);
      
      if(pos_type == POSITION_TYPE_BUY)
      {
         double new_sl = open_price + (TrailLockUSD * 0.1); 
         if(old_sl == 0 || new_sl > old_sl)
         {
            if(tick.bid - new_sl >= min_stops)
            {
               trade.PositionModify(ticket, NormalizeDouble(new_sl, _Digits), tp);
            }
         }
      }
      else
      {
         double new_sl = open_price - (TrailLockUSD * 0.1);
         if(old_sl == 0 || new_sl < old_sl)
         {
            if(new_sl - tick.ask >= min_stops)
            {
               trade.PositionModify(ticket, NormalizeDouble(new_sl, _Digits), tp);
            }
         }
      }
   }
}

void OpenOrder(int dir, string why)
{
   MqlTick tick;
   if(!SymbolInfoTick(S, tick)) return;
   
   double atr = GetBuffer(hATR_M1, 0, 1);
   if(atr <= 0) atr = 1.0;
   
   double distance = atr * SL_ATR_Mult;
   double sl, tp;
   double stops_level = (double)SymbolInfoInteger(S, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(S, SYMBOL_POINT);
   
   if(dir > 0)
   {
      double entry = tick.ask;
      sl = entry - distance;
      tp = entry + (distance * RiskReward);
      
      if(stops_level > 0 && (entry - sl) < stops_level) sl = entry - stops_level - SymbolInfoDouble(S, SYMBOL_POINT);
      trade.Buy(Lot, S, entry, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "Trend-Buy " + why);
   }
   else
   {
      double entry = tick.bid;
      sl = entry + distance;
      tp = entry - (distance * RiskReward);
      
      if(stops_level > 0 && (sl - entry) < stops_level) sl = entry + stops_level + SymbolInfoDouble(S, SYMBOL_POINT);
      trade.Sell(Lot, S, entry, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "Trend-Sell " + why);
   }
}

void OnTick()
{
   ManageProtection();
   
   if(NewBarM5())
   {
      double lv;
      int m5_trend = CheckM5TrendBOS(lv);
      if(m5_trend != 0)
      {
         pending_dir = m5_trend;
         breakout_level = lv;
         age_m1 = 0; 
      }
   }
   
   if(pending_dir != 0)
   {
      static datetime last_m1_bar = 0;
      datetime current_m1 = iTime(S, PERIOD_M1, 0);
      if(current_m1 != last_m1_bar)
      {
         last_m1_bar = current_m1;
         age_m1++;
         
         double atr_m1 = GetBuffer(hATR_M1, 0, 1);
         double low_m1  = iLow(S, PERIOD_M1, 1);
         double high_m1 = iHigh(S, PERIOD_M1, 1);
         
         // إعادة الاختبار: للشراء ينتظر هبوط السعر للمستوى ثم الارتداد، وللبيع ينتظر صعود السعر للمستوى ثم الهبوط
         bool touched = (pending_dir > 0) ? (low_m1 <= breakout_level + (atr_m1 * RetestToleranceATR)) 
                                          : (high_m1 >= breakout_level - (atr_m1 * RetestToleranceATR));
                                          
         if(touched && !HasOpenPosition())
         {
            int direction_to_open = pending_dir;
            pending_dir = 0; 
            OpenOrder(direction_to_open, "RETEST");
            return;
         }
         
         if(age_m1 > RetestBarsM1)
         {
            pending_dir = 0;
         }
      }
   }
}
//+------------------------------------------------------------------+
