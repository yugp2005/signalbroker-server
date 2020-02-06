#!/usr/bin/env python
# Copyright 2015 gRPC authors.
# Copyright 2019 Volvo Cars
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""This examples shows how to publish signals to the namespace UDPCanInterface in SignalBroker.

This example works with 'distribution_example_sub.py' and it is meant to receive the signals publish from here.
In this code we get user input from the console (only 10 times then we stop).
Each time we capture a number, we publish it as the value of signal called 'BenchC_d_2' in the 'UDPCanInterface' namespace.
Note that there is no need to specify a database for this kind of signals.

Make sure you have an interface of type 'udp' in your config/interfaces.json. Ex.:
  {
    "default_namespace": "VirtualInterface",
    "chains": [
      {
        "namespace": "UDPCanInterface",
        "type": "udp",
        "human_file": "configuration/human/benchc.json",
        "device_name": "udp2",
        "server_port": 2001,
        "target_host": "127.0.0.1",
        "target_port": 2000,
        "fixed_payload_size": 8
      }
    ],
    "gateway": {
      "gateway_pid": "gateway_pid",
      "tcp_socket_port": 4040
    },
    "auto_config_boot_server": {
      "port": 4000,
      "server_pid": "auto_config_boot_server_pid"
    },
    "reflectors": [
    ]
  }
"""
import grpc

import sys
sys.path.append('generated')

import network_api_pb2
import network_api_pb2_grpc
import common_pb2

if __name__ == '__main__':
  # Create a channel
  channel = grpc.insecure_channel('localhost:50051')
  # Create the stub
  network_stub = network_api_pb2_grpc.NetworkServiceStub(channel)
  # For 10 messages
  for _ in range(10):
    input_value = input("Enter a number: ")
    try:
      signal_value = int(input_value)
    except ValueError:
        # print(f"{input_value} is not a number. Only numbers are allowed")
        printf("error")
    else:
      # Create a signal
      namespace = common_pb2.NameSpace(name = "UDPCanInterface")
      signal = common_pb2.SignalId(name='BenchC_d_2', namespace=namespace)
      # Add payload to the signal
      signal_with_payload = network_api_pb2.Signal(id = signal)
      signal_with_payload.integer = signal_value
      # Create a publisher config
      client_id = common_pb2.ClientId(id="some_client_id")
      signals = network_api_pb2.Signals(signal= (signal_with_payload,))
      publisher_info = network_api_pb2.PublisherConfig(clientId = client_id, signals = signals, frequency = 0)
      # Publish
      try:
          network_stub.PublishSignals(publisher_info)
      except grpc._channel._Rendezvous as err:
          print(err)
