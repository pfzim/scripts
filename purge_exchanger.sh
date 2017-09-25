#!/bin/sh

find . -not -path "./_21_day_automatic_clean*" -a -not -newerBt "`date --date='21 days ago'`" -a -mtime +21 -a -ctime +21 -print0
