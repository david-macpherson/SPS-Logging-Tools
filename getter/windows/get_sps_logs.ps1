# Set up script paramaters
param(
    [String]$namespace="",
    [switch]$Help=$false,
    [switch]$h=$false,
    [switch]$stopJobs=$false
)


# If the -h or -Help flags are present show the help message and exit
if ($Help -Or $h){
    write-host "Usage: $0 [OPTIONS]"
    write-host "Options:"
    write-host "-h | -Help  Display this help message"
    write-host "-namespace  Overides the kubectl context namespace"
    write-host "-stopJobs    Will stop all the background jobs that are running"
    
    exit 0
}

if ($stopJobs) {
    Write-Host "Stopping all background logging jobs, This can take some time"
    get-job | stop-job
    Write-Host "All logging jobs have been stopped"
    exit 0
}

# Get the current context
$context = $(kubectl config current-context)

# Check if the namespace flag is empty
if ($namespace -eq "") {

    # Set the namespace var to the contexts namespace
    $namespace = $(kubectl config view --minify -o jsonpath='{..namespace}')

    # Check if the namespace is still null
    if ($namespace -eq $null) {
             
        # Set the namespace to default as a fallback
        Write-Host "Namespace not set in the context: $($context) falling back to default"
        $namespace = "default"
    }
}

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

Write-Host "Getting pods logs for context: $($context) in namespace: $($namespace) press crtl+c or close the powershell window to stop the logging jobs"

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
                $job = Start-Job -ScriptBlock { kubectl logs --follow $args[0] --container $args[1] --namespace $args[2] > $args[3] } -ArgumentList $POD.metadata.name, $CONTAINER.name, $namespace, $LOG_FILE | Out-Null
                
                # Add the job id to the job table
                $jobTable[$LOG_FILENAME] = $job.Id
            }        
        }
    }
}