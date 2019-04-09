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

defmodule AppCounterTest do
  use ExUnit.Case

  test "No ticks" do
    {:ok, c} = Counter.start_link(:ok)
    {:ok, t} = Counter.Timer.start_link(:ok)

    assert GenServer.stop(c, :normal) == :ok
    assert GenServer.stop(t, :normal) == :ok
  end

  test "One some" do
    {:ok, c} = Counter.start_link(:ok)
    {:ok, t} = Counter.Timer.start_link(:ok)

    Counter.add_listen(self())

    Counter.tick_signal()
    Counter.tick_frame(2)

    Counter.Timer.force_tick()

    assert_receive {
      :"$gen_cast",
      {:counter_stats, %Counter.Stats{signals: 1, frames: 2}}
    }

    assert GenServer.stop(c, :normal) == :ok
    assert GenServer.stop(t, :normal) == :ok
  end
end
