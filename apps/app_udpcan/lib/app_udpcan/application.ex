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

defmodule CanUdp.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    config = Util.Config.get_config()

    children =
      config.chains
      |> Enum.filter(fn(conf) -> # Filter out all non-CAN
        conf.type == "udp"
      end)
      |> Enum.map(fn(conf) -> # Spawn controller for each CAN network
        namespace = String.to_atom(conf.namespace)
        server_port = conf.server_port
        target_host = conf.target_host |> Util.Config.parse_ip_string()
        target_port = conf.target_port
        signal_base = conf.device_name
                      |> SignalBase.Application.make_signal_broker_name()
        type = conf.type

        # Create supervised child process
        Supervisor.child_spec({
            CanUdp.App, {
              namespace, signal_base, conf,
              server_port, target_host, target_port, type
            }
          }, id: conf.device_name)
      end)

    opts = [strategy: :one_for_one, name: AppUdpcan.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
