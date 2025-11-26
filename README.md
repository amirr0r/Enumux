# Enumux

`Enumux` is a lightweight Bash tool that automates network reconnaissance and service enumeration across multiple hosts using `tmux`. After identifying live hosts via a ping sweep, `Enumux` launches dedicated `tmux` sessions for each responsive IP. Inside each session, it performs `nmap` scans and protocol-specific enumeration using tools like `gobuster`, `ldapsearch`, `smbclient`, and more.

I wrote this tool to help speed up and organize initial enumeration during OSCP, OSEP, VulnHub, and HackTheBox-style labs.

```bash
$ ./enumux.sh 192.168.218.0/24

[*] Active hosts detected:
192.168.218.130
192.168.218.131
192.168.218.132

[*] Enumerating 192.168.218.130...
[+] Tmux session created for 192.168.218.130.
    → Attach with: tmux attach-session -t 192_168_218_130

[*] Enumerating 192.168.218.131...
[+] Tmux session created for 192.168.218.131.
    → Attach with: tmux attach-session -t 192_168_218_131

[*] Enumerating 192.168.218.132...
[+] Tmux session created for 192.168.218.132.
    → Attach with: tmux attach-session -t 192_168_218_132

[*] Active tmux sessions:
0: 3 windows (created Sun Oct 12 14:17:02 2025) (attached)
192_168_218_130: 7 windows (created Wed Nov 26 15:55:11 2025)
192_168_218_131: 5 windows (created Wed Nov 26 15:55:16 2025)
192_168_218_132: 1 windows (created Wed Nov 26 15:55:22 2025)
```

> [!TIP]
> If you don't want to scan an entire IP range, you can manually create a file named `active_hosts.txt` in your current directory. This file should contain one IP address per line. When present, Enumux will skip the ping sweep and use the IPs listed in this file as the targets to enumerate:
> `[*] Found existing active_hosts.txt — skipping ping sweep.`
