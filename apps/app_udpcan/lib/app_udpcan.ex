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

defmodule CanUdp.App do
  @moduledoc """
  Instance of a UDP server. An instance represents a CAN network.
  """

  use Supervisor

  # CLIENT

  def start_link({namespace, signalbase_pid, conf, server_port, target_host, target_port, type}) when is_atom(namespace) do

    sup_pid = Payload.Name.generate_name_from_namespace(namespace, :supervisor)
    Util.Config.app_log("Starting udpcan `#{inspect sup_pid}`")
    args = {
      Payload.Name.generate_name_from_namespace(namespace, :server),
      Payload.Name.generate_name_from_namespace(namespace, :desc),
      Payload.Name.generate_name_from_namespace(namespace, :writer),
      Payload.Name.generate_name_from_namespace(namespace, :signal),
      Payload.Name.generate_name_from_namespace(namespace, :cache),
      signalbase_pid,
      conf,
      server_port,
      target_host,
      target_port,
      type
    }
    Supervisor.start_link(__MODULE__, args, name: sup_pid)
  end

  # SERVER

  def init({
    server_pid, desc_pid, writer_pid, signal_pid, cache_pid, signalbase_pid, conf,
    server_port, target_host, target_port, type,
  }) do

    Supervisor.init([
      {Payload.Cache, {cache_pid, desc_pid, signal_pid}},
      {Payload.Writer, {writer_pid, server_pid, desc_pid, signal_pid, cache_pid, signalbase_pid, type}},
      {Payload.Signal, {signal_pid, server_pid, desc_pid, cache_pid, writer_pid, signalbase_pid, type}},
      {Payload.Descriptions, {desc_pid, signal_pid, conf, writer_pid}},
      {CanUdp.Server, {server_pid, signal_pid, server_port, target_host, target_port}},
    ], strategy: :one_for_one)
  end
end
