# Tradebot

[Tutorial](https://book.elixircryptobot.com/)

## Apps

### Streamer

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

### Strategy

Chapter 2 Create a naive trading strategy - a single trader process without supervision
2.1 Objectives

- create another supervised application inside the umbrella to store our trading strategy
- define callbacks for events dependent on the state of the trader
- push events from the streamer app to the naive app

### Deps

- [binance API](https://github.com/dvcrn/binance.ex)
- decimal (avoid precisions issues)
