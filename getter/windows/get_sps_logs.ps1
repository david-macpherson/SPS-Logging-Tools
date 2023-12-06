# Const for the log directory
$LOG_OUTPUT_DIR="$($PWD)\logs"

# Check if the log directory exists
if (Test-Path $LOG_OUTPUT_DIR) {
    
    # Remove the log directory
    Remove-Item -Path $LOG_OUTPUT_DIR -Recurse
}

# Create a new log directory
New-Item -ItemType "directory" -Path $LOG_OUTPUT_DIR | Out-Null

# To keep track of what jobs have been started
$jobTable = @{}

while ($True) {
    # Get a list of pods
    $PODS=$(kubectl get pod -o json | ConvertFrom-Json).items

    # Loop through each pod
    foreach ($POD in $PODS) {
        
        # Loop through each container in the pod
        foreach ($CONTAINER in $POD.spec.containers) {
           
            # Generate the log filename
            $LOG_FILENAME="$($POD.metadata.name).$($CONTAINER.name)"
            
            # Generate the log file path
            $LOG_FILE="$($LOG_OUTPUT_DIR)\$($LOG_FILENAME).log"

            # Check if the log file name doesn't appear in the job table
            if (-Not ($jobTable.ContainsKey($LOG_FILENAME))) {
                
                # Output the pod and container 
                Write-Host $($POD.metadata.name) - $($CONTAINER.name)
                
                # Start the container log capture
                $job = Start-Job -ScriptBlock { kubectl logs --follow $args[0] --container $args[1] > $args[2] } -ArgumentList $POD.metadata.name, $CONTAINER.name, $LOG_FILE | Out-Null
                
                # Add the job id to the job table
                $jobTable[$LOG_FILENAME] = $job.Id
            }        
        }
    }
}