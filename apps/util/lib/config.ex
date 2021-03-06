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

  def get_config(pid) do
    GenServer.call(pid, :get_config)
  end

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
    _config =
      path
      |> File.read()
      |> case do
        {:ok, content} ->
          config =
            content
            |> Poison.decode!(keys: :atoms)
            |> refine()
          {:ok, config}
        {:error, reason} ->
          {:stop, "Can't open configuration file (#{path}) reason: #{inspect reason}"}
      end
  end

  def handle_call(:get_config, _, config) do
    {:reply, config, config}
  end

  # Change some fields from strings to atoms
  defp refine(config) do
    # Change gateway from a string to an Atom
    new_gateway = %{config.gateway | gateway_pid: String.to_atom(config.gateway.gateway_pid)}

    # Return with updated fields
    %{config | gateway: new_gateway}
  end
end
