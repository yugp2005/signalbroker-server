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

defmodule UnixDS.ClientHolder do
  use Supervisor

  def start_link(name),
    do: Supervisor.start_link(__MODULE__, [], name: name)

  def start_client(pid, client, name, gateway) do
    Supervisor.start_child(pid, [{name, client, gateway}])
  end

  def init([]),
    do: Supervisor.init([UnixDS.ClientCouple], strategy: :simple_one_for_one)
end

defmodule UnixDS.ClientCouple do
  use Supervisor

  def start_link(_sup_opts, params),
    do: Supervisor.start_link(__MODULE__, params)

  def init({name, socket, gateway}) do
    timeout_name = String.to_atom("#{name}_timeout")

    Supervisor.init([
      {UnixDS.Client, {name, socket, gateway, timeout_name}},
      {UnixDS.Timeout, {timeout_name, name}},
    ], strategy: :one_for_all)
  end
end
