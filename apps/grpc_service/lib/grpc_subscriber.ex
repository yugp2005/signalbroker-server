# Copyright 2019 Volvo Cars
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# ”License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# “AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

defmodule GRPCSubscriber do

  @gateway_pid GRPCService.Application.get_gateway_pid()

  use GenServer
  require Logger
  alias Base.SignalId
  alias SignalBase.Message

  defstruct [
    grpc_pid: nil,
    signals: nil,
    submit_response_code: nil,
    signal_cache: %{},
    on_change: nil
  ]

  #Client

  def start_link(name, grpc_pid, signals, source, submit_response_code, on_change \\ false) do
    GenServer.start_link(__MODULE__, {grpc_pid, signals, source, submit_response_code, on_change}, name: name)
  end

  def subscribe_blocking(pid) do
    GenServer.cast(pid, {:block})
  end

  #Server
  def init({grpc_pid, signals, source, submit_response_code, on_change}) do
    subscribe_list = Enum.reduce(signals, %{},
      fn (%SignalId{name: signal_name, namespace: %Base.NameSpace{name: namespace}}, acc) ->
        Map.update(acc, namespace, [signal_name], fn(entry) -> [signal_name | entry] end)
      end)

    Enum.map(subscribe_list, fn{namespace, signals} ->
      SignalServerProxy.register_listeners(@gateway_pid, signals, source, self(), String.to_atom(namespace))
    end)
    # we like to ge callback in terminate
    Process.flag(:trap_exit, true)
    {:ok, %__MODULE__{grpc_pid: grpc_pid, signals: signals, submit_response_code: submit_response_code, on_change: on_change}}
  end

  def handle_cast({:signal, %Message{name_values: channels_with_values, time_stamp: timestamp, namespace: namespace}}, %__MODULE__{on_change: true} = state) do
    namespace_map = Map.get(state.signal_cache, namespace, %{})

    {map, publish_list} =
      Enum.reduce(channels_with_values, {%{}, []}, fn({channel, value} = channel_with_value, {map, publish_list}) ->
        case Map.get(namespace_map, channel, nil) do
          nil -> {Map.merge(map, %{channel => value}), [channel_with_value | publish_list]}
          old_value ->
            case old_value == value do
              true -> {map, publish_list}
              false -> {Map.merge(map, %{channel => value}), [channel_with_value | publish_list]}
            end
        end
      end)

    state.submit_response_code.(publish_list, timestamp, namespace)
    update_signal_cache = Map.put(state.signal_cache, namespace, Map.merge(namespace_map, map))
    {:noreply, %__MODULE__{state | signal_cache: update_signal_cache}}
  end

  def handle_cast({:signal, %Message{name_values: channels_with_values, time_stamp: timestamp, namespace: namespace}}, state) do
    state.submit_response_code.(channels_with_values, timestamp, namespace)
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    case Util.Config.is_test() do
      true -> :ok
      _ -> SignalServerProxy.remove_listeners(@gateway_pid, self())
    end
  end

end
