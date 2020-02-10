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

defmodule GRPCServiceTest do
  use ExUnit.Case, async: false

  @gateway_pid GRPCService.Application.get_gateway_pid()

  @body "BodyCANhs"
  @lin "Lin"

  @tag :success_with_dbc
  test "setup connection" do
    channel = GRPCClientTest.setup_connection()
    assert channel.host == "localhost"
    assert channel.port == 50051
  end

  test "make grpc call, (OpenPassWindow) make sure it reaches cache, grpc -> cache" do
    simple_initialize()

    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr01"]) == [{"TestFr01", :empty}]
    GRPCClientTest.test_open_window()
    assert_receive :cache_decoded
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr01_Child23_UB"]) == [{"TestFr01_Child23_UB", 1}]
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr01_Child23"]) == [{"TestFr01_Child23", 4}]
    # TODO aren't we expecting the raw frame here?
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr01"]) == [{"TestFr01", 0}]
    simple_terminate()
  end

  test "make grpc call, (ClosePassWindow) make sure it reaches cache, grpc -> cache" do
    simple_initialize()

    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr01"]) == [{"TestFr01", :empty}]
    GRPCClientTest.test_close_window()
    assert_receive :cache_decoded
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr01_Child23_UB"]) == [{"TestFr01_Child23_UB", 1}]
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr01_Child23"]) == [{"TestFr01_Child23", 2}]
    # TODO aren't we expecting the raw frame here?
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr01"]) == [{"TestFr01", 0}]
    simple_terminate()
  end

  test "make functional (set_fan_speed) hammer call with one shot, make sure it reaches cache, grpc -> cache" do
    simple_initialize()

    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr02_Child05"]) == [{"TestFr02_Child05", :empty}]
    GRPCClientTest.start_hvac_hammer(12, 0)
    assert_receive :cache_decoded
    # TODO aren't we expecting the raw frame here?
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr02_Child05"]) == [{"TestFr02_Child05", 12}]
    simple_terminate()
  end

  test "make network hammer call with one shot, make sure it reaches cache, grpc -> cache" do
    simple_initialize()

    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr02_Child05"]) == [{"TestFr02_Child05", :empty}]
    GRPCClientTest.start_hvac_hammer(12, 0)
    assert_receive :cache_decoded
    # TODO aren't we expecting the raw frame here?
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr02_Child05"]) == [{"TestFr02_Child05", 12}]
    simple_terminate()
  end

  test "make hammer call with 10 hz, make sure it reaches cache and make sure it's stoppable, grpc -> cache" do
    simple_initialize()

    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr02_Child05"]) == [{"TestFr02_Child05", :empty}]
    GRPCClientTest.start_hvac_hammer(12, 100)
    assert_receive :cache_decoded

    # TODO aren't we expecting the raw frame here?
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr02_Child05"]) == [{"TestFr02_Child05", 12}]


    GRPCClientTest.start_hvac_hammer(12, 0)
    # stop it again
    # once it's stopped write to cache and chech that it's not updated again
    SignalServerProxy.publish(@gateway_pid, [{"TestFr02_Child05_UB", 5}], :none, String.to_atom(@body))
    assert_receive :cache_decoded
    :timer.sleep(100)
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr02_Child05_UB"]) == [{"TestFr02_Child05_UB", 5}]

    simple_terminate()
  end

  test "publish raw bytes make sure they arrive as published" do
    simple_initialize()
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")

    <<expected::size(16)>> = <<256::size(16)>>

    spawn(GRPCClientTest, :subscribe_to_signal, [["TestFr03"], @body, GRPCClientTest.setup_connection()])

    :timer.sleep(500)

    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr03"]) == [{"TestFr03", :empty}]
    source = Base.ClientId.new(id: "publisher_string")
    signal1 = Base.SignalId.new(name: "TestFr03", namespace: Base.NameSpace.new(name: @body))
    signals_with_payload = [
      Base.Signal.new(id: signal1, raw: <<expected::size(16)>>)
    ]
    request = Base.PublisherConfig.new(clientId: source, frequency: 0, signals: Base.Signals.new(signal: signals_with_payload))
    _stream = channel |> Base.NetworkService.Stub.publish_signals(request)
    assert_receive :cache_decoded

    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr03"]) == [{"TestFr03", expected}]

    :timer.sleep(500)

    assert_receive {:subscription_received, {:ok, %Base.Signals{signal: [response | t]}}}
    assert response.payload == {:integer, expected}
    assert response.raw == <<expected::size(16)>>
    assert response.id.name == "TestFr03"
    assert response.id.namespace.name == @body



    simple_terminate()
  end

  test "publish signal and read it using readfunction" do
    simple_initialize
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    # check empty...
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr02_Child05_UB"]) == [{"TestFr02_Child05_UB", :empty}]
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr01_Child23"]) == [{"TestFr01_Child23", :empty}]

    source = Base.ClientId.new(id: "source_string")
    signal1 = Base.SignalId.new(name: "TestFr02_Child05", namespace: Base.NameSpace.new(name: @body))
    signal2 = Base.SignalId.new(name: "TestFr01_Child23", namespace: Base.NameSpace.new(name: @body))
    signal3 = Base.SignalId.new(name: "TestFrBytes05", namespace: Base.NameSpace.new(name: @body))
    signal4 = Base.SignalId.new(name: "BfrLin18Fr00", namespace: Base.NameSpace.new(name: @lin))
    signal5 = Base.SignalId.new(name: "TestFr02_Child10", namespace: Base.NameSpace.new(name: @body))

    signals_with_payload = [
      Base.Signal.new(id: signal1, payload: {:integer, 3}),
      Base.Signal.new(id: signal2, payload: {:double, 0.5}),
      Base.Signal.new(id: signal3, payload: {:double, 7.5}),
      Base.Signal.new(id: signal4, payload: {:arbitration, true}),
      Base.Signal.new(id: signal5, payload: {:integer, 23}, raw: <<01,02>>)
    ] |> Enum.sort

    request = Base.PublisherConfig.new(clientId: source, frequency: 0, signals: Base.Signals.new(signal: signals_with_payload))

    # now publish
    stream = channel |> Base.NetworkService.Stub.publish_signals(request)

    assert_receive :cache_decoded

    # let read

    signals = [
      signal1, signal2, signal3, signal4, signal5
    ]

    request = Base.SignalIds.new(signalId: signals)
    response = Base.NetworkService.Stub.read_signals(channel, request)

    {:ok, %Base.Signals{signal: signals}} = response
    [returned_signal | t] = signals |> Enum.sort
    assert returned_signal.id.name == "BfrLin18Fr00"
    assert returned_signal.payload == {:empty, true}
    assert returned_signal.id.namespace.name == @lin
    assert returned_signal.raw == <<>>

    [returned_signal | t] = t
    assert returned_signal.id.name == "TestFr01_Child23"
    assert returned_signal.payload == {:double, 0.5}
    assert returned_signal.id.namespace.name == @body
    assert returned_signal.raw == <<>>

    [returned_signal | t] = t
    assert returned_signal.id.name == "TestFr02_Child05"
    assert returned_signal.payload == {:integer, 3}
    assert returned_signal.id.namespace.name == @body
    assert returned_signal.raw == <<3>>

    [returned_signal | t] = t
    assert returned_signal.id.name == "TestFr02_Child10"
    assert returned_signal.id.namespace.name == @body
    assert returned_signal.raw == <<01,02>>

    [returned_signal | t] = t
    assert returned_signal.id.name == "TestFrBytes05"
    assert returned_signal.payload == {:double, 7.5}
    assert returned_signal.id.namespace.name == @body
    assert returned_signal.raw == <<>>


    simple_terminate()
  end

  test "fetch signals from server" do
    simple_initialize()

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    request = Base.NameSpace.new(name: @body)
    {:ok, response} = Base.SystemService.Stub.list_signals(channel, request)
    assert (Enum.count(response.frame) > 0)
    [first | rem] = response.frame

    assert ((%Base.SignalInfo{id: %Base.SignalId{name: "TestFr01", namespace: %Base.NameSpace{name: "BodyCANhs"}}, metaData: %Base.MetaData{description: "", isRaw: false, max: 0, min: 0, size: 64, unit: ""}}) == first.signalInfo)

    [firstkid | rem] = first.childInfo
    assert ((%Base.SignalInfo{id: %Base.SignalId{name: "TestFr01_Child01_UB", namespace: %Base.NameSpace{name: "BodyCANhs"}}, metaData: %Base.MetaData{description: "", isRaw: false, max: 0, min: 0, size: 1, unit: ""}} == firstkid))

    simple_terminate()
  end


  test "fetch signals from server - return empty list" do
    simple_initialize()

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    request = Base.NameSpace.new(name: "made_up_namespace")
    {:ok, response} = Base.SystemService.Stub.list_signals(channel, request)
    assert (Enum.count(response.frame) == 0)

    simple_terminate()
  end

  test "fetch signals from server - use virtual network" do
    simple_initialize()

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    request = Base.NameSpace.new(name: "Virtual")
    {:ok, response} = Base.SystemService.Stub.list_signals(channel, request)
    assert (Enum.count(response.frame) == 0)

    simple_terminate()
  end


  test "get configuration" do
    simple_initialize()

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    request = Base.Empty.new()
    {:ok, response} = Base.SystemService.Stub.get_configuration(channel, request)
    assert (Enum.count(response.networkInfo) == 2)

    simple_terminate()
  end

  test "write signal and make sure it reaches cache" do
    simple_initialize()
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr02_Child05"]) == [{"TestFr02_Child05", :empty}]
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr01_Child23"]) == [{"TestFr01_Child23", :empty}]

    source = Base.ClientId.new(id: "source_string")
    namespace = Base.NameSpace.new(name: @body)
    signal1 = Base.SignalId.new(name: "TestFr02_Child05", namespace: namespace)
    signal2 = Base.SignalId.new(name: "TestFr01_Child23", namespace: namespace)
    signal3 = Base.SignalId.new(name: "TestFrBytes05", namespace: namespace)
    signal4 = Base.SignalId.new(name: "BfrLin18Fr00", namespace: Base.NameSpace.new(name: @lin))

    signals_with_payload = [
      Base.Signal.new(id: signal1, payload: {:integer, 3}),
      Base.Signal.new(id: signal2, payload: {:double, 0.5}),
      Base.Signal.new(id: signal3, payload: {:double, 7.5}),
      Base.Signal.new(id: signal4, payload: {:arbitration, true})
    ]
    request = Base.PublisherConfig.new(clientId: source, frequency: 0, signals: Base.Signals.new(signal: signals_with_payload))

    stream = channel |> Base.NetworkService.Stub.publish_signals(request)

    assert_receive :cache_decoded

    :timer.sleep(500)

    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr02_Child05"]) == [{"TestFr02_Child05", 3}]
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFr01_Child23"]) == [{"TestFr01_Child23", 0.5}]
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["TestFrBytes05"]) == [{"TestFrBytes05", 7.5}]
    # arbitration doesn't reach cache....
    assert Payload.Cache.read_channels(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), ["BfrLin18Fr00"]) == [{"BfrLin18Fr00", :empty}]

    simple_terminate()
  end

  require Logger

  test "subscribe to signal and make sure it arrives from can, cache -> grpc" do
    simple_initialize()

    field = Payload.Descriptions.get_field_by_name(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :desc), "TestFr01_Child23")
    spawn(GRPCClientTest, :subscribe_to_signal, [["TestFr01_Child23", "TestFr01_Child20"], @body, GRPCClientTest.setup_connection()])

    :timer.sleep(500)
    Payload.Signal.handle_raw_can_frames(
      Payload.Name.generate_name_from_namespace(String.to_atom(@body), :signal), :test_source,
      [{field.id, <<0x12, 0x34,0x56,0x78,0xab,0xcd,0xef,0x01>>}])


    assert_receive {:subscription_received, {:ok, %Base.Signals{signal: signals}}}

    [response | t] = signals |> Enum.sort()
    assert response.payload == {:integer, 7}
    assert response.id.name == "TestFr01_Child20"
    assert response.id.namespace.name == @body

    [response | t] = t
    assert response.payload == {:integer, 1}
    assert response.id.name == "TestFr01_Child23"
    assert response.id.namespace.name == @body

    simple_terminate()
  end

  test "subscribe to signal and make sure it arrives from signal broker" do
    simple_initialize()

    # field = Payload.Descriptions.get_field_by_name(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :desc), "TestFr01_Child23")
    spawn(GRPCClientTest, :subscribe_to_signal, [["TestFr01_Child23"], @body, GRPCClientTest.setup_connection()])

    :timer.sleep(500)
    SignalServerProxy.publish(@gateway_pid, [{"TestFr01_Child23", 5}], :none, String.to_atom(@body))

    assert_receive {:subscription_received, {:ok, %Base.Signals{signal: [response | t]}}}, 1000
    assert response.payload == {:integer, 5}
    assert response.id.name == "TestFr01_Child23"
    assert response.id.namespace.name == @body

    # second signal, same as before
    SignalServerProxy.publish(@gateway_pid, [{"TestFr01_Child23", 5}], :none, String.to_atom(@body))

    assert_receive {:subscription_received, {:ok, %Base.Signals{signal: [response | t]}}}, 1000
    assert response.payload == {:integer, 5}
    assert response.id.name == "TestFr01_Child23"
    assert response.id.namespace.name == @body

    simple_terminate()
  end


  test "subscribe to signal and make sure it arrives from signal broker onchange active" do
     simple_initialize()

    # field = Payload.Descriptions.get_field_by_name(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :desc), "SomeSignal")
    spawn(GRPCClientTest, :subscribe_to_signal, [["TestFr01_Child23", "TestFr01_Child20"], @body, GRPCClientTest.setup_connection(), true])

    :timer.sleep(2000)
    SignalServerProxy.publish(@gateway_pid, [{"TestFr01_Child23", 5}], :none, String.to_atom(@body))

    assert_receive {:subscription_received, {:ok, %Base.Signals{signal: [response | t]}}}, 1000
    assert response.payload == {:integer, 5}
    assert response.id.name == "TestFr01_Child23"
    assert response.id.namespace.name == @body

    # second signal, same as before, only the changed should arrive
    SignalServerProxy.publish(@gateway_pid, [{"TestFr01_Child23", 5}, {"TestFr01_Child20", 3}], :none, String.to_atom(@body))

    assert_receive {:subscription_received, {:ok, %Base.Signals{signal: [response | t]}}}, 1000
    assert response.payload == {:integer, 3}
    assert response.id.name == "TestFr01_Child20"
    assert response.id.namespace.name == @body

    SignalServerProxy.publish(@gateway_pid, [{"TestFr01_Child23", 6}, {"TestFr01_Child20", 3}], :none, String.to_atom(@body))

    assert_receive {:subscription_received, {:ok, %Base.Signals{signal: [response | t]}}}, 1000
    assert response.payload == {:integer, 6}
    assert response.id.name == "TestFr01_Child23"
    assert response.id.namespace.name == @body

    SignalServerProxy.publish(@gateway_pid, [{"TestFr01_Child23", 1}, {"TestFr01_Child20", 2}], :none, String.to_atom(@body))

    assert_receive {:subscription_received, {:ok, %Base.Signals{signal: signals}}}, 1000

    [response | t] = signals |> Enum.sort()
    assert response.payload == {:integer, 2}
    assert response.id.name == "TestFr01_Child20"
    assert response.id.namespace.name == @body

    [response | t] = t
    assert response.payload == {:integer, 1}
    assert response.id.name == "TestFr01_Child23"
    assert response.id.namespace.name == @body

    simple_terminate()
  end

  @tag :success_with_dbc
  test "subscribe to fan speed" do
    simple_initialize()
    spawn(GRPCClientTest, :subscribe_to_fan_speed, ["source_string", GRPCClientTest.setup_connection()])
    :timer.sleep(500)
    SignalServerProxy.publish(@gateway_pid, [{"TestFr02_Child05", 3}], :none, String.to_atom(@body))

    assert_receive {:subscription_received, {:ok, response}}
    assert response.payload == 3

    simple_terminate()
  end

  defp start_diag_flow() do

  end


  defmodule LocalListener do
    use GenServer
    require Logger
    alias SignalBase.Message
    @gateway_pid GRPCService.Application.get_gateway_pid()
    @body "BodyCANhs"

    defstruct [
      test_pid: nil
    ]

    def start_link(name, {signal, test_pid}) do
      GenServer.start_link(__MODULE__, {name, signal, test_pid}, name: name)
    end

    #Server
    def init({name, signal, test_pid}) do
      SignalServerProxy.register_listeners(@gateway_pid, [signal], :sniffer, self(), String.to_atom(@body))
      {:ok, %{test_pid: test_pid}}
    end

    def handle_cast({:signal, %Message{name_values: channels_with_values, time_stamp: timestamp, namespace: namespace}}, state) do
      [{name, value}] = channels_with_values
      send(state.test_pid, value)
      {:noreply, state}
    end
  end

  def local_publisher(response_data_raw) do
    # send messages back to Diagnostics ans make sure the a re concatenaded accordingly
    :timer.sleep(500)
    Enum.each(response_data_raw, fn(entry) ->
      SignalServerProxy.publish(@gateway_pid, [{"TesterPhysicalResCEMHS", entry}], :none, String.to_atom(@body))
    end)
  end

  @expected_request 0x0322F19000000000
  @expected_request2 0x3000000000000000
  test "simple read diagnostics VIN" do

    simple_initialize()

    pid = LocalListener.start_link(:some_name, {"TesterPhysicalReqCEMHS", self()})

    Diagnostics.Application.start(1, 2)
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    up_link = Base.SignalId.new(name: "TesterPhysicalReqCEMHS", namespace: Base.NameSpace.new(name: @body))
    down_link = Base.SignalId.new(name: "TesterPhysicalResCEMHS", namespace: Base.NameSpace.new(name: @body))
    service_id = <<0x22>>
    data_identifier = <<0xf190::size(16)>>

    # response_data = [<<16, 27, 98, 241, 144, 89, 86, 49>>, "!FW41L0G", "\"1285060", <<35, 0, 0, 0, 0, 0, 0, 0>>]
    response_data_raw = [0x101B62F190595631, 0x21465734314C3047, 0x2231323835303630, 0x2300000000000000]
    spawn(__MODULE__, :local_publisher, [response_data_raw])

    request = Base.DiagnosticsRequest.new(upLink: up_link, downLink: down_link, serviceId: service_id, dataIdentifier: data_identifier)
    {:ok, response} = Base.DiagnosticsService.Stub.send_diagnostics_query(channel, request)

    assert_receive 0x0322F19000000000, 1000
    assert_receive 0x3000000000000000, 1000
    assert response.raw == <<89, 86, 49, 70, 87, 52, 49, 76, 48, 71, 49, 50, 56, 53, 48, 54, 48, 0, 0, 0, 0, 0, 0, 0>>
    simple_terminate()
  end

  @expected_request3 0x0322F12E00000000
  @expected_request4 0x3000000000000000
  test "simple read diagnostics something else" do

    simple_initialize()

    LocalListener.start_link(:some_name, {"TesterPhysicalReqCEMHS", self()})

    Diagnostics.Application.start(1, 2)
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    up_link = Base.SignalId.new(name: "TesterPhysicalReqCEMHS", namespace: Base.NameSpace.new(name: @body))
    down_link = Base.SignalId.new(name: "TesterPhysicalResCEMHS", namespace: Base.NameSpace.new(name: @body))
    service_id = <<0x22>>
    data_identifier = <<0xf12e::size(16)>>

    response_data_raw = [0x102062F12E043322, 0x2119204124153222, 0x2211802404114222, 0x2313208220423165, 0x2482134523200000]
    spawn(__MODULE__, :local_publisher, [response_data_raw])

    request = Base.DiagnosticsRequest.new(upLink: up_link, downLink: down_link, serviceId: service_id, dataIdentifier: data_identifier)
    {:ok, response} = Base.DiagnosticsService.Stub.send_diagnostics_query(channel, request)

    assert_receive 0x0322F12E00000000, 1000
    assert_receive 0x3000000000000000, 1000
    assert response.raw == <<4, 51, 34, 25, 32, 65, 36, 21, 50, 34, 17, 128, 36, 4, 17, 66, 34, 19, 32, 130, 32, 66, 49, 101, 130, 19, 69, 35, 32>>

    simple_terminate()
  end


  test "simple read diagnostics single frame" do

    simple_initialize()

    LocalListener.start_link(:some_name, {"TesterPhysicalReqCEMHS", self()})

    Diagnostics.Application.start(1, 2)
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    up_link = Base.SignalId.new(name: "TesterPhysicalReqCEMHS", namespace: Base.NameSpace.new(name: @body))
    down_link = Base.SignalId.new(name: "TesterPhysicalResCEMHS", namespace: Base.NameSpace.new(name: @body))
    service_id = <<0x22>>
    data_identifier = <<0xd11c::size(16)>>

    response_data_raw = [0x462D11C42000000]
    spawn(__MODULE__, :local_publisher, [response_data_raw])

    request = Base.DiagnosticsRequest.new(upLink: up_link, downLink: down_link, serviceId: service_id, dataIdentifier: data_identifier)
    {:ok, response} = Base.DiagnosticsService.Stub.send_diagnostics_query(channel, request)

    assert_receive 0x0322D11C00000000, 1000
    # assert_receive 0x3000000000000000, 1000
    # assert_receive :ok, 1000
    assert response.raw == <<66>>


    simple_terminate()
  end


  @simple_conf %{
    BodyCANhs: %{signal_base_pid: :broker0_pid, desc_pid: Payload.Name.generate_name_from_namespace(String.to_atom(@body), :desc), signal_cache_pid: Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), type: "udp"},
    Virtual: %{signal_base_pid: :broker1_pid, desc_pid: Payload.Name.generate_name_from_namespace(String.to_atom(@body), :desc), signal_cache_pid: :cache1, type: "virtual"},
  }

  # defp simple_initialize() do
  #   # Application.ensure_all_started(:grpc_service,  :permanent)
  #   {:ok, _} = Util.Forwarder.start_link(self())

  require Logger

  defp simple_initialize() do
    # Application.ensure_all_started(:grpc_service,  :permanent)
    {:ok, pid} = Util.Forwarder.start_link(self())

    {:ok, pid} = SignalServerProxy.start_link({@gateway_pid, @simple_conf, String.to_atom(@body)})
    assert_receive :signal_proxy_ready, 5000
    {:ok, pid} = SignalBase.start_link(:broker0_pid, String.to_atom(@body), nil)
    assert_receive :signal_base_ready, 5000
    # {:ok, _} = SignalBase.start_link(:broker1_pid, :any, nil)
    # {:ok, _} = SignalBase.start_link(:broker2_pid, :any, nil)

    #   def start_link({{device, desc, conn, signal, canwriter, cache, signalbase, namespace, type}, physical}) when is_atom(namespace)
    # {:ok, pid} = AppNgCan.start_link({{"vcan0", Payload.Name.generate_name_from_namespace(String.to_atom(@body), :desc), :conn, Payload.Name.generate_name_from_namespace(String.to_atom(@body), :signal), :writer, Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), :broker0_pid, String.to_atom(@body), "can"}, dbc_file: "../../configuration/can_files/SPA0610/SPA0610_140404_BodyCANhs.dbc"})

    #   def start_link({namespace, signalbase_pid, conf, server_port, target_host, target_port, type}) when is_atom(namespace) do

    {:ok, pid} = CanUdp.App.start_link({String.to_atom(@body), :broker0_pid, [dbc_file: "../../configuration/can/test.dbc"], 2001, '127.0.0.1', 2000, "udp"})
    assert_receive {:ready_descriptors, :broker0_pid}, 3_000
  end

  defp simple_terminate() do
    # Application.stop(:grpc_service)
    close_processes([@gateway_pid, :broker0_pid])
    close_processes([(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :supervisor))])

    # assert GenServer.stop(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :supervisor)) == :ok

    assert Util.Forwarder.terminate() == :ok
  end

  defp assert_down(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, _, _, _}
  end

  defp close_process(p) do
    :ok = GenServer.stop(p, :normal)
    assert_down(p)
  end

  defp close_processes(pids), do: pids |> Enum.map(&close_process/1)

end
