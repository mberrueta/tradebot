defmodule Naive do
  def trade(symbol, profit) do
    Naive.Trader.start_link(%{symbol: symbol, profit_interval: profit})
  end
end
