defmodule BinanceMock do
  @moduledoc """
  Mock the Buy/Sell Binance
  """

  use GenServer

  alias Decimal, as: D
  alias Streamer.Binance.TradeEvent

  require Logger

  defmodule State do
    defstruct order_books: %{}, subscriptions: [], fake_order_id: 1
  end

  defmodule OrderBook do
    defstruct buy_side: [], sell_side: [], historical: []
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_args) do
    {:ok, %State{}}
  end

  #  Call the real (No need to mock, call real)
  def get_exchange_info, do: Binance.get_exchange_info()

  ####################################################################
  # Place BUY or SELL orders
  ####################################################################
  def order_limit_buy(symbol, quantity, price, "GTC") do
    order_limit(symbol, quantity, price, "BUY")
  end

  def order_limit_sell(symbol, quantity, price, "GTC") do
    order_limit(symbol, quantity, price, "SELL")
  end

  #  generate a fake order based on symbol, quantity, price, and side
  #  cast a message to the BinanceMock process to add the fake order
  #  return with a tuple with %OrderResponse{} struct to be consistent with the Binance module
  defp order_limit(symbol, quantity, price, side) do
    %Binance.Order{} = fake_order = generate_fake_order(symbol, quantity, price, side)

    GenServer.cast(__MODULE__, {:add_order, fake_order})

    {:ok, convert_order_to_order_response(fake_order)}
  end

  defp convert_order_to_order_response(%Binance.Order{} = order) do
    %{
      struct(
        Binance.OrderResponse,
        order |> Map.to_list()
      )
      | transact_time: order.time
    }
  end

  # callback to :add_order to the order book
  def handle_cast(
        {:add_order, %Binance.Order{symbol: symbol} = order},
        %State{order_books: order_books, subscriptions: subscriptions} = state
      ) do
    new_subscriptions = subscribe_to_topic(symbol, subscriptions)
    updated_order_books = add_order(order, order_books)

    {
      :noreply,
      %{
        state
        | order_books: updated_order_books,
          subscriptions: new_subscriptions
      }
    }
  end

  defp subscribe_to_topic(symbol, subscriptions) do
    symbol = String.upcase(symbol)
    stream_name = "TRADE_EVENTS:#{symbol}"

    # Will subscribe if is not already, otherwise ignore it
    case Enum.member?(subscriptions, symbol) do
      false ->
        Logger.debug("BinanceMock subscribing to #{stream_name}")

        Phoenix.PubSub.subscribe(Streamer.PubSub, stream_name)
        [symbol | subscriptions]

      _ ->
        subscriptions
    end
  end

  #  get the order book for the symbol of the order.
  #  Depends on the side of the order we will update either the buy_side or sell_side of the order_books
  defp add_order(%Binance.Order{symbol: symbol} = order, order_books) do
    order_book = order_books |> Map.get(:"#{symbol}", %OrderBook{})

    order_book =
      if order.side == 'SELL' do
        Map.replace!(
          order_book,
          :sell_side,
          [order | order_book.sell_side]
          |> Enum.sort(&D.lt?(&1.price, &2.price))
        )
      else
        Map.replace!(
          order_book,
          :buy_side,
          [order | order_book.buy_side]
          |> Enum.sort(&D.gt?(&1.price, &2.price))
        )
      end

    Map.put(order_books, :"#{symbol}", order_book)
  end

  defp generate_fake_order(symbol, quantity, price, side)
       when is_binary(symbol) and
              is_binary(quantity) and
              is_binary(price) and
              (side == "BUY" or side == "SELL") do
    current_timestamp = :os.system_time(:millisecond)
    order_id = GenServer.call(__MODULE__, :generate_id)
    client_order_id = :crypto.hash(:md5, "#{order_id}") |> Base.encode16()

    Binance.Order.new(%{
      symbol: symbol,
      order_id: order_id,
      client_order_id: client_order_id,
      price: price,
      orig_qty: quantity,
      executed_qty: "0.00000000",
      cummulative_quote_qty: "0.00000000",
      status: "NEW",
      time_in_force: "GTC",
      type: "LIMIT",
      side: side,
      stop_price: "0.00000000",
      iceberg_qty: "0.00000000",
      time: current_timestamp,
      update_time: current_timestamp,
      is_working: true
    })
  end

  # callback that will iterate the fake order id and return it:
  def handle_call(
        :generate_id,
        _from,
        %State{fake_order_id: id} = state
      ) do
    {:reply, id + 1, %{state | fake_order_id: id + 1}}
  end

  ####################################################################
  # order retrieval
  ####################################################################
  def get_order(symbol, time, order_id) do
    GenServer.call(__MODULE__, {:get_order, symbol, time, order_id})
  end

  def handle_call(
        {:get_order, symbol, time, order_id},
        _from,
        %State{order_books: order_books} = state
      ) do
    order_book =
      Map.get(
        order_books,
        :"#{symbol}",
        %OrderBook{}
      )

    #  As we don’t know the order’s side, we will concat all 3 lists
    result =
      (order_book.buy_side ++
         order_book.sell_side ++
         order_book.historical)
      |> Enum.find(
        &(&1.symbol == symbol and
            &1.time == time and
            &1.order_id == order_id)
      )

    {:reply, {:ok, result}, state}
  end

  ####################################################################
  # order retrieval
  ####################################################################

  #  handle incoming trade events(streamed from the PubSub topic)
  def handle_info(
        %TradeEvent{} = trade_event,
        %{order_books: order_books} = state
      ) do
    #  get the order book for the symbol from the trade event
    order_book =
      Map.get(
        order_books,
        :"#{trade_event.symbol}",
        %OrderBook{}
      )

    #  take orders with price greater than current price
    filled_buy_orders =
      order_book.buy_side
      |> Enum.take_while(&D.lt?(trade_event.price, &1.price))
      |> Enum.map(&Map.replace!(&1, :status, "FILLED"))

    #  take orders with price less than current price
    filled_sell_orders =
      order_book.sell_side
      |> Enum.take_while(&D.gt?(trade_event.price, &1.price))
      |> Enum.map(&Map.replace!(&1, :status, "FILLED"))

    # Concat both orders and broadcast PubSub TRADE_EVENTS topic
    (filled_buy_orders ++ filled_sell_orders)
    |> Enum.map(&convert_order_to_event(&1, trade_event.event_time))
    |> Enum.each(&broadcast_trade_event/1)

    # Remove the filled orders
    remaining_buy_orders =
      order_book.buy_side
      |> Enum.drop(length(filled_buy_orders))

    remaining_sell_orders =
      order_book.sell_side
      |> Enum.drop(length(filled_sell_orders))

    order_books =
      Map.replace!(
        order_books,
        :"#{trade_event.symbol}",
        %{
          buy_side: remaining_buy_orders,
          sell_side: remaining_sell_orders,
          historical:
            filled_buy_orders ++
              filled_sell_orders ++
              order_book.historical
        }
      )

    {:noreply, %{state | order_books: order_books}}
  end

  #  simply return a new Streamer.Binance.TradeEvent struct filled with data
  defp convert_order_to_event(%Binance.Order{} = order, time) do
    %TradeEvent{
      event_type: order.type,
      event_time: time - 1,
      symbol: order.symbol,
      trade_id: Integer.floor_div(time, 1000),
      price: order.price,
      quantity: order.orig_qty,
      buyer_order_id: order.order_id,
      seller_order_id: order.order_id,
      trade_time: time - 1,
      buyer_market_maker: false
    }
  end

  defp broadcast_trade_event(%Streamer.Binance.TradeEvent{} = trade_event) do
    Phoenix.PubSub.broadcast(
      Streamer.PubSub,
      "TRADE_EVENTS:#{trade_event.symbol}",
      trade_event
    )
  end
end
