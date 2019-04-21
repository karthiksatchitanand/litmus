#!/bin/bash
set -x

function show_help(){
    cat << EOF
Usage: $(basename "$0") --mode <pod failure type>
       $(basename "$0") --namespace 
       $(basename "$0") --label
       $(basename "$0") --help
-h|--help                Display this help and exit  
--mode 		         Pod failure type; supported: pod-delete, pod-kill; default: pod-delete
--namespace              Namespace of deployment subjected to pod failure
--label		         Unique Label of deployment subjected to pod failure
EOF
}

#######################
## VERIFY ARGUMENTS  ##
#######################

if [[ ! $@ =~ "--namespace" || ! $@ =~ "--label" ]]; then    
    show_help
    exit 2
fi

while [[ $# -gt 0 ]]
do
    case $1 in 
         -h|--help)   # Call a "show_help" function, then exit
                      show_help
                      exit
                      ;;
          
         --mode)      # Determine pod failure type
                      if [ -n "$2" ]; then
                        chaos_type=$2
                      else
                        echo "Pod failure type not specified, using defaults"
                        chaos_type="pod-delete"
                      fi
                      ;;

         --container) # Get the container to be killed in a pod 
                      if [ -n "$2" ]; then
                        app_container=$2
                        echo "Only used in mode=pod-kill"
                      else
                        app_container=""
                        echo "Container not specified, random selection will occur"
                      fi
                      ;; 

         --namespace) # Deployment namespace
                      if [ -n "$2" ]; then
                        app_ns=$2
                      else
                        echo "Deployment namespace undefined, exiting"
                        show_help; exit 2
                      fi 
                      ;;
                       
         --label)     # Deployment Labels
                      if [ -n "$2" ]; then
                        app_label=$2
                      else
                        echo "Deployment labels undefined, exiting"
                        show_help; exit 2 
                      fi
                      ;;

          --id)   # Run Instance Metadata
                      if [ -n "$2" ]; then
                        run_id=$2
                      else
                        run_id=""         
                      fi
    
                       
utils_path="/common/utils/bash"

#########################
## GENERATE TESTNAME   ##
#########################

##TODO: Make testnames & job names consistent
test_name=$(${utils_path}/generate_test_name testcase=simple-pod-failure metadata="")

#############################
## PRECONDITION LITMUS JOB ##
#############################

kubectl set env -f run_litmus_test.yml APP_NAMESPACE=${app_ns} APP_LABEL=${app_label} \
CHAOS_TYPE=${chaos_type} TARGET_CONTAINER=${app_container} RUN_ID=${id} --dry-run -o yaml > ready_litmus_test.yml

#################
##  RUN TEST   ##
#################

# Presumes that all litmus jobs have label defined w/ key "name"
echo "Get litmusjob label to monitor its progress"
value=$(kubectl create -f ready_litmus_test.yml --dry-run -o jsonpath='{.spec.template.metadata.labels.name}')

echo "Running the litmus test.."
${utils_path}/litmus_job_runner label='name:${value}' job=ready_litmus_test.yml
${utils_path}/task_delimiter;

#################
## GET RESULT  ##
#################

## Check the test status & result from the litmus result custom resource
${utils_path}/get_litmus_result ${test_name}
