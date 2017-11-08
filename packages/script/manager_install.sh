#!/bin/bash
# SkyWire Install
Manager_Pid_FILE=manager.pid
echo "kill $(cat ${Manager_Pid_FILE})"
pkill -F "${Manager_Pid_FILE}"
type "manager" && type "discovery" && type "socksc" && type "sockss" && type "sshc" && type "sshs" > /dev/null || {
		cd ${GOPATH}/src/github.com/skycoin/skywire/cmd
		go install ./...
}
echo "Starting SkyWire Manager"
nohup manager -web-dir ${GOPATH}/bin/dist-manager &
echo $! > "${Manager_Pid_FILE}"
cat "${Manager_Pid_FILE}"
echo "SkyWire Manager Done"