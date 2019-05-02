#!/bin/bash
# Debian 9 on DigitalOCean
# Credentials for the root user - use a long secret password - watchout for url encoding in case of using special characters
read -p 'Username: ' USERNAME
read -p 'Password: ' PASSWORD

# Change sources.list
sed -i -e '$ a\apt_preserve_sources_list: true' /etc/cloud/cloud.cfg
# Comment out all lines
sed -i -e 's/^#*/#/' /etc/apt/sources.list
sed -i -e 's/^#*/#/' /etc/cloud/templates/sources.list.debian.tmpl
# Create customSources.list
echo 'deb http://deb.debian.org/debian stretch main contrib non-free' >> /etc/apt/sources.list.d/customSources.list
echo 'deb http://deb.debian.org/debian-security/ stretch/updates main contrib non-free' >> /etc/apt/sources.list.d/customSources.list
echo 'deb http://deb.debian.org/debian stretch-updates main contrib non-free' >> /etc/apt/sources.list.d/customSources.list
echo 'deb http://deb.debian.org/debian stretch-backports main contrib non-free' >> /etc/apt/sources.list.d/customSources.list

# Non-interactive
export DEBIAN_FRONTEND=noninteractive

# Update and Upgrade
apt -y update && apt -y upgrade && apt -y autoremove

# Install ufw
apt install -y ufw
ufw allow 'OpenSSH'
yes | ufw enable

# Install dirmngr
sudo apt install -y dirmngr

# Import the public key used by the package management system.
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4

# Create a source list for mongoDB
echo "deb http://repo.mongodb.org/apt/debian stretch/mongodb-org/4.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list

# Reload local package
sudo apt update

# Install mongoDB
sudo apt-get install -y mongodb-org

# To prevent unintended upgrades, you can pin the package at the currently installed version
echo "mongodb-org hold" | sudo dpkg --set-selections
echo "mongodb-org-server hold" | sudo dpkg --set-selections
echo "mongodb-org-shell hold" | sudo dpkg --set-selections
echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
echo "mongodb-org-tools hold" | sudo dpkg --set-selections

# Enable and Start MongoDB in the background
sudo systemctl enable mongod && sudo systemctl start mongod
sleep 5  #  Give 5 seconds to make sure mongoDB is online

# Create a user (root)
sudo mongo --eval "db.getSiblingDB('admin').createUser({user: '$USERNAME', pwd: '$PASSWORD', roles: [{role: 'root', db: 'admin' }, 'readWriteAnyDatabase']})"

# Firewall
sudo ufw allow 27017

# Enable Authentication
# Append a new line below security :)
sudo sed -i -e 's/#security/security/' /etc/mongod.conf
sudo sed -i '/security/a \  authorization: "enabled"' /etc/mongod.conf

# bindIP
# set bindIp to ::,0.0.0.0 to bind to all IP addresses
sudo sed -i -e 's/bindIp: 127.0.0.1/bindIp: ::,0.0.0.0/' /etc/mongod.conf

# Connection String URI
IP="$(ifconfig eth0 | grep inet | awk '/[0-9]\./{print $2}')"
echo "********* mongoDB connection string URI *********"
echo "mongodb://$USERNAME:$PASSWORD@$IP:27017/"

# Restart mongoDB
systemctl restart mongod
