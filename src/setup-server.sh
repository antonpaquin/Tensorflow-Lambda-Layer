#! /bin/bash

# Attach and mount a larger storage device
mkdir build
sudo mkfs.ext4 /dev/nvme1n1
sudo mount /dev/nvme1n1 build
sudo chown -R ec2-user:ec2-user build

# Unzip the transfer file sent to the server
mv build_targets.zip build
mv build-layer.sh build
pushd build
unzip build_targets.zip
rm build_targets.zip
popd

# Install some libraries needed to build openssl and python
sudo yum groupinstall -y \
	development

sudo yum install -y \
	zlib-devel \
	openssl-devel 

# Install openssl from source
wget https://github.com/openssl/openssl/archive/OpenSSL_1_0_2l.tar.gz
tar -zxvf OpenSSL_1_0_2l.tar.gz
pushd openssl-OpenSSL_1_0_2l/
./config shared
make
sudo make install
export LD_LIBRARY_PATH=/usr/local/ssl/lib/
popd
rm -rf OpenSSL_1_0_2l.tar.gz openssl-OpenSSL_1_0_2l/

# Install python from source
wget https://www.python.org/ftp/python/3.6.6/Python-3.6.6.tar.xz
tar xJf Python-3.6.6.tar.xz
pushd Python-3.6.6
./configure
make
sudo make install
popd
sudo rm -rf Python-3.6.6.tar.xz Python-3.6.6

# Start up the installation virtualenv
sudo env PATH=$PATH pip3 install --upgrade virtualenv

# Add the "epel" yum repo and install inotifytools
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo yum install -y \
	epel-release-latest-7.noarch.rpm
rm epel-release-latest-7.noarch.rpm
sudo yum install -y \
	inotify-tools

sudo pip install --upgrade awscli
