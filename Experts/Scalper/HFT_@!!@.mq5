//+------------------------------------------------------------------+
//|                                                          HFT.mq5 |
//|                      High-Frequency Bracket Scalping EA          |
//|                Based on YouTube Logic + Professional Features    |
//| 03.02.2026 - Initial release (Modular Version)                   |
//+------------------------------------------------------------------+
#property copyright "HFT Bracket Pro - Professional Edition"
#property link      "https://mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Include Modular Files                                            |
//+------------------------------------------------------------------+
#include "HFT_Inputs.mqh"           // Input parameters & enums
#include "HFT_Globals.mqh"          // Global variables & trade objects
#include "HFT_SymbolUtils.mqh"      // Symbol & spread utilities
#include "HFT_Filters.mqh"          // VWAP, ATR, ADX, Spread filters
#include "HFT_Session.mqh"          // Session & daily loss management
#include "HFT_RiskManagement.mqh"   // Lot size & commission calculation
#include "HFT_Orders.mqh"           // Order placement & modification
#include "HFT_Positions.mqh"        // Position management & trailing
#include "HFT_Display.mqh"          // Chart display functions
#include "HFT_Database.mqh"         // SQLite database logging

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set magic number
   trade.SetExpertMagicNumber(InpMagic);
   
   // Remove grid from chart
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   
   // Initialize symbol parameters
   UpdateSymbolParameters();
   
   // Initialize broker limits
   InitializeBrokerLimits();
   
   // Initialize spread array
   InitializeSpreadArray();
   
   // Initialize statistics arrays for time-based tracking
   InitializeStatisticsArrays();
   
   // Initialize filters (VWAP, ATR, ADX)
   InitializeFilters();
   
   // Initialize daily session
   InitializeSession();
   
   // Calculate commission from history
   CalculateCommissionFromHistory();
   
   // Initialize trailing values
   BaseTrailingStop = Kost;
   TrailingStopIncrement = Kost;
   
   // Initialize database
   if(InitializeDatabase())
   {
      DB_StartSession();
   }
   
   // Log initialization info
   LogInitialization();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // End database session and close
   DB_EndSession(GetDailyPNL(), TotalTradesAllTime, TotalOrdersPlaced, TotalOrdersModified, 0, 0);
   CloseDatabase();
   
   // Release indicator handles
   ReleaseFilters();
   
   // Clear chart display
   ClearChartDisplay();
   
   // Log deinitialization
   LogDeinitialization(reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new session (daily reset)
   CheckNewSession();
   
   // Check daily loss limit
   if(CheckDailyLossLimit())
   {
      UpdateChartDisplay();
      return;
   }
   
   // Check if trading session is active
   if(!IsSessionActive())
   {
      TradingAllowed = false;
      StatusMessage = "Outside trading hours";
      UpdateChartDisplay();
      return;
   }
   
   // Update symbol parameters
   UpdateSymbolParameters();
   
   // Update spread tracking
   UpdateSpread();
   
   // Calculate order distances
   CalculateDistances();
   
   // Count positions and orders
   CountPositions();
   
   // Check all filters (spread, VWAP, ATR, ADX)
   if(!PassAllFilters())
   {
      UpdateChartDisplay();
      return;
   }
   
   TradingAllowed = true;
   StatusMessage = "Trading ACTIVE";
   
   //+------------------------------------------------------------------+
   //| Main Trading Logic                                               |
   //+------------------------------------------------------------------+
   
   // 1. Trail existing positions
   ManageOpenPositions();
   
   // 2. Adjust pending orders
   ModifyPendingOrders();
   
   // 3. Place new bracket orders
   PlaceBracketOrders();
   
   // 4. Add scale-in positions if enabled
   CheckForScaleIn();
   
   // Update chart display
   UpdateChartDisplay();
}

//+------------------------------------------------------------------+
//| Trade Transaction Handler - Track Closed Trades                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   // Only process deal additions (completed trades)
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      // Get deal info
      ulong dealTicket = trans.deal;
      
      if(HistoryDealSelect(dealTicket))
      {
         // Check if it's our EA's deal
         if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagic) return;
         if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;
         
         // Get deal type
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         
         // Only record closing deals (DEAL_ENTRY_OUT)
         if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         {
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
            double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
            double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
            ulong positionID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
            datetime closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
            
            ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
            string tradeType = (dealType == DEAL_TYPE_BUY) ? "SELL" : "BUY"; // Opposite because it's closing
            
            // Find the opening deal to get open price and time
            double openPrice = 0;
            datetime openTime = 0;
            double sl = 0, tp = 0;
            
            if(HistorySelectByPosition(positionID))
            {
               for(int i = 0; i < HistoryDealsTotal(); i++)
               {
                  ulong histDeal = HistoryDealGetTicket(i);
                  if(histDeal == dealTicket) continue;
                  
                  ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(histDeal, DEAL_ENTRY);
                  if(entry == DEAL_ENTRY_IN)
                  {
                     openPrice = HistoryDealGetDouble(histDeal, DEAL_PRICE);
                     openTime = (datetime)HistoryDealGetInteger(histDeal, DEAL_TIME);
                     break;
                  }
               }
            }
            
            // Record to statistics
            RecordTrade(profit + commission + swap);
            
            // Record to database
            DB_RecordTrade(dealTicket, positionID, tradeType, volume,
                          openPrice, closePrice, sl, tp,
                          openTime, closeTime, profit, commission, swap,
                          HistoryDealGetString(dealTicket, DEAL_COMMENT));
            
            Print(StringFormat("📊 Trade Recorded: %s %.2f lots, Profit: $%.2f", 
                  tradeType, volume, profit + commission + swap));
         }
      }
   }
}
//+------------------------------------------------------------------+
