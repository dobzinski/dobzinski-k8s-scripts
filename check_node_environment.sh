#!/usr/bin/bash
################################################################
#
# Script to check the Rancher/RKE2 Operating System
#  - by: Robson Dobzinski
#  - review: 2026-01-29
#
################################################################

# profile
ENV_PROFILE=1            # 1=small, 2=medium, 3=large
IGNORE_PROFILE=0         # 1=enabled, 0=disabled
CHECK_CPU=8              # IGNORE_PROFILE needs to be set to 1
CHECK_MEM_MB=32768       # IGNORE_PROFILE needs to be set to 1
CHECK_DISK_GB=40         # IGNORE_PROFILE needs to be set to 1

# os
CHECK_OS_ID="ol"         # id=sles|opensuse-leap|ol|rhel|rocky|ubuntu
CHECK_OS_VERSION="9.4"   # version

# network
DISABLE_IPV6=1           # 1=enabled, 0=disabled

# list of interfaces for verification
INTERFACES_LIST=(
    "enp1s0"
)

# nfs sharing
NFS_LIST=(
  "nfsserver1.domain:/path/to/nfs_sharing1"
  "nfsserver2.domain:/path/to/nfs_sharing2"
)

# /var with mount point
MOUNT_VAR=1              # 1=enabled, 0=disabled

# available space in /var
VAR_DISK_GB=100

# data in /var (MOUNT_VAR needs to be set to 1)
#VAR_DATA=(
#    "/var/log/messages"
#    "/var/log/boot.log"
#    "/var/log/zypper.log"
#)
# list for ol / rhel / rocky
VAR_DATA=(
    "/var/log/messages"
    "/var/log/secure"
    "/var/log/cron"
    "/var/log/dnf.log"
    "/var/log/boot.log"
)
# list for sles / opensuse-leap
# list for ubuntu
#VAR_DATA=(
#    "/var/log/syslog"
#    "/var/log/auth.log"
#)

# result
LINE_WIDTH=80
GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"

# check os
if [ -r /etc/os-release ]; then
    . /etc/os-release
    OS_NAME="$NAME"
    OS_ID="$ID"
    OS_VERSION="$VERSION_ID"
else
    OS_NAME="Unknown"
    OS_ID="unknown"
    OS_VERSION="unknown"
fi

# check profile
if [ "$IGNORE_PROFILE" = 0 ]; then
    case "$ENV_PROFILE" in
        1)
          PROFILE_NAME="Small"
          REQUIRED_CPU=4
          REQUIRED_MEM_MB=16384
          MINIMUM_DISK_SPACE=60
          NUMBERS_CLUSTERS=150
          NUMBERS_NODES=1500
          ;;
        2)
          PROFILE_NAME="Medium"
          REQUIRED_CPU=8
          REQUIRED_MEM_MB=32768
          MINIMUM_DISK_SPACE=60
          NUMBERS_CLUSTERS=300
          NUMBERS_NODES=3000
          ;;
        3)
          PROFILE_NAME="Large"
          REQUIRED_CPU=16
          MINIMUM_DISK_SPACE=60
          REQUIRED_MEM_MB=65536
          NUMBERS_CLUSTERS=500
          NUMBERS_NODES=5000
          ;;
        *)
          echo "Invalid ENV_PROFILE. Use 1 (Small), 2 (Medium), or 3 (Large)."
          echo ""
          exit 1
          ;;
    esac
    echo ""
    echo "Rancher profile: $PROFILE_NAME"
    echo "Maximum Number of Clusters: $NUMBERS_CLUSTERS"
    echo "Maximum Number of Nodes: $NUMBERS_NODES"
    echo ""
    echo "Operating System: ${OS_NAME} (${OS_ID}) ${OS_VERSION}"
    echo ""
    date +"%Y-%m-%d %H:%M:%S"
    echo "---"
else
    REQUIRED_CPU=$CHECK_CPU
    REQUIRED_MEM_MB=$CHECK_MEM_MB
    MINIMUM_DISK_SPACE=$CHECK_DISK_GB
    echo ""
    echo "Rancher profile: Custom"
    echo ""
    echo "Operating System: ${OS_NAME} (${OS_ID}) ${OS_VERSION}"
    echo ""
    date +"%Y-%m-%d %H:%M:%S"
    echo "---"
fi

# output
result() {
    local label="$1"
    local status="$2"
    local dots=$((LINE_WIDTH - ${#label} - 8))
    if [ "$dots" -lt 0 ]; then
        dots=1
    fi
    printf "%s " "$label"
    printf "%*s" "$dots" "" | tr ' ' '.'
    if [ "$status" = "PASS" ]; then
        echo -e " [ ${GREEN}PASS${NC} ]"
    else
        echo -e " [ ${RED}FAIL${NC} ]"
    fi
}

# check item in list
in_list() {
    local needle="$1"
    shift
    for item in "$@"; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}

# os
if [ "$OS_ID" = "$CHECK_OS_ID" ] && [ "$OS_VERSION" = "$CHECK_OS_VERSION" ]; then
    result "Operating System" "PASS"
else
    result "Operating System" "FAIL"
fi

# cpu
CPU_COUNT=$(grep -c '^processor' /proc/cpuinfo)
if [ "$CPU_COUNT" -ge "$REQUIRED_CPU" ]; then
    result "CPU cores (${CPU_COUNT}/$REQUIRED_CPU)" "PASS" "$CPU_COUNT detected"
else
    result "CPU cores (${CPU_COUNT}/$REQUIRED_CPU)" "FAIL" "$CPU_COUNT detected"
fi

# memory
MEM_TOTAL_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
if [ "$MEM_TOTAL_MB" -ge "$REQUIRED_MEM_MB" ]; then
    result "Memory (${MEM_TOTAL_MB}/${REQUIRED_MEM_MB})" "PASS"
else
    result "Memory (${MEM_TOTAL_MB}/${REQUIRED_MEM_MB})" "FAIL"
fi

# swap
SWAP_TOTAL_KB=$(awk 'NR>1 {sum+=$3} END {print sum+0}' /proc/swaps)
if [ "$SWAP_TOTAL_KB" -eq 0 ]; then
    result "Swap disabled" "PASS"
else
    SWAP_MB=$((SWAP_TOTAL_KB / 1024))
    result "Swap disabled (${SWAP_MB}MB enabled)" "FAIL"
fi

# firewalld
if systemctl list-unit-files | grep -q '^firewalld\.service'; then
    FIREWALLD_ENABLED=$(systemctl is-enabled firewalld 2>/dev/null)
    FIREWALLD_ACTIVE=$(systemctl is-active firewalld 2>/dev/null)
    if [ "$FIREWALLD_ENABLED" = "disabled" ] && [ "$FIREWALLD_ACTIVE" = "inactive" ]; then
        result "Firewalld disabled/inactive" "PASS"
    else
        result "Firewalld disabled/inactive" "FAIL"
    fi
else
    result "Firewalld not installed" "PASS"
fi

# seLinux (check enforcing or permissive)
SELINUX_STATUS=$(getenforce 2>/dev/null || echo "Unknown")
if [ "$SELINUX_STATUS" != "Unknown" ]; then
    if [ "$SELINUX_STATUS" = "Disabled" ]; then
        result "SELinux (${SELINUX_STATUS})" "FAIL"
    else
        result "SELinux (${SELINUX_STATUS})" "PASS"
    fi
else
    result "SELinux not installed" "FAIL"
fi

# apparmor (check disabled)
if command -v apparmor_status >/dev/null 2>&1; then
    if apparmor_status | grep -q "profiles are loaded"; then
        result "AppArmor enabled" "FAIL"
    else
        result "AppArmor disabled" "PASS"
    fi
else
    result "AppArmor not installed" "PASS"
fi

# interfaces
#LIST_IFACES=$(ls /sys/class/net | grep -Ev '^(lo|docker|cni|veth|flannel|kube|vxlan|cali)')
LIST_IFACES=$(find /sys/class/net -mindepth 1 -maxdepth 1 -printf '%f\n' \
                 | grep -Ev '^(lo|docker|cni|veth|flannel|kube|vxlan|cali)')
TOTAL_INTERFACES=0
INTERFACES=""
if [ -n "$LIST_IFACES" ]; then
    for IFACE in $LIST_IFACES; do
        if [ $TOTAL_INTERFACES -eq 0 ]; then
            INTERFACES="${IFACE}"
        else
            INTERFACES+=",${IFACE}"
        fi
        ((TOTAL_INTERFACES++))
    done
    # total interfaces
    if [ $TOTAL_INTERFACES -eq ${#INTERFACES_LIST[@]} ]; then
        result "Total configured interfaces ($TOTAL_INTERFACES/${#INTERFACES_LIST[@]})" "PASS"
    else
        result "Total configured interfaces ($TOTAL_INTERFACES/${#INTERFACES_LIST[@]})" "FAIL"
    fi
    # interfaces list verification
    if [ -n "$LIST_IFACES" ]; then
        for IFACE in $LIST_IFACES; do
            if in_list "$IFACE" "${INTERFACES_LIST[@]}"; then
                result "Interface identified (${IFACE})" "PASS"
            else
                result "Unidentified interface (${IFACE})" "FAIL"
            fi
        done
    fi
fi

# reverse dns
HOST_SHORT=$(hostname -s)
PRIMARY_IP=$(ip route get 1 | awk '{print $7; exit}')
PTR_FULL=""
if command -v dig >/dev/null 2>&1; then
    REVERSE_COMMAND="dig"
    PTR_FULL=$(dig -x "$PRIMARY_IP" +short | sed 's/\.$//' | head -n1)
else
    REVERSE_COMMAND="getent"
    PTR_FULL=$(getent hosts "$PRIMARY_IP" | awk '{print $2; exit}')
fi
PTR_SHORT=${PTR_FULL%%.*}
if [ -n "$PTR_FULL" ]; then
    if [[ -n "$PTR_SHORT" && "$PTR_SHORT" == "$HOST_SHORT" ]]; then
        result "Reverse DNS ($REVERSE_COMMAND: $PRIMARY_IP → $PTR_SHORT)" "PASS"
    else
        result "Reverse DNS ($REVERSE_COMMAND: $PRIMARY_IP → $PTR_SHORT)" "FAIL"
    fi
else
    result "Reverse DNS ($REVERSE_COMMAND: $PRIMARY_IP → not found)" "FAIL"
fi

# ip forward
IP_FORWARD=$(sysctl -n net.ipv4.ip_forward)
if [ "$IP_FORWARD" = "1" ]; then
    result "IP forwarding enabled" "PASS"
else
    result "IP forwarding enabled" "FAIL"
fi

# bridge
IPT_BRIDGE=$(sysctl -n net.bridge.bridge-nf-call-iptables 2>/dev/null)
if [ -z "$IPT_BRIDGE" ]; then
    result "bridge-nf-call-iptables detected" "FAIL"
elif [ "$IPT_BRIDGE" = "1" ]; then
    result "bridge-nf-call-iptables detected" "PASS"
else
    result "bridge-nf-call-iptables detected" "FAIL"
fi

# ipv6 check
if [ "$DISABLE_IPV6" -gt 0 ]; then
    IPV6_FOUND=0
    if [ -n "$LIST_IFACES" ]; then
        for IFACE in $LIST_IFACES; do
            if ip addr show dev "$IFACE" | grep -q 'inet6'; then
                IPV6_FOUND=1
                break
            fi
        done
    fi
    if [ "$IPV6_FOUND" -gt 0 ]; then
        result "IPv6 disabled on interfaces" "FAIL"
    else
        result "IPv6 disabled on interfaces" "PASS"
    fi
else
    # ipv6 bridge
    IP6_BRIDGE=$(sysctl -n net.bridge.bridge-nf-call-ip6tables 2>/dev/null)
    if [ "$IP6_BRIDGE" = "1" ]; then
        result "bridge-nf-call-ip6tables detected" "PASS"
    else
        result "bridge-nf-call-ip6tables detected" "FAIL"
    fi
fi

# file system in /
ROOT_FS=$(findmnt -n -o FSTYPE /)
if [ "$ROOT_FS" = "xfs" ] || [ "$ROOT_FS" = "ext4" ] || [ "$ROOT_FS" = "btrfs" ]; then
    result "File system type in / ($ROOT_FS)" "PASS"
else
    result "File system type in / ($ROOT_FS)" "FAIL"
fi

# space in /
ROOT_FREE_GB=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
if [ "$ROOT_FREE_GB" -ge $MINIMUM_DISK_SPACE ]; then
    result "Free disk space / (${ROOT_FREE_GB}GB/${MINIMUM_DISK_SPACE}GB)" "PASS"
else
    result "Free disk space / (${ROOT_FREE_GB}GB/${MINIMUM_DISK_SPACE}GB)" "FAIL"
fi

# /var
if [ "$MOUNT_VAR" -gt 0 ]; then
    # file system in /var
    VAR_FS=$(findmnt -n -o FSTYPE /var)
    if mountpoint -q /var; then
        result "Partition /var mounted" "PASS"
        if [ "$VAR_FS" = "xfs" ] || [ "$VAR_FS" = "ext4" ] || [ "$VAR_FS" = "btrfs" ]; then
            result "File system type in /var ($VAR_FS)" "PASS"
        else
            result "File system type in /var ($VAR_FS)" "FAIL"
        fi
        # space in /var
        VAR_FREE_GB=$(df -BG --output=avail /var | tail -1 | tr -dc '0-9')
        if [ "$VAR_FREE_GB" -ge $VAR_DISK_GB ]; then
            result "Free disk space /var (${VAR_FREE_GB}GB/${VAR_DISK_GB}GB)" "PASS"
        else
            result "Free disk space /var (${VAR_FREE_GB}GB/${VAR_DISK_GB}GB)" "FAIL"
        fi
    else
        result "Partition /var not mounted" "FAIL"
    fi
    # checking data in /var
    VAR_MISSING=0
    for ITEM in "${VAR_DATA[@]}"; do
        if [ ! -f "$ITEM" ]; then
            VAR_MISSING=1
            break
        fi
    done
    if [ "$VAR_MISSING" -eq 0 ]; then
        result "System data in /var" "PASS"
    else
        result "System data in /var" "FAIL"
    fi
fi

# nfs support
if command -v mount.nfs >/dev/null 2>&1; then
    result "NFS mount support" "PASS"
    if [ "${#NFS_LIST[@]}" -gt 0 ]; then
        for NFS in "${NFS_LIST[@]}"; do
            [[ "$NFS" != *:* ]] && {
                result "Invalid NFS entry ($NFS)" "FAIL"
                continue
            }
            NFS_SERVER="${NFS%%:*}"
            NFS_PATH="${NFS#*:}"
            NFS_SAFE_SERVER=$(echo "$NFS_SERVER" | sed 's/[^a-zA-Z0-9._-]/_/g')
            NFS_MOUNT="/tmp/nfs_checking_${NFS_SAFE_SERVER}"
            mkdir -p "$NFS_MOUNT"
            if [ -n "$NFS_SERVER" ] && [ -n "$NFS_PATH" ] && [ -n "$NFS_MOUNT" ]; then
                if mount -t nfs -o soft,timeo=600,retrans=1 \
                        "${NFS_SERVER}:${NFS_PATH}" "$NFS_MOUNT" >/dev/null 2>&1; then
                    if mountpoint -q "$NFS_MOUNT"; then
                        result "NFS connected (${NFS_SERVER})" "PASS"
                        TEST_FILE="$NFS_MOUNT/.nfs_write_test_$$"
                        if touch "$TEST_FILE" >/dev/null 2>&1; then
                            rm -f "$TEST_FILE"
                            result "NFS write access (${NFS_PATH})" "PASS"
                        else
                            result "NFS no write permission (${NFS_PATH})" "FAIL"
                        fi
                    else
                        result "NFS not active (${NFS_MOUNT})" "FAIL"
                    fi
                    if umount "$NFS_MOUNT" >/dev/null 2>&1; then
                        rmdir "$NFS_MOUNT" 2>/dev/null
                    else
                        result "NFS umount failed ($NFS_MOUNT)" "FAIL"
                    fi
                else
                    result "NFS failed (${NFS_SERVER}:${NFS_PATH})" "FAIL"
                    rmdir "$NFS_MOUNT" 2>/dev/null
                fi
            else
                result "NFS configuration" "FAIL"
            fi
        done
    else
        result "NFS is empty" "FAIL"
    fi
else
    result "NFS mount support" "FAIL"
fi

# end
echo "---"
echo ""
exit 0
