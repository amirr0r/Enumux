#!/bin/bash

SLOW="$2"

# Step 1: Use active_hosts.txt if available
if [ -f "active_hosts.txt" ]; then
    echo "[*] Found existing active_hosts.txt — skipping ping sweep."
    ACTIVE_IPS=$(grep -v '^#' active_hosts.txt | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
else
    IP_RANGE="$1"
    if [ -z "$IP_RANGE" ]; then
        echo "Usage: bash enumux.sh <IP_RANGE> [slow]"
        echo "Or place a file named 'active_hosts.txt' in this folder with one IP per line."
        exit 1
    fi

    echo "[*] Performing ping sweep over $IP_RANGE..."
    nmap -sn -T4 "$IP_RANGE" -oN active_hosts.txt
    ACTIVE_IPS=$(grep "Nmap scan report for" active_hosts.txt | awk '{print $NF}')
fi

# Step 2: Confirm IPs found
if [ -z "$ACTIVE_IPS" ]; then
    echo "[!] No active hosts found."
    exit 1
fi

echo -e "\n[*] Active hosts detected:"
echo "$ACTIVE_IPS"

# Step 3: Enumeration functions
check_os_from_ttl() {
    local IP="$1"
    local ttl
    ttl=$(ping -c1 -W 1 "$IP" 2>/dev/null | grep -o 'ttl=[0-9]*' | cut -d= -f2)

    if [[ -z "$ttl" ]]; then
        echo -e "    OS detection: \e[33mUnknown (no ping reply)\e[0m"
    elif [[ "$ttl" -gt 60 && "$ttl" -lt 119 ]]; then
        echo -e "    OS detection: \e[1m\e[32mLinux\e[0m (TTL=$ttl)"
    elif [[ "$ttl" -gt 119 && "$ttl" -lt 254 ]]; then
        echo -e "    OS detection: \e[1m\e[34mWindows\e[0m (TTL=$ttl)"
    else
        echo -e "    OS detection: \e[33mUnknown TTL=$ttl\e[0m"
    fi
}

enumerate_host() {
    IP="$1"
    SESSION_NAME="${IP//./_}"

    echo -e "\n[*] Enumerating $IP..."
    check_os_from_ttl "$IP"
    mkdir -p "$IP/services" "$IP/img"
    cd "$IP" || exit 1

    # Uncomment if you want README generation
    # printf "# %s\n\n## Enumeration\n\n### \`nmap\` scan\n\n## Foothold\n\n## Privesc\n\n___\n\n## Useful links\n\n" > README.md

    tmux start-server
    tmux new-session -d -s "$SESSION_NAME" -n nmap

    USERNAMES="/usr/share/wordlists/seclists/Usernames/top-usernames-shortlist.txt"
    WEBDIR="/usr/share/wordlists/seclists/Discovery/Web-Content/common.txt"

    if [ "$SLOW" == "slow" ]; then
        tmux send-keys -t "$SESSION_NAME:0" "nmap -sS -oN ports.txt $IP -Pn" C-m
    else
        tmux send-keys -t "$SESSION_NAME:0" "nmap -min-rate 5000 --max-retries 1 -sS -oN ports.txt $IP -Pn" C-m
    fi

    sleep 5
    i=1

    tmux send-keys -t "$SESSION_NAME:0" "
for p in \$(grep -E '^[0-9]+/tcp' ports.txt | grep open | cut -d'/' -f1); do
    case \$p in
        21)
            tmux new-window -t $SESSION_NAME:\$((++i)) -n FTP
            tmux send-keys -t $SESSION_NAME:\$i 'ftp $IP' C-m ;;
        25)
            tmux new-window -t $SESSION_NAME:\$((++i)) -n SMTP
            # tmux send-keys -t $SESSION_NAME:\$i \"echo '[*] Checking SMTP VRFY responses...'\"
            # tmux send-keys -t $SESSION_NAME:\$i \"for user in \$(cat $USERNAMES); do echo VRFY \$user | nc -nv -w 1 $IP \$p | grep ^'250'; done | tee services/25-smtp-vrfy.txt\" C-m
            tmux send-keys -t $SESSION_NAME:\$i \"echo '[*] Checking for SMTP open relay...'\"
            tmux send-keys -t $SESSION_NAME:\$i \"nmap -p25 -sV --script smtp-open-relay $IP -oN services/25-smtp-relay-check.txt\" C-m ;;
        53)
            tmux new-window -t $SESSION_NAME:\$((++i)) -n DNS
            tmux send-keys -t $SESSION_NAME:\$i \"dig axfr @$IP | tee services/53-dns.txt\" C-m ;;
        79)
            tmux new-window -t $SESSION_NAME:\$((++i)) -n FINGER
            tmux send-keys -t $SESSION_NAME:\$i \"/opt/finger-user-enum.pl -U $USERNAMES -t $IP\" C-m ;;
        80)
            tmux new-window -t $SESSION_NAME:\$((++i)) -n HTTP
            tmux send-keys -t $SESSION_NAME:\$i \"gobuster dir -u http://$IP -w $WEBDIR -x .txt -o services/80-http.txt\" C-m
            tmux send-keys -t $SESSION_NAME:\$i \"wait; nikto -h $IP | tee services/80-nikto.txt\" C-m ;;
        135)
            tmux new-window -t $SESSION_NAME:\$((++i)) -n RPC
            tmux send-keys -t $SESSION_NAME:\$i \"rpcclient -U '%' $IP | tee services/135-rpc.txt\" C-m ;;
        389)
            tmux new-window -t $SESSION_NAME:\$((++i)) -n LDAP
            tmux send-keys -t $SESSION_NAME:\$i \"ldapsearch -h $IP -x -s base namingcontexts | tee services/389-ldap.txt\" C-m ;;
        443)
            tmux new-window -t $SESSION_NAME:\$((++i)) -n HTTPS
            tmux send-keys -t $SESSION_NAME:\$i \"gobuster dir -u https://$IP -w $WEBDIR -x .txt -k -o services/443-https.txt\" C-m ;;
        445)
            tmux new-window -t $SESSION_NAME:\$((++i)) -n SMB
            tmux send-keys -t $SESSION_NAME:\$i \"smbclient -L //$IP -U '%' | tee services/445-smbclient.txt\" C-m
            tmux send-keys -t $SESSION_NAME:\$i \"wait; nxc smb $IP --shares\" C-m
            #tmux send-keys -t $SESSION_NAME:\$i \"wait; smbmap -H $IP -R | tee services/445-smbmap.txt\" C-m
            tmux new-window -t $SESSION_NAME:\$((++i)) -n enum4linux
            tmux send-keys -t $SESSION_NAME:\$i \"enum4linux -a $IP | tee linux-enum.txt\" C-m ;;
        1521)
            tmux new-window -t $SESSION_NAME:\$((++i)) -n Oracle
            tmux send-keys -t $SESSION_NAME:\$i \"git clone https://github.com/quentinhardy/odat.git\" C-m ;;
        2049)
            tmux new-window -t $SESSION_NAME:\$((++i)) -n NFS
            tmux send-keys -t $SESSION_NAME:\$i \"showmount -e $IP | tee services/2049-NFS.txt\" C-m ;;
        3306)
            tmux new-window -t $SESSION_NAME:\$((++i)) -n MySQL ;;
        3389)
            tmux new-window -t $SESSION_NAME:\$((++i)) -n RDP
            tmux send-keys -t $SESSION_NAME:\$i \"nmap --script 'rdp-ntlm-info' -p 3389 -T4 -Pn -oN $IP-rdp-enum.txt $IP\" C-m ;;
        5432)
            tmux new-window -t $SESSION_NAME:\$((++i)) -n PostgreSQL ;;
    esac
done
" C-m

    # Extended enumeration scans (optional — uncomment as needed)
    tmux send-keys -t "$SESSION_NAME:0" "wait; nmap -vvv -sS -sV -oN $IP.txt $IP -Pn &" C-m
    # tmux send-keys -t "$SESSION_NAME:0" "wait; nmap -vvv -sV -sC -p- -oN $IP-full-port-scan.txt $IP -Pn &" C-m
    # tmux send-keys -t "$SESSION_NAME:0" "wait; nmap -vvv -sU -oN UDP-scan.txt $IP -Pn &" C-m
    # tmux send-keys -t "$SESSION_NAME:0" "wait; nmap -vvv -sS --script vuln -oN vuln-scan.txt $IP -Pn" C-m

    echo -e "[+] Tmux session created for $IP."
    echo -e "    → Attach with: \033[1mtmux attach-session -t $SESSION_NAME\033[0m"
    echo -e "    → Close session: \033[1mtmux kill-session -t $SESSION_NAME\033[0m"

    cd ..
}

# Step 4: Enumerate all IPs
for IP in $ACTIVE_IPS; do
    enumerate_host "$IP"
done

echo -e "\n[*] Active tmux sessions:"
tmux ls
