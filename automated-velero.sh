#!/usr/bin/bash
##########################################################
#
# Script to automate backups and restores using Velero
#  - by: Robson Dobzinski
#  - review: 2025-11-21
#
##########################################################

# Params
P1="$1"
P2="$2" # Inform using the second parameter
#P2=$(date +"%Y%m%d%H%M") # Or, if you prefer, you can use a fixed date and time

# Variables options
##########################################################
# Option 1: Namespaces matrix
#LIST=( "ns1" "ns2" "ns3" )

# Option 2: List of Namespaces from file
#FILE="my-namespaces.txt"
#if [[ -f "$FILE" ]]; then
#  mapfile -t LIST < <(sed 's/^[[:space:]]*//' "$FILE" | sort -u)
#fi

# Option 3: Dynamic Namespaces (get Kubernetes list)
EXCLUDE="^fleet-local|^fleet-default|^velero|^ingress-nginx|^cert-manager|^local|^cattle-|^cluster-|^kube-|^user-|^p-" # Exclude the system Namespaces list for not use
#EXCLUDE="$EXCLUDE|^default" # Exclude the default Namespace
#EXCLUDE="$EXCLUDE|^ns1|^ns2|^ns3" # Exclude others Namespaces
mapfile -t LIST < <(kubectl get namespaces --no-headers -o custom-columns=":metadata.name" | egrep -v "$EXCLUDE")

# Debug
DEBUG=1
##########################################################

# Run
if [ $DEBUG -ne 0 ]; then
  echo ""
  echo "Starting the automated Velero script ..."
  echo ""
  date +"%Y-%m-%d %H:%M:%S"
  echo ""
fi
if [ -n "$P1" ]; then
  if [[ "$P1" != "backup" && "$P1" != "restore" ]]; then
    echo "Please use only valid parameters: backup or restore"
    exit 2
  fi
else
  echo "Please, specify the first parameter: backup or restore"
  echo ""
  exit 1
fi
if [ -n "$P2" ]; then
  if [[ ${#LIST[@]} -gt 0 ]]; then
    if [ $DEBUG -ne 0 ]; then
      echo "Starting the script using: $P1 ..."
      echo ""
      echo "Items:"
    fi
    for i in "${LIST[@]}"; do
      [[ -z "$i" ]] && continue
      if [[ "$P1" = 'backup' ]]; then
        if [ $DEBUG -ne 0 ]; then
          NS+=("${i}")
          echo "${i}-${P2}"
        fi
        velero $P1 create ${i}-${P2} --include-namespaces ${i} > /dev/null 2>&1
      else
        if [ $DEBUG -ne 0 ]; then
          echo "${i}-${P2}"
        fi
        velero $P1 create --from-backup ${i}-${P2} > /dev/null 2>&1
      fi
    done
    if [ $DEBUG -ne 0 ]; then
      if [[ "$P1" = 'backup' ]]; then
        if [[ ${#NS[@]} -gt 0 ]]; then
          echo ""
          echo "Namespaces:"
            for n in "${LIST[@]}"; do
              echo  "$n"
            done
          echo ""
        fi
      fi
    fi
  else
    echo "No Namespace!"
    echo ""
    exit 4
  fi
else
  echo "Please specify the second parameter for identification!"
  echo ""
  exit 2
fi
if [ $DEBUG -ne 0 ]; then
  echo ""
  echo "The automated Velero script has been completed!"
  echo ""
  date +"%Y-%m-%d %H:%M:%S"
  echo ""
  echo "---"
  echo ""
fi
exit 0
