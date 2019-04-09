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

defmodule SignalService.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    config = Util.Config.get_config()

    #TODO this should really be the proxy and not the directly signal base.
    signal_base = config.gateway.gateway_pid
    tcp_socket_port = config.gateway.tcp_socket_port

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: SignalService.Worker.start_link(arg1, arg2, arg3)
      # worker(SignalService.Worker, [arg1, arg2, arg3]),
      supervisor(SocketSupervisor, [[]]),
      worker(Task, [SignalService, :accept, [tcp_socket_port, signal_base]])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SignalService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
