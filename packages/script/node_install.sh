#!/bin/bash
# SkyWire Install
Node_Pid_FILE=node.pid
echo "kill $(cat ${Node_Pid_FILE})"
pkill -F "${Node_Pid_FILE}"
type "manager" && type "discovery" && type "socksc" && type "sockss" && type "sshc" && type "sshs" > /dev/null || {
		cd ${GOPATH}/src/github.com/skycoin/skywire/cmd
		go install ./...
}
echo "Starting SkyWire Node"
node -connect-manager -manager-address :5998 -discovery-address www.yiqishare.com:5999 -address :5000 &
echo $! > "${Node_Pid_FILE}"
cat "${Node_Pid_FILE}"
echo "SkyWire Node Done"