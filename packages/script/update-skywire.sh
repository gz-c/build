#!/bin/bash
branch=$1
echo "Updating SkyWire..."
cd $GOPATH/src/github.com/skycoin/skywire
git pull origin $branch
cd $GOPATH/src/github.com/skycoin/skywire/cmd
go install ./...

[[ -f /tmp/skywire-pids/manager.pid ]] && pkill -F /tmp/skywire-pids/manager.pid
[[ -f /tmp/skywire-pids/node.pid ]] && pkill -F /tmp/skywire-pids/node.pid

echo "Done"
reboot