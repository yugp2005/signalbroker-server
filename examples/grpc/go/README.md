#  Go grpc signal broker example

## Example

This go example connects to the signal broker using grpc and subscribes to a set of can vehicle signals that represent the system time. The result is continously published on http://localhost:9000. 

![alt text](https://github.com/PeterWinzell/signalbroker-server/blob/go-example/examples/grpc/go/timeSync/printer/screen.png)

## Setup
First download and install go:https://golang.org/dl/. I recommend using Golang as IDE: https://www.jetbrains.com/go/
The example uses the following additional go libraries which is installed from github:

```
go get -u github.com/fogleman/gg
go get -u github.com/sirupsen/logrus
```

The grpc proto files are generated in the folder proto_files.
```
protoc -I proto_files proto_files/*.proto  --go_out=plugins=grpc:. proto_files/*.proto
```
So, the go hook files (*.pb.go) is also generated in the folder proto_files.

We have previously explained: https://github.com/volvo-cars/signalbroker-server/blob/master/configuration/interfaces.json how the signal broker needs to be initialized through **interfaces.json**, and that the matching dbc file needs to be exposed to the signal broker at startup. We can through **canplayer**, https://github.com/linux-can/can-utils., record data from a real driving cycle and replay that with can player having defined a virtual can interface which is exposed to the broker.

Set up the virtual can interfaces vcan0 on linux:

``` 
    sudo ip link add dev vcan0 type vcan
    sudo ip link set vcan0 up
```    
Start the can log playback, assuming that we have a can log named can.log

```
    canplayer -I can.log -l i vcan0=can0
```

  
## Go and the signal broker

In order to subscribe to vehicle signals we need to build a **base.SubscriberConfig struct** :
```
func subsignalDB() (*settings){
	data := &settings{
		Namespaces: []spaces{
			{Name: "BodyCANhs",
				Frames: []framee{
					{Frameid: "CEMBodyFr29",
						Sigids: []signalid{
							{Identifier: "Day"},
							{Identifier: "Hr"},
							{Identifier: "Mins"},
							{Identifier: "Sec"},
						}},
				},
			},
		},
	}

   return data
}
```
...
```
// set signals and namespaces to grpc subscriber configuration, see files under proto_files
func getSignals(data *settings)*base.SubscriberConfig{
	var signalids []*base.SignalId;
	var namespacename string

	for cindex := 0; cindex < len(data.Namespaces); cindex++{
		namespacename = data.Namespaces[cindex].Name;
		for _,frameelement := range data.Namespaces[cindex].Frames{
			for _,sigelement := range frameelement.Sigids{
				log.Info("subscribing to signal: " , sigelement);
				signalids = append(signalids,getSignaId(sigelement.Identifier,namespacename));
			}
		}
	}

	// add selected signals to subscriber configuration
	signals := &base.SubscriberConfig{
		ClientId: &base.ClientId{
			Id: "app_identifier",
		},
		Signals: &base.SignalIds{
			SignalId:signalids,
		},
		OnChange: false,
	}

	return signals
}
...
```
Together with some connection setup and a call to 

```
...
response, err := clientconnection.SubscribeToSignals(context.Background(),signals);
...
msg,err := response.Recv();
...
```
we are able to subcribe to the specified signals.
 
## Cross-compiling 

For cross-compiling go checkout: https://dave.cheney.net/2015/08/22/cross-compilation-with-go-1-5
Current example was built on mac os with the following settings to cross-compile for debian jessie and rpi3.
**GOOS=linux;GOARCH=arm;GOARM=5**
