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

defmodule CanUdp do
  @moduledoc """
  Help functions.
  """

  @doc """
  Creates a binary packet for a UDP CAN frame.
  Transmitable over UDP.

  ## Example
    iex> CanUdp.make_udp_frame(3, <<1, 2, 3>>)
    <<0, 0, 0, 3, 3, 1, 2, 3>>
  """
  def make_udp_frame(frame_id, frame_payload) do
    size = byte_size(frame_payload)

    <<
      frame_id :: unsigned-size(32),
      size :: unsigned-size(8),
      frame_payload :: binary
    >>
  end

  def make_udp_frame_size(frame_id, expected_bytes_in_response) do
    <<
      frame_id :: unsigned-size(32),
      expected_bytes_in_response :: unsigned-size(8),
    >>
  end

  def parse_udp_frames(data) do
    <<
      id :: unsigned-size(32),
      _size :: unsigned-size(8),
      payload :: binary
    >> = data

    [{id, payload}]
  end
end
