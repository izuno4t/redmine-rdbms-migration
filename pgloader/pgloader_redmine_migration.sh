#!/bin/bash -xv

docker run --rm --net="host" --name pgloader -v $(pwd)/config.load:/tmp/config.load dimitri/pgloader:latest pgloader --dry-run /tmp/config.load
