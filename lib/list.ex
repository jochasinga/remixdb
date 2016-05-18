defmodule Remixdb.List do
  use GenServer
  def start(key_name) do
    GenServer.start __MODULE__, {:ok, key_name}, []
  end

  def init({:ok, key_name}) do
    {:ok, %{items: [], key_name: key_name}}
  end

  def rpush(name, items) do
    GenServer.call(name, {:rpush, items})
  end

  def rpushx(nil, items) do; 0; end
  def rpushx(name, items) do
    GenServer.call(name, {:rpushx, items})
  end

  def lpush(name, items) do
    GenServer.call(name, {:lpush, items})
  end

  def lpushx(nil, items) do; 0; end
  def lpushx(name, items) do
    GenServer.call(name, {:lpushx, items})
  end

  def lpop(nil) do; :undefined; end
  def lpop(name) do
    GenServer.call(name, :lpop)
  end

  def rpop(nil) do; :undefined; end
  def rpop(name) do
    GenServer.call(name, :rpop)
  end

  def llen(nil) do; 0; end
  def llen(name) do
    GenServer.call(name, :llen)
  end

  def lrange(nil, start, stop) do; []; end
  def lrange(name, start, stop) do
    to_i = &String.to_integer/1
    GenServer.call(name, {:lrange, to_i.(start), to_i.(stop)})
  end

  def popped_out(name) do
    spawn(fn ->
      GenServer.stop(name, :normal)
    end)
  end

  def handle_call(:llen, _from, state) do
    %{items: items} = state
    list_sz = items |> Enum.count
    {:reply, list_sz, state}
  end

  def handle_call({:rpush, new_items}, _from, state) do
    add_items_to_list :right, new_items, state
  end

  def handle_call({:rpushx, new_items}, _from, state) do
    add_items_to_list :right, new_items, state
  end

  def handle_call({:lpush, new_items}, _from, state) do
    add_items_to_list :left, new_items, state
  end

  def handle_call({:lpushx, new_items}, _from, state) do
    add_items_to_list :left, new_items, state
  end

  def handle_call(:lpop, _from, state) do
    pop_items_from_list :left, state
  end

  def handle_call(:rpop, _from, state) do
    pop_items_from_list :right, state
  end

  def handle_call({:lrange, start, stop}, _from, state) do
    %{items: it} = state
    length = it |> Enum.count
    {drop_amt, take_amt} = case (stop < start) do
      true -> {0, 0}
      _ ->
        new_start = case (start < 0) do
          true -> (length - :erlang.abs(start))
          _    -> start
        end
        new_stop = (case (stop < 0) do
          true -> (length - :erlang.abs(stop))
          _    -> stop
        end) + 1
        {new_start, new_stop}
    end
    items = it |> Enum.drop(:erlang.max(0, drop_amt)) |> Enum.take(take_amt)
    {:reply, items, state}
  end

  # SantoshTODO: Mixin Termination stuff
  def terminate(:normal, %{key_name: key_name}) do
    Remixdb.KeyHandler.remove key_name
    :ok
  end

  defp add_items_to_list(push_direction, new_items, state) do
    %{items: items} = state
    updated_items = case push_direction do
      :left  -> (new_items ++ items)
      :right -> (items ++ new_items)
    end
    new_state = Dict.merge(state, %{items: updated_items})
    list_sz = updated_items |> Enum.count
    {:reply, list_sz, new_state}
  end

  defp pop_items_from_list(pop_direction, state) do
    {head, updated_items} = case Dict.get(state, :items) do
      []    ->
        Remixdb.List.popped_out self
        {:undefined, []}
      list ->
        case pop_direction do
          :left ->
            [h|t] = list
            {h, t}
          :right ->
            [h|t] = list |> :lists.reverse
            {h, (t |> :lists.reverse)}
        end
    end
    new_state = Dict.merge(state, %{items: updated_items})
    {:reply, head, new_state}
  end
end
