#!/bin/bash

doppler setup -p "evk-periphery" --config "prd"
doppler secrets download --no-file --format env > .env
doppler configure unset config
