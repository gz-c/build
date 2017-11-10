#!/bin/bash
# SkyWire Install
Manager_Pid_FILE=manager.pid
isKill=$1
if [ $isKill == "yes" ];then
	[[ -f /tmp/skywire-pids/${Manager_Pid_FILE} ]] && pkill -F "tmp/skywire-pids/${Manager_Pid_FILE}"
fi
command -v "manager" && command -v "discovery" && command -v "socksc" && command -v "sockss" && command -v "sshc" && command -v "sshs" > /dev/null || {
		[[ -d /usr/local/go/pkg/linux_arm64/github.com/skycoin ]] && rm -rf /usr/local/go/pkg/linux_arm64/github.com/skycoin
		cd /usr/local/go/src/github.com/skycoin/skywire/cmd
		/usr/local/go/bin/go install ./...
}
echo "Starting SkyWire Manager"
if [[ ! -d /tmp/skywire-pids ]]; then
	mkdir -p /tmp/skywire-pids
fi
nohup /usr/local/go/bin/manager -web-dir /usr/local/go/bin/dist-manager &
echo $! > "/tmp/skywire-pids/${Manager_Pid_FILE}"
cat "/tmp/skywire-pids/${Manager_Pid_FILE}"
cd /root
echo "SkyWire Manager Done"

/usr/bin/node_install.sh
