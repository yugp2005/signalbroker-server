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

defmodule Diagnostics do

# inspiration https://en.wikipedia.org/wiki/ISO_15765-2


  use GenServer
  require Logger
  alias SignalBase.Message

  defstruct [
    :signal_server_proxy,
    req: "",
    resp: "",
    flow_mode: "",
    requester: nil,
    namespace: nil,
    response_data: <<>>,
    remaining_bytes: 0,
    query_length_bits: 0
  ]

  # CLIENT

  def start_link({signal_server_proxy}) do
    state = %__MODULE__{signal_server_proxy: signal_server_proxy}
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def send_raw(payload) when is_binary(payload) do
    GenServer.call(__MODULE__, {:send_raw, payload})
  end

  @doc """
    if you dont provide namespace you will end up using the default namespace which is specified in the config.ex file.
  """
  def setup_diagnostics(req_name, resp_name, flow_mode, namespace, requester) do
    GenServer.call(__MODULE__, {:populate_state, resp_name, req_name, flow_mode, namespace, requester})
    GenServer.call(__MODULE__, {:start_subscribe})
  end

  # SERVER

  def init(state) do
    {:ok, state}
  end

  def handle_call({:populate_state, resp_signal, req_signal, flow_mode, namespace, requester}, _from, state) do
    state = %__MODULE__{state | resp: resp_signal, req: req_signal, flow_mode: flow_mode, namespace: namespace, response_data: <<>>, remaining_bytes: 0, query_length_bits: 0, requester: requester}
    {:reply, :ok, state}
  end

  def handle_call({:start_subscribe}, _from, state) do
    SignalServerProxy.register_listeners(state.signal_server_proxy, [state.resp], :diag, self(), state.namespace)
    {:reply, :ok, state}
  end

  def handle_call({:send_raw, payload}, _from, state) do
    request_length_bits = (byte_size(payload) * 8)
    send_request(state, payload <> <<0::size(request_length_bits)>>)
    # - 8 remove the byte occupying the byte length
    {:reply, :ok, %__MODULE__{state | query_length_bits: request_length_bits - 8}}
  end

  def send_request(state, payload) do
    Logger.info "send_request: #{inspect payload}"
    <<payload_int::integer-size(64)>> = payload
    SignalServerProxy.publish(state.signal_server_proxy, [{state.req, payload_int}], :diag_write, state.namespace)
  end

  @flow_type 0x3
  @flow_continue 0

  @flow_request_all_frames 0

  def resp_flow(state, flow_command, nbr_frames, delay \\ 0)

  #delay_in_millies [0..127]
  def resp_flow(state, flow_command, @flow_request_all_frames, separation_in_millies) do
    send_request(state, <<@flow_type::size(4), flow_command::size(4), @flow_request_all_frames::size(8), separation_in_millies::size(8), 0::size(40)>>)
  end

  #delay in micros according to standard
  def resp_flow(state, flow_command, nbr_frames, delay_in_micros) do
    send_request(state, <<@flow_type::size(4), flow_command::size(4), nbr_frames::size(8), get_code_for_delay(delay_in_micros)::size(8), 0::size(40)>>)
  end

  @doc ~S"""
    iex> Diagnostics.get_code_for_delay(100)
    0xF1
  """
  def get_code_for_delay(micro_delay) do
    delay =
    case micro_delay do
      0 -> 0xF1
      _ -> 0xF0 + div(micro_delay, 100)
    end
    case (micro_delay>900) do
      true -> 0xF9
      _ -> delay
    end
  end

  #TODO we need to check that the header of the returned message matches with what was sent
  # def verify_response_header(request, response) do
  #   header_size = byte_size(header)
  # end

  @single 0
  @first 1
  @consecutive 2
  @flow 3

  def handle_cast({:signal, %Message{name_values: msg, time_stamp: timestamp, namespace: namespace}}, state) do

    # if there is more than one entry in this list the query is broken....
    [{extracted_bytes, bytes_remaining}] =
    msg
    |> Enum.map(fn {_, value} ->
      Logger.info("Received from #{state.resp} value 0x#{Integer.to_string(value, 16)} decimal #{value}")

      <<flow::size(4), _rem::size(60)>> = <<value::size(64)>>
      case state.flow_mode do
        [flow_mode: :auto] ->
          case flow do
            @single ->
              <<_::size(4), size::size(4), _::size(56)>> = <<value::size(64)>>
              size_bits = size * 8
              rem_size = 56-size_bits
              query_length_bits = state.query_length_bits
              payload_length_bits = size_bits - query_length_bits
              <<_::size(4), size::size(4), payload_confirm::size(query_length_bits), payload::size(payload_length_bits), _::size(rem_size)>> = <<value::size(64)>>
              Logger.info "single frame, number of bytes is size: #{size}, payload is #{inspect <<payload::size(payload_length_bits)>>}"
              {<<payload::size(payload_length_bits)>>, 0}
            @first -> Logger.info "first frame"
              <<_::size(4), size::size(12), payload::size(48)>> = <<value::size(64)>>
              Logger.info "remember first few bytes correspond to the query you made."
              Logger.info "first frame, number of bytes is size: #{size}, payload is #{inspect <<payload::size(48)>>}"
              query_length_bits = state.query_length_bits
              payload_length_bits = (6*8) - query_length_bits
              <<_::size(4), size::size(12), payload_confirm::size(query_length_bits), payload::size(payload_length_bits)>> = <<value::size(64)>>
              # for demo purpose split the message in smaller chunks if possible
              # case size > 16 do
              #   true -> resp_flow(state, @flow_continue, 2, 900)
              #   _ -> resp_flow(state, @flow_continue, @flow_request_all_frames, 10)
              # end
              # resp_flow(state, @flow_continue, 2, 100)
              # resp_flow(state, @flow_continue, @flow_request_all_frames, 10)
              # :timer.sleep(10)
              # send_request(state, <<0x3, 0x22, 0xf1, 0x90, 0 ,0 ,0 ,0>>)

              resp_flow(state, @flow_continue, @flow_request_all_frames)
              # 3 bytes removed from the payload, first is the query +0x40, then the send request for vin its 0xf1, 0x90... useful bytes.
              # 3 first bytes are counted
              {<<payload::size(payload_length_bits)>>, size - div(48, 8)}
              # resp_flow(state, @flow_continue, 3, 100)
            @consecutive -> Logger.info "consecutive frame"
              <<_::size(4), index::size(4), payload::size(56)>> = <<value::size(64)>>
              case state.remaining_bytes > 7 do
                true ->
                  Logger.info "consecutive frame, index is: #{index}, payload is #{inspect <<payload::size(56)>>}"
                  {<<payload::size(56)>>, (state.remaining_bytes - div(56,8))}
                false ->
                  remaining_bytes = state.remaining_bytes*8
                  <<last_bytes::size(remaining_bytes), ignore::binary>> = <<payload::size(56)>>
                  Logger.info "last frame, index is: #{index}, payload is #{inspect <<last_bytes::size(remaining_bytes)>>}"
                  {<<last_bytes::size(remaining_bytes)>>, 0}
              end
              # resp_flow(state, @flow_continue, @flow_request_all_frames)
              # resp_flow(state, @flow_continue, 3, 100)
              # send_request(state, <<0x3, 0x22, 0xf1, 0x90, 0 ,0 ,0 ,0>>)
            @flow -> Logger.info "flow frame"
              <<_::size(4), _::size(4), block_size::size(8), st::size(8)>> = <<value::size(64)>>
              Logger.info "flow frame, block size: #{inspect block_size}, ST is #{inspect <<st::size(8)>>}"
              {<<>>, state.remaining_bytes}
            _ -> Logger.info "not expected #{flow}"
              {<<>>, state.remaining_bytes}
          end
        _ -> Logger.info "manual flow control, match is #{inspect state.flow_mode}"
          {<<>>, state.remaining_bytes}
      end
      # Logger.info("size is #{size}, payload is #{inspect payload}")
    end)
    concatenated_data = state.response_data <> extracted_bytes
    Logger.debug "Responce is #{inspect concatenated_data} length is #{inspect byte_size(concatenated_data)} remaining bytes #{inspect bytes_remaining}"
    case bytes_remaining do
      0 -> :ok
        GenServer.cast(state.requester, {:diagnostics, concatenated_data})
        # send back result
        {:noreply, %__MODULE__{state | response_data: concatenated_data, remaining_bytes: bytes_remaining}}
      _ ->
        {:noreply, %__MODULE__{state | response_data: concatenated_data, remaining_bytes: bytes_remaining}}
    end
  end

end
