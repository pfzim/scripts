#!/bin/sh

find . -not -path "./_21_day_automatic_clean*" -a -type f -a -not -newerBt "21 days ago" -a -mtime +21 -a -ctime +21 -print0 | xargs -0 -I {} sh -c '
    file="{}"
    destination="/home/DZimin/_21_day_automatic_clean/_21_day_automatic_clean"
    mkdir -p "$destination/${file%/*}"
    mv "$file" "$destination/$file"'
