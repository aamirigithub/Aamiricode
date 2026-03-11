#!/bin/bash

# Digital Clock - Multiple Time Zones
# Display current time in different time zones with a refresh animation
# Usage: ./digital-clock-timezones.sh

# Color codes
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default time zones (can be customized)
declare -a TIMEZONES=(
    "UTC:Etc/UTC"
    "EST:US/Eastern"
    "CST:US/Central"
    "MST:US/Mountain"
    "PST:US/Pacific"
    "GMT:Europe/London"
    "CET:Europe/Paris"
    "IST:Asia/Kolkata"
    "SGT:Asia/Singapore"
    "JST:Asia/Tokyo"
    "AEST:Australia/Sydney"
)

# Animation frames for loading
FRAMES=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )

# Function to print centered text
center_text() {
    local text=$1
    local width=80
    local padding=$(( (width - ${#text}) / 2 ))
    printf "%${padding}s%s\n" "" "$text"
}

# Function to get color based on timezone
get_color() {
    local tz_index=$1
    case $((tz_index % 6)) in
        0) echo -e "${CYAN}" ;;
        1) echo -e "${YELLOW}" ;;
        2) echo -e "${GREEN}" ;;
        3) echo -e "${MAGENTA}" ;;
        4) echo -e "${RED}" ;;
        5) echo -e "${BLUE}" ;;
    esac
}

# Function to display clock header
display_header() {
    clear
    echo -e "${BOLD}${CYAN}"
    center_text "╔════════════════════════════════════════╗"
    center_text "║     DIGITAL CLOCK - MULTIPLE TIME ZONES    ║"
    center_text "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# Function to display single timezone clock
display_timezone() {
    local tz_label=$1
    local tz_value=$2
    local tz_index=$3
    local color=$(get_color $tz_index)
    
    # Get current time in the specified timezone
    local current_time=$(TZ=$tz_value date '+%H:%M:%S')
    local current_date=$(TZ=$tz_value date '+%A, %B %d, %Y')
    
    # Display with formatting
    printf "${color}%-8s${NC} │ " "$tz_label"
    printf "${BOLD}${color}%s${NC}" "$current_time"
    printf " │ ${color}%s${NC}\n" "$current_date"
}

# Function to create digital display using larger ASCII
display_large_time() {
    local tz_label=$1
    local tz_value=$2
    local color=$3
    
    local current_time=$(TZ=$tz_value date '+%H:%M:%S')
    
    echo -e "${color}${BOLD}═══════════════════════════════════${NC}"
    echo -e "${color}${BOLD}│ $tz_label: $current_time ${NC}${BOLD}│${NC}"
    echo -e "${color}${BOLD}═══════════════════════════════════${NC}"
}

# Function to create a 7-segment display style time
display_segment_time() {
    local time=$1
    local color=$2
    
    # Simple 7-segment approximation
    declare -A segments=(
        ["0"]="███\n█ █\n█���█"
        ["1"]="  █\n  █\n  █"
        ["2"]="███\n  █\n███"
        ["3"]="███\n  █\n███"
        ["4"]="█ █\n███\n  █"
        ["5"]="███\n█\n███"
        ["6"]="███\n█ █\n███"
        ["7"]="███\n  █\n  █"
        ["8"]="███\n█ █\n███"
        ["9"]="███\n█ █\n  █"
        [":"]="\n █\n"
    )
    
    echo -e "${color}${time}${NC}"
}

# Function for interactive mode
interactive_mode() {
    local running=1
    local update_rate=1  # Update every 1 second
    
    while [ $running -eq 1 ]; do
        display_header
        
        echo -e "${BOLD}${GREEN}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
        
        local index=0
        for tz_pair in "${TIMEZONES[@]}"; do
            IFS=':' read -r tz_label tz_value <<< "$tz_pair"
            display_timezone "$tz_label" "$tz_value" "$index"
            ((index++))
        done
        
        echo -e "${BOLD}${GREEN}└─────────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${BOLD}${YELLOW}Last updated: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
        echo -e "${BOLD}${CYAN}(Press Ctrl+C to exit)${NC}"
        
        sleep "$update_rate"
    done
}

# Function for compact mode
compact_mode() {
    local running=1
    
    while [ $running -eq 1 ]; do
        clear
        echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
        
        local index=0
        for tz_pair in "${TIMEZONES[@]}"; do
            IFS=':' read -r tz_label tz_value <<< "$tz_pair"
            local color=$(get_color $index)
            display_large_time "$tz_label" "$tz_value" "$color"
            ((index++))
        done
        
        echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        
        sleep 1
    done
}

# Function to add custom timezone
add_timezone() {
    echo -e "${BOLD}${CYAN}Add Custom Timezone${NC}"
    echo "Example: EST for US/Eastern"
    read -p "Enter timezone abbreviation: " tz_abbr
    read -p "Enter timezone value (e.g., US/Eastern): " tz_value
    
    # Validate timezone
    if TZ=$tz_value date &>/dev/null; then
        TIMEZONES+=("$tz_abbr:$tz_value")
        echo -e "${GREEN}✓ Timezone added successfully${NC}"
    else
        echo -e "${RED}✗ Invalid timezone${NC}"
    fi
}

# Function to display menu
show_menu() {
    clear
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}   Digital Clock - Time Zone Display${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "1. Standard View (Compact)"
    echo "2. Extended View (Detailed)"
    echo "3. Large Display"
    echo "4. Add Custom Timezone"
    echo "5. Exit"
    echo ""
    read -p "Select option (1-5): " choice
}

# Function to display help
show_help() {
    cat << EOF
${BOLD}${CYAN}Digital Clock - Multiple Time Zones${NC}

${BOLD}Usage:${NC}
    ./digital-clock-timezones.sh [OPTIONS]

${BOLD}Options:${NC}
    -i, --interactive    Start in interactive mode with menu
    -c, --compact        Display in compact view
    -l, --large          Display in large format
    -h, --help           Show this help message
    -t, --timezone LIST  Custom timezone list (comma-separated)

${BOLD}Examples:${NC}
    ./digital-clock-timezones.sh --interactive
    ./digital-clock-timezones.sh --compact
    ./digital-clock-timezones.sh --timezone "EST:US/Eastern,PST:US/Pacific"

${BOLD}Default Timezones:${NC}
    UTC, EST, CST, MST, PST, GMT, CET, IST, SGT, JST, AEST

EOF
}

# Main program
main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        -i|--interactive)
            interactive_mode
            ;;
        -c|--compact)
            compact_mode
            ;;
        -l|--large)
            display_large_time "Sample" "UTC" "${CYAN}"
            ;;
        -t|--timezone)
            if [ -n "$2" ]; then
                IFS=',' read -ra TIMEZONES <<< "$2"
            fi
            interactive_mode
            ;;
        *)
            # Interactive menu
            while true; do
                show_menu
                case $choice in
                    1)
                        compact_mode
                        ;;
                    2)
                        interactive_mode
                        ;;
                    3)
                        compact_mode
                        ;;
                    4)
                        add_timezone
                        read -p "Press Enter to continue..."
                        ;;
                    5)
                        echo -e "${GREEN}Goodbye!${NC}"
                        exit 0
                        ;;
                    *)
                        echo -e "${RED}Invalid option${NC}"
                        sleep 2
                        ;;
                esac
            done
            ;;
    esac
}

# Trap Ctrl+C for graceful exit
trap 'echo -e "\n${YELLOW}Clock stopped${NC}"; exit 0' INT

# Run main program
main "$@"
