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

defmodule RoutingTest do
  use ExUnit.Case
  alias Debug.Route.Ets, as: R

  @bignum 0_500_000

  test "Create router" do
    {:ok, _} = R.start_link(:r)
    assert GenServer.stop(:r) == :ok
  end

  test "Register and publish" do
    {:ok, _} = R.start_link(:r)
    R.reg(:r, :a, self())
    R.pub(:r, :a, :value)

    assert_receive {:"$gen_cast", {:signal, :a, :value}}
    assert GenServer.stop(:r) == :ok
  end

  test "Pingpong with #{@bignum} events" do
    {:ok, _} = R.start_link(:r)
    {:ok, pp} = Debug.Route.PingPong.start_link(self(), {:signal, :b, :value_b})

    R.reg(:r, :a, pp)
    R.reg(:r, :b, self())

    for _ <- 1..@bignum do
      R.pub(:r, :a, :value_a)
      assert_receive {:"$gen_cast", {:signal, :b, :value_b}}
    end

    assert GenServer.stop(:r) == :ok
    assert GenServer.stop(pp) == :ok
  end
end
