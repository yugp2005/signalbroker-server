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

defmodule CanTest do
  use ExUnit.Case
  alias SignalBase.Message

  # Create a suporvised instance.
  # See code for `AppNgCan.start_link` for clarification. - code refactored now using udpcan

  @tag :success
  test "test create message" do
    supervised_start()
    GenServer.cast(:canWriter, {:signal, %Message{name_values: [{WheelSpeedReR, 10}, {FuelLevelIndicated, 4}]}})
    #read out the code generated from canwriter and then canconnector...

    supervised_stop()
  end

  @body "BodyCANhs"
  @lin "Lin"

  @simple_conf %{
    BodyCANhs: %{signal_base_pid: :broker0_pid, signal_cache_pid: Payload.Name.generate_name_from_namespace(String.to_atom(@body), :cache), type: "udp"},
    Virtual: %{signal_base_pid: :broker1_pid, signal_cache_pid: :cache1, type: "virtual"},
  }

  def supervised_start() do
    Process.register(self(), :test)
    Util.Forwarder.start_link(self())

    {:ok, pid} = SignalBase.start_link(:broker0_pid, String.to_atom(@body), nil)
    assert_receive :signal_base_ready, 5000

    {:ok, pid} = CanUdp.App.start_link({String.to_atom(@body), :broker0_pid, [human_file: "../../configuration/human/benchc.json"], 2001, '127.0.0.1', 2000, "udp"})
    # Wait for DBC files to be parsed
    assert_receive {:ready_descriptors, :broker0_pid}, 3_000
  end

  def supervised_stop() do
    close_processes([:broker0_pid])
    close_processes([(Payload.Name.generate_name_from_namespace(String.to_atom(@body), :supervisor))])

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


  describe "Varying payload size" do
    @composed <<48, 57, 192, 100>>

    @tag :success
    test ".dbc frame line" do

      {:bo, info} = DBC.line("BO_ 1407 TestFrame: 4 CEM\n")
      assert info.can_id == 1407
      assert info.name == "TestFrame"
      assert info.size_bytes == 4
      assert info.tag == "CEM"
    end

    @tag :success
    test "compose" do
      {:ok, dbc} = Payload.Descriptions.start_link({:dbc_pid, nil, [
        dbc_file: "../../configuration/can/test.dbc"
      ], nil})
      # SG_ TestFr04_Child01 : 31|8@0+ (1.0, 0.0) [0.0|255.0] "NoUnit" CCM, DDM, PDM, POT, PSMD, PSMP, TEM0, TRM
      # SG_ TestFr04_Child01_UB : 22|1@0+ (1,0) [0|1] "" CCM, DDM, PDM, POT, PSMD, PSMP, TEM0, TRM
      # SG_ TestFr04_Child02 : 7|16@0+ (1.0, 0.0) [0.0|65535.0] "NoUnit" CCM, DDM, PDM, POT, PSMD, PSMP, TEM0, TRM
      # SG_ TestFr04_Child02_UB : 23|1@0+ (1,0) [0|1] "" CCM, DDM, PDM, POT, PSMD, PSMP, TEM0, TRM

      fields_with_values = [
        {"TestFr04_Child01", 100},
        {"TestFr04_Child01_UB", 1},
        {"TestFr04_Child02", 12345},
        {"TestFr04_Child02_UB", 1},
      ]
      |> Enum.map(fn({name, value}) ->
        {Payload.Descriptions.get_field_by_name(dbc, name), value}
      end)

      assert Payload.Descriptions.build_payload(dbc, fields_with_values) ==
        @composed

      assert GenServer.stop(dbc) == :ok
    end

    @tag :success
    test "decompose" do
      {:ok, dbc} = Payload.Descriptions.start_link({:dbc_pid, nil, [
        dbc_file: "../../configuration/can/test.dbc"
      ], nil})

      parsed = Payload.Descriptions.get_info_map(dbc, 1405, @composed)
               |> Enum.sort()

      parsed_value = fn(key) ->
        parsed
        |> List.keyfind(key, 0)
        |> elem(1)
      end

      # Check that it's the same as in test case "compose"
      assert parsed_value.("TestFr04_Child01") == 100
      assert parsed_value.("TestFr04_Child01_UB") == 1
      assert parsed_value.("TestFr04_Child02") == 12345
      assert parsed_value.("TestFr04_Child02_UB") == 1

      assert GenServer.stop(dbc) == :ok
    end
  end
end
