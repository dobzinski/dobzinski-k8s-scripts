#!/usr/bin/bash
##########################################################
#
# Script to clear the Kubernetes Namespace
#  - by: Robson Dobzinski
#  - review: 2025-11-21
#
##########################################################

# vars
FILE=/path/my-namespaces-list-file
DEBUG=1  # show logs
FORCE=0  # force delete
RUN=0    # do not execute, remember to enable debug

# run
if [ $DEBUG -ne 0 ]; then
  echo ""
  echo "---"
  date +"%Y-%m-%d %H:%M:%S"
  echo ""
  echo "Starting script to safe remove Namespaces from the list ..."
  echo ""
fi
if [[ -f "$FILE" ]]; then
  mapfile -t LIST < <(sed 's/^[[:space:]]*//' "$FILE" | sort -u)
  if [[ ${#LIST[@]} -gt 0 ]]; then
    for ns in "${LIST[@]}"; do
      [[ -z "$ns" ]] && continue
        if [ $DEBUG -ne 0 ]; then
          echo "Verify Namespace ${ns} ..."
        fi
        CHECKNS=$(kubectl get ns ${ns} 2>/dev/null | tail -n +2 | wc -l)
        if [[ $CHECKNS -gt 0 ]]; then
          CHECKDP=$(kubectl get deployments -n ${ns} 2>/dev/null | tail -n +2 | wc -l)
          if [[ $CHECKDP -gt 0 ]]; then
            mapfile -t DEPLOYMENTS < <(kubectl get deployments -n myapp3 2>/dev/null | tail -n +2 | awk '{print $1}')
            if [[ ${#DEPLOYMENTS[@]} -gt 0 ]]; then
              for dp in "${DEPLOYMENTS[@]}"; do
                [[ -z "$dp" ]] && continue
                  if [ $DEBUG -ne 0 ]; then
                    echo "Deployment ${dp} found! Starting scale-down ..."
                    if [ $RUN -ne 0 ]; then
                      kubectl -n ${ns} scale deployment ${dp} --replicas=0
                    else
                      echo "CMD: kubectl -n ${ns} scale deployment ${dp} --replicas=0"
                    fi
                  else
                    if [ $RUN -ne 0 ]; then
                      kubectl -n ${ns} scale deployment ${dp} --replicas=0 > /dev/null 2>&1
                    fi
                  fi
              done
            fi
          else
            if [ $DEBUG -ne 0 ]; then
              echo "No Deployment were found in the Namespace ${ns}."
            fi
          fi
          CHECKPD=$(kubectl get pods -n ${ns} 2>/dev/null | tail -n +2 | wc -l)
          if [[ $CHECKPD -gt 0 ]]; then
            if [ $DEBUG -ne 0 ]; then
              echo "Starting the deletion of all Pods in the Namespace ${ns} ..."
              if [ $FORCE -ne 0 ]; then
                if [ $RUN -ne 0 ]; then
                  kubectl -n ${ns} delete pods --all --grace-period=0 --force
                else
                  echo "CMD: kubectl -n ${ns} delete pods --all --grace-period=0 --force"
                fi
              else
                if [ $RUN -ne 0 ]; then
                  kubectl -n ${ns} delete pods --all
                fi
              fi
            else
              if [ $RUN -ne 0 ]; then
                if [ $FORCE -ne 0 ]; then
                  kubectl -n ${ns} delete pods --all --grace-period=0 --force > /dev/null 2>&1
                else
                  kubectl -n ${ns} delete pods --all > /dev/null 2>&1
                fi
              fi
            fi
          else
            if [ $DEBUG -ne 0 ]; then
              echo "No Pods were found in the ${ns} Namespace."
            fi
          fi
          if [ $DEBUG -ne 0 ]; then
            echo "Starting deletion of Namespace ${ns} ..."
            if [ $FORCE -ne 0 ]; then
              if [ $RUN -ne 0 ]; then
                kubectl delete namespace ${ns} --grace-period=0 --force
              else
                echo "CMD: kubectl delete namespace ${ns} --grace-period=0 --force"
              fi
            else
              if [ $RUN -ne 0 ]; then
                kubectl delete namespace ${ns}
              else
                echo "CMD: kubectl delete namespace ${ns}"
              fi
            fi
          else
            if [ $FORCE -ne 0 ]; then
              if [ $RUN -ne 0 ]; then
                kubectl delete namespace ${ns} --grace-period=0 --force > /dev/null 2>&1
              fi
            else
              if [ $RUN -ne 0 ]; then
                kubectl delete namespace ${ns} > /dev/null 2>&1
              fi
            fi
          fi
          if [ $DEBUG -ne 0 ]; then
            echo ""
          fi
        else
          if [ $DEBUG -ne 0 ]; then
            echo "The Namespace ${ns} could not be found!"
            echo ""
          fi
        fi
    done
  fi
fi
if [ $DEBUG -ne 0 ]; then
  echo "Script completed!"
  echo ""
  date +"%Y-%m-%d %H:%M:%S"
  echo "---"
  echo ""
fi
exit 0
