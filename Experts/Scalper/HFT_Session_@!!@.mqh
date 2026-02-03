//+------------------------------------------------------------------+
//|                                                  HFT_Session.mqh |
//|                                         Copyright 2026, YourName |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, YourName"
#property link      "https://mql5.com"

#ifndef HFT_SESSION_MQH
#define HFT_SESSION_MQH

#include "HFT_Globals.mqh"
#include "HFT_Inputs.mqh"

// Forward declaration
void CancelAllOrders();

//+------------------------------------------------------------------+
//| Get Start of Day                                                 |
//+------------------------------------------------------------------+
datetime DayStart(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);
   st.hour = 0;
   st.min = 0;
   st.sec = 0;
   return StructToTime(st);
}

//+------------------------------------------------------------------+
//| Initialize Session                                               |
//+------------------------------------------------------------------+
void InitializeSession()
{
   CurrentSessionDay = DayStart(TimeCurrent());
   SessionStartBalance = AccountInfoDouble(ACCOUNT_EQUITY);
   DailyLimitReached = false;
   SessionTradeCount = 0;
}

//+------------------------------------------------------------------+
//| Check for New Session                                            |
//+------------------------------------------------------------------+
void CheckNewSession()
{
   datetime currentDay = DayStart(TimeCurrent());
   
   if(currentDay != CurrentSessionDay)
   {
      CurrentSessionDay = currentDay;
      SessionStartBalance = AccountInfoDouble(ACCOUNT_EQUITY);
      DailyLimitReached = false;
      SessionTradeCount = 0;
      
      Print("=== NEW TRADING SESSION ===");
      Print("Date: ", TimeToString(currentDay, TIME_DATE));
      Print("Starting Equity: $", DoubleToString(SessionStartBalance, 2));
   }
}

//+------------------------------------------------------------------+
//| Get Daily P/L                                                    |
//+------------------------------------------------------------------+
double GetDailyPNL()
{
   if(SessionStartBalance == 0.0) return 0.0;
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   return (currentEquity - SessionStartBalance);
}

//+------------------------------------------------------------------+
//| Check Daily Loss Limit                                           |
//+------------------------------------------------------------------+
bool CheckDailyLossLimit()
{
   if(!UseDailyLossLimit) return false;
   
   double dailyPNL = GetDailyPNL();
   double lossThreshold = -(SessionStartBalance * (DailyLossPercent / 100.0));
   
   if(dailyPNL <= lossThreshold && !DailyLimitReached)
   {
      DailyLimitReached = true;
      
      Print("════════════════════════════════════");
      Print("⚠️ DAILY LOSS LIMIT REACHED!");
      Print("════════════════════════════════════");
      Print("Daily P/L: $", DoubleToString(dailyPNL, 2));
      Print("Loss Limit: $", DoubleToString(lossThreshold, 2));
      Print("EA SHUT DOWN for today");
      Print("════════════════════════════════════");
      
      // Cancel all pending orders
      CancelAllOrders();
   }
   
   return DailyLimitReached;
}

//+------------------------------------------------------------------+
//| Check if Session is Active                                       |
//+------------------------------------------------------------------+
bool IsSessionActive()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   if(dt.hour < SessionStartHour || dt.hour >= SessionEndHour)
      return false;
   
   // Warn if too many trades
   if(SessionTradeCount >= MaxTradesPerSession)
   {
      StatusMessage = StringFormat("⚠️ Max trades reached: %d", SessionTradeCount);
      Print("⚠️ WARNING: Max trades per session reached!");
      Print("⚠️ Consider stopping EA to avoid broker complaints!");
   }
   
   return true;
}

#endif // HFT_SESSION_MQH
//+------------------------------------------------------------------+