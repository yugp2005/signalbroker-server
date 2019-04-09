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

defmodule Debug.Route.Process do
  use GenServer
  alias Debug.Route.Process.Child, as: Child

  defmodule State, do: defstruct [
    :name,
    children: [],
  ]

  # CLIENT

  def start_link(name),
    do: GenServer.start_link(__MODULE__, name, name: name)

  def reg(pid, name, target),
    do: GenServer.call(pid, {:reg, name, target})

  def pub(pid, name, value),
    do: GenServer.cast(pid, {:pub, name, value})

    # SERVER

  def init(name) do
    {:ok, %State{name: name}}
  end

  def handle_call({:reg, name, target}, _, state) do
    proc_name = child_proc_name(state.name, name)
    {:ok, _} = Child.start_link(proc_name)
    Child.reg(proc_name, target)

    new_state = %State{state| children: [proc_name | state.children]}
    {:reply, :ok, new_state}
  end

  def handle_cast({:pub, name, value}, state) do
    proc_name = child_proc_name(state.name, name)
    GenServer.cast(proc_name, {:signal, name, value})
    {:noreply, state}
  end

  def terminate(_reason, state) do
    Enum.map(state.children, &GenServer.stop/1)
    :ok
  end

  defp child_proc_name(parent, child),
    do: String.to_atom("#{parent}_#{child}")
end

defmodule Debug.Route.Process.Child do
  use GenServer

  def start_link(name),
    do: GenServer.start_link(__MODULE__, nil, name: name)

  def reg(pid, new_child),
    do: GenServer.call(pid, {:reg, new_child})

  def init(_), do: {:ok, []}

  def handle_call({:reg, target}, _, children) do
    {:reply, :ok, [target | children]}
  end

  def handle_cast({:signal, name, value}, children) do
    Enum.map(children, fn(pid) ->
      GenServer.cast(pid, {:signal, name, value})
    end)

    {:noreply, children}
  end
end
