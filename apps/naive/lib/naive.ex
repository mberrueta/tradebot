defmodule Naive do
  @moduledoc """

  Start the trader server

  Naive.Trader.start_link(%{symbol: "XRPUSDT", profit_interval: "-0.01"})

  """

  alias Streamer.Binance.TradeEvent

  def send_event(%TradeEvent{} = event) do
    GenServer.cast(:trader, event)
  end
end
