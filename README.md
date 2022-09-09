# Tradebot

[Tutorial](https://book.elixircryptobot.com/)

## Apps

### Streamer

 Connect to [Binance API Web Socket Stream (wss)](https://github.com/binance/binance-spot-api-docs/blob/master/web-socket-streams.md)

- The base endpoint is: `wss://stream.binance.com:9443`
- Raw streams are accessed at `/ws/<streamName>`
- All symbols for streams are lowercase
- Stream Name: <symbol>@trade -> `wss://stream.binance.com:9443/ws/xrpusdt@trade`

#### Deps

- WebSocket To establish a connection to Binance API’s stream
