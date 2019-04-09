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

ExUnit.start()

defmodule Helper.SignalCatcher do
  use GenServer
  require Logger

  defstruct [latest: nil, counter: 0]

  # CLIENT
  def start_link(), do: GenServer.start_link(__MODULE__, %__MODULE__{})

  # SERVER
  def init(state), do: {:ok, state}

  def handle_cast({:execute, cb}, state) do
    cb.()
    {:noreply, state}
  end
  def handle_cast(msg, st), do: {:noreply, tick_state(st, msg)}
  def handle_call(:get_state, _, state), do: {:reply, state.latest, state}
  def handle_call(:get_counter, _, state), do: {:reply, state.counter, state}
  def handle_call(:reset_counter, _, _state), do: {:reply, nil, %__MODULE__{}}
  def handle_call(msg, _, st), do: {:reply, :ok, tick_state(st, msg)}

  # INTERNAL
  defp tick_state(st, msg), do:
  %__MODULE__{st| latest: msg, counter: st.counter+1}
end

defmodule Helpers do
  def close_process(p), do: :ok = GenServer.stop(p, :normal)
  def close_processes(pids), do: pids |> Enum.map(&close_process/1)
end
