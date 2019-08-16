package main

import (
	"context"
	"encoding/json"
	"fmt"
	log "github.com/sirupsen/logrus"
	"os"
)
import "google.golang.org/grpc"
import "signalbroker-server/examples/grpc/go/timeSync/proto_files"


type Configuration struct{
	Brokerip string
	Brokerport string
}

var conf Configuration

func InitConfiguration()(bool){
	file,err := os.Open("configuration.json")
	defer file.Close()

	if  err != nil {
		log.Error("could not open configuration.json ", err)
		return false
	} else{
		decoder := json.NewDecoder(file)
		conf = Configuration{}
		err2 := decoder.Decode(&conf)
		if err2 != nil{
			log.Error("could not parse configuration.json ", err2)
			return false
		}

	}

	return true
}

type signalid struct{
	Identifier string
}

type framee struct{
	Frameid string `json:frameid`
	Sigids []signalid `json:sigids`
}

type spaces struct{
	Name  string `json:name`
	Frames []framee `json:framee`
}

type settings struct{
	Namespaces []spaces `json:namespaces`
}

type VehiclesList struct{
	Vehicles []settings `json:vehicles`
}


// print current configuration to the console
func printSignalTree(clientconnection *grpc.ClientConn) {
	systemServiceClient := base.NewSystemServiceClient(clientconnection);
	configuration,err := systemServiceClient.GetConfiguration(context.Background(),&base.Empty{})

	infos := configuration.GetNetworkInfo();
	for _,element := range infos{
		printSignals(element.Namespace.Name,clientconnection);
	}

	if err != nil{
		log.Debug("could not retrieve configuration " , err);
	}

}

// print signal tree(s) to console , using fmt for this.
func printSpaces(number int){
	for k := 1; k < number; k++ {
		fmt.Print(" ");
	}
}

func printTreeBranch(){
	fmt.Print("|");
}

func getFirstNameSpace(frames []*base.FrameInfo) string{
	element := frames[0];
	return element.SignalInfo.Id.Name;
}

func printSignals(zenamespace string,clientconnection *grpc.ClientConn){
	systemServiceClient := base.NewSystemServiceClient(clientconnection)
	signallist, err := systemServiceClient.ListSignals(context.Background(),&base.NameSpace{Name : zenamespace})

	frames := signallist.GetFrame();

	rootstring := "|[" + zenamespace + "]---|";
	rootstringlength := len(rootstring);
	fmt.Println(rootstring);

	for _,element := range frames{

		printTreeBranch();
		printSpaces(rootstringlength -1);

		framestring := "|---[" + element.SignalInfo.Id.Name + "]---|";
		framestringlength := len(framestring);

		fmt.Println(framestring);
		childs := element.ChildInfo;

		for _,childelement := range childs{
			outstr := childelement.Id.Name;
			printTreeBranch();
			printSpaces(rootstringlength -1);
			printTreeBranch();
			printSpaces(framestringlength - 1);
			fmt.Println("|---{", outstr, "}");
		}
	}

	if err != nil {
		log.Debug(" could not list signals ", err);
	}
}

// hard coded predefined settings used for examples.
func fakeSignalDB(vin string) (*settings){
	data := &settings{
		Namespaces: []spaces{
			{Name: "BodyCANhs",
				Frames: []framee{
					{Frameid: "DDMBodyFr01",
						Sigids: []signalid{
							{Identifier: "ChdLockgProtnFailrStsToHmi_UB"},
							{Identifier: "ChdLockgProtnStsToHmi_UB"},
							{Identifier: "DoorDrvrLockReSts_UB"},
							{Identifier: "ChdLockgProtnFailrStsToHmi"},
							{Identifier: "WinPosnStsAtDrvrRe"},
						}},
					{Frameid: "PAMDevBodyFr09",
						Sigids: []signalid{
							{Identifier: "DevDataForPrkgAssi9Byte0"},
							{Identifier: "DevDataForPrkgAssi9Byte1"},
							{Identifier: "DevDataForPrkgAssi9Byte2"},
						},
					},
				},
			},
		},
	}


   return data
}

func main(){
	fmt.Println(" we are testing go with the volvo signal broker")

	InitConfiguration()
	conn, err := grpc.Dial(conf.Brokerip + ":"+ string(conf.Brokerport), grpc.WithInsecure())
	if err != nil {
		log.Debug("did not connect: %v", err)
	}
	defer conn.Close()

	// printSignalTree
	printSignalTree(conn)
}
