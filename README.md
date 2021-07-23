

### Requirements:

 - [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
 - [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)

   Example of installation for ubuntu:
```shell
sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible
```

 - [AWS Cli](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
 - [AWS Authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html)
 - openvpn
```shell
sudo apt install -y openvpn
``` 

### Create the certificates (if dont exist):  FIRST TIME ONLY!!!
```shell
CWD=`pwd`
mkdir certs
cd certs
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 >  .rnd

openssl genrsa -out rootCA.key 4096
openssl req -x509 -new -nodes -key rootCA.key -sha512 -days 3650 -out rootCA.pem -subj "/C=BR/CN=rootca.cloud.int"
openssl genrsa -out openvpn.key 4096
openssl req -new -key openvpn.key -out openvpn.csr -subj "/C=BR/CN=openvpn.cloud.int"
openssl x509 -req -in openvpn.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out openvpn.crt -days 3650 -sha512
openssl dhparam -dsaparam -out dh4096.pem 4096
/usr/sbin/openvpn --genkey --secret ta.key
```

### Create the certificates for clients  ( 1 Time Only )

#### Examples:  client01 and client02

```shell
cn="client01.cloud.int"
openssl genrsa -out ${cn}.key 4096
openssl req -new -key ${cn}.key -out ${cn}.csr -subj "/C=BR/CN=${cn}"
openssl x509 -req -in ${cn}.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out ${cn}.crt -days 3650 -sha512

mkdir -pv clients/${cn}

mv ${cn}.crt clients/${cn}/
mv ${cn}.key clients/${cn}/
cp ta.key clients/${cn}/
cp rootCA.pem clients/${cn}/
cp dh4096.pem clients/${cn}/
```

#### Configuration file

- Linux:
```shell
cat << EOF > clients/${cn}/${cn}.conf
client
dev tap
proto tcp
remote #VPN_IP#
port 8000

#pull
comp-lzo
keepalive 10 120
float
tls-client
persist-tun
persist-key
log-append /var/log/openvpn.log
dh /etc/openvpn/certs/dh4096.pem
ca /etc/openvpn/certs/rootCA.pem
cert /etc/openvpn/certs/${cn}.crt
key /etc/openvpn/certs/${cn}.key
tls-auth /etc/openvpn/certs/ta.key
route-method exe
route-delay 2
EOF
```

-  Windows:
```shell
cat << EOF > clients/${cn}/${cn}.ovpn
client
dev tap
proto tcp
remote #VPN_IP#
port 8000

#pull
comp-lzo
keepalive 10 120
float
tls-client
persist-tun
persist-key
log-append openvpn.log
dh dh4096.pem
ca rootCA.pem
cert ${cn}.crt
key ${cn}.key
tls-auth ta.key
route-method exe
route-delay 2
EOF
```

####  Client 02.  CN:  client01.cloud.int 

```shell
cn="client02.cloud.int"
openssl genrsa -out ${cn}.key 4096
openssl req -new -key ${cn}.key -out ${cn}.csr -subj "/C=BR/CN=${cn}"
openssl x509 -req -in ${cn}.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out ${cn}.crt -days 3650 -sha512

mkdir -pv clients/${cn}

mv ${cn}.crt clients/${cn}/
mv ${cn}.key clients/${cn}/
cp ta.key clients/${cn}/
cp rootCA.pem clients/${cn}/
cp dh4096.pem clients/${cn}/
```

#### Config file

- Linux:
```shell
cat << EOF > clients/${cn}/${cn}.conf
client
dev tap
proto tcp
remote #VPN_IP#
port 8000

#pull
comp-lzo
keepalive 10 120
float
tls-client
persist-tun
persist-key
log-append /var/log/openvpn.log
dh /etc/openvpn/certs/dh4096.pem
ca /etc/openvpn/certs/rootCA.pem
cert /etc/openvpn/certs/${cn}.crt
key /etc/openvpn/certs/${cn}.key
tls-auth /etc/openvpn/certs/ta.key
route-method exe
route-delay 2
EOF
```

- Windows:
```shell
cat << EOF > clients/${cn}/${cn}.ovpn
client
dev tap
proto tcp
remote #VPN_IP#
port 8000

#pull
comp-lzo
keepalive 10 120
float
tls-client
persist-tun
persist-key
log-append openvpn.log
dh dh4096.pem
ca rootCA.pem
cert ${cn}.crt
key ${cn}.key
tls-auth ta.key
route-method exe
route-delay 2
EOF
```

Return to the original directory:
```shell
cd ${CWD}
```


### Create the virtual machine

- Create a IAM user with needed permission for ec2 in aws
- Configure aws:

```shell
aws configure
```

- Create a private kay to access the virtual machine (don't type any password):
```shell
ssh-keygen -t rsa -f id_rsa
```

- Create the virtual machine using terraform:
```shell
terraform init 
terraform apply -auto-approve
```

Obs.:  The instance hostname will be configured in hosts  file. Type "cat hosts" to verify

### Configure openvpn

Before start, edit the file "config.yml" for your environment

- Update and configure virtual machine:
```shell
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts --private-key id_rsa openvpn.yml
```

- Reconfigure virtual machine (without update):
```shell
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts --private-key id_rsa configure.yml
```

Important: change the vpn ip/hostname for client configuration files:
```shell  
vpn_hostname=`grep -oP '.*\..*' hosts | tail -1`
echo ${vpn_hostname} 
find certs/clients/ -name *.conf -exec sed -i "s|#VPN_IP#|${vpn_hostname}|g" {} \;
find certs/clients/ -name *.ovpn -exec sed -i "s|#VPN_IP#|${vpn_hostname}|g" {} \;
```

### To destroy the virtual machine:
```shell
terraform destroy -auto-approve
```
