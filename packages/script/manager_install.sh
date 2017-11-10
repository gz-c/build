#!/bin/bash
# SkyWire Install
Manager_Pid_FILE=manager.pid
Node_Pid_FILE=node.pid
isKill=$1
if [ $isKill == "yes" ];then
	[[ -f /tmp/skywire-pids/${Manager_Pid_FILE} ]] && pkill -F "tmp/skywire-pids/${Manager_Pid_FILE}"
	[[ -f /tmp/skywire-pids/${Node_Pid_FILE} ]] && pkill -F "tmp/skywire-pids/${Node_Pid_FILE}"
fi
type "manager" && type "discovery" && type "socksc" && type "sockss" && type "sshc" && type "sshs" > /dev/null || {
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

nohup /usr/local/go/bin/node -connect-manager -manager-addrecd ss 192.168.0.2:5998 -discovery-address www.yiqishare.com:5999 -address :5000 &
echo $! > "/tmp/skywire-pids/${Node_Pid_FILE}"
cat "/tmp/skywire-pids/${Node_Pid_FILE}"

cd /root
echo "SkyWire Manager Done"

