#!/bin/bash
# SkyWire Install
Manager_Pid_FILE=manager.pid
type "manager" && type "discovery" && type "socksc" && type "sockss" && type "sshc" && type "sshs" > /dev/null || {
		cd /usr/local/go/src/github.com/skycoin/skywire/cmd
		/usr/local/go/bin/go install ./...
}
echo "Starting SkyWire Manager"
nohup /usr/local/go/bin/manager -web-dir /usr/local/go/bin/dist-manager &
echo $! > "/root/skywire/${Manager_Pid_FILE}"
cat "/root/skywire/${Manager_Pid_FILE}"
echo "SkyWire Manager Done"