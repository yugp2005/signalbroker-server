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

defmodule Payload.Name do

  # namespace is string
  def generate_name_from_namespace(namespace, :desc) do
    generate_name(namespace, "desc")
  end

  def generate_name_from_namespace(namespace, :server) do
    generate_name(namespace, "server")
  end

  def generate_name_from_namespace(namespace, :writer) do
    generate_name(namespace, "writer")
  end

  def generate_name_from_namespace(namespace, :signal) do
    generate_name(namespace, "signal")
  end

  def generate_name_from_namespace(namespace, :supervisor) do
    generate_name(namespace, "supervisor")
  end

  def generate_name_from_namespace(namespace, :scheduler) do
    generate_name(namespace, "scheduler")
  end

  def generate_name_from_namespace(namespace, :config_server) do
    generate_name(namespace, "config_server")
  end

  def generate_name_from_namespace(namespace, :cache) do
    SignalBase.Application.make_cache_name(namespace)
    # generate_name(namespace, "supervisor")
  end

  defp generate_name(namespace, suffix) when is_atom(namespace) do

    config = if Util.Config.is_test() do
      Util.Config.Test.get_test_config()
    else
      Util.Config.get_config()
    end

    [chain] =
      config.chains
      |> Enum.filter(fn(conf) ->
        String.to_atom(conf.namespace) == namespace
      end)

    prefix = %{
      "can" => "can_",
      "canfd" => "can_",
      "udp" => "canudp_",
      "lin" => "linudp_",
      "flexray" => "flexrayip_"
    }[chain.type]

    namespace_str = Atom.to_string(namespace)

    String.to_atom(prefix <> namespace_str <> "_" <> suffix)
  end
end
