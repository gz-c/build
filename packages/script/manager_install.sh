#!/bin/bash
# SkyWire Install
Manager_Pid_FILE=manager.pid
if [ $1 == "yes" ];then
	pkill -F "${Manager_Pid_FILE}"
fi
type "manager" && type "discovery" && type "socksc" && type "sockss" && type "sshc" && type "sshs" > /dev/null || {
		[[ -d /usr/local/go/pkg/linux_arm64/github.com/skycoin ]] && rm -rf /usr/local/go/pkg/linux_arm64/github.com/skycoin
		cd /usr/local/go/src/github.com/skycoin/skywire/cmd
		/usr/local/go/bin/go install ./...
}
echo "Starting SkyWire Manager"
nohup /usr/local/go/bin/manager -web-dir /usr/local/go/bin/dist-manager &
if [[ ! -d /root/skywire-pids ]]; then
	mkdir -p /root/skywire-pids
fi
echo $! > "/root/skywire-log/${Manager_Pid_FILE}"
cat "/root/skywire/${Manager_Pid_FILE}"
cd /root
echo "SkyWire Manager Done"

