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

defmodule Util.Config do
  use GenServer
  require Logger

  # CLIENT

  def start_link(path) do
    GenServer.start_link(__MODULE__, path, name: __MODULE__)
  end

  def start_link(path, pid) do
    GenServer.start_link(__MODULE__, path, name: pid)
  end

  def get_config() do
    GenServer.call(__MODULE__, :get_config)
  end

  def get_full_config() do
    GenServer.call(__MODULE__, :get_full_config)
  end

  # def get_config(pid) do
  #   GenServer.call(pid, :get_config)
  # end

  def is_test() do
    Application.get_env(:util, :is_test)
  end

  @doc """
  Converts a IP-4 address to a tuple compatible with `:gen_udp` and `:gen_tcp`.
  """
  def parse_ip_string(str) do
    to_charlist(str)
  end

  @doc """
  Log a message that doesn't show up during testing
  """
  def app_log(msg) do
    if !is_test() do
      Logger.info(msg)
    end
  end

  # SERVER

  def init(path) do
    with {:ok, content} <- File.read(path),
         {:ok, decoded_data} <- Poison.decode(content, keys: :atoms),
         config = refine(decoded_data),
         {:ok, _result} <- add_master_node(config) do
      {:ok, config}
    else
      {:error, reason} ->
        {
          :stop,
          "Failed to load config(#{path}) reason: #{inspect reason}"
        }
    end
  end

  def handle_call(:get_config, _, config) do
    # todo this is where we get the relevant per node configutation. Something like..
    # System.get_env("NODE_IDENTIFIER")
    node_identifier = Map.get(config, :master_node, :single_node)

    case node_identifier do
      :single_node ->
        {:reply, refine(config), config}

      _distribution ->
        [node_config] =
          Enum.filter(config.nodes, fn node ->
            node.identifier == node_identifier
          end)

        {:reply, refine(node_config), config}
    end
  end

  def handle_call(:get_full_config, _from, config) do
    {:reply, config, config}
  end

  # Change some fields from strings to atoms
  # TODO not this modules consern...
  defp refine(config) do
    # Change gateway from a string to an Atom
    new_gateway = %{config.gateway | gateway_pid: String.to_atom(config.gateway.gateway_pid)}

    # Return with updated fields
    %{config | gateway: new_gateway}
  end

  # Add master node to the nodes discovery database
  @spec add_master_node(map()) :: result when
    result: {:ok, :self} | {:ok, :added} | {:error, :missing_config}
  defp add_master_node(_config = %{master_node: master_node}) do
    # String.to_atom is required to use erlang node name.
    node_name = String.to_atom(master_node)
    case node_name == Node.self() do
      true ->
        # I am the master node, don't need to connect to myself
        {:ok, :self}
      false ->
        :ok = :erlang_node_discovery.add_node(node_name, :any_port)
        {:ok, :added}
      end
  end

  defp add_master_node(_config), do: {:error, :missing_config}

end
