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

defmodule Reflector.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    # List all child processes to be supervised

    config = Util.Config.get_config()

    signal_base_proxy = config.gateway.gateway_pid

    children =
      config.reflectors
      |> Enum.flat_map(fn(reflector) ->
        reflector_pid = Map.get(reflector, :application_pid) |> String.to_atom()
        reflects = Map.get(reflector, :reflect)
        count = Enum.count(reflects)
        base_name = Atom.to_string(reflector_pid)

        Util.Config.app_log("Starting reflector `#{inspect reflector_pid}`")

        Enum.map(Enum.zip(reflects, Enum.to_list(1..count)), fn({reflector, id}) ->
          name_pid = "#{base_name}_name_#{id}" |> String.to_atom()
          sup_id = "#{base_name}_id_#{id}" |> String.to_atom()

          Supervisor.child_spec({
            Reflector, {
              String.to_atom(reflector.source), String.to_atom(reflector.dest),
              name_pid, reflector_pid,
              reflector.exclude, signal_base_proxy
            }
          }, id: sup_id)
        end)
      end)


    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Reflector.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
