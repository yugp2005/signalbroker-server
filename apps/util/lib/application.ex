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

defmodule Util.Application do
  use Application
  require Logger

  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
    config_path = System.get_env("CONFIGURATION_FILE_PATH") || get_config_path()
    Logger.info "Loading main configuration file #{config_path}"

    Supervisor.start_link([
      {Util.Config, config_path},
    ], strategy: :one_for_one)
  end

  # Return the config path from relative folder
  defp get_config_path() do
    {:ok, base} = File.cwd()
    config_path = if !Util.Config.is_test do
      "#{base}/configuration/interfaces.json"
    else
      "#{base}/../../configuration/interfaces.json"
    end
  end
end
