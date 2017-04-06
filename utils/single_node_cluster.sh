#!/bin/bash

DOCKER='docker'

# Ubuntu only
OS=`gawk -F= '/^NAME/{print $2}' /etc/os-release`

echo "Running $OS"

if [ $OS == "\"Ubuntu\"" ]; then
    DOCKER='sudo docker'
fi

start() {
    # ETCD
    $DOCKER run -d \
	    --name=etcd \
	    --net=host \
	    gcr.io/google_containers/etcd:2.0.9 \
	    /usr/local/bin/etcd \
	    --addr=127.0.0.1:4001 \
	    --bind-addr=0.0.0.0:4001 \
	    --data-dir=/var/etcd/data

    # MASTER
    $DOCKER run -d \
	    --name=master \
	    --net=host \
	    -v /var/run/docker.sock:/var/run/docker.sock \
	    jetstack/hyperkube:v0.20.1 \
	    /hyperkube kubelet \
	    --api_servers=http://localhost:8080 \
	    --v=2 \
	    --address=0.0.0.0 \
	    --enable_server \
	    --hostname_override=127.0.0.1 \
	    --config=/etc/kubernetes/manifests

    # PROXY
    $DOCKER run -d \
	    --name=proxy \
	    --net=host \
	    --privileged \
	    jetstack/hyperkube:v0.20.1 \
	    /hyperkube proxy \
	    --master=http://127.0.0.1:8080 \
	    --v=2
}


stop() {
    for n in proxy master etcd; do
	$DOCKER kill $n
	$DOCKER rm $n
    done

    for c in `$DOCKER ps -a --format="{{.Names}}"`; do
	if [[ $c == k8s* ]]; then
	    $DOCKER rm $c
	fi
    done
}


if [ \( $# -ne 1 \) ]; then
    echo '$0 <start|stop>'
    exit 1
fi

if [ $1 != "start" -a $1 != "stop" ]; then
    echo 'Invalid command'
    exit 1
fi

if [ $1 == "start" ]; then
    start
else
    stop
fi



