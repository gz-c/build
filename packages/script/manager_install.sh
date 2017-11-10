#!/bin/bash
# SkyWire Install
Manager_Pid_FILE=manager.pid
type "manager" && type "discovery" && type "socksc" && type "sockss" && type "sshc" && type "sshs" > /dev/null || {
		[[ -d /usr/local/go/pkg/linux_arm64/github.com/skycoin ]] && rm -rf /usr/local/go/pkg/linux_arm64/github.com/skycoin
		cd /usr/local/go/src/github.com/skycoin/skywire/cmd
		/usr/local/go/bin/go install ./...
}
echo "Starting SkyWire Manager"
nohup /usr/local/go/bin/manager -web-dir /usr/local/go/bin/dist-manager &
if [[ ! -d /root/skywire-log ]]; then
	mkdir -p /root/skywire-log
fi
echo $! > "/root/skywire-log/${Manager_Pid_FILE}"
cat "/root/skywire/${Manager_Pid_FILE}"
cd /root
[[ ! -f /usr/bin/manager_install.sh ]] && ln -s /usr/bin/manager_install.sh .
echo "SkyWire Manager Done"