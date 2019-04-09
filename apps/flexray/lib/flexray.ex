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

defmodule FlexRay do
  @moduledoc """
  Documentation for FlexRay.
  """

  @doc """
  FlexRay - readonly implementation toward Wice MX-4.
  """

  require Logger
  use GenServer

  def start_link({namespace, args}) do

    sup_pid = Payload.Name.generate_name_from_namespace(namespace, :supervisor)
    Util.Config.app_log("Starting flexray `#{inspect sup_pid}`")

    Supervisor.start_link(__MODULE__, args, name: sup_pid)
  end

  def init({server_pid, desc_pid, writer_pid, signal_pid, cache_pid, signalbase_pid, conf, addr, port}) do
    Supervisor.init([
      {Payload.Cache, {cache_pid, desc_pid, signal_pid}},
      {Payload.Writer, {writer_pid, server_pid, desc_pid, signal_pid, cache_pid, signalbase_pid, conf.type}},
      {Payload.Signal, {signal_pid, server_pid, desc_pid, cache_pid, writer_pid, signalbase_pid, conf.type}},
      {Payload.Descriptions, {desc_pid, signal_pid, conf, writer_pid}},
      {FlexRay.Server, {server_pid, signal_pid, addr, port}},
    ], strategy: :one_for_one)
  end

  def make_name(name, postfix) when is_atom(name),
    do: String.to_atom("flexrayip_"<>Atom.to_string(name)<>"_"<>postfix)

end
