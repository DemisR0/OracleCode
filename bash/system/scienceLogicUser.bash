# add user to linux system
adduser krnsl101 -p xxx -m
useradd -G sl1mon krnsl101
usermod -L krnsl101
chage  -M -1 krnsl101
mkdir /home/krnsl101/.ssh
chmod 700 /home/krnsl101/.ssh
echo "ssh-rsa xxx" >> /home/krnsl101/.ssh/authorized_keys
chmod 600 /home/krnsl101/.ssh/authorized_keys

## add sudo for science logic user
## copy file 154_SCIENCELOGICL_RMIS_GLB into /etc/sudoer.d/
