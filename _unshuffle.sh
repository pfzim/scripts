#!/bin/bash

find . -name "*.mp3" -printf "%f\n" | shuf | sed -e "s/\([0-9]\+- \)\(.*\)/\\\"\1\2\\\" \\\"\2\\\"/" | xargs -L1 mv

