#!/usr/bin/env bash
#Script created to launch Jmeter tests directly from the current terminal without accessing the jmeter master pod.
#It requires that you supply the path to the jmx file
#After execution, test script jmx file may be deleted from the pod itself but not locally.

working_dir=`pwd`

#Condition given as true by default
status=true;

#Creating function to validate the file is available in the specified location
validateFile () {

        if [ -f $1 ];then
                return 0
        else
                echo "File does not exists in the specified path. Please Check!";
                exit 1
        fi
}

#Get namesapce variable
tenant=`awk '{print $NF}' $working_dir/tenant_export`

#Get Master pod details
kubectl get po -n $tenant | grep jmeter-master | awk '{print $1}' >master.csv

kubectl exec -ti -n $tenant $master_pod -- rm mapper.csv

#file which will store the jmx and csv file names

kubectl exec -ti -n $tenant $master_pod -- touch mapper.csv

#Get Slave pod details
slaveList=`kubectl get po -n $tenant | grep slaves | cut -d ' ' -f1`

while $status; do

read -p 'Enter path to the jmx file: ' jmx
validateFile $jmx
echo "Started to copy $jmx on master"
kubectl cp $jmx -n $tenant $master_pod:/$jmx
echo "Successfully copied on $master_pod - $jmx"

read -p "Do you want to pass the csv file [y/n]: " csvStatus

if [ $csvStatus ];then

        if [ $csvStatus == 'y' ]; then
                read -p "Enter path to the csv file: " csv
                validateFile $csv
		echo "Started to copy $csv folder on slave pods"
			for i in $slaveList
			do
			kubectl exec -ti -n $tenant $i -- mkdir -p /jmeter/apache-jmeter-4.0/bin/csv/
        		kubectl cp $csv -n $tenant $i:/jmeter/apache-jmeter-4.0/bin/csv/
       			         if [ $? -gt '0' ];then
                	             echo "Sorry copy failed! - $1"
                	             exit 1
        		         else
                	             echo "Successfully copied on $i - $csv"
       		                 fi
                        done

        fi
else

   echo "Please enter a valid response y or n: ";
   status=true;

fi

kubectl exec -ti -n $tenant $master_pod -- bash -c "echo $jmx>>mapper.csv"

read -p "Do you have another jmx file [y/n]: " status

if [ $status ];then

        if [ $status == 'y' ]; then
           status=true;
        elif [ $status == 'n' ]; then
           status=false;
        else
           echo "Please enter a valid response y or n: ";
           status=true;
        fi
else

   echo "Please enter a valid response y or n: ";
   status=true;
fi

done

## Echo Starting Jmeter load test

kubectl exec -ti -n $tenant $master_pod -- /jmeter/load_test
