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

defmodule Test.Config do
  def get_test_config do
    %{
      chains: [
        %{
          dbc_file: "configuration/can_files/SPA0610/SPA0610_140404_BodyCANhs.dbc",
          device_name: "vcan0",
          type: "can",
          namespace: "body",
        },
        %{
          dbc_file: "configuration/can_files/SPA0610/SPA0610_140404_BodyCANhs.dbc",
          device_name: "vcan0",
          type: "can",
          namespace: "BodyCANhs",
        },
        %{
          dbc_file: "configuration/can_files/SPA0610/SPA0610_140404_ChassisCANhs.dbc",
          device_name: "vcan1",
          type: "can",
          namespace: "chassis",
        },
        %{
          dbc_file: "configuration/can_files/SPA0610/SPA0610_140404_ChassisCANhs.dbc",
          device_name: "vcan1",
          type: "can",
          namespace: "chassis2"
        },
        %{
          dbc_file: "configuration/can_files/SPA0610/SPA0610_140404_PropulsionCANhs.dbc",
          device_name: "udp2",
          server_port: 2001,
          target_host: {127, 0, 0, 1},
          target_port: 2000,
          type: "udp",
          namespace: "PropulsionCANhs",
        },
        %{
          type: "flexray",
          device_name: "wicevflexray0",
          namespace: "FlexrayBackbone",
          config: %{
                   target_host: "127.0.0.1",
                   target_port: 51111
          },
          fibex_file: "configuration/fibex_files/SPA0911_160121_BackBone_VCC.xml"
        },
        %{
          type: "lin",
          namespace: "Lin",
          ldf_file: "apps/app_lin/config/ldf_files/SPA1910_LIN18.ldf",
          schedule_file: "apps/app_lin/config/ldf_files/single_schedule.ldf",
          schedule_table_name: "CcmLin18ScheduleTable1",
          schedule_autostart: true,
          device_name: "lin",
          server_port: 2002,
          target_host: "127, 0, 0, 1",
          target_port: 2003
        },
        %{
          type: "lin",
          namespace: "Lin1",
          ldf_file: "../app_lin/config/ldf_files/SPA1910_LIN18.ldf",
          schedule_file: "../app_lin/config/ldf_files/single_schedule.ldf",
          schedule_table_name: "CcmLin18ScheduleTable1",
          schedule_autostart: true,
          device_name: "lin",
          server_port: 2002,
          target_host: "127, 0, 0, 1",
          target_port: 2003
        },
        %{
          device_name: "virtual",
          type: "virtual",
          namespace: "Virtual"
        }
      ],
      default_namespace: "body",
      gateway: %{gateway_pid: :gateway_pid, tcp_socket_port: 4040},
      reflectors: [
        [
          application_pid: :my_name1,
          reflect: %{
            dest: "PropulsionCANhs",
            exclude: ["CEMBodyFr15", "CEMBodyFr22"],
            source: "body",
          }
        ]
      ]
    }
  end
end
