#property copyright "Trading Demo"
#property version   "1.00"
#property strict
#property description "Read-only MT5 quote and candle bridge for Trading Demo."
#property description "Add ApiBaseUrl to Tools > Options > Expert Advisors > allowed WebRequest URLs."

input string ApiBaseUrl = "https://api.example.com";
input string FeedKey = "";
input string SymbolMappings = "XAUUSD+=XAUUSD";
input int TickIntervalMilliseconds = 50;
input int MaximumBatchTicks = 256;
input int HistoryBars = 500;
input bool SeedHistory = true;

struct SymbolMapping
  {
   string            app_symbol;
   string            broker_symbol;
   long              first_time_msc;
   long              last_time_msc;
  };

struct PendingBridgeTick
  {
   int               mapping_index;
   double            bid;
   double            ask;
   long              time_msc;
   int               digits;
  };

SymbolMapping mappings[];
bool seed_pending = true;
datetime next_seed_attempt = 0;

ENUM_TIMEFRAMES bridge_timeframes[9] =
  {
   PERIOD_M1,
   PERIOD_M5,
   PERIOD_M15,
   PERIOD_M30,
   PERIOD_H1,
   PERIOD_H4,
   PERIOD_D1,
   PERIOD_W1,
   PERIOD_MN1
  };

string bridge_timeframe_names[9] =
  {
   "M1",
   "M5",
   "M15",
   "M30",
   "H1",
   "H4",
   "D1",
   "W1",
   "MN"
  };

int OnInit()
  {
   if(StringLen(FeedKey)<16)
     {
      Print("TradingDemoMarketBridge: FeedKey must contain at least 16 characters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(StringFind(ApiBaseUrl,"http://")!=0 && StringFind(ApiBaseUrl,"https://")!=0)
     {
      Print("TradingDemoMarketBridge: ApiBaseUrl must begin with http:// or https://.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ParseMappings())
      return INIT_PARAMETERS_INCORRECT;

   for(int index=0; index<ArraySize(mappings); index++)
     {
      if(!SymbolSelect(mappings[index].broker_symbol,true))
         PrintFormat("TradingDemoMarketBridge: cannot select broker symbol %s (error %d).",
                     mappings[index].broker_symbol,
                     GetLastError());

      MqlTick current={};
      if(SymbolInfoTick(mappings[index].broker_symbol,current) && current.time_msc>0)
         mappings[index].first_time_msc=current.time_msc;
     }

   int interval=MathMax(50,TickIntervalMilliseconds);
   if(!EventSetMillisecondTimer(interval))
     {
      PrintFormat("TradingDemoMarketBridge: cannot start timer (error %d).",GetLastError());
      return INIT_FAILED;
     }

   seed_pending=SeedHistory;
   next_seed_attempt=TimeCurrent();
   PrintFormat("TradingDemoMarketBridge started for %d symbol mapping(s).",ArraySize(mappings));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

void OnTimer()
  {
   if(seed_pending && TimeCurrent()>=next_seed_attempt)
     {
      seed_pending=!SeedAllHistory();
      next_seed_attempt=TimeCurrent()+30;
     }

   PendingBridgeTick batch[];
   int count=CollectTickBatch(batch);
   if(count<=0 || !SendTickBatch(batch,count))
      return;

   for(int index=0; index<count; index++)
     {
      int mapping_index=batch[index].mapping_index;
      if(batch[index].time_msc>mappings[mapping_index].last_time_msc)
         mappings[mapping_index].last_time_msc=batch[index].time_msc;
     }
  }

bool ParseMappings()
  {
   string entries[];
   int count=StringSplit(SymbolMappings,StringGetCharacter(";",0),entries);
   if(count<=0)
     {
      Print("TradingDemoMarketBridge: SymbolMappings is empty.");
      return false;
     }

   ArrayResize(mappings,count);
   int mapped=0;
   for(int index=0; index<count; index++)
     {
      string entry=Trim(entries[index]);
      if(StringLen(entry)==0)
         continue;

      string parts[];
      int part_count=StringSplit(entry,StringGetCharacter("=",0),parts);
      string app_symbol=Trim(parts[0]);
      string broker_symbol=part_count>1 ? Trim(parts[1]) : app_symbol;
      if(StringLen(app_symbol)==0 || StringLen(broker_symbol)==0)
         continue;

      mappings[mapped].app_symbol=app_symbol;
      mappings[mapped].broker_symbol=broker_symbol;
      mappings[mapped].first_time_msc=0;
      mappings[mapped].last_time_msc=0;
      mapped++;
     }

   ArrayResize(mappings,mapped);
   if(mapped==0)
     {
      Print("TradingDemoMarketBridge: no valid symbol mappings were found.");
      return false;
     }
   return true;
  }

int CollectTickBatch(PendingBridgeTick &batch[])
  {
   ArrayResize(batch,0);
   int maximum=MathMax(1,MathMin(256,MaximumBatchTicks));
   int count=0;
   for(int mapping_index=0;
       mapping_index<ArraySize(mappings) && count<maximum;
       mapping_index++)
     {
      MqlTick current={};
      if(!SymbolInfoTick(mappings[mapping_index].broker_symbol,current) ||
         current.time_msc<=0)
         continue;

      if(mappings[mapping_index].first_time_msc<=0)
         mappings[mapping_index].first_time_msc=current.time_msc;

      long from_msc=mappings[mapping_index].last_time_msc>0
                    ? mappings[mapping_index].last_time_msc+1
                    : mappings[mapping_index].first_time_msc;
      if(from_msc>current.time_msc)
         continue;

      MqlTick ticks[];
      ArraySetAsSeries(ticks,false);
      ResetLastError();
      int copied=CopyTicksRange(mappings[mapping_index].broker_symbol,
                                ticks,
                                COPY_TICKS_ALL,
                                (ulong)from_msc,
                                (ulong)current.time_msc);
      if(copied<=0)
         continue;

      int remaining=maximum-count;
      int take=MathMin(copied,remaining);

      // Never split ticks that share one source millisecond across requests.
      // Otherwise advancing the millisecond cursor could skip the remainder.
      if(take<copied)
        {
         long next_time=ticks[take].time_msc;
         while(take>0 && ticks[take-1].time_msc==next_time)
            take--;
        }

      int digits=(int)SymbolInfoInteger(
         mappings[mapping_index].broker_symbol,
         SYMBOL_DIGITS);
      for(int tick_index=0; tick_index<take; tick_index++)
        {
         if(ticks[tick_index].time_msc<=0 ||
            ticks[tick_index].bid<=0 ||
            ticks[tick_index].ask<=0 ||
            ticks[tick_index].ask<ticks[tick_index].bid)
            continue;

         ArrayResize(batch,count+1);
         batch[count].mapping_index=mapping_index;
         batch[count].bid=ticks[tick_index].bid;
         batch[count].ask=ticks[tick_index].ask;
         batch[count].time_msc=ticks[tick_index].time_msc;
         batch[count].digits=digits;
         count++;
        }
     }

   return count;
  }

bool SendTickBatch(PendingBridgeTick &batch[],int count)
  {
   string source=AccountInfoString(ACCOUNT_COMPANY)+" / "+AccountInfoString(ACCOUNT_SERVER);
   string json="{\"ticks\":[";
   for(int index=0; index<count; index++)
     {
      if(index>0)
         json+=",";
      SymbolMapping mapping=mappings[batch[index].mapping_index];
      json+=
         "{\"symbol\":\""+JsonEscape(mapping.app_symbol)+"\","+
         "\"bid\":"+DoubleToString(batch[index].bid,batch[index].digits)+","+
         "\"ask\":"+DoubleToString(batch[index].ask,batch[index].digits)+","+
         "\"timeMsc\":"+LongToString(batch[index].time_msc)+","+
         "\"source\":\""+JsonEscape(source)+"\"}";
     }
   json+="]}";
   return PostJson("/api/market/feed/ticks/batch",json);
  }

bool SeedAllHistory()
  {
   bool all_seeded=true;
   for(int symbol_index=0; symbol_index<ArraySize(mappings); symbol_index++)
     {
      for(int timeframe_index=0; timeframe_index<ArraySize(bridge_timeframes); timeframe_index++)
        {
         if(!SeedOneSeries(mappings[symbol_index],
                           bridge_timeframes[timeframe_index],
                           bridge_timeframe_names[timeframe_index]))
            all_seeded=false;
        }
     }
   if(all_seeded)
      Print("TradingDemoMarketBridge: history seed completed.");
   return all_seeded;
  }

bool SeedOneSeries(const SymbolMapping &mapping,
                   ENUM_TIMEFRAMES timeframe,
                   string timeframe_name)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int requested=MathMax(50,MathMin(2000,HistoryBars));
   int copied=CopyRates(mapping.broker_symbol,timeframe,0,requested,rates);
   if(copied<=0)
     {
      PrintFormat("TradingDemoMarketBridge: waiting for %s %s history (error %d).",
                  mapping.broker_symbol,
                  timeframe_name,
                  GetLastError());
      return false;
     }

   int digits=(int)SymbolInfoInteger(mapping.broker_symbol,SYMBOL_DIGITS);
   string json=
      "{\"symbol\":\""+JsonEscape(mapping.app_symbol)+"\","+
      "\"timeframe\":\""+timeframe_name+"\","+
      "\"candles\":[";
   for(int index=0; index<copied; index++)
     {
      if(index>0)
         json+=",";
      json+=
         "{\"time\":"+LongToString((long)rates[index].time)+
         ",\"open\":"+DoubleToString(rates[index].open,digits)+
         ",\"high\":"+DoubleToString(rates[index].high,digits)+
         ",\"low\":"+DoubleToString(rates[index].low,digits)+
         ",\"close\":"+DoubleToString(rates[index].close,digits)+
         ",\"volume\":"+LongToString((long)rates[index].tick_volume)+"}";
     }
   json+="]}";
   return PostJson("/api/market/feed/candles/seed",json);
  }

bool PostJson(string path,string json)
  {
   string base_url=ApiBaseUrl;
   while(StringLen(base_url)>0 &&
         StringSubstr(base_url,StringLen(base_url)-1,1)=="/")
      base_url=StringSubstr(base_url,0,StringLen(base_url)-1);

   char body[];
   char result[];
   string response_headers;
   StringToCharArray(json,body,0,WHOLE_ARRAY,CP_UTF8);
   if(ArraySize(body)>0 && body[ArraySize(body)-1]==0)
      ArrayResize(body,ArraySize(body)-1);

   string headers=
      "Content-Type: application/json\r\n"+
      "X-Market-Feed-Key: "+FeedKey+"\r\n";
   ResetLastError();
   int status=WebRequest("POST",
                         base_url+path,
                         headers,
                         5000,
                         body,
                         result,
                         response_headers);
   if(status>=200 && status<300)
      return true;

   string response=CharArrayToString(result,0,WHOLE_ARRAY,CP_UTF8);
   PrintFormat("TradingDemoMarketBridge: POST %s failed, HTTP %d, error %d, response %s.",
               path,
               status,
               GetLastError(),
               response);
   return false;
  }

string Trim(string value)
  {
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
  }

string LongToString(long value)
  {
   return StringFormat("%I64d",value);
  }

string JsonEscape(string value)
  {
   StringReplace(value,"\\","\\\\");
   StringReplace(value,"\"","\\\"");
   StringReplace(value,"\r","\\r");
   StringReplace(value,"\n","\\n");
   return value;
  }
