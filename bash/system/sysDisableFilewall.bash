firewall-cmd --state
systemctl stop firewalld
systemctl disable firewalld
systemctl mask --now firewalld
