# add user to linux system
adduser krnsl101 -p AW6GdhVba=qbkQu* -m
useradd -G sl1mon krnsl101
usermod -L krnsl101
chage  -M -1 krnsl101
mkdir /home/krnsl101/.ssh
chmod 700 /home/krnsl101/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDOJvfLaHwvUwgX82zVe442w+cI3gfMglut7C8I5G8L+0IfujQCQLef+bSgFzTpVkMN/BJHkUTTuquyZu7glNZ70KfNX1BOR/tsTJUixQT5reFeJIRsKhdz6w/FDP9/DcKwpqBXoDlFY+1MaqCpAPHlPpK+1GYkQeatWo9Od2fY5bPQTfYIWNQmeEXtYUt2q3Ir28gGRAt3jfMtRgeuXIQY8sNLi31D7Dr+K+uRW+Nd29dsjrU40rXcd1B6OceOlGBRTHmCJCk6jyOgY3RPVvtHap512uPPgHho1NhT6tcYn5MSG5TlgDcVwQf4ZQR8QCe56Eke4odoOi9onVDU6meR gmx\p02675820@LAPTOP-R1DH4ROQ" >> /home/krnsl101/.ssh/authorized_keys
chmod 600 /home/krnsl101/.ssh/authorized_keys

## add sudo for science logic user
## copy file 154_SCIENCELOGICL_RMIS_GLB into /etc/sudoer.d/
