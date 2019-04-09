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

defmodule UnixDS.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    config = Util.Config.get_config()
    UnixDS.Supervisor.start_link(config.gateway.gateway_pid)
  end


  @doc """
  Get unique name for client process.
  @param pid PID of client socket owner.
  """
  def get_client_name(id),
    do: get_name("client_#{id}")

  def get_name(name),
    do: String.to_atom("unixds_" <> name)
end
