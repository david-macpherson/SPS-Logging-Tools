#!/bin/bash

#
# This script will loop through each pod and start to stream the pods logs to a file
# args 
#   -h | --help      Displays the help message
#   -n | --namespace Overides the kubectl context namespace
#


# Stop the script if an error occurs
set -e

# Const to set the log output dir
DATE=$(date '+%Y-%m-%d-T-%H-%M')
LOG_OUTPUT_DIR=./logs-$DATE

# Var to set the current namespace
NAMESPACE=`kubectl config view --minify -o jsonpath='{..namespace}'`
CONTEXT=`kubectl config current-context`
COMMAND_NAMESPACE_ARGS=""


# Sets the handling of the flags for the script
while [ $# -gt 0 ]; do
    case $1 in
        -h | --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo " -h, --help       Display this help message"
            echo " -n, --namespace  Overides the kubectl context namespace"
            exit 0
        ;;
        -n | --namespace)
            shift
            NAMESPACE="$1"
            shift
        ;;
    esac
done



# If the Namespace var is not empty then set the command namespace args to the namespace flags
if [ ! -z "$NAMESPACE" ]
then
      COMMAND_NAMESPACE_ARGS="--namespace $NAMESPACE"     
fi


echo "Getting pods logs for context: $CONTEXT in namespace: $NAMESPACE press crtl+c to stop logging"

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
            if [ ! -s $LOG_OUTPUT_DIR/$FILE ]; then
                # Output the pod and container name
                echo "$POD - $CONTAINER"

                # Start a background process to stream the pods container logs to the  log file
                kubectl logs --follow $POD --container $CONTAINER $COMMAND_NAMESPACE_ARGS > $LOG_OUTPUT_DIR/$FILE &
            fi
        done
    done
done