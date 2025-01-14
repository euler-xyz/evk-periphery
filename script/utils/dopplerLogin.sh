#!/bin/bash

doppler login
EXITCODE=$?

if [ "$EXITCODE" -ne "0" ]; then
    echo "Doppler CLI is probably not installed. Please go to https://docs.doppler.com/docs/install-cli and follow the instructions for your OS."
    exit $EXITCODE
fi
