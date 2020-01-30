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

defmodule AppUdpcanTest do
  use ExUnit.Case
  alias SignalBase.Message

  @udp_packet_count 5_000
  @local_host {127, 0, 0, 1}
  @local_port 4050
  @remote_port 4031

  @body :body

  doctest CanUdp
  doctest CanUdp.Server

  test "Create server" do
    {:ok, _} = CanUdp.Server.start_link({:s, self(), 4030, @local_host, 4031})
    assert GenServer.stop(:s) == :ok
  end

  test "Server connection" do
    {:ok, _} = CanUdp.Server.start_link({:s, self(), 4031, @local_host, @local_port})
    c = helper_client_start()

    Helper.UdpClient.send_data(c, CanUdp.make_udp_frame(5, <<1, 2, 3>>))

    assert_receive {:"$gen_cast", {:raw_can_frames, [{id, payload}], :s, _}}
    assert id == 5
    assert payload == <<1, 2, 3>>

    helper_client_stop(c)
    assert GenServer.stop(:s) == :ok
  end

  test "Supervised start" do
    supervised_start()
    supervised_stop()
  end

  test "Supervised receive empty" do
    supervised_start()
    c = helper_client_start()

    # Send nonsens CAN frame
    Helper.UdpClient.send_data(c, CanUdp.make_udp_frame(0, <<0 :: size(64)>>))

    SignalBase.publish(:broker0_pid, [{"SomeSignal_A", 10}], :any)
    assert_receive {:helper_udp, _}

    helper_client_stop(c)
    supervised_stop()
  end

  test "Supervised produce UDP message via signal" do
    supervised_start()
    c = helper_client_start()

    SignalBase.publish(:broker0_pid, [{"SomeSignal_A", 10}], :any)

    assert_receive {:helper_udp, data}
    assert CanUdp.parse_udp_frames(data) == [{907, <<0, 0, 0, 0, 40, 0, 0, 0>>}]

    helper_client_stop(c)
    supervised_stop()
  end

  test "Send and receive #{@udp_packet_count} UDP CAN frames" do
    supervised_start()
    c = helper_client_start()

    for _n <- 1..@udp_packet_count do
      SignalBase.publish(:broker0_pid, [{"BenchC_c_2", 10}], :any)

      assert_receive {:helper_udp, data}
      assert CanUdp.parse_udp_frames(data) == [{96, <<0, 10, 0, 0, 0, 0, 0, 0>>}]
    end

    helper_client_stop(c)
    supervised_stop()
  end

  describe "Variable payload size" do
    @composed <<48, 57, 192, 100>>

    def payload_start(opts \\ []) do
      Util.Forwarder.start_link(self())

      assert {:ok, _} = SignalBase.start_link(:sig0, :any, nil)
      assert_receive :signal_base_ready
      assert {:ok, _} = CanUdp.App.start_link({
        @body,
        :sig0,
        [dbc_file: "../../configuration/can/test.dbc"] ++ opts,
        4020,
        @local_host, @local_port, "can"
      })

      # Wait for DBC files to be parsed
      assert_receive {:ready_descriptors, :sig0}
    end

    defp payload_stop() do
      assert :ok == Supervisor.stop(Payload.Name.generate_name_from_namespace(@body, :supervisor))
      assert GenServer.stop(:sig0) == :ok
      assert Util.Forwarder.terminate() == :ok
    end

    test "receive" do
      # Start
      payload_start()
      SignalBase.register_listeners(:sig0, [
        "TestFr04_Child01",
        "TestFr04_Child01_UB",
        "TestFr04_Child02",
        "TestFr04_Child02_UB",
      ], :none, self())
      c = helper_client_start(@local_port, 4020)

      # Send
      Helper.UdpClient.send_data(c, CanUdp.make_udp_frame(1405, @composed))

      # Receive
      assert_receive {:"$gen_cast",
        {:signal, %SignalBase.Message{name_values: name_values, namespace: :any}}}

      assert Enum.sort(name_values) == [
        {"TestFr04_Child01", 100},
        {"TestFr04_Child01_UB", 1},
        {"TestFr04_Child02", 12345},
        {"TestFr04_Child02_UB", 1},
      ]

      # Stop
      helper_client_stop(c)
      payload_stop()
    end

    test "send" do
      payload_start()
      c = helper_client_start(@local_port, 4020)
      SignalBase.publish(:sig0, [
        {"TestFr04_Child01", 100},
        {"TestFr04_Child01_UB", 1},
        {"TestFr04_Child02", 12345},
        {"TestFr04_Child02_UB", 1},
      ], :none)

      assert_receive {:helper_udp, data}
      assert CanUdp.parse_udp_frames(data) == [{1405, @composed}]

      helper_client_stop(c)
      payload_stop()
    end

    test "send with fixed_payload_size: 8" do
      payload_start(fixed_payload_size: 16)
      c = helper_client_start(@local_port, 4020)
      SignalBase.publish(:sig0, [
        {"TestFr04_Child01", 100},
        {"TestFr04_Child01_UB", 1},
        {"TestFr04_Child02", 12345},
        {"TestFr04_Child02_UB", 1},
      ], :none)

      assert_receive {:helper_udp, data}
      composed_padded = <<@composed :: binary, 0 :: size(96)>>
      assert CanUdp.parse_udp_frames(data) == [{1405, composed_padded}]

      helper_client_stop(c)
      payload_stop()
    end
  end

  # Extract from human file
  # {
  # "startbit" : 48, "hs" : true, "name" : "SomeSignal_C", "id" : "1ef",
  # "length" : 8, "factor" : 1, "offset" : 0
  # }

  test "Send raw data via UDP and read it back from cache" do
    supervised_start()
    c = helper_client_start()
    cache_pid = Payload.Name.generate_name_from_namespace(@body, :cache)
    desc_pid = Payload.Name.generate_name_from_namespace(@body, :desc)

    # Register a listener on a signal we'll use in this test
    SignalBase.register_listeners(:broker0_pid, ["SomeSignal_C"], :none, self())

    # Get field information
    field = Payload.Descriptions.get_field_by_name(desc_pid, "SomeSignal_C")
    # Assert we've gotten the right field
    assert field.name == "SomeSignal_C"
    assert field.id == 0x1ef
    assert field.startbit == 48

    # The cache shall say there's no stored value with this key
    assert Payload.Cache.read_channels(cache_pid, ["SomeSignal_C"]) == [{"SomeSignal_C", :empty}]

    # Send some data via a UDP connection
    Helper.UdpClient.send_data(c, CanUdp.make_udp_frame(field.id, <<0, 0, 0, 0, 0, 0, 250, 0>>))

    # Make sure we receive the data we just sent
    assert_receive {:"$gen_cast", {:signal, %Message{name_values: [{"SomeSignal_C", value}]}}}
    assert value == 250

    assert_cache_decode()

    # Assert the value matches the value from the signaling system
    assert Payload.Cache.read_channels(cache_pid, ["SomeSignal_C"]) == [{"SomeSignal_C", 250}]

    helper_client_stop(c)
    supervised_stop()
  end

  test "Try building payload with empty value" do
    supervised_start()
    desc_pid = Payload.Name.generate_name_from_namespace(@body, :desc)

    field = Payload.Descriptions.get_field_by_name(desc_pid, "SomeSignal_C")

    # Try encoding with real value
    Payload.Descriptions.build_payload(desc_pid, [{field, 1}])

    # Try encoding with bad value
    Payload.Descriptions.build_payload(desc_pid, [{field, :empty}])

    supervised_stop()
  end

  test "Update cache via signalbroker" do
    supervised_start()

    cache_pid = Payload.Name.generate_name_from_namespace(@body, :cache)

    assert Payload.Cache.read_channels(cache_pid, ["SomeSignal_C"]) == [{"SomeSignal_C", :empty}]
    assert Payload.Cache.get_nbr_entries(cache_pid) == 0

    SignalBase.register_listeners(:broker0_pid, ["SomeSignal_C"], :none, self())
    SignalBase.publish(:broker0_pid, [{"SomeSignal_C", 210}], :any)

    assert_receive {:"$gen_cast", {:signal, %Message{name_values: [{"SomeSignal_C", 210}]}}}
    assert_receive :cache_decoded

    assert Payload.Cache.read_channels(cache_pid, ["SomeSignal_C"]) == [{"SomeSignal_C", 210}]
    assert Payload.Cache.get_nbr_entries(cache_pid) == 1

    # Write a signal that doesn't exist
    SignalBase.publish(:broker0_pid, [{"Nothing", 230}], :any)

    assert Payload.Cache.get_nbr_entries(cache_pid) == 1 # Should still be 1

    # Update 2 values and assert the cache still only has 1 entry
    SignalBase.publish(:broker0_pid, [
      {"SomeSignal_C", 140},
      {"SomeSignal_B", 150},
    ], :any)

    assert_receive :cache_decoded
    assert Payload.Cache.get_nbr_entries(cache_pid) == 1

    # Assert values
    assert Payload.Cache.read_channels(cache_pid, ["SomeSignal_C"]) == [{"SomeSignal_C", 140}]
    assert Payload.Cache.read_channels(cache_pid, ["SomeSignal_B"]) == [{"SomeSignal_B", 150}]

    # Update 3 values with 1 entry that will update a new frame in the cache
    SignalBase.publish(:broker0_pid, [
      {"SomeSignal_C", 40},
      {"SomeSignal_B", 50},
      {"SomeSignal_E", 60},
    ], :any)

    # Two decoding operations because signals are from two different packets
    assert_receive :cache_decoded
    assert_receive :cache_decoded
    assert Payload.Cache.get_nbr_entries(cache_pid) == 2

    # Assert all published values
    assert Payload.Cache.read_channels(cache_pid, ["SomeSignal_C"]) == [{"SomeSignal_C", 40}]
    assert Payload.Cache.read_channels(cache_pid, ["SomeSignal_B"]) == [{"SomeSignal_B", 50}]
    assert Payload.Cache.read_channels(cache_pid, ["SomeSignal_E"]) == [{"SomeSignal_E", 60}]

    supervised_stop()
  end

  test "Update cache via signalbroker, make sure signals are decoded when needed" do
    supervised_start()
    cache_pid = Payload.Name.generate_name_from_namespace(@body, :cache)

    assert Payload.Cache.read_channels(cache_pid, ["SomeSignal_C"]) == [{"SomeSignal_C", :empty}]
    assert Payload.Cache.get_nbr_entries(cache_pid) == 0
    assert Payload.Cache.get_nbr_entries_unpacked(cache_pid) == 0

    SignalBase.register_listeners(:broker0_pid, ["SomeSignal_C"], :none, self())
    SignalBase.publish(:broker0_pid, [{"SomeSignal_C", 210}], :any)

    assert_receive {:"$gen_cast", {:signal, %Message{name_values: [{"SomeSignal_C", 210}]}}}

    assert_receive :cache_decoded

    # there is a listern so signal should exist unpacked
    assert Payload.Cache.get_nbr_entries_unpacked(cache_pid) == 1

    assert Payload.Cache.read_channels(cache_pid, ["SomeSignal_C"]) == [{"SomeSignal_C", 210}]
    assert Payload.Cache.get_nbr_entries(cache_pid) == 1

    supervised_stop()
  end

  test "Send raw data via VCAN and read it back from cache, make sure its rendered invalid in cache" do
    supervised_start()
    c = helper_client_start()
    cache_pid = Payload.Name.generate_name_from_namespace(@body, :cache)
    desc_pid = Payload.Name.generate_name_from_namespace(@body, :desc)

    assert Payload.Cache.read_channels(cache_pid, ["SomeSignal_C"]) == [{"SomeSignal_C", :empty}]

    SignalBase.register_listeners(:broker0_pid, ["SomeSignal_C"], :none, self())
    field = Payload.Descriptions.get_field_by_name(desc_pid, "SomeSignal_C")
    assert field.name == "SomeSignal_C"
    assert field.id == 0x1ef
    assert field.startbit == 48

    assert Payload.Cache.get_nbr_entries(cache_pid) == 0
    assert Payload.Cache.get_nbr_entries_unpacked(cache_pid) == 0
    # Send raw data
    # Send some data via a UDP connection

    Helper.UdpClient.send_data(c, CanUdp.make_udp_frame(field.id, <<0, 0, 0, 0, 0, 0, 240, 0>>))

    # Recieve value via signaling system
    assert_receive {:"$gen_cast", {:signal, %Message{name_values: [{"SomeSignal_C", value}]}}}
    assert value == 240

    assert_cache_decode() # Give enough time to flush value tocache_pid

    # Receive value viacache_pid system. Then assert the value fromcache_pid is the
    # same as the value received from the signaling system
    assert Payload.Cache.read_channels(cache_pid, ["SomeSignal_C"]) == [{"SomeSignal_C", value}]

    # both table incache_pid should be populated
    assert Payload.Cache.get_nbr_entries(cache_pid) == 1
    assert Payload.Cache.get_nbr_entries_unpacked(cache_pid) == 1

    # remove listener
    SignalBase.remove_listener(:broker0_pid, "SomeSignal_C", self())

    # Send raw data,cache_pid should be populated with id but not decoded.
    Helper.UdpClient.send_data(c, CanUdp.make_udp_frame(field.id, <<0, 0, 0, 0, 0, 0, 240, 0>>))

    assert_cache_update() # Give enough time to flush value tocache_pid
    # both id should be updated, this decoded should be purged (no listener)
    assert Payload.Cache.get_nbr_entries(cache_pid) == 1
    assert Payload.Cache.get_nbr_entries_unpacked(cache_pid) == 0

    supervised_stop()
  end

  describe "Two clients" do
    def two_start() do
      Util.Forwarder.start_link(self())

      assert {:ok, _} = SignalBase.start_link(:sig0, :any, nil)
      assert {:ok, _} = CanUdp.App.start_link({
        @body,
        :sig0,
        [human_file: "../../configuration/human/benchc.json"],
        4031,
        @local_host, @local_port,
        "can"
      })

      assert_receive {:ready_descriptors, :sig0}
    end

    def two_stop() do
      assert :ok == Supervisor.stop(Payload.Name.generate_name_from_namespace(@body, :supervisor))
      assert GenServer.stop(:sig0) == :ok
      assert Util.Forwarder.terminate() == :ok
    end

    # Send messages like this
    # TEST (this) -> Client #1
    # Client #1 -> Client #2
    # Client #2 -> TEST
    test "talking to each others" do
      two_start()
      SignalBase.register_listeners(:sig0, ["channel"], :none, self())
      two_stop()
    end
  end


  # INTERNAL

  # @body "BodyCANhs"
  # @lin "Lin"

  @simple_conf %{
    BodyCANhs: %{signal_base_pid: :broker0_pid, signal_cache_pid: Payload.Name.generate_name_from_namespace(@body, :cache), type: "udp"},
    Virtual: %{signal_base_pid: :broker1_pid, signal_cache_pid: :cache1, type: "virtual"},
  }

  def supervised_start() do
    Process.register(self(), :test)
    Util.Forwarder.start_link(self())

    {:ok, pid} = SignalBase.start_link(:broker0_pid, @body, nil)
    assert_receive :signal_base_ready, 5000

    {:ok, pid} = CanUdp.App.start_link({@body, :broker0_pid, [human_file: "../../configuration/human/benchc.json"], @remote_port, '127.0.0.1', @local_port, "udp"})
    # Wait for DBC files to be parsed
    assert_receive {:ready_descriptors, :broker0_pid}, 3_000
  end

  # Create a suporvised `app_udpcan` instance.
  # See code for `CanUdp.App.start_link` for clarification.
  # defp supervised_start() do
  #   Util.Forwarder.start_link(self())

  #   assert {:ok, _} = SignalBase.start_link(:sig0, :any, nil)
  #   assert {:ok, _} = CanUdp.App.start_link({
  #     @body,
  #     :sig0,
  #     [human_file: "../../configuration/human/cfile.json"],
  #     4031,
  #     @local_host, @local_port, "can"
  #   })

  #   # Wait for DBC files to be parsed
  #   assert_receive {:ready_descriptors, :sig0}
  # end

  def supervised_stop() do
    close_processes([:broker0_pid])
    close_processes([(Payload.Name.generate_name_from_namespace(@body, :supervisor))])

    # assert GenServer.stop(:sig0) == :ok
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

  # Waits for a forwarded :cache_decode via Util.Forwarder send from Payload.Cache
  defp assert_cache_decode(), do: assert_receive :cache_decoded
  defp assert_cache_update(), do: assert_receive :cache_update

  # Create a simple UDP helper client.
  # Use `helper_client_stop` to terminate.
  defp helper_client_start(listen_port \\ @local_port , dest_port \\ @remote_port) do
    {:ok, c} = Helper.UdpClient.start_link(listen_port, dest_port)
    c
  end

  defp helper_client_stop(pid) do
    assert GenServer.stop(pid) == :ok
  end
end
