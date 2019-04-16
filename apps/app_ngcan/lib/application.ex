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

defmodule AppNgCan.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do

    config = Util.Config.get_config()
    children =
      config.chains
      |> Enum.filter(fn(conf) -> # Filter out all non-CAN
        conf.type == "can" || conf.type == "canfd"
      end)
      |> Enum.map(fn(conf) -> # Spawn controller for each CAN network
        namespace = String.to_atom(conf.namespace)
        device = conf.device_name
        conn = Payload.Name.generate_name_from_namespace(namespace, :server)
        desc = Payload.Name.generate_name_from_namespace(namespace, :desc)
        signal = Payload.Name.generate_name_from_namespace(namespace, :signal)
        canwriter = Payload.Name.generate_name_from_namespace(namespace, :writer)
        can_cache =  Payload.Name.generate_name_from_namespace(namespace, :cache)
        id = conf.device_name
        signal_base = conf.device_name
                      |> SignalBase.Application.make_signal_broker_name()

        type = conf.type
        # Create supervised child process
        Supervisor.child_spec(
          {AppNgCan, {
            {device, desc, conn, signal, canwriter, can_cache, signal_base, namespace, type},
            conf}}, id: id)
      end)

    Supervisor.start_link(
      children, strategy: :one_for_one)
  end

  def make_name(device, type) when is_atom(device),
    do: String.to_atom("can_"<>Atom.to_string(device)<>"_"<>type)
end
