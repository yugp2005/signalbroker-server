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

defmodule V542Examples do

  # operates on BodyCANhs, barely tested

  @read_data_by_identifier 0x22

  def v542_read_vin() do
    Diagnostics.setup_diagnostics("CemToCcmBodyDiagReqFrame ", "CcmToCemBodyDiagResFrame", [flow_mode: :auto], :can0, self())
    # 3 bytes
    # 0x22 read data by identinifier (Service id)
    # 0x1f90 did for vin number (Data identifier)
    Diagnostics.send_raw(<<0x03, @read_data_by_identifier, 0xF190::size(16), 0x00, 0x00, 0x00, 0x00>>)
  end

  # same again but defaults to default namespace which is specified on the config file.
  def v542_read_vin_default() do
    Diagnostics.setup_diagnostics("CemToCcmBodyDiagReqFrame ", "CcmToCemBodyDiagResFrame", [flow_mode: :auto], :can0, self())
    # 3 bytes
    # 0x22 read data by identinifier (Service id)
    # 0x1f90 did for vin number (Data identifier)
    Diagnostics.send_raw(<<0x03, @read_data_by_identifier, 0xF190::size(16), 0x00, 0x00, 0x00, 0x00>>)
  end

  def v542_read_fuel_lid_latch_status() do
    Diagnostics.setup_diagnostics("CemToAllFuncBodyDiagReqFrame", "CcmToCemBodyDiagResFrame", [flow_mode: :auto], :can0, self())
    # 3 bytes
    # 0x22 read data by identinifier (Service id)
    Diagnostics.send_raw(<<0x03, @read_data_by_identifier, 0xEFFC::size(16), 0x00, 0x00, 0x00, 0x00>>)
  end

  def v542_read_in_car_temp() do
    Diagnostics.setup_diagnostics("CemToAllFuncBodyDiagReqFrame", "CcmToCemBodyDiagResFrame", [flow_mode: :auto], :can0, self())
    # 3 bytes
    # 0x22 read data by identinifier (Service id)
    Diagnostics.send_raw(<<0x03, @read_data_by_identifier, 0xDD04::size(16), 0x00, 0x00, 0x00, 0x00>>)
  end

  def v542_read_in_car_temp_outside() do
    Diagnostics.setup_diagnostics("CemToAllFuncBodyDiagReqFrame", "CcmToCemBodyDiagResFrame", [flow_mode: :auto], :can0, self())
    # 3 bytes
    # 0x22 read data by identinifier (Service id)
    Diagnostics.send_raw(<<0x03, @read_data_by_identifier, 0xDD05::size(16), 0x00, 0x00, 0x00, 0x00>>)
  end

  def v542_air_condition_on_switch() do
    Diagnostics.setup_diagnostics("CemToAllFuncBodyDiagReqFrame", "CcmToCemBodyDiagResFrame", [flow_mode: :auto], :can0, self())
    # 3 bytes
    # 0x22 read data by identinifier (Service id)
    Diagnostics.send_raw(<<0x03, @read_data_by_identifier, 0x99A3::size(16), 0x00, 0x00, 0x00, 0x00>>)
  end

end
