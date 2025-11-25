#!/usr/bin/bash
##########################################################
#
# Script to check resources in the Kubernetes Namespace
#  - by: Robson Dobzinski
#  - review: 2025-11-25
#
##########################################################

# vars
FILE=/path/my-namespaces-list-file
HEADERS=("ROW" "NMS" "SVC" "ING" "DEP" "DST" "RST" "SST" "JOB" "CJB" "PDR" "PDC" "PDE" "PVB" "PVE")
REFERENCES=(
    "Line Number"
    "Namespace"
    "Service"
    "Ingress"
    "Deployment"
    "Daemonset"
    "Replicaset"
    "Statefulset"
    "Job"
    "Cronjob"
    "Pods Running"
    "Pods Completed"
    "Pods not Running"
    "PVC Bound"
    "PVC not Bound"
)

# run
echo ""
echo "Starting script to check resources in Namespaces from the list ..."
echo ""
date +"%Y-%m-%d %H:%M:%S"
echo ""
if [[ -f "$FILE" ]]; then
  mapfile -t LIST < <(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$FILE" | sort -u)
  if [[ ${#LIST[@]} -gt 0 ]]; then
    if [[ ${#HEADERS[@]} -gt 0 ]]; then
      LINE=1
      COL=""
      for C in "${!HEADERS[@]}"; do
        COL=$COL"${HEADERS[$C]} "
      done
      echo "$COL"
      echo "------------------------------------------------------------"
    fi
    for NS in "${LIST[@]}"; do
      [[ -z "$NS" ]] && continue
        CHECKNS=$(kubectl get ns ${NS} --no-headers 2>/dev/null | wc -l)
        if [[ $CHECKNS -gt 0 ]]; then
          SVC=$(kubectl get svc -n ${NS} --no-headers 2>/dev/null | wc -l)
          ING=$(kubectl get ingress -n ${NS} --no-headers 2>/dev/null | wc -l)
          DEP=$(kubectl get deployments -n ${NS} --no-headers 2>/dev/null | wc -l)
          DST=$(kubectl get daemonsets -n ${NS} --no-headers 2>/dev/null | wc -l)
          RST=$(kubectl get replicasets -n ${NS} --no-headers 2>/dev/null | wc -l)
          SST=$(kubectl get statefulsets -n ${NS} --no-headers 2>/dev/null | wc -l)
          JOB=$(kubectl get jobs -n ${NS} --no-headers 2>/dev/null | wc -l)
          CJB=$(kubectl get cronjobs -n ${NS} --no-headers 2>/dev/null | wc -l)
          PDR=$(kubectl get pods -n ${NS} --no-headers -o custom-columns=STATUS:.status.phase | grep "Running" 2>/dev/null | wc -l)
          PDC=$(kubectl get pods -n ${NS} --no-headers -o custom-columns=STATUS:.status.phase | grep "Succeeded" 2>/dev/null | wc -l)
          PDA=$(kubectl get pods -n ${NS} --no-headers -o custom-columns=STATUS:.status.phase | egrep -v "Running|Succeeded" 2>/dev/null | wc -l)
          PVB=$(kubectl get pvc -n ${NS} --no-headers -o custom-columns=STATUS:.status.phase | grep "^Bound" 2>/dev/null | wc -l)
          PVA=$(kubectl get pvc -n ${NS} --no-headers -o custom-columns=STATUS:.status.phase | egrep -v "^Bound" 2>/dev/null | wc -l)
          echo "$LINE ${NS} $SVC $ING $DEP $DST $RST $SST $JOB $CJB $PDR $PDC $PDA $PVB $PVA"
        ((LINE++))
        fi
        echo "------------------------------------------------------------"
    done
  fi
fi
echo ""
echo "References:"
echo "-----------"
for C in "${!HEADERS[@]}"; do
    echo " ${HEADERS[$C]} : ${REFERENCES[$C]}"
done
echo ""
echo "Script completed!"
echo ""
date +"%Y-%m-%d %H:%M:%S"
echo ""
echo "---"
echo ""
exit 0
