# Enumux

`Enumux` is a lightweight Bash tool that automates network reconnaissance and service enumeration across multiple hosts using `tmux`. After identifying live hosts via a ping sweep, `Enumux` launches dedicated `tmux` sessions for each responsive IP. Inside each session, it performs `nmap` scans and protocol-specific enumeration using tools like `gobuster`, `ldapsearch`, `smbclient`, and more.

I wrote this tool to help speed up and organize initial enumeration during OSCP, OSEP, VulnHub, and HackTheBox-style labs.

```bash
$ ./enumux.sh 10.10.110.0/24

[*] Active hosts detected:
10.10.110.2
...

[*] Enumerating 10.10.110.2...
[+] Tmux session created for 10.10.110.2.
    → Attach with: tmux attach-session -t 10_10_110_2

[*] Active tmux sessions:
10_10_110_2: 1 windows ...
...
```

> [!TIP]
> If you don't want to scan an entire IP range, you can manually create a file named `active_hosts.txt` in your current directory. This file should contain one IP address per line. When present, Enumux will skip the ping sweep and use the IPs listed in this file as the targets to enumerate:
> `[*] Found existing active_hosts.txt — skipping ping sweep.`
