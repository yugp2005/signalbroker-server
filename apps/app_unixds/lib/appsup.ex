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

defmodule UnixDS.Supervisor do
  use Supervisor

  # CLIENT

  def start_link(gateway) do
    name = UnixDS.Application.get_name("app")
    Util.Config.app_log("Starting UDS `#{inspect name}`")
    Supervisor.start_link(__MODULE__, gateway, name: name)
  end

  # SERVER

  def init(gateway) do
    socket_path = "/tmp/signalserver/cs-unix"
    name_server = UnixDS.Application.get_name("server")
    name_clientholder = UnixDS.Application.get_name("clientholder")

    Supervisor.init([
      {UnixDS.Server, {name_server, name_clientholder, socket_path, gateway}},
      {UnixDS.ClientHolder, name_clientholder},
    ], strategy: :one_for_one)
  end
end
