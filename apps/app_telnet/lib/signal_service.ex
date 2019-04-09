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

defmodule SignalService do
  @moduledoc """
  Documentation for SignalService.
  """

  @doc """
  Hello world.

  ## Examples

      iex> SignalService.hello
      :world

  """

  require Logger

  def accept(port, signal_server_proxy) do
    # The options below mean:
    #
    # 1. `:binary` - receives data as binaries (instead of lists)
    # 2. `packet: :line` - receives data line by line
    # 3. `active: false` - blocks on `:gen_tcp.recv/2` until data is available
    # 3. `active: true` - sockets indata is received in handle_info in GenServer
    # 4. `reuseaddr: true` - allows us to reuse the address if the listener crashes
    #
    # {:ok, socket} = :gen_tcp.listen(port,
                      # [:binary, packet: :line, active: false, reuseaddr: true])
    {:ok, socket} = :gen_tcp.listen(port,
                      [:binary, active: true, reuseaddr: true])
    Logger.info "Accepting connections on port #{port}"
    loop_acceptor(socket, signal_server_proxy)
  end

  defp loop_acceptor(socket, signal_server_proxy) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Supervisor.start_child(SocketSupervisor.Supervisor, [{client, signal_server_proxy}])
    :ok = :gen_tcp.controlling_process(client, pid)
    # This makes the child process the “controlling process” of the client socket. ,
    # If we didn’t do this, the acceptor would bring down all the clients if it crashed because
    # sockets would be tied to the process that accepted them (which is the default behaviour)
    loop_acceptor(socket, signal_server_proxy)
  end
end
