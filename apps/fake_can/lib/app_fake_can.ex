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

defmodule AppFakeCan do
  use Supervisor
  require Logger

  @moduledoc """
  CAN application using (ng_can)[https://github.com/johnnyhh/ng_can].

  Can send and recieve CAN frames.
  """

  @doc """
  Start a supervised CAN-bus device app.
  ```
  iex>
  AppNgCan.start_link("can0", human_file: "configuration/human_files/cfile.json")
  {:ok, pid(0,121,0)}
  ```
  """
  def start_link(device, recorded_file, descriptions) do
    name = make_name(device, "app")
    Supervisor.start_link(__MODULE__, {device, descriptions, recorded_file}, name: name)
  end

  @doc """
  AppNgCan.start_link("can0", human_file: "configuration/human_files/cfile.json")
  """
  # def start_bil01 do
  #   AppNgCan.start_link("can0", human_file: "configuration/human_files/cfile.json")
  # end
  #
  # @doc """
  # AppNgCan.start_link("vcan0", human_file: "configuration/human_files/cfile.json")
  # """
  # def start_simulation do
  #   AppNgCan.start_link("vcan0", human_file: "configuration/human_files/cfile.json")
  # end


  def init({device, descriptions, recorded_file}) do
    desc = make_name(device, "desc") # CanDescriptions process name
    conn = make_name(device, "conn") # CanConnector
    signal = make_name(device, "signal") # CanSignal

    children = [
      worker(Payload.Signal, [signal, conn, desc]),
      worker(Payload.Descriptions, [desc, signal, descriptions]),
      worker(FakeCanConnection, [conn, signal, recorded_file]),
    ]
    supervise(children, strategy: :one_for_one)
  end

  defp make_name(device, type),
    do: String.to_atom("can_"<>device<>"_"<>type)
end
