#!/bin/bash

read -p 'Enter path to the jmx file ' jmx

if [ ! -f "$jmx" ];
then
    echo "File was not found in PATH"
    echo "Please check and input the correct file path"
    exit
fi

read -p 'Enter path to the jmx file ' csv

if [ ! -f "$csv" ];
then
    echo "File was not found in PATH"
    echo "Please check and input the correct file path"
    exit
fi

slaveList=`kubectl get po -n kubernauts | grep slaves | cut -d ' ' -f1`
for i in $slaveList
do
	kubectl cp $jmx $csv -n kubernauts $i:/jmeter/apache-jmeter-4.0/bin/
	if [ $? -gt '0' ];then
		echo "copy failed - $1"
		exit 1
	else
		echo "Successfully copied on $i - $jmx"
		echo "Successfully copied on $i - $csv"

	fi
done
