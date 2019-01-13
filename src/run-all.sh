#! /bin/bash

./setup-server.sh

for f in $(cat build_targets.list); do
	pushd build
	./build-layer.sh $f
	popd
done
