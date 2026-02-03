//+------------------------------------------------------------------+
//|                                                   HFT_Inputs.mqh |
//|                                         Copyright 2026, YourName |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, YourName"
#property link      "https://mql5.com"

#ifndef HFT_INPUTS_MQH
#define HFT_INPUTS_MQH

//+------------------------------------------------------------------+
//| Risk Mode Enumeration                                            |
//+------------------------------------------------------------------+
enum ENUM_RISK_MODE
{
   RISK_FIXED_LOTS,    // Fixed Lot Size
   RISK_PERCENT,       // Risk % of Equity
   RISK_DOLLAR         // Fixed Dollar Risk
};

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+

input group "=== EA IDENTIFICATION ==="
input string InpEAName = "HFT_Bracket";        // EA Name
input int    InpMagic = 200001;                // Magic Number

input group "=== POSITION SIZING ==="
input ENUM_RISK_MODE InpRiskMode = RISK_PERCENT;  // Risk Mode
input double InpFixedLots = 0.01;                 // Fixed Lot Size
input double InpRiskPercent = 2.0;                // Risk % per trade
input double InpRiskDollar = 100.0;               // Risk $ per trade
input double InpMaxLotSize = 10.0;                // Maximum Lot Size

input group "=== BRACKET ORDER SETTINGS (× Spread) ==="
input double Delta = 0.5;                      // Order Distance (× spread)
input double Theta = 7.0;                      // Max Order Distance (× spread)
input double InitialStop = 10.0;               // Initial Stop Loss (× spread)
input double Kost = 4.0;                       // Profit to Start Trail (× spread)

input group "=== ORDER MODIFICATION ==="
input int    ModificationInterval = 60;        // Modification Interval (seconds)
input double ModificationFactor = 3.0;         // Modification Factor

input group "=== SCALING IN ==="
input bool   EnableScaling = true;             // Enable Scaling In
input int    MaxScalePositions = 3;            // Max Scale-In Positions

input group "=== DAILY LOSS PROTECTION ==="
input bool   UseDailyLossLimit = true;         // Use Daily Loss Limit
input double DailyLossPercent = 5.0;           // Daily Loss % Limit

input group "=== SESSION MANAGEMENT ==="
input int    SessionStartHour = 16;            // Session Start Hour
input int    SessionEndHour = 17;              // Session End Hour (1 hour max!)
input int    MaxTradesPerSession = 200;        // Max Trades Warning

input group "=== VWAP FILTER (Optional) ==="
input bool   UseVWAPFilter = false;            // Use VWAP Filter
input int    VWAP_Period = 20;                 // VWAP Period

input group "=== ATR FILTER (Optional) ==="
input bool   UseATRFilter = false;             // Use ATR Filter
input int    ATR_Period = 14;                  // ATR Period
input double ATR_MinPercent = 0.03;            // Min ATR (% of price)

input group "=== ADX FILTER (Optional) ==="
input bool   UseADXFilter = false;             // Use ADX Filter
input int    ADX_Period = 14;                  // ADX Period
input double ADX_MinLevel = 20.0;              // Min ADX Level

input group "=== SPREAD FILTER ==="
input double MaxSpreadPercent = 0.03;          // Max Spread (% of price)

#endif // HFT_INPUTS_MQH
//+------------------------------------------------------------------+
