ip_fun () {
	if [[ "$IP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
                echo -e "\e[1;36m[OK] Valid IP\e[0m"
	else
                echo -e "\e[1;31m[Error] Invalid IP\e[0m"
		exit
	fi
}
dns_fun () {
	echo $DNS | grep -P "^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9](?:\.[a-zA-Z]{2,})+$" 2>&1 > /dev/null
        if [ $? -eq 0 ]
	then
                echo -e "\e[1;36m[OK] Valid DNS\e[0m"
	else
	        echo -e "\e[1;31m[Error] Invalid DNS\e[0m"
		exit
	fi
}

clear
echo -e "\e[1;32m
+-+-+-+ +-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+-+-+-+-+-+
|D|N|S| |S|e|r|v|e|r| |C|o|n|f|i|g|u|r|a|t|i|o|n|
+-+-+-+ +-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+-+-+-+-+-+
\e[0m\e[1;36m
C O D E R ~ [ A U N G T H U M Y I N T ]\e[0m
"
read -p "[#] IP Address [192.168.0.9] : " IP
ip_fun
read -p "[#] DNS Domain [techlab.com] : " DNS
dns_fun

yum -y install bind bind-utils
RevAddr=$(for FIELD in 3 2 1; do printf "$(echo ${IP} | cut -d '.' -f $FIELD)."; done)
RevFile1="$RevAddr""in-addr.arpa"
RevFile2="$RevAddr""db"
ZONE="$DNS"".db"
SubNet=$(for FIELD in 1 2 3 ; do printf "$(echo ${IP} | cut -d '.' -f $FIELD)."; done)
Mask="$SubNet""0"

cat > /etc/named.conf <<- EOF
options {
        listen-on port 53 { 127.0.0.1; $IP; };
        listen-on-v6 port 53 { ::1; };
        directory 	"/var/named";
        dump-file 	"/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        secroots-file	"/var/named/data/named.secroots";
        recursing-file	"/var/named/data/named.recursing";
        allow-query     { localhost; $Mask/24; };

        /* 
        - If you are building an AUTHORITATIVE DNS server, do NOT enable recursion.
        - If you are building a RECURSIVE (caching) DNS server, you need to enable 
        recursion. 
        - If your recursive DNS server has a public IP address, you MUST enable access 
        control to limit queries to your legitimate users. Failing to do so will
        cause your server to become part of large scale DNS amplification 
        attacks. Implementing BCP38 within your network would greatly
        reduce such attack surface 
        */
        recursion yes;

        dnssec-enable yes;
        dnssec-validation yes;

        managed-keys-directory "/var/named/dynamic";

        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";

        /* https://fedoraproject.org/wiki/Changes/CryptoPolicy */
        include "/etc/crypto-policies/back-ends/bind.config";
        };

        logging {
                channel default_debug {
                file "data/named.run";
                severity dynamic;
                };
        };

        zone "$DNS" IN {
                type master;
                file "$DNS.db";
                allow-update { none; };
        };
        zone "$RevFile1" IN {
                type master;
                file "$RevFile2";
                allow-update { none; };
        };

        include "/etc/named.rfc1912.zones";
        include "/etc/named.root.key";

EOF
echo -e "\e[1;36m[OK] Config File\e[0m"

cat > /var/named/$RevFile2 <<- EOF
\$TTL 86400
@   IN  SOA     dns.$DNS. root.$DNS. (
3           ;Serial
3600        ;Refresh
1800        ;Retry
604800      ;Expire
86400       ;Minimum TTL
)
;Name Server Information
@         IN      NS         dns.$DNS.
;Reverse lookup for Name Server
10        IN  PTR     dns.$DNS.
;PTR Record IP address to HostName
100      IN  PTR     www.$DNS.
150      IN  PTR     mail.$DNS.

EOF
echo -e "\e[1;36m[OK] Reverse Zone\e[0m"

cat > /var/named/$ZONE <<- EOF
\$TTL 86400
@	IN	SOA	dns.$DNS.	root.$DNS. (
3           ;Serial
3600        ;Refresh
1800        ;Retry
604800      ;Expire
86400       ;Minimum TTL
)

;Name Server Information
@	IN	NS	dns.$DNS.

;IP address of Name Server
dns	IN	A	$IP

;Mail exchanger
$DNS.	IN	MX	10	mail.$DNS.

;A - Record HostName To Ip Address
www	IN	A	$IP
mail	IN	A	$IP

;CNAME record
ftp     IN CNAME        www.$DNS.


EOF
echo -e "\e[1;36m[OK] Forward Zone\e[0m"

cat > /etc/resolv.conf <<- EOF
nameserver $IP
EOF

echo -e "\e[1;36m[OK] Resolv.conf\e[0m"
systemctl stop firewalld
systemctl disable firewalld
systemctl start named
systemctl enable named
echo -e "\e[1;36m[#] www.$DNS\e[0m"
echo -e "\e[1;36m[#] mail.$DNS\e[0m"
echo -e "\e[1;36m[#] ftp.$DNS\e[0m"
echo -e "\e[1;36m[#] dns.$DNS\e[0m"
echo -e "\e[1;36m[#] Done\e[0m"
systemctl restart named
