#!/usr/bin/env bash
#Script created to launch Jmeter tests directly from the current terminal without accessing the jmeter master pod.
#It requires that you supply the path to the jmx file
#After execution, test script jmx file may be deleted from the pod itself but not locally.

working_dir=`pwd`

#Get namesapce variable
tenant=`awk '{print $NF}' $working_dir/tenant_export`

read -p 'Enter path to the jmx file ' jmx

if [ ! -f "$jmx" ];
then
    echo "Test script file was not found in PATH"
    echo "Kindly check and input the correct file path"
    exit
fi

read -p 'Enter path to the csv folder ' csv

if [ ! -d "$csv" ];
then
    echo "CSV folder was not found in PATH"
    echo "Kindly check and input the correct file path"
    exit
fi

#Get Master pod details

echo "Started to copy $jmx on master"

master_pod=`kubectl get po -n $tenant | grep jmeter-master | awk '{print $1}'`

kubectl cp $jmx -n $tenant $master_pod:/$jmx

echo "Successfully copied on $master_pod - $jmx"

echo 

echo "Started to copy $csv folder on slave pods"

slaveList=`kubectl get po -n $tenant | grep slaves | cut -d ' ' -f1`
for i in $slaveList
do
        kubectl cp $csv -n $tenant $i:/jmeter/apache-jmeter-4.0/bin/
        if [ $? -gt '0' ];then
                echo "copy failed - $1"
                exit 1
        else
                echo "Successfully copied on $i - $csv"

        fi
done

## Echo Starting Jmeter load test

kubectl exec -ti -n $tenant $master_pod -- /jmeter/load_test $jmx
