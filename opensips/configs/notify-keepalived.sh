#!/bin/bash
TYPE=$1
NAME=$2
STATE=$3
if [ $STATE="MASTER" ]
  then opensipsctl fifo dlg_db_sync
fi
