//+------------------------------------------------------------------+
//|                                                  HFT_Display.mqh |
//|                                         Copyright 2026, YourName |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, YourName"
#property link      "https://mql5.com"

#ifndef HFT_DISPLAY_MQH
#define HFT_DISPLAY_MQH

#include "HFT_Globals.mqh"
#include "HFT_Inputs.mqh"
#include "HFT_Session.mqh"

//+------------------------------------------------------------------+
//| Update Chart Display                                             |
//+------------------------------------------------------------------+
void UpdateChartDisplay()
{
   string display = "";
   
   display += "═══════════════════════════════════\n";
   display += "    HFT BRACKET PRO - STATUS\n";
   display += "═══════════════════════════════════\n\n";
   
   // EA Status
   display += "Status: " + StatusMessage + "\n";
   
   // Daily P/L
   double dailyPNL = GetDailyPNL();
   double dailyPercent = (SessionStartBalance > 0) ? (dailyPNL / SessionStartBalance) * 100.0 : 0;
   
   display += StringFormat("Daily P/L: $%.2f (%.2f%%)\n", dailyPNL, dailyPercent);
   
   if(DailyLimitReached)
      display += "⚠️ DAILY LIMIT REACHED - EA STOPPED\n";
   
   display += "\n";
   
   // Position Info
   display += StringFormat("Open Positions: BUY=%d SELL=%d\n", OpenBuyCount, OpenSellCount);
   display += StringFormat("Session Trades: %d", SessionTradeCount);
   
   if(SessionTradeCount >= MaxTradesPerSession)
      display += " ⚠️ MAX REACHED!";
   
   display += "\n\n";
   
   //--- Time-Based Trade Statistics ---
   display += "─── TRADES (Time Windows) ───\n";
   display += StringFormat("1min: %d | 5min: %d | 10min: %d | 15min: %d\n",
                           GetTradesInLastMinutes(1),
                           GetTradesInLastMinutes(5),
                           GetTradesInLastMinutes(10),
                           GetTradesInLastMinutes(15));
   
   //--- Time-Based PNL Statistics ---
   display += "─── P/L (Time Windows) ───\n";
   display += StringFormat("1min: $%.2f | 5min: $%.2f | 10min: $%.2f\n",
                           GetPNLInLastMinutes(1),
                           GetPNLInLastMinutes(5),
                           GetPNLInLastMinutes(10));
   
   //--- Order Statistics ---
   display += "─── ORDERS (Time Windows) ───\n";
   display += StringFormat("Placed  - 1min: %d | 5min: %d | 10min: %d\n",
                           GetOrdersPlacedInLastMinutes(1),
                           GetOrdersPlacedInLastMinutes(5),
                           GetOrdersPlacedInLastMinutes(10));
   display += StringFormat("Modified- 1min: %d | 5min: %d | 10min: %d\n",
                           GetOrdersModifiedInLastMinutes(1),
                           GetOrdersModifiedInLastMinutes(5),
                           GetOrdersModifiedInLastMinutes(10));
   
   //--- Cumulative Totals ---
   display += "─── SESSION TOTALS ───\n";
   display += StringFormat("Total Trades: %d | Orders Placed: %d | Modified: %d\n",
                           TotalTradesAllTime, TotalOrdersPlaced, TotalOrdersModified);
   
   display += "\n";
   
   // Spread Info
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spreadPercent = (CurrentSpread / currentPrice) * 100.0;
   display += StringFormat("Spread: %.4f%% ", spreadPercent);
   
   if(spreadPercent > MaxSpreadPercent)
      display += "❌ TOO WIDE";
   else
      display += "✅";
   
   display += "\n";
   
   // Filter Status
   if(VWAPFilterActive)
      display += "VWAP: ON\n";
   if(ATRFilterActive)
      display += "ATR: ON (M1)\n";
   if(ADXFilterActive)
      display += "ADX: ON\n";
   
   display += "\n═══════════════════════════════════";
   
   Comment(display);
}

//+------------------------------------------------------------------+
//| Clear Chart Display                                              |
//+------------------------------------------------------------------+
void ClearChartDisplay()
{
   Comment("");
}

//+------------------------------------------------------------------+
//| Log Initialization Info                                          |
//+------------------------------------------------------------------+
void LogInitialization()
{
   Print("═══════════════════════════════════════");
   Print("=== HFT BRACKET PRO INITIALIZED ===");
   Print("═══════════════════════════════════════");
   Print("Symbol: ", _Symbol);
   Print("Magic: ", InpMagic);
   Print("Risk Mode: ", EnumToString(InpRiskMode));
   Print("Order Distance: ", Delta, "× spread");
   Print("Initial SL: ", InitialStop, "× spread");
   Print("Trail Start: ", Kost, "× spread");
   Print("Scaling In: ", EnableScaling ? "ON" : "OFF");
   Print("Max Positions: ", MaxScalePositions);
   Print("Daily Limit: ", UseDailyLossLimit ? StringFormat("%.1f%%", DailyLossPercent) : "OFF");
   Print("Session: ", SessionStartHour, ":00 - ", SessionEndHour, ":00");
   Print("VWAP Filter: ", VWAPFilterActive ? "ON" : "OFF");
   Print("ATR Filter: ", ATRFilterActive ? "ON (M1)" : "OFF");
   Print("ADX Filter: ", ADXFilterActive ? "ON" : "OFF");
   Print("═══════════════════════════════════════");
   Print("⚠️ WARNING: HIGH FREQUENCY EA");
   Print("⚠️ Run for 10-15 minutes MAX per session!");
   Print("⚠️ Monitor broker warnings closely!");
   Print("═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Log Deinitialization Info                                        |
//+------------------------------------------------------------------+
void LogDeinitialization(int reason)
{
   Print("HFT Bracket Pro deinitialized. Reason: ", reason);
   Print("Session trades: ", SessionTradeCount);
   Print("Total trades: ", TotalTradesAllTime);
   Print("Total orders placed: ", TotalOrdersPlaced);
   Print("Total orders modified: ", TotalOrdersModified);
}

//+------------------------------------------------------------------+
//| Initialize Statistics Arrays                                     |
//+------------------------------------------------------------------+
void InitializeStatisticsArrays()
{
   ArrayResize(TradeTimestamps, MAX_TRADE_HISTORY);
   ArrayResize(TradePNLs, MAX_TRADE_HISTORY);
   ArrayResize(OrderPlacedTimestamps, MAX_ORDER_HISTORY);
   ArrayResize(OrderModifiedTimestamps, MAX_ORDER_HISTORY);
   
   ArrayInitialize(TradeTimestamps, 0);
   ArrayInitialize(TradePNLs, 0);
   ArrayInitialize(OrderPlacedTimestamps, 0);
   ArrayInitialize(OrderModifiedTimestamps, 0);
   
   TradeHistoryCount = 0;
   TradeHistoryIndex = 0;
   OrderPlacedCount = 0;
   OrderModifiedCount = 0;
   OrderPlacedIndex = 0;
   OrderModifiedIndex = 0;
   TotalTradesAllTime = 0;
   TotalOrdersPlaced = 0;
   TotalOrdersModified = 0;
}

//+------------------------------------------------------------------+
//| Record a Trade                                                   |
//+------------------------------------------------------------------+
void RecordTrade(double pnl)
{
   TradeTimestamps[TradeHistoryIndex] = TimeCurrent();
   TradePNLs[TradeHistoryIndex] = pnl;
   
   TradeHistoryIndex = (TradeHistoryIndex + 1) % MAX_TRADE_HISTORY;
   if(TradeHistoryCount < MAX_TRADE_HISTORY)
      TradeHistoryCount++;
   
   TotalTradesAllTime++;
}

//+------------------------------------------------------------------+
//| Record Order Placed                                              |
//+------------------------------------------------------------------+
void RecordOrderPlaced()
{
   OrderPlacedTimestamps[OrderPlacedIndex] = TimeCurrent();
   
   OrderPlacedIndex = (OrderPlacedIndex + 1) % MAX_ORDER_HISTORY;
   if(OrderPlacedCount < MAX_ORDER_HISTORY)
      OrderPlacedCount++;
   
   TotalOrdersPlaced++;
}

//+------------------------------------------------------------------+
//| Record Order Modified                                            |
//+------------------------------------------------------------------+
void RecordOrderModified()
{
   OrderModifiedTimestamps[OrderModifiedIndex] = TimeCurrent();
   
   OrderModifiedIndex = (OrderModifiedIndex + 1) % MAX_ORDER_HISTORY;
   if(OrderModifiedCount < MAX_ORDER_HISTORY)
      OrderModifiedCount++;
   
   TotalOrdersModified++;
}

//+------------------------------------------------------------------+
//| Get Trades in Last N Minutes                                     |
//+------------------------------------------------------------------+
int GetTradesInLastMinutes(int minutes)
{
   datetime cutoff = TimeCurrent() - (minutes * 60);
   int count = 0;
   
   for(int i = 0; i < TradeHistoryCount; i++)
   {
      if(TradeTimestamps[i] >= cutoff)
         count++;
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Get PNL in Last N Minutes                                        |
//+------------------------------------------------------------------+
double GetPNLInLastMinutes(int minutes)
{
   datetime cutoff = TimeCurrent() - (minutes * 60);
   double pnl = 0;
   
   for(int i = 0; i < TradeHistoryCount; i++)
   {
      if(TradeTimestamps[i] >= cutoff)
         pnl += TradePNLs[i];
   }
   
   return pnl;
}

//+------------------------------------------------------------------+
//| Get Orders Placed in Last N Minutes                              |
//+------------------------------------------------------------------+
int GetOrdersPlacedInLastMinutes(int minutes)
{
   datetime cutoff = TimeCurrent() - (minutes * 60);
   int count = 0;
   
   for(int i = 0; i < OrderPlacedCount; i++)
   {
      if(OrderPlacedTimestamps[i] >= cutoff)
         count++;
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Get Orders Modified in Last N Minutes                            |
//+------------------------------------------------------------------+
int GetOrdersModifiedInLastMinutes(int minutes)
{
   datetime cutoff = TimeCurrent() - (minutes * 60);
   int count = 0;
   
   for(int i = 0; i < OrderModifiedCount; i++)
   {
      if(OrderModifiedTimestamps[i] >= cutoff)
         count++;
   }
   
   return count;
}

#endif // HFT_DISPLAY_MQH
//+------------------------------------------------------------------+
