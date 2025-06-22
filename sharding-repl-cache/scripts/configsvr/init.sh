#!/bin/bash
sleep 1
until mongosh --port 27017 --file "$(dirname "$0")/init.js"
do
sleep 1
done