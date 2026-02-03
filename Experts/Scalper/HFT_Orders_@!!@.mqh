//+------------------------------------------------------------------+
//|                                                   HFT_Orders.mqh |
//|                                         Copyright 2026, YourName |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, YourName"
#property link      "https://mql5.com"

#ifndef HFT_ORDERS_MQH
#define HFT_ORDERS_MQH

#include "HFT_Globals.mqh"
#include "HFT_Inputs.mqh"
#include "HFT_RiskManagement.mqh"

// Forward declarations for statistics recording functions
void RecordOrderPlaced();
void RecordOrderModified();

// Forward declarations for database functions
void DB_RecordOrderPlaced(ulong ticket, string orderType, double lots, double price, double sl, double tp, string comment = "");
void DB_RecordOrderModified(ulong ticket, double oldPrice, double newPrice, double oldSL, double newSL, string reason = "");
void DB_RecordOrderCancelled(ulong ticket, string orderType, string reason = "");

//+------------------------------------------------------------------+
//| Cancel Buy Orders                                                |
//+------------------------------------------------------------------+
void CancelBuyOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!orderInfo.SelectByIndex(i)) continue;
      if(orderInfo.Magic() != InpMagic) continue;
      if(orderInfo.Symbol() != _Symbol) continue;
      
      if(orderInfo.OrderType() == ORDER_TYPE_BUY_STOP)
      {
         ulong ticket = orderInfo.Ticket();
         if(trade.OrderDelete(ticket))
         {
            DB_RecordOrderCancelled(ticket, "BUY_STOP", "Opposite filled");
            Print("❌ BUY STOP cancelled (opposite filled)");
            BuyOrderTicket = 0;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Cancel Sell Orders                                               |
//+------------------------------------------------------------------+
void CancelSellOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!orderInfo.SelectByIndex(i)) continue;
      if(orderInfo.Magic() != InpMagic) continue;
      if(orderInfo.Symbol() != _Symbol) continue;
      
      if(orderInfo.OrderType() == ORDER_TYPE_SELL_STOP)
      {
         ulong ticket = orderInfo.Ticket();
         if(trade.OrderDelete(ticket))
         {
            DB_RecordOrderCancelled(ticket, "SELL_STOP", "Opposite filled");
            Print("❌ SELL STOP cancelled (opposite filled)");
            SellOrderTicket = 0;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Cancel All Orders                                                |
//+------------------------------------------------------------------+
void CancelAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!orderInfo.SelectByIndex(i)) continue;
      if(orderInfo.Magic() != InpMagic) continue;
      if(orderInfo.Symbol() != _Symbol) continue;
      
      ulong ticket = orderInfo.Ticket();
      string orderType = (orderInfo.OrderType() == ORDER_TYPE_BUY_STOP) ? "BUY_STOP" : "SELL_STOP";
      
      if(trade.OrderDelete(ticket))
      {
         DB_RecordOrderCancelled(ticket, orderType, "Daily limit or session end");
      }
   }
   
   BuyOrderTicket = 0;
   SellOrderTicket = 0;
}

//+------------------------------------------------------------------+
//| Place Bracket Orders (Both Sides)                                |
//+------------------------------------------------------------------+
void PlaceBracketOrders()
{
   // Only place if no orders exist and conditions met
   if(TotalBuyCount > 0 || TotalSellCount > 0)
      return;
   
   // Check if enough time passed since last order
   if(TimeCurrent() - MathMax(LastBuyOrderTime, LastSellOrderTime) < ModificationInterval)
      return;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double lotSize = CalculateLotSize();
   
   // BUY STOP (above price)
   double buyPrice = NormalizeDouble(ask + AdjustedOrderDistance, SymDigits);
   double buySL = NormalizeDouble(buyPrice - CalculatedStopLoss, SymDigits);
   
   if(trade.BuyStop(lotSize, buyPrice, _Symbol, buySL, 0, ORDER_TIME_GTC, 0, "HFT_BUY"))
   {
      BuyOrderTicket = trade.ResultOrder();
      LastBuyOrderTime = TimeCurrent();
      SessionTradeCount++;
      RecordOrderPlaced();
      DB_RecordOrderPlaced(BuyOrderTicket, "BUY_STOP", lotSize, buyPrice, buySL, 0, "HFT_BUY");
      Print("✅ BUY STOP placed at ", buyPrice);
   }
   
   // SELL STOP (below price)
   double sellPrice = NormalizeDouble(bid - AdjustedOrderDistance, SymDigits);
   double sellSL = NormalizeDouble(sellPrice + CalculatedStopLoss, SymDigits);
   
   if(trade.SellStop(lotSize, sellPrice, _Symbol, sellSL, 0, ORDER_TIME_GTC, 0, "HFT_SELL"))
   {
      SellOrderTicket = trade.ResultOrder();
      LastSellOrderTime = TimeCurrent();
      SessionTradeCount++;
      RecordOrderPlaced();
      DB_RecordOrderPlaced(SellOrderTicket, "SELL_STOP", lotSize, sellPrice, sellSL, 0, "HFT_SELL");
      Print("✅ SELL STOP placed at ", sellPrice);
   }
}

//+------------------------------------------------------------------+
//| Modify Pending Orders                                            |
//+------------------------------------------------------------------+
void ModifyPendingOrders()
{
   if(TimeCurrent() - LastModificationTime < ModificationInterval)
      return;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Modify BUY STOP and SELL STOP
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!orderInfo.SelectByIndex(i)) continue;
      if(orderInfo.Magic() != InpMagic) continue;
      if(orderInfo.Symbol() != _Symbol) continue;
      
      if(orderInfo.OrderType() == ORDER_TYPE_BUY_STOP)
      {
         double currentPrice = orderInfo.PriceOpen();
         double currentSL = orderInfo.StopLoss();
         double newPrice = NormalizeDouble(ask + AdjustedOrderDistance, SymDigits);
         
         if(MathAbs(newPrice - currentPrice) > AdjustedOrderDistance * 0.1)
         {
            double newSL = NormalizeDouble(newPrice - CalculatedStopLoss, SymDigits);
            ulong ticket = orderInfo.Ticket();
            if(trade.OrderModify(ticket, newPrice, newSL, 0, ORDER_TIME_GTC, 0))
            {
               LastModificationTime = TimeCurrent();
               RecordOrderModified();
               DB_RecordOrderModified(ticket, currentPrice, newPrice, currentSL, newSL, "Price adjustment");
               Print("🔄 BUY STOP modified to ", newPrice);
            }
         }
      }
      
      if(orderInfo.OrderType() == ORDER_TYPE_SELL_STOP)
      {
         double currentPrice = orderInfo.PriceOpen();
         double currentSL = orderInfo.StopLoss();
         double newPrice = NormalizeDouble(bid - AdjustedOrderDistance, SymDigits);
         
         if(MathAbs(newPrice - currentPrice) > AdjustedOrderDistance * 0.1)
         {
            double newSL = NormalizeDouble(newPrice + CalculatedStopLoss, SymDigits);
            ulong ticket = orderInfo.Ticket();
            if(trade.OrderModify(ticket, newPrice, newSL, 0, ORDER_TIME_GTC, 0))
            {
               LastModificationTime = TimeCurrent();
               RecordOrderModified();
               DB_RecordOrderModified(ticket, currentPrice, newPrice, currentSL, newSL, "Price adjustment");
               Print("🔄 SELL STOP modified to ", newPrice);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for Scale In                                               |
//+------------------------------------------------------------------+
void CheckForScaleIn()
{
   if(!EnableScaling) return;
   
   // Scale into BUY positions
   if(OpenBuyCount > 0 && OpenBuyCount < MaxScalePositions)
   {
      // Only scale if original SL hasn't started trailing
      bool originalSLActive = (CurrentBuyStopLoss > 0);
      
      if(originalSLActive && TotalBuyCount < MaxScalePositions)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double buyPrice = NormalizeDouble(ask + AdjustedOrderDistance, SymDigits);
         double buySL = NormalizeDouble(buyPrice - CalculatedStopLoss, SymDigits);
         double lotSize = CalculateLotSize();
         
         if(trade.BuyStop(lotSize, buyPrice, _Symbol, buySL, 0, ORDER_TIME_GTC, 0, "HFT_SCALE_BUY"))
         {
            ulong ticket = trade.ResultOrder();
            SessionTradeCount++;
            RecordOrderPlaced();
            DB_RecordOrderPlaced(ticket, "BUY_STOP", lotSize, buyPrice, buySL, 0, "HFT_SCALE_BUY");
            Print("📈 SCALE IN: BUY STOP placed");
         }
      }
   }
   
   // Scale into SELL positions
   if(OpenSellCount > 0 && OpenSellCount < MaxScalePositions)
   {
      bool originalSLActive = (CurrentSellStopLoss > 0);
      
      if(originalSLActive && TotalSellCount < MaxScalePositions)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sellPrice = NormalizeDouble(bid - AdjustedOrderDistance, SymDigits);
         double sellSL = NormalizeDouble(sellPrice + CalculatedStopLoss, SymDigits);
         double lotSize = CalculateLotSize();
         
         if(trade.SellStop(lotSize, sellPrice, _Symbol, sellSL, 0, ORDER_TIME_GTC, 0, "HFT_SCALE_SELL"))
         {
            ulong ticket = trade.ResultOrder();
            SessionTradeCount++;
            RecordOrderPlaced();
            DB_RecordOrderPlaced(ticket, "SELL_STOP", lotSize, sellPrice, sellSL, 0, "HFT_SCALE_SELL");
            Print("📉 SCALE IN: SELL STOP placed");
         }
      }
   }
}

#endif // HFT_ORDERS_MQH
//+------------------------------------------------------------------+
