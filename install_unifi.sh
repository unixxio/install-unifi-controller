#!/bin/bash
# date: 07/05/2019 (D/m/Y)
# version: v1.0
# creator: unixx.io

# variables
nginx_hostname="$1"

# check if script is executed as root
myuid="$(/usr/bin/id -u)"
if [[ "${myuid}" != 0 ]]; then
    echo -e "\n[ Error ] This script must be run as root.\n"
    exit 0;
fi

# check if the nginx_hostname variable is not empty
if [[ "${nginx_hostname}" = "" ]]; then
    echo -e "\n[ Error ] Please enter a domain for unifi. (Example: unifi.yourdomain.com)\n"
    exit
fi

# prompt to accept before continue
clear
echo ""
echo "We are now going to install UniFi Controller"
echo "This will also install Nginx."
echo ""
echo "#########################################################################"
echo "#                                                                       #"
echo "#      DO NOT USE THIS SCRIPT IF YOU ALREADY HAVE NGINX INSTALLED!      #"
echo "#                                                                       #"
echo "#########################################################################"
echo ""
read -p "Are you sure you want to continue (y/n)? " choice
case "$choice" in
  y|Y ) echo "" && echo "Installation can take a few minutes, please wait...";;
  n|N ) echo "" && exit;;
  * ) echo "Invalid option";;
esac

# install nginx with let's encrypt support
apt-get install python-certbot-nginx -y > /dev/null 2>&1

# add ubiquiti repository
echo 'deb http://www.ui.com/downloads/unifi/debian stable ubiquiti' > /etc/apt/sources.list.d/100-ubnt-unifi.list
wget -q -O /etc/apt/trusted.gpg.d/unifi-repo.gpg https://dl.ui.com/unifi/unifi-repo.gpg

# install unifi controller
apt-get update > /dev/null 2>&1
apt-get install apt-transport-https unifi -y > /dev/null 2>&1

# generate selfsigned certificate
mkdir -p /etc/nginx/ssl
cd /etc/nginx/ssl
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj '/CN=${nginx_hostname}' -keyout ${nginx_hostname}.key -out ${nginx_hostname}.crt > /dev/null 2>&1
chmod 400 ${nginx_hostname}.key

# generate nginx vhost
variable="$"
cat <<EOF>> /etc/nginx/sites-available/${nginx_hostname}.conf
server {
  listen 80;

  server_name ${nginx_hostname};
  return 301 https://${nginx_hostname};
}

server {
  listen 443 ssl;

  server_name ${nginx_hostname};

  access_log /var/log/nginx/${nginx_hostname}.access.log;
  error_log /var/log/nginx/${nginx_hostname}.error.log;

  ssl on;
  ssl_certificate /etc/nginx/ssl/${nginx_hostname}.crt;
  ssl_certificate_key /etc/nginx/ssl/${nginx_hostname}.key;
  ssl_session_timeout 5m;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';
  ssl_prefer_server_ciphers on;
  ssl_session_cache shared:SSL:10m;

  location /wss/ {
      proxy_pass https://localhost:8443;
      proxy_http_version 1.1;
      proxy_buffering off;
      proxy_set_header Upgrade ${variable}http_upgrade;
      proxy_set_header Connection "Upgrade";
      proxy_read_timeout 86400;
  }

  location / {
      proxy_pass https://localhost:8443/;
      proxy_set_header Host ${variable}host;
      proxy_set_header X-Real-IP ${variable}remote_addr;
      proxy_set_header X-Forward-For ${variable}proxy_add_x_forwarded_for;
  }
}
EOF

# make nginx vhost active
ln -s /etc/nginx/sites-available/${nginx_hostname}.conf /etc/nginx/sites-enabled/

# start services
systemctl restart nginx

# done
echo ""
echo "You can now access https://${nginx_hostname}."
echo ""
echo "Make sure your DNS settings are correct and that the following ports are allowed in your firewall:"
echo ""
echo " -TCP_IN/TCP6_IN: 8080,8443,8880,8843,6789"
echo " -TCP_OUT/TCP6_OUT: 8883"
echo " -UDP_IN/UDP6_IN: 3478"
echo " -UDP_OUT/UDP6_OUT: 3478"
echo ""
echo "If your DNS settings are correct you can obtain an Let's Certificate with: sudo certbot --nginx -d ${nginx_hostname}"
echo ""
exit
