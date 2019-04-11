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

defmodule DiagnosticsTest do
  use ExUnit.Case
  doctest Diagnostics

  test "convert micros to hex" do
    assert Diagnostics.get_code_for_delay(200) == 0xF2
  end

  test "convert micros to hex test 0" do
    assert Diagnostics.get_code_for_delay(0) == 0xF1
  end

  test "convert micros to hex test saturate" do
    assert Diagnostics.get_code_for_delay(1000) == 0xF9
  end

  alias SignalBase.Message

  @namespace "test_namespace"
  @read_data_by_identifier 0x22

  def local_server do
    # send messages back to Diagnostics ans make sure the a re concatenaded accordingly
    response_data_raw = [0x101B62F190595631, 0x21465734314C3047, 0x2231323835303630, 0x2300000000000000]
    # response_data = [<<16, 27, 98, 241, 144, 89, 86, 49>>, "!FW41L0G", "\"1285060", <<35, 0, 0, 0, 0, 0, 0, 0>>]
    Enum.each(response_data_raw, fn(data) ->
      GenServer.cast(Elixir.Diagnostics, {:signal, %Message{name_values: [{"TesterPhysicalResCEMHS", data}], time_stamp: 0, namespace: @namespace}})
    end)
  end

  require Logger
  #
  # test "read vin" do
  #   Diagnostics.setup_diagnostics("TesterPhysicalReqCEMHS", "TesterPhysicalResCEMHS", [flow_mode: :auto], String.to_atom(@namespace), self())
  #   Diagnostics.sendraw(<<0x03, @read_data_by_identifier, 0xF190::size(16), 0x00, 0x00, 0x00, 0x00>>)
  #   # assert response == "YV1FW41L0G1285060"
  #   spawn(__MODULE__, :local_server, [])
  #   r = receive do
  #     {_, {:diagnostics, <<89, 86, 49, 70, 87, 52, 49, 76, 48, 71, 49, 50, 56, 53, 48, 54, 48, 0, 0, 0, 0, 0, 0, 0>>}} -> true
  #   after
  #      1_000 -> false
  #   end
  #   assert r
  # end
end
