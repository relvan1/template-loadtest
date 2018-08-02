#!/bin/bash

sudo rm mapper.csv -rf
sudo rm *.yaml -rf

working_dir=`pwd`


### Getting NameSpace ###
tenant=`awk '{print $NF}' $working_dir/tenant_export`

touch mapper.csv

status=true;

validateFile () {

	if [ -f $1 ];then
		return 0
	else
		echo "file not exists";
		exit 1
	fi
}

while $status; do

jmxFile=""
csv=""
nodeName=""

read -p "Enter node name : " nodeName

read -p "Enter jmx file : " jmxFile
validateFile $jmxFile


read -p "You want to pass csv file [y/n] " csvStatus

if [ $csvStatus ];then

	if [ $csvStatus == 'y' ]; then
		read -p "Enter csv file : " csv
		validateFile $csv
	fi
else

   echo  "Enter a valid response y or n ";
   status=true;

fi

echo $jmxFile,$csv,$nodeName >>mapper.csv

read -p "Enter another jmx file [y/n] " status

if [ $status ];then

	if [ $status == 'y' ]; then
	   status=true;
	elif [ $status == 'n' ]; then
	   status=false;
	else
	   echo  "Enter a valid response y or n ";
	   status=true;
	fi
else
   echo  "Enter a valid response y or n ";
   status=true;
fi

done

echo "### Provisioning ###"

jmx=`cat mapper.csv | awk 'BEGIN{FS=","} ; { print $1 }'`

for i in $jmx
do

	### Master deployment ###
	
        cp templates/jmeter_master_configmap.yaml ./

	nodeName=`cat mapper.csv | grep $i | awk 'BEGIN{FS=","} ; { print $3 }'`

	sed -i "s/nodeVariable/$nodeName/g" jmeter_master_configmap.yaml
        
	kubectl create -n $tenant -f $working_dir/jmeter_master_configmap.yaml

	cp templates/jmeter_master_deploy.yaml ./

	jmxName=`echo $i | cut -d '.' -f1`

	sed -i "s/nameVariable/$jmxName-master/g" jmeter_master_deploy.yaml
	sed -i "s/labelVariable/$jmxName-master/g" jmeter_master_deploy.yaml
	sed -i "s/containerNameVariable/$jmxName-master/g" jmeter_master_deploy.yaml
	sed -i "s/nodeVariable/$nodeName/g" jmeter_master_deploy.yaml

	kubectl get pods -n $tenant | grep $jmxName-master
	
	if [ $? -gt '0' ];then

	kubectl create -n $tenant -f jmeter_master_deploy.yaml
	
	fi
        
        sleep 10

        master_pod=`kubectl get po -n $tenant | grep  ${jmxName}-master | awk '{print $1}'`

	kubectl cp $i -n $tenant $master_pod:/$i

	#Get Master pod details
		
        kubectl exec -ti -n $tenant $master_pod -- cp  /load_test /jmeter/load_test

        kubectl exec -ti -n $tenant $master_pod -- chmod 755 /jmeter/load_test


	### Slaves creation ###

	cp templates/jmeter_slaves_deploy.yaml ./

	csv=`cat mapper.csv | grep $i | awk 'BEGIN{FS=","} ; { print $2 }'`

	sed -i "s/nameVariable/$jmxName-slave/g" jmeter_slaves_deploy.yaml
	sed -i "s/labelVariable/$jmxName-slave/g" jmeter_slaves_deploy.yaml
	sed -i "s/containerNameVariable/$jmxName-slave/g" jmeter_slaves_deploy.yaml
	sed -i "s/nodeVariable/$nodeName/g" jmeter_slaves_deploy.yaml

	kubectl get pods -n $tenant | grep $jmxName-slave
	
	if [ $? -gt '0' ];then

	kubectl create -n $tenant -f jmeter_slaves_deploy.yaml

	fi

	sleep 10

	if [ $csv ];then
	echo "Started to copy $csv folder on slave pods"
	slaveList=`kubectl get po -n $tenant | grep ${jmxName}-slave | cut -d ' ' -f1`
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
	### Service creation ###

	cp templates/jmeter_slaves_svc.yaml $working_dir


	sed -i "s/nameVariable/$jmxName-slave-svc/g" jmeter_slaves_svc.yaml
	sed -i "s/labelVariable/$jmxName-slave/g" jmeter_slaves_svc.yaml

	kubectl get svc -n $tenant | grep $jmxName-slave-svc
	
	if [ $? -gt '0' ];then

	kubectl create -n $tenant -f jmeter_slaves_svc.yaml

	fi

#	kubectl exec -ti -n $tenant $master_pod -- /jmeter/load_test $jmxName &

done


echo "### Starting Load test ###"

jmx=`cat mapper.csv | awk 'BEGIN{FS=","} ; { print $1 }'`

for i in $jmx
do

	jmxName=`echo $i | cut -d '.' -f1`
        master_pod=`kubectl get po -n $tenant | grep  ${jmxName}-master | awk '{print $1}'`
	kubectl exec -ti -n $tenant $master_pod -- /jmeter/load_test $jmxName &

done
