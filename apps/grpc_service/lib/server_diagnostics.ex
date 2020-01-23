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

defmodule Base.DiagnosticsService.Server do
  use GRPC.Server, service: Base.DiagnosticsService.Service
  require Logger

  @spec send_diagnostics_query(Base.DiagnosticsRequest.t, GRPC.Server.Stream.t) :: Base.DiagnosticsResponse.t
  def send_diagnostics_query(request, _stream) do
    Diagnostics.setup_diagnostics(request.upLink.name, request.downLink.name, [flow_mode: :auto], String.to_atom(request.upLink.namespace.name), self())
    length = 1 + byte_size(request.serviceId) + byte_size(request.dataIdentifier)
    case length > 8 do
      true ->
        Logger.warn "request to long, not currently supported"
        Base.DiagnosticsResponse.new(raw: <<>>)
      false ->
        Diagnostics.send_raw(<<(length-1)::size(8)>> <> request.serviceId <> request.dataIdentifier)
        receive do
          {_, {:diagnostics, response_bytes}} ->
            Base.DiagnosticsResponse.new(raw: response_bytes)
        after
          1_000 ->
            Base.DiagnosticsResponse.new(raw: <<>>)
        end
    end
  end
end
