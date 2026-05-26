#!/bin/bash
################################################################
#	Name: SSH Watchdog                                         
#	Author: Grant Bassham                                      
#	Date:                                                      
#	Last rev:                                                  
#	Description: Parses auth logs for failed SSH login         
#	             attempts, displays them ranked by count,      
#	             and auto-blacklists IPs over threshold via UFW
################################################################

# Colored text (matching logins.sh style)
declare -r RESET="\e[0m"
declare -r CYAN="\e[36m"
declare -r YELLOW="\e[38;5;228m"
declare -r PURPLE="\e[38;5;141m"
declare -r RED="\e[38;5;196m"
declare -r GREEN="\e[38;5;43m"
declare -r ORANGE="\e[38;5;216m"
declare -r HLINE="======================================================================"

# Threshold for auto-blacklisting
declare -r THRESHOLD=100

# Temp file for parsing
TMPFILE=$(mktemp)

#### Parse failed SSH attempts from auth.log ####
# Try journalctl first, fall back to auth.log
if journalctl -u ssh --no-pager -q &>/dev/null; then
    journalctl -u ssh --no-pager -q 2>/dev/null | \
        grep -i "failed\|invalid\|disconnect.*preauth" | \
        grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | \
        sort | uniq -c | sort -nr > "$TMPFILE"
else
    grep -i "failed\|invalid\|disconnect.*preauth" /var/log/auth.log 2>/dev/null | \
        grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | \
        sort | uniq -c | sort -nr > "$TMPFILE"
fi

TOTAL_IPS=$(wc -l < "$TMPFILE")
TOTAL_ATTEMPTS=$(awk '{sum+=$1} END {print sum}' "$TMPFILE")
BLACKLISTED=0
i=1

clear
printf "${RED}"
printf "SSH Watchdog - Failed Login Monitor\n"
printf "${HLINE}\n"
sleep 0.5

printf "${YELLOW}"
printf "  Threshold: ${THRESHOLD} attempts --> auto UFW deny\n"
printf "  Total unique IPs: ${TOTAL_IPS}\n"
printf "  Total failed attempts: ${TOTAL_ATTEMPTS}\n"
printf "${HLINE}\n"

printf "${PURPLE}"
printf "%4s %8s %20s %10s\n" "#" "count" "ip address" "status"
printf "${HLINE}\n${RESET}"

# Read through results
while read -r num ip; do
    # Alternate row colors
    if (( !(i % 2) )); then
        COLOR=$PURPLE
    else
        COLOR=$CYAN
    fi

    # Determine status and act if over threshold
    if (( num > THRESHOLD )); then
        STATUS="${RED}BLACKLISTED${RESET}"

        # Check if UFW rule already exists
        if ! ufw status | grep -q "$ip"; then
            ufw insert 1 deny from "$ip" to any &>/dev/null
            ((BLACKLISTED++))
        fi
    elif (( num > 50 )); then
        STATUS="${ORANGE}WARNING${RESET}"
    else
        STATUS="${GREEN}OK${RESET}"
    fi

    printf "${COLOR}%4s. %6s %20s   " "$i" "$num" "$ip"
    printf "${STATUS}\n"
    ((i++))
done < "$TMPFILE"

printf "${PURPLE}"
printf "${HLINE}\n"

if (( BLACKLISTED > 0 )); then
    printf "${RED}  !! Auto-blacklisted ${BLACKLISTED} new IP(s) via UFW\n"
else
    printf "${GREEN}  No new IPs blacklisted this run.\n"
fi

printf "${PURPLE}${HLINE}\n${RESET}"

# Cleanup
rm -f "$TMPFILE"

exit 0
