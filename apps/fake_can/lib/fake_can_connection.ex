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

defmodule FakeCanConnection do

  use GenServer
  require Logger

  defstruct [ :signal_pid, :recorded_file, :name, :publish_name ]

  @interval 3000
  @moduledoc """
  Documentation for FakeCan.
  """

  @doc """
  Hello world.

  ## Examples

      iex> FakeCan.hello
      :world

  """
  # def hello do
  #   :world
  # end
  #
  def convert_string_to_can_frame(line, signal_pid, source) do
    [time, _bus, id_and_message]= String.split(line)
    time = String.replace(time, "(", "")
    time = String.replace(time, ")", "")
    {time, _rem} = Float.parse(time)

    DelayAgent.delay(time)
    # IO.inspect time

    [id, message] = String.split(id_and_message, "#")
    can_message = {elem(Integer.parse(id, 16),0), <<elem(Integer.parse(message, 16),0)::size(64)>>}
    Payload.Signal.handle_raw_can_frames(signal_pid, source, [can_message])
  end

  def read_file_and_generate_can_frames(file, signal_pid, name) do
    File.stream!(file)
    |> Stream.map(&(convert_string_to_can_frame(&1, signal_pid, name)))
    |> Stream.run
  end

  # CLIENT

  @doc """
  Start a fake CAN-device interface.
   * `name` name to give the process.
   * `signal_pid` Reference to `CanSignal` to send frames.
   * `recorded_file` File to read signals from.
  """
  def start_link(name, namespace, recorded_file) do
    state = %__MODULE__{signal_pid: Payload.Name.generate_name_from_namespace(namespace, :signal), recorded_file: recorded_file, name: name, publish_name: Payload.Name.generate_name_from_namespace(namespace, :server)}
    GenServer.start_link(__MODULE__, state, name: name)
  end

  def stop(), do: GenServer.stop(__MODULE__)

  def write(pid, can_id, payload),
    do: GenServer.call(pid, {:write, can_id, payload})

  # SERVER

  def init(state) do
    schedule_work()
    DelayAgent.start_link(1497864597.758009)
    {:ok, state}
  end

  @doc """
  WARNING, not tested!
  """
  def handle_call({:send_message, _message}, _from, state),
    do: {:reply, :ok, state}

  def handle_call({:write, _can_id, _payload}, _from, state),
    do: {:reply, :ok, state}

  defp schedule_work(),
    do: Process.send_after(self(), :work, @interval)

  def handle_info(:work, state) do
    read_file_and_generate_can_frames(state.recorded_file, state.signal_pid, state.publish_name)
    schedule_work()
    {:noreply, state}
  end
end
