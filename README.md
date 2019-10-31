# Signalbroker

[![Build Status](https://travis-ci.com/volvo-cars/signalbroker-server.svg?branch=master)](https://travis-ci.com/volvo-cars/signalbroker-server)

Development tool to read and write CAN/LIN and other buses using gRPC which allows usage of preferred language.

Sample scenarios:
* [5Gcar](https://5gcar.eu/) where it's used to gather realtime data from Volvo vehicles.  
    Video: [5GCar data collection](https://www.youtube.com/watch?time_continue=9&v=LJ5k8XmLfH4)<br />
    Report: [link to report 5.2](https://5gcar.eu/wp-content/uploads/2019/08/5GCAR_D5.2_v1.0.pdf)
* [W3C automotive specification](https://github.com/MEAE-GOT/W3C_VehicleSignalInterfaceImpl/) more specific [code location](https://github.com/MEAE-GOT/W3C_VehicleSignalInterfaceImpl/blob/W3C_Demo_2019/server/Go/server-1.0/service_mgr_broker.go)

## Disclaimer

Documentation is still ongoing, Project is operational out of the box, but custom dbc/ldf/human files are recomended to get the most out of it.

## Teaser

![Components](/examples/grpc/grpc-web/signalBrokerScreenshot.png)

![Components](/examples/grpc/grpc-web/SBDiags.png)
keep reading...

## Hardware

The software can execute on any Linux with [SocketCAN](https://en.wikipedia.org/wiki/SocketCAN). On hosts without hardware CAN interfaces, CAN be configured using:
```
sudo modprobe vcan
sudo ip link add dev vcan0 type vcan
sudo ifconfig vcan0 up
```

System is configured using [interfaces.json](configuration/interfaces.json)

Extensive reference can be found here [link](configuration/interfaces_referense.json)

## Real deal

In order to access real CAN the following hardware can be used.

Suggested hardware
- Raspberry PI.
- Raspberry PI CAN shield [get it here for US](https://copperhilltech.com/pican2-duo-can-bus-board-for-raspberry-pi-2-3/) or [here for Europe](http://skpang.co.uk/catalog/pican2-duo-canbus-board-for-raspberry-pi-23-with-smps-p-1481.html).
- [lin DYI](https://github.com/volvo-cars/signalbroker-lin-transceiver/tree/master)

Works is ongoing for CAN-FD support which is in experimental stage.
- Raspberry PI CAN-FD shield [get it here for US](https://copperhilltech.com/pican-fd-can-bus-fd-duo-board-with-real-time-clock-for-raspberry-pi/) or [here for Europe](http://skpang.co.uk/catalog/pican-fd-duo-board-with-real-time-clock-for-raspberry-pi-3-p-1568.html)

## Accessing the server
Signalbroker is headless but can be accessed using the grpc-web [frontend](https://github.com/volvo-cars/signalbroker-web-client)

To get aquainted to the system the easiest way to get going is by checking out the simple [telnet guide](apps/app_telnet/README.md)

However, the preferred way of accessing the system is by using grpc. Follow this [link](/apps/grpc_service/proto_files) to find the protofiles, and browse the [examples](/examples/grpc) to get inspiration

### Additional access possibilities
* c code. If you like to use c code [go here](/apps/app_unixds/README.md)
* websockets, make it play with node [red](https://nodered.org/) or similar, [go here]((https://github.com/volvo-cars/signalbroker-web-client))

## Starting the server (for docker skip down)

- [Install elixir](https://elixir-lang.org/install.html).
- Clone this repository.
- Make sure your `configuration/interfaces.json` makes sense (or try out of the box).
- Start the software by doing.

```
mix deps.get
iex -S mix
```

## Alternatively; start using docker

```bash
docker build -t signalbroker:v1 -f ./docker/Dockerfile .
```


to run with your configuration:
```bash
docker run --rm -it --privileged=true --net=host -p 4040:4040 -p 50051:50051 -p 2000:2000/udp -p 2001:2001/udp -v $PWD/configuration/:/signalbroker/_build/prod/rel/signal_server/configuration signalbroker:v1
```

or run it with sample configuration:
```bash
docker run --rm -it -p 4040:4040 -p 50051:50051 -p 2000:2000/udp -p 2001:2001/udp signalbroker:v1

```

note 1: mac doesn't have socketcan so you can omit `--net=host`

note 2: you should be able to do above on intel or arm. However ARM is not testad at this point.


## Playback for off line purposes
On your Linux computer, install the following.
```
apt-get install can-utils
```
Record can from a real network:
```
candump -L can0 > myfile.log
```
Once you configured your *interfaces.json* to use virtual CAN interfaces by setting using `vcan0` instead of `can0` just play back your recorded file:
```
canplayer vcan0=can0 -I myfile.log
```

## Running examples with fake data
Install `can-utils` as described above the generate fake data using:
```
cangen vcan0  -v -g 1
```

## Running examples with fake data without socketcan (particulary useful for mac/osx)
Interfaces contains a namespace "UDPCanInterface" this accepts data over UDP.

to simulate can traffic from your host:
```bash
echo -n '00000040080102030405060708' | xxd -r -p | nc -w 1 -u 127.0.0.1 2001
```

or wrap it with `watch` to keep it repeating the command
```bash
watch -n 0 "echo -n '00000040080102030405060708' | xxd -r -p | nc -w 1 -u 127.0.0.1 2001"
```

format is id::size(32), payload_length::size(8), payload::(64)
Size is ignored if `"fixed_payload_size": 8` in `interfaces.json` file is set.

Above command will produce a message on id 0x40 where `BenchC_a` signal resides in the default sample configuration. You can verify this by doing
```bash
telnet 127.0.0.1 4040
{"command": "subscribe", "signals": ["BenchC_d_8","BenchC_d_2","BenchC_c_5","BenchC_c_1","BenchC_c_6","BenchC_d_7","BenchC_d_1","BenchC_c_7","BenchC_a","BenchC_d_4","BenchC_c_2","BenchC_d_6","BenchC_d_5","BenchC_c_8","BenchC_d_3","BenchC_c_4","BenchC_b","BenchC_c_3"], "namespace" : "UDPCanInterface"}
```
if you now send `echo -n ..` you will receive something like
```
{"timestamp":1569247543145471,"signals":{"BenchC_a":72623859790382856}}
```

## ODB diagnostics

https://en.wikipedia.org/wiki/OBD-II_PIDs is a set of predifined queries which many vehicle supports. For this scenario you can start by using the predefiend [dbc](configuration/can/diagnostics.dbc). Start by running queries using the [frontend](https://github.com/volvo-cars/signalbroker-web-client) or check out the diagnostics [sample](examples/grpc/python/simple_example.py#L62). 

## TODO - help appreciated
- [x] Provide ~~pre~~ build docker image.
- [x] Add default configuration.
- [x] Add gRPC sample code.
- [x] Publish repository for creating custom LIN hardware.
- [ ] Add sample dbc files.
- [ ] Re-enable test suite.
- [ ] ~~Make code (branch) runnable on mac where SocketCan is missing~~ fixed with other mac bullets
- [x] Add example on how to feed server with (can) traffic over udp. Enables traffic simulation on osx/mac.
- [ ] Add bash/py script which playbacks recorded can traffic using udp
- [x] Add inspirational video
- [ ] Parse signal meta data and fill in appropriate fields in the
- [ ] Elixir module that dumps data to [InfluxDB](https://www.influxdata.com/) alternatively to [Riak TS](https://riak.com/products/riak-ts/), which can be visualized by [Grafana](https://grafana.com/).
- [ ] Promote your .dbc and .ldf files
- [ ] Add reflection sample or documentation.

# Help us improve!

The Signalbroker is in active development and would appreciate your feature suggestions or bug reports. File them as issues in this repository :)
