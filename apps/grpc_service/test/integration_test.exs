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

defmodule GRPCService.IntegrationTest do
  @moduledoc """
  Define integration tests for GRPC subscriptions

  These tests depend on the docker network to be started beforehand (so it's
  possible to perform connections to 40051 and 40052 ports, opened by
  docker-compose.test.yml)

  It's possible to start the docker network with:
  docker-compose -f docker-compose.test.yml up
  """
  use ExUnit.Case, async: false

  @tag :integration_test
  test "Can receive local subscriptions (from the same slave)" do
    signalId = Base.SignalId.new(
      name: "BenchC_c_6",
      namespace: Base.NameSpace.new(name: "UDPCanInterface"))

    pid = self()
    subscribe = fn ->
      ## Subscription

      {:ok, channel} = GRPC.Stub.connect("localhost:40052")

      signalIds = Base.SignalIds.new(signalId: [signalId])
      request = Base.SubscriberConfig.new(
        clientId: Base.ClientId.new(id: "grpc-client"),
        signals: signalIds,
        on_change: false)

      {:ok, stream} =
        Base.NetworkService.Stub.subscribe_to_signals(
          channel,
          request,
          timeout: :infinity)
      Enum.each stream, fn item -> send(pid, item) end
    end

    _subscriber = spawn(fn -> subscribe.() end)

    # A bit ugly way of synchronising publisher with subscriber
    Process.sleep(100)

    ## Publishing
    {:ok, channel} = GRPC.Stub.connect("localhost:40052")

    source = Base.ClientId.new(id: "slave1")
    signals_with_payload = [Base.Signal.new(id: signalId, payload: {:integer, 3})]
    request = Base.PublisherConfig.new(
      clientId: source,
      frequency: 0,
      signals: Base.Signals.new(signal: signals_with_payload)
    )
    Base.NetworkService.Stub.publish_signals(channel, request)
    {:ok, msg} = receive do msg -> msg after 1000 -> :nok end

    # Check if we have received a Signals structure
    assert %Base.Signals{} = msg

    # Check if we have received a Signal structure as a signal
    [signal] = Map.get(msg, :signal)
    assert %Base.Signal{} = signal

    # Finally checking the payload as well
    assert Map.get(signal, :payload) == {:integer, 3}
    assert Map.get(signal, :id) == signalId
  end
end