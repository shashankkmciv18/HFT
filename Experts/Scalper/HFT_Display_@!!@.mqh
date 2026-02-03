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
}

#endif // HFT_DISPLAY_MQH
//+------------------------------------------------------------------+
