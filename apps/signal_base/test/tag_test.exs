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

defmodule TagTest do
  use ExUnit.Case

  test "Register publisher with and without tag" do
    {:ok, _} = SignalBase.start_link(:broker0, :any, nil)

    SignalBase.register_publisher(:broker0, ["Hello0"], self())
    SignalBase.register_publisher_with_tags(:broker0, [{"Hello1", [:tag0]}], self())
    SignalBase.register_publisher_with_tags(:broker0, [{"Hello2", [:tag0, :tag1]}], self())

    Helpers.close_processes([:broker0])
  end

  test "Register publisher with and without tag using arrays" do
    {:ok, _} = SignalBase.start_link(:broker0, :any, nil)

    SignalBase.register_publisher(:broker0, ["Hello0", "Hello1"], self())
    SignalBase.register_publisher_with_tags(:broker0, [{"Hello3", [:tag0]}, {"Hello4", [:tag0, :tag1]}], self())

    Helpers.close_processes([:broker0])
  end

  test "Get registered by tag" do
    {:ok, _} = SignalBase.start_link(:broker0, :any, nil)

    SignalBase.register_publisher_with_tags(:broker0, [{"Hello0", [:tag0]}], self())
    SignalBase.register_publisher_with_tags(:broker0, [{"Hello1", [:tag1]}], self())

    assert SignalBase.get_channels_by_tag(:broker0, :tag0) == ["Hello0"]
    assert SignalBase.get_channels_by_tag(:broker0, :tag1) == ["Hello1"]

    Helpers.close_processes([:broker0])
  end

  test "Get registered by tag using arrays" do
    {:ok, _} = SignalBase.start_link(:broker0, :any, nil)

    SignalBase.register_publisher(:broker0, ["Hello0", "Hello1"], self())
    SignalBase.register_publisher_with_tags(:broker0, [{"Hello3", [:tag0]}, {"Hello4", [:tag0, :tag1]}], self())

    assert Enum.sort(SignalBase.get_channels_by_tag(:broker0, :tag0)) == Enum.sort(["Hello3", "Hello4"])
    assert SignalBase.get_channels_by_tag(:broker0, :tag1) == ["Hello4"]

    Helpers.close_processes([:broker0])
  end
end
