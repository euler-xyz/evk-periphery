#!/bin/bash

base_file="$1"
counter=0
new_file="${base_file%.*}_${counter}.${base_file##*.}"
while [[ -e "$new_file" ]]; do
    ((counter++))
    new_file="${base_file%.*}_${counter}.${base_file##*.}"
done
echo $counter
