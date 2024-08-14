#!/bin/bash

find . -name "*.mp3" -printf "%f\n" | shuf | awk '{ printf("\"%s\" \"%03d- %s\"\n", $0, FNR+10, $0 ) }' | xargs -L1 mv
