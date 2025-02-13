#!/bin/bash

PROFILES=(
    "sb1" 
    "sb2" 
    "sb3" 
    "emt"
)
REGIONS=("us-east-1" "us-east-2")

for REGION in ${REGIONS[@]}
do
	export AWS_REGION=$REGION
	for PROFILE in "${PROFILES[@]}" 
	do
    		echo "Checking: $PROFILE $REGION"
    		export AWS_PROFILE=$PROFILE
    		INSTANCE_IDS=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId]' --output text)
    		if [ -z "$INSTANCE_IDS" ]; then
        		echo "No instances found"
        		continue
    		else
        		echo "$INSTANCE_IDS"
        		aws ec2 stop-instances --instance-ids $INSTANCE_IDS > /dev/null
			echo "Done"
    		fi
	done
done
