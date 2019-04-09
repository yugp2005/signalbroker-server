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

defmodule DelayAgent do

  # state currently only holds the name of the database

  # require Logger

  @doc """
  sets the inital state to dbname.
  """
  def start_link(list) do
    Agent.start_link(fn -> list end, name: __MODULE__)
  end

  @doc """
  just returns the intial state.
  """
  def get_state do
    Agent.get(__MODULE__, fn list -> list end)
  end

  @doc """
  ignores the parameter from external state.
  """
  def delay(new_entry) do
    Agent.update(__MODULE__, fn list -> sleep(new_entry, list) end)
  end

  def sleep(new_time, _old_time) do
    #delaytime = (new_time - old_time) * 1000.0
    # Logger.debug "delaytime is #{inspect delaytime}"
    :timer.sleep(10)
    new_time
  end
end
