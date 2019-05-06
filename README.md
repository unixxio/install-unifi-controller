# Install Ubiquiti UniFi Controller on Debian or Ubuntu

This script will help you install Ubiquiti UniFi Controller on Debian. Change unifi.yourdomain.com accordingly. It will:

* Install Nginx (with Let's Encrypt support)

#### Download and install UniFi Controller

```
bash <( curl -sSL https://raw.githubusercontent.com/unixxio/install-unifi-controller/master/install_unifi.sh ) | unifi.yourdomain.com
```

#### Tested on

* Debian 9 Stretch
