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

defmodule SignalBase.Application do
  use Application
  require Logger

  def start(_type, _args) do

    config = Util.Config.get_config()

    # Create list of specs for all signal brokers to be started
    children = Enum.map(config.chains, fn(conf) ->
      namespace = String.to_atom(conf.namespace)
      signal_base_pid = make_signal_broker_name(conf.device_name)
      id = conf.namespace
      case conf.type do
        "virtual" ->
          Supervisor.child_spec({AppSignalBase, {namespace, signal_base_pid, make_cache_name(namespace)}}, id: id)
        _ ->
          Supervisor.child_spec({AppSignalBase, {namespace, signal_base_pid, :not_needed}}, id: id)
      end
    end)

    proxy_config = Enum.reduce(config.chains, %{}, fn(conf, acc) ->
      signal_base_pid = make_signal_broker_name(conf.device_name)
      namespace = String.to_atom(conf.namespace)
      type = conf.type
      Map.put(acc, String.to_atom(conf.namespace), %{
        :signal_base_pid => signal_base_pid,
        :signal_cache_pid => make_cache_name(namespace),
        :type => type
      })
    end)

    # Create spec for proxy
    proxy_spec = Supervisor.child_spec(
      {SignalServerProxy,
        {config.gateway.gateway_pid, proxy_config, String.to_atom(config.default_namespace)}},
      id: "proxy")

    # Add proxy spec to others specs
    children = [proxy_spec | children]

    Supervisor.start_link(
      children, strategy: :one_for_one, name: __MODULE__)
  end

  def make_signal_broker_name(device_name) do
    "signal_broker_#{device_name}" |> String.to_atom()
  end

  def make_cache_name(namespace) do
    # this could be can cache of virtual cache
    type = "signal_read_cache"
    String.to_atom(Atom.to_string(namespace)<>"_"<>type)
  end

end
