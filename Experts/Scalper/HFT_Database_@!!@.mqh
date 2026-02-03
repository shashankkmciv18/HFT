//+------------------------------------------------------------------+
//|                                                 HFT_Database.mqh |
//|                                         Copyright 2026, YourName |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, YourName"
#property link      "https://mql5.com"

#ifndef HFT_DATABASE_MQH
#define HFT_DATABASE_MQH

#include "HFT_Globals.mqh"
#include "HFT_Inputs.mqh"

//+------------------------------------------------------------------+
//| Database Handle                                                  |
//+------------------------------------------------------------------+
int DatabaseHandle = INVALID_HANDLE;
string DatabasePath = "";
bool DatabaseEnabled = true;

//+------------------------------------------------------------------+
//| Initialize Database                                              |
//+------------------------------------------------------------------+
bool InitializeDatabase()
{
   // Create database filename with symbol
   DatabasePath = "HFT_" + _Symbol + ".sqlite";
   
   // Open or create database in common folder
   DatabaseHandle = DatabaseOpen(DatabasePath, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE | DATABASE_OPEN_COMMON);
   
   if(DatabaseHandle == INVALID_HANDLE)
   {
      Print("❌ Database: Failed to open/create database. Error: ", GetLastError());
      DatabaseEnabled = false;
      return false;
   }
   
   Print("✅ Database: Opened successfully - ", DatabasePath);
   
   // Create tables
   if(!CreateTables())
   {
      Print("❌ Database: Failed to create tables");
      DatabaseEnabled = false;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Create Database Tables                                           |
//+------------------------------------------------------------------+
bool CreateTables()
{
   string sql;
   
   //--- Sessions Table
   sql = "CREATE TABLE IF NOT EXISTS sessions ("
         "id INTEGER PRIMARY KEY AUTOINCREMENT,"
         "session_date TEXT NOT NULL,"
         "start_time TEXT NOT NULL,"
         "end_time TEXT,"
         "symbol TEXT NOT NULL,"
         "magic INTEGER NOT NULL,"
         "start_balance REAL,"
         "end_balance REAL,"
         "total_pnl REAL DEFAULT 0,"
         "total_trades INTEGER DEFAULT 0,"
         "total_orders_placed INTEGER DEFAULT 0,"
         "total_orders_modified INTEGER DEFAULT 0,"
         "winning_trades INTEGER DEFAULT 0,"
         "losing_trades INTEGER DEFAULT 0,"
         "max_drawdown REAL DEFAULT 0,"
         "status TEXT DEFAULT 'ACTIVE'"
         ");";
   
   if(!DatabaseExecute(DatabaseHandle, sql))
   {
      Print("❌ Database: Failed to create sessions table. Error: ", GetLastError());
      return false;
   }
   
   //--- Orders Table
   sql = "CREATE TABLE IF NOT EXISTS orders ("
         "id INTEGER PRIMARY KEY AUTOINCREMENT,"
         "ticket INTEGER NOT NULL,"
         "session_id INTEGER,"
         "symbol TEXT NOT NULL,"
         "magic INTEGER NOT NULL,"
         "order_type TEXT NOT NULL,"
         "action TEXT NOT NULL,"
         "lot_size REAL,"
         "price REAL,"
         "stop_loss REAL,"
         "take_profit REAL,"
         "spread REAL,"
         "timestamp TEXT NOT NULL,"
         "comment TEXT,"
         "FOREIGN KEY (session_id) REFERENCES sessions(id)"
         ");";
   
   if(!DatabaseExecute(DatabaseHandle, sql))
   {
      Print("❌ Database: Failed to create orders table. Error: ", GetLastError());
      return false;
   }
   
   //--- Trades Table (Closed Positions)
   sql = "CREATE TABLE IF NOT EXISTS trades ("
         "id INTEGER PRIMARY KEY AUTOINCREMENT,"
         "ticket INTEGER NOT NULL,"
         "position_id INTEGER,"
         "session_id INTEGER,"
         "symbol TEXT NOT NULL,"
         "magic INTEGER NOT NULL,"
         "trade_type TEXT NOT NULL,"
         "lot_size REAL,"
         "open_price REAL,"
         "close_price REAL,"
         "stop_loss REAL,"
         "take_profit REAL,"
         "open_time TEXT,"
         "close_time TEXT,"
         "duration_seconds INTEGER,"
         "profit REAL,"
         "commission REAL,"
         "swap REAL,"
         "spread_at_open REAL,"
         "spread_at_close REAL,"
         "comment TEXT,"
         "FOREIGN KEY (session_id) REFERENCES sessions(id)"
         ");";
   
   if(!DatabaseExecute(DatabaseHandle, sql))
   {
      Print("❌ Database: Failed to create trades table. Error: ", GetLastError());
      return false;
   }
   
   //--- Order Modifications Table
   sql = "CREATE TABLE IF NOT EXISTS order_modifications ("
         "id INTEGER PRIMARY KEY AUTOINCREMENT,"
         "order_ticket INTEGER NOT NULL,"
         "session_id INTEGER,"
         "symbol TEXT NOT NULL,"
         "old_price REAL,"
         "new_price REAL,"
         "old_sl REAL,"
         "new_sl REAL,"
         "timestamp TEXT NOT NULL,"
         "reason TEXT,"
         "FOREIGN KEY (session_id) REFERENCES sessions(id)"
         ");";
   
   if(!DatabaseExecute(DatabaseHandle, sql))
   {
      Print("❌ Database: Failed to create order_modifications table. Error: ", GetLastError());
      return false;
   }
   
   //--- Ticks/Signals Table (for analysis)
   sql = "CREATE TABLE IF NOT EXISTS signals ("
         "id INTEGER PRIMARY KEY AUTOINCREMENT,"
         "session_id INTEGER,"
         "timestamp TEXT NOT NULL,"
         "symbol TEXT NOT NULL,"
         "bid REAL,"
         "ask REAL,"
         "spread REAL,"
         "atr REAL,"
         "adx REAL,"
         "vwap REAL,"
         "signal_type TEXT,"
         "action_taken TEXT,"
         "reason TEXT,"
         "FOREIGN KEY (session_id) REFERENCES sessions(id)"
         ");";
   
   if(!DatabaseExecute(DatabaseHandle, sql))
   {
      Print("❌ Database: Failed to create signals table. Error: ", GetLastError());
      return false;
   }
   
   //--- Performance Snapshots Table (periodic stats)
   sql = "CREATE TABLE IF NOT EXISTS performance_snapshots ("
         "id INTEGER PRIMARY KEY AUTOINCREMENT,"
         "session_id INTEGER,"
         "timestamp TEXT NOT NULL,"
         "equity REAL,"
         "balance REAL,"
         "floating_pnl REAL,"
         "open_positions INTEGER,"
         "pending_orders INTEGER,"
         "trades_1min INTEGER,"
         "trades_5min INTEGER,"
         "trades_10min INTEGER,"
         "pnl_1min REAL,"
         "pnl_5min REAL,"
         "pnl_10min REAL,"
         "FOREIGN KEY (session_id) REFERENCES sessions(id)"
         ");";
   
   if(!DatabaseExecute(DatabaseHandle, sql))
   {
      Print("❌ Database: Failed to create performance_snapshots table. Error: ", GetLastError());
      return false;
   }
   
   Print("✅ Database: All tables created successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Current Session ID                                               |
//+------------------------------------------------------------------+
int CurrentSessionID = 0;

//+------------------------------------------------------------------+
//| Start New Session in Database                                    |
//+------------------------------------------------------------------+
int DB_StartSession()
{
   if(!DatabaseEnabled || DatabaseHandle == INVALID_HANDLE) return 0;
   
   string sql = StringFormat(
      "INSERT INTO sessions (session_date, start_time, symbol, magic, start_balance, status) "
      "VALUES ('%s', '%s', '%s', %d, %.2f, 'ACTIVE');",
      TimeToString(TimeCurrent(), TIME_DATE),
      TimeToString(TimeCurrent(), TIME_MINUTES),
      _Symbol,
      InpMagic,
      AccountInfoDouble(ACCOUNT_EQUITY)
   );
   
   if(!DatabaseExecute(DatabaseHandle, sql))
   {
      Print("❌ Database: Failed to start session. Error: ", GetLastError());
      return 0;
   }
   
   // Get the session ID
   sql = "SELECT last_insert_rowid();";
   int request = DatabasePrepare(DatabaseHandle, sql);
   
   if(request != INVALID_HANDLE && DatabaseRead(request))
   {
      DatabaseColumnInteger(request, 0, CurrentSessionID);
      DatabaseFinalize(request);
   }
   
   Print("✅ Database: Session started with ID: ", CurrentSessionID);
   return CurrentSessionID;
}

//+------------------------------------------------------------------+
//| End Session in Database                                          |
//+------------------------------------------------------------------+
void DB_EndSession(double totalPNL, int totalTrades, int ordersPlaced, int ordersModified, int wins, int losses)
{
   if(!DatabaseEnabled || DatabaseHandle == INVALID_HANDLE || CurrentSessionID == 0) return;
   
   string sql = StringFormat(
      "UPDATE sessions SET "
      "end_time = '%s', "
      "end_balance = %.2f, "
      "total_pnl = %.2f, "
      "total_trades = %d, "
      "total_orders_placed = %d, "
      "total_orders_modified = %d, "
      "winning_trades = %d, "
      "losing_trades = %d, "
      "status = 'COMPLETED' "
      "WHERE id = %d;",
      TimeToString(TimeCurrent(), TIME_MINUTES),
      AccountInfoDouble(ACCOUNT_EQUITY),
      totalPNL,
      totalTrades,
      ordersPlaced,
      ordersModified,
      wins,
      losses,
      CurrentSessionID
   );
   
   if(!DatabaseExecute(DatabaseHandle, sql))
      Print("❌ Database: Failed to end session. Error: ", GetLastError());
   else
      Print("✅ Database: Session ended successfully");
}

//+------------------------------------------------------------------+
//| Record Order Placed                                              |
//+------------------------------------------------------------------+
void DB_RecordOrderPlaced(ulong ticket, string orderType, double lots, double price, double sl, double tp, string comment = "")
{
   if(!DatabaseEnabled || DatabaseHandle == INVALID_HANDLE) return;
   
   string sql = StringFormat(
      "INSERT INTO orders (ticket, session_id, symbol, magic, order_type, action, lot_size, price, stop_loss, take_profit, spread, timestamp, comment) "
      "VALUES (%I64u, %d, '%s', %d, '%s', 'PLACED', %.2f, %.5f, %.5f, %.5f, %.5f, '%s', '%s');",
      ticket,
      CurrentSessionID,
      _Symbol,
      InpMagic,
      orderType,
      lots,
      price,
      sl,
      tp,
      CurrentSpread,
      TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      comment
   );
   
   if(!DatabaseExecute(DatabaseHandle, sql))
      Print("❌ Database: Failed to record order. Error: ", GetLastError());
}

//+------------------------------------------------------------------+
//| Record Order Modified                                            |
//+------------------------------------------------------------------+
void DB_RecordOrderModified(ulong ticket, double oldPrice, double newPrice, double oldSL, double newSL, string reason = "")
{
   if(!DatabaseEnabled || DatabaseHandle == INVALID_HANDLE) return;
   
   // Record in orders table
   string sql = StringFormat(
      "INSERT INTO orders (ticket, session_id, symbol, magic, order_type, action, price, stop_loss, spread, timestamp, comment) "
      "VALUES (%I64u, %d, '%s', %d, 'MODIFICATION', 'MODIFIED', %.5f, %.5f, %.5f, '%s', '%s');",
      ticket,
      CurrentSessionID,
      _Symbol,
      InpMagic,
      newPrice,
      newSL,
      CurrentSpread,
      TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      reason
   );
   
   if(!DatabaseExecute(DatabaseHandle, sql))
      Print("❌ Database: Failed to record order modification. Error: ", GetLastError());
   
   // Also record in modifications table for detailed tracking
   sql = StringFormat(
      "INSERT INTO order_modifications (order_ticket, session_id, symbol, old_price, new_price, old_sl, new_sl, timestamp, reason) "
      "VALUES (%I64u, %d, '%s', %.5f, %.5f, %.5f, %.5f, '%s', '%s');",
      ticket,
      CurrentSessionID,
      _Symbol,
      oldPrice,
      newPrice,
      oldSL,
      newSL,
      TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      reason
   );
   
   DatabaseExecute(DatabaseHandle, sql);
}

//+------------------------------------------------------------------+
//| Record Order Cancelled                                           |
//+------------------------------------------------------------------+
void DB_RecordOrderCancelled(ulong ticket, string orderType, string reason = "")
{
   if(!DatabaseEnabled || DatabaseHandle == INVALID_HANDLE) return;
   
   string sql = StringFormat(
      "INSERT INTO orders (ticket, session_id, symbol, magic, order_type, action, timestamp, comment) "
      "VALUES (%I64u, %d, '%s', %d, '%s', 'CANCELLED', '%s', '%s');",
      ticket,
      CurrentSessionID,
      _Symbol,
      InpMagic,
      orderType,
      TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      reason
   );
   
   if(!DatabaseExecute(DatabaseHandle, sql))
      Print("❌ Database: Failed to record order cancellation. Error: ", GetLastError());
}

//+------------------------------------------------------------------+
//| Record Trade (Closed Position)                                   |
//+------------------------------------------------------------------+
void DB_RecordTrade(ulong ticket, ulong positionID, string tradeType, double lots, 
                    double openPrice, double closePrice, double sl, double tp,
                    datetime openTime, datetime closeTime, double profit, 
                    double commission, double swap, string comment = "")
{
   if(!DatabaseEnabled || DatabaseHandle == INVALID_HANDLE) return;
   
   int duration = (int)(closeTime - openTime);
   
   string sql = StringFormat(
      "INSERT INTO trades (ticket, position_id, session_id, symbol, magic, trade_type, lot_size, "
      "open_price, close_price, stop_loss, take_profit, open_time, close_time, duration_seconds, "
      "profit, commission, swap, comment) "
      "VALUES (%I64u, %I64u, %d, '%s', %d, '%s', %.2f, %.5f, %.5f, %.5f, %.5f, '%s', '%s', %d, %.2f, %.2f, %.2f, '%s');",
      ticket,
      positionID,
      CurrentSessionID,
      _Symbol,
      InpMagic,
      tradeType,
      lots,
      openPrice,
      closePrice,
      sl,
      tp,
      TimeToString(openTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      TimeToString(closeTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      duration,
      profit,
      commission,
      swap,
      comment
   );
   
   if(!DatabaseExecute(DatabaseHandle, sql))
      Print("❌ Database: Failed to record trade. Error: ", GetLastError());
}

//+------------------------------------------------------------------+
//| Record Signal/Tick Data                                          |
//+------------------------------------------------------------------+
void DB_RecordSignal(string signalType, string actionTaken, string reason, 
                     double atr = 0, double adx = 0, double vwap = 0)
{
   if(!DatabaseEnabled || DatabaseHandle == INVALID_HANDLE) return;
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   string sql = StringFormat(
      "INSERT INTO signals (session_id, timestamp, symbol, bid, ask, spread, atr, adx, vwap, signal_type, action_taken, reason) "
      "VALUES (%d, '%s', '%s', %.5f, %.5f, %.5f, %.5f, %.1f, %.5f, '%s', '%s', '%s');",
      CurrentSessionID,
      TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      _Symbol,
      bid,
      ask,
      CurrentSpread,
      atr,
      adx,
      vwap,
      signalType,
      actionTaken,
      reason
   );
   
   DatabaseExecute(DatabaseHandle, sql);
}

//+------------------------------------------------------------------+
//| Record Performance Snapshot                                      |
//+------------------------------------------------------------------+
void DB_RecordPerformanceSnapshot(int trades1m, int trades5m, int trades10m,
                                   double pnl1m, double pnl5m, double pnl10m)
{
   if(!DatabaseEnabled || DatabaseHandle == INVALID_HANDLE) return;
   
   string sql = StringFormat(
      "INSERT INTO performance_snapshots (session_id, timestamp, equity, balance, floating_pnl, "
      "open_positions, pending_orders, trades_1min, trades_5min, trades_10min, pnl_1min, pnl_5min, pnl_10min) "
      "VALUES (%d, '%s', %.2f, %.2f, %.2f, %d, %d, %d, %d, %d, %.2f, %.2f, %.2f);",
      CurrentSessionID,
      TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      AccountInfoDouble(ACCOUNT_EQUITY),
      AccountInfoDouble(ACCOUNT_BALANCE),
      AccountInfoDouble(ACCOUNT_EQUITY) - AccountInfoDouble(ACCOUNT_BALANCE),
      OpenBuyCount + OpenSellCount,
      TotalBuyCount + TotalSellCount - OpenBuyCount - OpenSellCount,
      trades1m,
      trades5m,
      trades10m,
      pnl1m,
      pnl5m,
      pnl10m
   );
   
   DatabaseExecute(DatabaseHandle, sql);
}

//+------------------------------------------------------------------+
//| Close Database                                                   |
//+------------------------------------------------------------------+
void CloseDatabase()
{
   if(DatabaseHandle != INVALID_HANDLE)
   {
      DatabaseClose(DatabaseHandle);
      DatabaseHandle = INVALID_HANDLE;
      Print("✅ Database: Closed successfully");
   }
}

//+------------------------------------------------------------------+
//| Get Session Statistics from Database                             |
//+------------------------------------------------------------------+
bool DB_GetSessionStats(int sessionID, double &totalPNL, int &totalTrades, int &wins, int &losses)
{
   if(!DatabaseEnabled || DatabaseHandle == INVALID_HANDLE) return false;
   
   string sql = StringFormat(
      "SELECT SUM(profit), COUNT(*), "
      "SUM(CASE WHEN profit > 0 THEN 1 ELSE 0 END), "
      "SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) "
      "FROM trades WHERE session_id = %d;",
      sessionID
   );
   
   int request = DatabasePrepare(DatabaseHandle, sql);
   if(request == INVALID_HANDLE) return false;
   
   if(DatabaseRead(request))
   {
      DatabaseColumnDouble(request, 0, totalPNL);
      DatabaseColumnInteger(request, 1, totalTrades);
      DatabaseColumnInteger(request, 2, wins);
      DatabaseColumnInteger(request, 3, losses);
   }
   
   DatabaseFinalize(request);
   return true;
}

//+------------------------------------------------------------------+
//| Execute Custom Query                                             |
//+------------------------------------------------------------------+
bool DB_ExecuteQuery(string sql)
{
   if(!DatabaseEnabled || DatabaseHandle == INVALID_HANDLE) return false;
   return DatabaseExecute(DatabaseHandle, sql);
}

#endif // HFT_DATABASE_MQH
//+------------------------------------------------------------------+
