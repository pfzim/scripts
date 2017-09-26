#!/bin/sh

# This script for clear shared folder in 2 steps
# Step 1: Move files that does not created and not modified since last XX days to subfolder _XX_day_automatic_clean
# Step 2: If moved files not modified in XX days it will be deleted

days=21
src=/share/public/exchange

# move files to trash
eval "find \"$src/\" -not -path \"$src/_${days}_day_automatic_clean/*\" -a -type f -a -not -newerBt \"$days days ago\" -a -mtime +$days -a -ctime +$days -print0 | sed -z -e \"s|^$src/||\" | xargs -0 -I {} sh -c 'file=\"{}\"; mkdir -p \"$src/_${days}_day_automatic_clean/\${file%/*}\"; mv \"$src/\$file\" \"$src/_${days}_day_automatic_clean/\$file\"'; touch \"$src/_${days}_day_automatic_clean/$file\""

# purge trash
find "$src/_${days}_day_automatic_clean" -type f -a -not -newerBt "$days days ago" -a -mtime +$days -a -ctime +$days -delete
