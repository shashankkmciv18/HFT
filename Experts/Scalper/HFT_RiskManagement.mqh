//+------------------------------------------------------------------+
//|                                          HFT_RiskManagement.mqh  |
//|                                         Copyright 2026, YourName |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, YourName"
#property link      "https://mql5.com"

#ifndef HFT_RISKMANAGEMENT_MQH
#define HFT_RISKMANAGEMENT_MQH

#include "HFT_Globals.mqh"
#include "HFT_Inputs.mqh"

//+------------------------------------------------------------------+
//| Calculate Commission from History                                |
//+------------------------------------------------------------------+
void CalculateCommissionFromHistory()
{
   if(!HistorySelect(0, TimeCurrent()))
      return;
   
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetDouble(ticket, DEAL_PROFIT) == 0) continue;
      
      double entryPrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
      ulong posID = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
      
      if(posID == 0) continue;
      
      // Find exit deal
      for(int j = i + 1; j < HistoryDealsTotal(); j++)
      {
         ulong exitTicket = HistoryDealGetTicket(j);
         if(HistoryDealGetInteger(exitTicket, DEAL_POSITION_ID) == posID)
         {
            double exitPrice = HistoryDealGetDouble(exitTicket, DEAL_PRICE);
            double profit = HistoryDealGetDouble(exitTicket, DEAL_PROFIT);
            double commission = HistoryDealGetDouble(exitTicket, DEAL_COMMISSION);
            
            if(exitPrice != entryPrice)
            {
               PriceToPipRatio = MathAbs(profit / (exitPrice - entryPrice));
               CommissionPerPip = -commission / PriceToPipRatio;
               return;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double lotSize = InpFixedLots;
   
   if(InpRiskMode == RISK_PERCENT)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskAmount = equity * (InpRiskPercent / 100.0);
      double slDistance = CalculatedStopLoss / SymPoint;
      
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tickSize > 0)
      {
         double pointValue = (tickValue / tickSize) * SymPoint;
         if(pointValue > 0)
            lotSize = riskAmount / (slDistance * pointValue);
      }
   }
   else if(InpRiskMode == RISK_DOLLAR)
   {
      double slDistance = CalculatedStopLoss / SymPoint;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tickSize > 0)
      {
         double pointValue = (tickValue / tickSize) * SymPoint;
         if(pointValue > 0)
            lotSize = InpRiskDollar / (slDistance * pointValue);
      }
   }
   
   // Normalize lot size
   if(BrokerLotStep > 0)
      lotSize = MathFloor(lotSize / BrokerLotStep) * BrokerLotStep;
   
   lotSize = MathMax(lotSize, BrokerMinLot);
   lotSize = MathMin(lotSize, BrokerMaxLot);
   lotSize = MathMin(lotSize, InpMaxLotSize);
   
   return NormalizeDouble(lotSize, 2);
}

#endif // HFT_RISKMANAGEMENT_MQH
//+------------------------------------------------------------------+
