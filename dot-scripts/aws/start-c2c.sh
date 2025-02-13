#!/bin/bash
INSTANCE_ID=i-0ffc2f2e3a74e0e49

aws ec2 start-instances --instance-id $INSTANCE_ID | jq -r '"Started instance \(.StartingInstances[].InstanceId)"'