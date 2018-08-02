#!/bin/bash
mappedValues=`paste jmx.csv master.csv -d ,`

for i in $mappedValues
do 
	echo "$i"

done
