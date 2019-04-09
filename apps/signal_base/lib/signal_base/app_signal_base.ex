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

defmodule AppSignalBase do
  use Supervisor

  def start_link({namespace, signal_base, signal_read_cache}) do
    name = make_name(namespace, "app")
    Supervisor.start_link(__MODULE__, {namespace, signal_base, signal_read_cache}, name: name)
  end

  def init({namespace, signal_base, signal_read_cache}) do
    children =
      case signal_read_cache do
        :not_needed ->
          [worker(SignalBase, [signal_base, namespace, signal_read_cache])]
        _ ->
          [
            worker(SignalBase, [signal_base, namespace, signal_read_cache]),
            worker(VirtualSignalReadCache, [signal_read_cache, signal_base])
          ]
      end

    Util.Config.app_log("Starting signal base `#{inspect signal_base}`")
    supervise(children, strategy: :one_for_one)
  end

  defp make_name(device, type),
    do: String.to_atom(Atom.to_string(device)<>"_"<>type)
end
