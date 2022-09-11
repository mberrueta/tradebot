# Tradebot

[Tutorial](https://book.elixircryptobot.com/)

## Apps

### Streamer (1)

[Chapter 1](https://book.elixircryptobot.com/stream-live-cryptocurrency-prices-from-the-binance-wss.html)

Chapter 1 Stream live cryptocurrency prices from the Binance WSS
1.1 Objectives

- create a new umbrella app
- create a supervised application inside an umbrella
- connect to Binance’s WebSocket Stream using the WebSockex module
- define a TradeEvent struct that will hold incoming data
- decode incoming events using the Jason module


 Connect to [Binance API Web Socket Stream (wss)](https://github.com/binance/binance-spot-api-docs/blob/master/web-socket-streams.md)

- The base endpoint is: `wss://stream.binance.com:9443`
- Raw streams are accessed at `/ws/<streamName>`
- All symbols for streams are lowercase
- Stream Name: <symbol>@trade -> `wss://stream.binance.com:9443/ws/xrpusdt@trade`

#### Deps

- WebSocket To establish a connection to Binance API’s stream

### Strategy (2)

[Chapter 2 Create a naive trading strategy](https://book.elixircryptobot.com/create-a-naive-trading-strategy-a-single-trader-process-without-supervision.html) 

a single trader process without supervision
2.1 Objectives

- create another supervised application inside the umbrella to store our trading strategy
- define callbacks for events dependent on the state of the trader
- push events from the streamer app to the naive app

### Deps

- [binance API](https://github.com/dvcrn/binance.ex)
- [binance testnet](https://binance-docs.github.io/apidocs/spot/en/#test-new-order-trade)
- [binance academy](https://academy.binance.com/en/articles/binance-api-series-pt-1-spot-trading-with-postman)
- [binance create test wallet](https://academy.binance.com/en/articles/binance-dex-creating-a-wallet)
- [binance fund test account](https://academy.binance.com/en/articles/binance-dex-funding-your-testnet-account)
- decimal (avoid precisions issues)

## Run example

```elixir
# USE TEST NET!
iex> Naive.Trader.start_link(%{symbol: "BTCUSDT", profit_interval: "-0.01"})
iex> Streamer.Binance.start_link("BTCUSDT")
```

### PubSub (3)

[Chapter 3](https://book.elixircryptobot.com/introduce-pubsub-as-a-communication-method.html)

Currently `Streamer` -send_event-> Naive -GenServer.call-> Naive.Trader (single process)
To be able to run in parallel we need to remove the GenServer call process with a single name
Also remove the dependency between Streamer and Trader. 

Streamer will broadcast and the traders will subscribe

Streamer -broadcast-> PubSub -subscribe-> Trader1 
                             -subscribe-> Trader2 
                             -subscribe-> Trader3 
