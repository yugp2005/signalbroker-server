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

defmodule Debug.Route.Ets do
  use GenServer

  defmodule State, do: defstruct [:ets_db]

  # CLIENT

  def start_link(name),
    do: GenServer.start_link(__MODULE__, name, name: name)

  def reg(pid, name, target),
    do: GenServer.call(pid, {:reg, name, target})

  def pub(pid, name, value),
    do: GenServer.cast(pid, {:pub, name, value})

  # SERVER

  def init(name) do
    db_name = String.to_atom("#{name}_ets")

    state = %State{
      ets_db: :ets.new(db_name, [:set]),
    }
    {:ok, state}
  end

  def handle_call({:reg, name, target}, _, state) do
    :ets.insert(state.ets_db, {name, target})
    {:reply, :ok, state}
  end

  # Does this even work? {:signal ...} is not suppose to look like that.
  def handle_cast({:pub, name, value}, state) do
    case :ets.lookup(state.ets_db, name) do
      [] -> :none
      targets -> Enum.map(targets, fn({_, target}) ->
        GenServer.cast(target, {:signal, name, value})
      end)
    end

    {:noreply, state}
  end
end
