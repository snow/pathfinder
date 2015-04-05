#!/bin/bash

DIR=$( cd "$( dirname "$0" )" && pwd )
DOMAINS_FILE="$DIR/home_domains.txt"
echo $1 >> $DOMAINS_FILE
sort $DOMAINS_FILE -uo $DOMAINS_FILE
