#!/bin/bash

# Stop the script if an error occurs
set -e


# Check if kubectl is accessible
if ! command -v kubectl &> /dev/null
then
    echo "kubectl could not be found"
    exit 1
fi

# Const to set the log output dir
LOG_OUTPUT_DIR=./logs

# If the log out put dir exists then remove it
if [ -d "$LOG_OUTPUT_DIR" ]; then 
    rm -rf $LOG_OUTPUT_DIR
fi

# Create the log output directory
mkdir -p $LOG_OUTPUT_DIR

# Loop through forever, to exit pres ctrl+c to terminate script
while [ true ]
do
    # Get a list of all the pods in the namespace
    PODS=`kubectl get pods --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'`
    
    # Loop through each of the pods
    for POD in $PODS
    do
        # Get a list of all the containers in the pod
        CONTAINERS=`kubectl get pods $POD -o jsonpath='{.spec.containers[*].name}'`
        
        # Loop through each container
        for CONTAINER in $CONTAINERS
        do
            # Generate the log file name based on the pod and container name
            FILE=$POD.$CONTAINER.log
            
            # Check if the log file doesn't exists and the file is empty
            if [ ! -f "$FILE" ] || [ ! -s $FILE ]; then

                # Output the pod and container name
                echo "$POD - $CONTAINER"

                # Start a background process to stream the pods container logs to the  log file
                kubectl logs --follow $POD --container $CONTAINER > $LOG_OUTPUT_DIR/$FILE &
            fi
        done
    done
done