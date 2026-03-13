# Scrip to check Proxmox health
#!/bin/bash

# Proxmox Health Check Script
# This script performs comprehensive health checks on a Proxmox VE system
# Usage: ./proxmox-healthcheck.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ALERT_CPU_THRESHOLD=80
ALERT_MEM_THRESHOLD=85
ALERT_DISK_THRESHOLD=85
ALERT_TEMP_THRESHOLD=80

# Initialize counters
WARNINGS=0
ERRORS=0

# Functions
print_header() {
    echo "======================================"
    echo "Proxmox Health Check Report"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "======================================"
    echo ""
}

check_status() {
    local status=$1
    local name=$2
    
    if [ $status -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $name: OK"
    else
        echo -e "${RED}✗${NC} $name: FAILED"
        ERRORS=$((ERRORS + 1))
    fi
}

warning_status() {
    local status=$1
    local name=$2
    local value=$3
    
    if [ $status -eq 1 ]; then
        echo -e "${YELLOW}⚠${NC} $name: WARNING - $value"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}✓${NC} $name: OK - $value"
    fi
}

# Check if running as root
check_root() {
    echo "--- System Privileges ---"
    if [ "$EUID" -eq 0 ]; then
        check_status 0 "Root access"
    else
        check_status 1 "Root access (required)"
    fi
    echo ""
}

# Check Proxmox services
check_services() {
    echo "--- Core Services ---"
    
    local services=("pveproxy" "pvedaemon" "pvestatd" "pmgproxy" "corosync" "pve-cluster")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet $service 2>/dev/null; then
            check_status 0 "Service: $service"
        else
            check_status 1 "Service: $service"
        fi
    done
    echo ""
}

# Check CPU usage
check_cpu() {
    echo "--- CPU Usage ---"
    
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d. -f1)
    
    if [ "$cpu_usage" -gt "$ALERT_CPU_THRESHOLD" ]; then
        warning_status 1 "CPU Usage" "${cpu_usage}% (threshold: ${ALERT_CPU_THRESHOLD}%)"
    else
        warning_status 0 "CPU Usage" "${cpu_usage}%"
    fi
    echo ""
}

# Check Memory usage
check_memory() {
    echo "--- Memory Usage ---"
    
    local mem_total=$(free -m | awk 'NR==2{print $2}')
    local mem_used=$(free -m | awk 'NR==2{print $3}')
    local mem_percent=$((mem_used * 100 / mem_total))
    
    if [ "$mem_percent" -gt "$ALERT_MEM_THRESHOLD" ]; then
        warning_status 1 "Memory Usage" "${mem_percent}% (${mem_used}MB/${mem_total}MB)"
    else
        warning_status 0 "Memory Usage" "${mem_percent}% (${mem_used}MB/${mem_total}MB)"
    fi
    echo ""
}

# Check Disk usage
check_disk() {
    echo "--- Disk Usage ---"
    
    df -h | grep -E '^/dev/' | while read line; do
        local usage=$(echo $line | awk '{print $5}' | cut -d% -f1)
        local mount=$(echo $line | awk '{print $6}')
        local device=$(echo $line | awk '{print $1}')
        
        if [ "$usage" -gt "$ALERT_DISK_THRESHOLD" ]; then
            warning_status 1 "$device on $mount" "${usage}% (threshold: ${ALERT_DISK_THRESHOLD}%)"
        else
            warning_status 0 "$device on $mount" "${usage}%"
        fi
    done
    echo ""
}

# Check Proxmox storage
check_storage() {
    echo "--- Proxmox Storage ---"
    
    if command -v pvesh &> /dev/null; then
        local storage_list=$(pvesh get /storage --noheader 2>/dev/null | grep -v "^--" || echo "")
        
        if [ -z "$storage_list" ]; then
            echo -e "${YELLOW}⚠${NC} No accessible storage found"
        else
            echo "$storage_list" | while read line; do
                local storage=$(echo $line | awk '{print $1}')
                echo "  - $storage"
            done
        fi
    else
        echo -e "${YELLOW}⚠${NC} pvesh command not available"
    fi
    echo ""
}

# Check network interfaces
check_network() {
    echo "--- Network Interfaces ---"
    
    ip link show | grep "^[0-9]" | awk '{print $2}' | sed 's/:$//' | while read iface; do
        if [ "$iface" != "lo" ]; then
            local status=$(ip link show $iface | grep -o "UP\|DOWN" | head -1)
            
            if [ "$status" = "UP" ]; then
                check_status 0 "Interface: $iface"
            else
                check_status 1 "Interface: $iface"
            fi
        fi
    done
    echo ""
}

# Check system temperature (if available)
check_temperature() {
    echo "--- System Temperature ---"
    
    if command -v sensors &> /dev/null; then
        sensors 2>/dev/null | grep -i "core\|package" | while read line; do
            local temp=$(echo "$line" | grep -oP '\+?\d+\.?\d*(?=°C)' | head -1)
            local label=$(echo "$line" | cut -d: -f1)
            
            if [ ! -z "$temp" ]; then
                local temp_int=${temp%.*}
                if [ "$temp_int" -gt "$ALERT_TEMP_THRESHOLD" ]; then
                    warning_status 1 "$label" "${temp}°C (threshold: ${ALERT_TEMP_THRESHOLD}°C)"
                else
                    warning_status 0 "$label" "${temp}°C"
                fi
            fi
        done
    else
        echo -e "${YELLOW}⚠${NC} lm-sensors not installed (run: apt install lm-sensors)"
    fi
    echo ""
}

# Check system uptime
check_uptime() {
    echo "--- System Uptime ---"
    local uptime=$(uptime -p)
    echo -e "${GREEN}✓${NC} Uptime: $uptime"
    echo ""
}

# Check cluster status
check_cluster() {
    echo "--- Cluster Status ---"
    
    if command -v pvecm &> /dev/null; then
        local cluster_status=$(pvecm status 2>/dev/null || echo "Not in cluster")
        
        if echo "$cluster_status" | grep -q "not in a cluster"; then
            echo -e "${YELLOW}⚠${NC} Node is not in a cluster"
        else
            check_status 0 "Cluster configured"
            echo "$cluster_status" | grep "^  " | head -5
        fi
    else
        echo -e "${YELLOW}⚠${NC} Cluster tools not available"
    fi
    echo ""
}

# Check running VMs
check_vms() {
    echo "--- Running Virtual Machines ---"
    
    if command -v pvesh &> /dev/null; then
        local vm_count=$(pvesh get /nodes/$(hostname)/qemu --noheader 2>/dev/null | wc -l)
        echo -e "${GREEN}✓${NC} Total VMs: $vm_count"
    else
        echo -e "${YELLOW}⚠${NC} Unable to query VMs"
    fi
    echo ""
}

# Check system logs for errors
check_logs() {
    echo "--- Recent System Errors (last 24h) ---"
    
    local error_count=$(journalctl --since "24 hours ago" -p err -q 2>/dev/null | wc -l)
    
    if [ "$error_count" -eq 0 ]; then
        check_status 0 "System errors"
    else
        warning_status 1 "System errors" "$error_count errors found"
        journalctl --since "24 hours ago" -p err -q 2>/dev/null | tail -3
    fi
    echo ""
}

# Summary
print_summary() {
    echo "======================================"
    echo "Health Check Summary"
    echo "======================================"
    echo -e "Errors:   ${RED}$ERRORS${NC}"
    echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
    
    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}Status: All checks passed!${NC}"
    elif [ $ERRORS -eq 0 ]; then
        echo -e "${YELLOW}Status: Checks passed with warnings${NC}"
    else
        echo -e "${RED}Status: Some checks failed - attention required${NC}"
    fi
    echo "======================================"
}

# Main execution
main() {
    print_header
    check_root
    check_services
    check_cpu
    check_memory
    check_disk
    check_storage
    check_network
    check_temperature
    check_uptime
    check_cluster
    check_vms
    check_logs
    print_summary
}

main "$@"
