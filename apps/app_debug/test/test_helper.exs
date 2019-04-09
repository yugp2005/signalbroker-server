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

defmodule Debug.Route.PingPong do
  use GenServer

  def start_link(target, message),
    do: GenServer.start_link(__MODULE__, {target, message})

  def init(state), do: {:ok, state}

  def handle_cast({:signal, _name, _value}, {target, message}=state) do
    GenServer.cast(target, message)
    {:noreply, state}
  end
end
