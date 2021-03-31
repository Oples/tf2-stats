#!/bin/sh
echo "Downloading every image listed inside the map_list.md file"
mkdir downloaded
cp map_list.md map_list.md.tmp
sed -i -e 's/- //g' map_list.md
wget -c -i map_list.md -P downloaded
mv map_list.md.tmp map_list.md
