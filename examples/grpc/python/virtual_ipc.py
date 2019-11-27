#inspired by https://grpc.io/docs/tutorials/basic/python.html

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

"""The Python implementation of the gRPC route guide client."""

from __future__ import print_function
from threading import Thread

import random
import time

import grpc

import sys
sys.path.append('generated')

import network_api_pb2
import network_api_pb2_grpc
import functional_api_pb2
import functional_api_pb2_grpc
import system_api_pb2
import system_api_pb2_grpc
import common_pb2
import diagnostics_api_pb2_grpc
import diagnostics_api_pb2

def subscribe_to_virtual_network_from_app_A(stub):
    source = common_pb2.ClientId(id="unique_app_name_A")
    namespace = common_pb2.NameSpace(name = "virtual")
    signal = common_pb2.SignalId(name="undeclared_signal", namespace=namespace)
    sub_info = network_api_pb2.SubscriberConfig(clientId=source, signals=network_api_pb2.SignalIds(signalId=[signal]), onChange=False)
    try:
        print("-------------- Listening --------------")
        for response in stub.SubscribeToSignals(sub_info):
            print(response)
    except grpc._channel._Rendezvous as err:
            print(err)


def publish_to_virtual_network_from_app_B_forever(stub):
    while True:
       publish_to_virtual_network_from_app_B(stub)


# make sure you have VirtualCanInterface namespace in interfaces.json
def publish_to_virtual_network_from_app_B(stub):
    source = common_pb2.ClientId(id="unique_app_name_B")
    namespace = common_pb2.NameSpace(name = "virtual")

    signal = common_pb2.SignalId(name="undeclared_signal", namespace=namespace)
    signal_with_payload = network_api_pb2.Signal(id = signal)
    signal_with_payload.integer = 4

    publisher_info = network_api_pb2.PublisherConfig(clientId=source, signals=network_api_pb2.Signals(signal=[signal_with_payload]), frequency = 0)
    try:
        print("-------------- Publishing --------------")
        stub.PublishSignals(publisher_info)
        time.sleep(1)
    except grpc._channel._Rendezvous as err:
        print(err)


# example show how signals can be sent between 2 (or more) client which reside on different node, potentially implemented in different languages
# key is the ClientId, which prevents the published of getting echos back.
def run():
    channel = grpc.insecure_channel('localhost:50051')
    functional_stub = functional_api_pb2_grpc.FunctionalServiceStub(channel)
    network_stub = network_api_pb2_grpc.NetworkServiceStub(channel)

    app_A_pretender = Thread(
        target = subscribe_to_virtual_network_from_app_A,
        args = (network_stub,))
    app_A_pretender.start()

    app_B_pretender = Thread(
        target = publish_to_virtual_network_from_app_B_forever,
        args = (network_stub,))
    app_B_pretender.start()

if __name__ == '__main__':
    run()
