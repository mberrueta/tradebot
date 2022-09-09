defmodule Naive.Trader do
  @moduledoc """
  Trader process.

  # States

    - New trader (buyer_order_id and sell_order_id nil)
    - Buy placed (buyer_order_id not nil)
    - Sell placed (sell_order_id not nil)
  """

  use GenServer

  require Logger

  alias Streamer.Binance.TradeEvent
  alias Decimal, as: D

  defmodule State do
    @moduledoc """
    State of the server

    What symbol does it need to trade ('symbol' for example 'XRPUSDT')
    Placed buy order (if any)
    Placed sell order (if any)
    Profit interval (what net profit % we would like to achieve when buying and selling an asset - single trade cycle)
    tick_size (it is the smallest acceptable price movement up or down. for example tick size for USD is a single cent)
    """

    @enforce_keys [:symbol, :profit_interval, :tick_size]
    defstruct [
      :symbol,
      :buy_order,
      :sell_order,
      :profit_interval,
      :tick_size
    ]
  end

  @doc """
  Convention to allows us to register the process with a name
  Default function that the Supervisor will use when starting the Trader
  """
  def start_link(%{} = args) do
    GenServer.start_link(__MODULE__, args, name: :trader)
  end

  def init(%{symbol: symbol, profit_interval: profit_interval}) do
    symbol = symbol |> String.upcase()
    Logger.info("Initializing new trader for #{symbol}")

    tick_size = fetch_tick_size(symbol)

    {
      :ok,
      %State{
        symbol: symbol,
        profit_interval: profit_interval,
        tick_size: tick_size
      }
    }
  end

  # New trader, we will pattern match on buy_order: nil
  def handle_cast(
        %TradeEvent{price: price},
        %State{symbol: symbol, buy_order: nil} = state
      ) do
    # hardcoded for now
    quantity = "100"

    Logger.info("Placing BUY order for #{symbol} @ #{price}, quantity: #{quantity}")

    {:ok, %Binance.OrderResponse{} = order} =
      Binance.order_limit_buy(symbol, quantity, price, "GTC")

    {:noreply, %{state | buy_order: order}}
  end

  # Our buy order got filled (order_id and quantity matches)
  def handle_cast(
        %TradeEvent{
          buyer_order_id: order_id,
          quantity: quantity
        },
        %State{
          symbol: symbol,
          buy_order: %Binance.OrderResponse{
            price: buy_price,
            order_id: order_id,
            orig_qty: quantity
          },
          profit_interval: profit_interval,
          tick_size: tick_size
        } = state
      ) do
    sell_price = calculate_sell_price(buy_price, profit_interval, tick_size)

    Logger.info(
      "Buy order filled, placing a SELL order for " <>
        "#{symbol} @ #{sell_price}, quantity: #{quantity}"
    )

    {:ok, %Binance.OrderResponse{} = order} =
      Binance.order_limit_sell(symbol, quantity, sell_price, "GTC")

    {:noreply, %{state | sell_order: order}}
  end

  # Our buy order sell was filled (order_id and quantity matches)
  def handle_cast(
        %TradeEvent{
          seller_order_id: order_id,
          quantity: quantity
        },
        %State{
          sell_order: %Binance.OrderResponse{
            order_id: order_id,
            orig_qty: quantity
          }
        } = state
      ) do
    Logger.info("Trade finished, trader will now exit ")

    {:stop, :normal, state}
  end

  # Fallback (no previous match)
  def handle_cast(%TradeEvent{}, state) do
    {:noreply, false}
  end

  #  Binance.get_exchange_info()
  #  {:ok, %{
  #        ...
  #        symbols: [
  #        %{
  #        "symbol": "ETHUSDT",
  #         ...
  #        "filters": [
  #        ...
  #        %{"filterType: "PRICE_FILTER", "tickSize": tickSize, ...}
  #      ],
  #      ...
  #    }
  #  ]
  # }}
  defp fetch_tick_size(symbol) do
    Binance.get_exchange_info()
    |> elem(1)
    |> Map.get(:symbol)
    |> Enum.find(&(&1["symbol"] == symbol))
    |> Map.get("filters")
    |> Enum.find(&(&1["filterType"] == "PRICE_FILTER"))
    |> Map.get("tickSize")
  end

  defp calculate_sell_price(buy_price, profit_interval, tick_size) do
    # hardcoded for now
    fee = "1.001"

    # price + fee
    original_price = D.mult(buy_price, fee)

    # paid price + profit
    net_target_price =
      D.mult(
        original_price,
        D.add("1.0", profit_interval)
      )

    # sell price + fee
    gross_target_price = D.mult(net_target_price, fee)

    # normalize the tick size by symbol (Binance won’t accept any prices that aren’t divisible)
    D.to_string(
      D.mult(
        D.div_int(gross_target_price, tick_size),
        tick_size
      ),
      :normal
    )
  end
end