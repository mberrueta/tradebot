defmodule Streamer.Binance do
  @moduledoc """
  Implement the WebSocket behavior for [Binance streams](https://github.com/binance/binance-spot-api-docs/blob/master/web-socket-streams.md)
  Use [WebSockex](https://github.com/Azolo/websockex) to connect to stream

  # usage

  ```shell
  iex(3)> Streamer.Binance.start_link("xrpusdt")
  {:ok, #PID<0.291.0>}
  Received Message - Type: :text -- Message: "{"e":"trade","E":1662712363477,"s":"XRPUSDT","t":467097955,"p":"0.35100000","q":"2955.00000000","b":4630453826,"a":4630453399,"T":1662712363477,"m":false,"M":true}"
  Received Message - Type: :text -- Message: "{"e":"trade","E":1662712363477,"s":"XRPUSDT","t":467097956,"p":"0.35100000","q":"1320.00000000","b":4630453826,"a":4630453406,"T":1662712363477,"m":false,"M":true}"
  ```
  """
  use WebSockex

  require Logger

  @stream_endpoint "wss://stream.binance.com:9443/ws"

  @doc """
  Connect to stream by symbol

  iex(3)> Streamer.Binance.start_link("xrpusdt")
  """
  def start_link(symbol) do
    symbol = String.downcase(symbol)

    WebSockex.start_link(
      "#{@stream_endpoint}/#{symbol}@trade",
      __MODULE__,
      nil
    )
  end

  @doc """
  Callback to be called with the message and the process’ state.

  message:
    {
    "e": "trade",     // Event type
    "E": 123456789,   // Event time
    "s": "BNBBTC",    // Symbol
    "t": 12345,       // Trade ID
    "p": "0.001",     // Price
    "q": "100",       // Quantity
    "b": 88,          // Buyer order ID
    "a": 50,          // Seller order ID
    "T": 123456785,   // Trade time
    "m": true,        // Is the buyer the market maker?
    "M": true         // Ignore
    }
  """
  def handle_frame({_type, msg}, state) do
    # IO.puts "Received Message - Type: #{inspect type} -- Message: #{inspect msg}"

    case Jason.decode(msg) do
      {:ok, event} -> process_event(event)
      {:error, _} -> Logger.error("Unable to parse msg: #{msg}")
    end

    {:ok, state}
  end

  #  we won't send messages back
  #  no place order needed
  #  def handle_cast({:sent, {type, msg} = frame}, state) do
  #    IO.puts "Sending #{type} frame with payload: #{msg}"
  #    {:reply, frame, state}
  #  end

  defp process_event(event) do
    trade_event = %Streamer.Binance.TradeEvent{
      event_type: event["e"],
      event_time: event["E"],
      symbol: event["s"],
      trade_id: event["t"],
      price: event["p"],
      quantity: event["q"],
      buyer_order_id: event["b"],
      seller_order_id: event["a"],
      trade_time: event["T"],
      buyer_market_maker: event["m"]
    }

    Logger.debug("Trade received " <> "#{trade_event.symbol}@#{trade_event.price}")
  end
end
