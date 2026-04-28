#!/bin/bash
##########################################################
#
# Script to add annotations to the pod to skip volumes in Velero backups
#  - by: Robson Dobzinski
#  - review: 2026-04-28
#
##########################################################

# Params
DEBUG=1
DRYRUN=1

# Variables
FILE=/path/my-namespaces-list-file
if [[ -f "$FILE" ]]; then
  mapfile -t LIST < <(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$FILE" | sort -u)
else
    echo "Error: File not found!"
    exit 1
fi

# Run
for ns in "${LIST[@]}"; do
    kubectl get pods -n "$ns" -o json | jq -c '.items[]' | while read -r pod; do
        pod_name=$(echo "$pod" | jq -r '.metadata.name')
        volumes_to_exclude=""
        while read -r vol_info; do
            vol_name=$(echo "$vol_info" | cut -d' ' -f1)
            vol_type=$(echo "$vol_info" | cut -d' ' -f2)
            pvc_name=$(echo "$vol_info" | cut -d' ' -f3)

            if [ "$vol_type" == "nfs" ]; then
                volumes_to_exclude="${volumes_to_exclude}${vol_name},"

            elif [ "$vol_type" == "pvc" ]; then
                pv_name=$(kubectl get pvc "$pvc_name" -n "$ns" -o jsonpath='{.spec.volumeName}' 2>/dev/null)
                if [ ! -z "$pv_name" ]; then
                    driver=$(kubectl get pv "$pv_name" -o jsonpath='{.spec.csi.driver}' 2>/dev/null)
                    if [ "$driver" == "smb.csi.k8s.io" ]; then
                        volumes_to_exclude="${volumes_to_exclude}${vol_name},"
                    fi
                fi
            fi
        done < <(echo "$pod" | jq -r '.spec.volumes[] |
            if .nfs != null then .name + " nfs none"
            elif .persistentVolumeClaim != null then .name + " pvc " + .persistentVolumeClaim.claimName
            else empty end')
        if [ ! -z "$volumes_to_exclude" ]; then
            volumes_to_exclude="${volumes_to_exclude%,}"
            if [[ $DEBUG -gt 0 ]]; then
                echo "Namespace: $ns | Pod: $pod_name | Volumes: $volumes_to_exclude"
            fi
            if [[ $DRYRUN -eq 0 ]]; then
                kubectl annotate pod "$pod_name" -n "$ns" backup.velero.io/backup-volumes-excludes="$volumes_to_exclude" --overwrite > /dev/null
            else
                echo "Dry Run: kubectl annotate pod ${pod_name} -n ${ns} backup.velero.io/backup-volumes-excludes=${volumes_to_exclude} --overwrite"
            fi
        fi
    done
done