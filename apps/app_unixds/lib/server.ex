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

defmodule UnixDS.Server do
  use GenServer

  defstruct [
    :socket,
    :name_clientholder
  ]

  @moduledoc """
  Intefrace to Core system through a Unix domain socket.
  """

  # CLIENT

  def start_link({name, name_clientholder, path, gateway}),
    do: GenServer.start_link(__MODULE__, {path, name_clientholder, gateway}, name: name)

  def start_loop(pid, gateway),
    do: GenServer.cast(pid, {:start_loop, gateway})

  # SERVER
  def init({path, name_clientholder, gateway}) do
    File.rm(path)
    Path.dirname(path) |> File.mkdir

    {:ok, socket} = :gen_tcp.listen(0, [
      :binary,
      ip: {:local, path},
      packet: 2,
      active: false,
      reuseaddr: true])
      File.chmod(path, 0o777)

    start_loop(self(), gateway)
    {:ok, %__MODULE__{socket: socket, name_clientholder: name_clientholder}}
  end

  def handle_cast({:start_loop, gateway}, state) do
    loop(state, gateway)
    {:stop, :normal, state}
  end

  defp loop(state, gateway, counter \\ 1) do
    case :gen_tcp.accept(state.socket) do
      {:ok, conn} ->

        client_name = UnixDS.Application.get_client_name(counter)
        {:ok, _} = UnixDS.ClientHolder.start_client(
          state.name_clientholder, conn, client_name, gateway)

        # Transfer process event signaling to client
        :gen_tcp.controlling_process(conn,  Process.whereis(client_name))
        :inet.setopts(conn, active: true)

        loop(state, gateway, counter+1)
    end
  end
end
