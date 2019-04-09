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

defmodule UnixDS.Timeout do
  use GenServer

  @moduledoc """
  Signals a UnixDS client whenever a timeout has been reached.
  """

  # CLIENT
  # ======

  @doc """
  Create instance. Will not start automatically. Call `activate` to start.
  `target` is the pid that will be called with GenServer cast message
  `:timeout`.
  """
  def start_link({name, target}) do
    GenServer.start_link(__MODULE__, target, name: name)
  end

  @doc "Start timeout detector with timeout in miliseconds"
  def activate(pid, millis) do
    GenServer.cast(pid, {:activate, millis})
  end

  def deactivate(pid) do
    GenServer.cast(pid, :deactivate)
  end


  # SERVER
  # ======

  def init(target), do: {:ok, target}
  def handle_cast({:activate, millis}, target) do
    if millis > 0 do
      {:noreply, target, millis}
    else
      {:noreply, target}
    end
  end

  def handle_cast(:deactivate, target) do
    {:noreply, target}
  end

  def handle_info(:timeout, target) do
    GenServer.cast(target, :timeout)
    {:noreply, target}
  end
end
