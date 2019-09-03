#  Go grpc signal broker example

## Example

This go example connects to the signal broker using grpc and subscribes to a set of can vehicle signals that represent the system time. The result is continously published on http://localhost:9000. 

![alt text](https://github.com/PeterWinzell/signalbroker-server/blob/go-example/examples/grpc/go/timeSync/printer/screen.png)

## setup
First download and install go:https://golang.org/dl/. I recommend using Golang as IDE: 
The example uses the following additional go libraries which is installed from github:

```
go get -u github.com/fogleman/gg
go get -u github.com/sirupsen/logrus
```

The grpc proto files are generated in the folder proto_files.
```
protoc -I proto_files proto_files/*.proto  --go_out=plugins=grpc:. proto_files/*.proto
```

