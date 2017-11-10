#!/bin/bash
# SkyWire Install
Node_Pid_FILE=node.pid
if [ $1 == "yes" ];then
	[[ -f /tmp/skywire-pids/${Node_Pid_FILE} ]] && pkill -F "tmp/skywire-pids/${Node_Pid_FILE}"
fi
type "manager" && type "discovery" && type "socksc" && type "sockss" && type "sshc" && type "sshs" > /dev/null || {
	  [[ -d /usr/local/go/pkg/linux_arm64/github.com/skycoin ]] && rm -rf /usr/local/go/pkg/linux_arm64/github.com/skycoin
			  cd /usr/local/go/src/github.com/skycoin/skywire/cmd
			  /usr/local/go/bin/go install ./...
}
echo "Starting SkyWire Node"
nohup /usr/local/go/bin/node -connect-manager -manager-address 192.168.0.2:5998 -discovery-address www.yiqishare.com:5999 -address :5000 &
if [[ ! -d /tmp/skywire-pids ]]; then
	  mkdir -p /tmp/skywire-pids
fi
echo $! > "/tmp/skywire-pids/${Node_Pid_FILE}"
cat "/tmp/skywire-pids/${Node_Pid_FILE}"
cd /root
echo "SkyWire Node Done"