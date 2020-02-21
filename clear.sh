#!/bin/bash
apt remove --purge -y puppet puppet-common puppetdb puppetdb-terminus puppetmaster puppetmaster-common postgresql-client-9.4 postgresql-client-common postgresql-common postgresql-contrib-9.4 libruby libruby2.3:amd64 ruby ruby-all-dev ruby-augeas ruby-deep-merge ruby-did-you-mean ruby-json ruby-minitest ruby-net-telnet ruby-power-assert ruby-shadow ruby-test-unit ruby2.3 ruby2.3-dev:amd64 rubygems-integration
apt -y autoremove
if [ -d "/.git" ]; then rm -r /.git; fi
if [ -d "/.gem" ]; then rm -r /.gem; fi
if [ -d "/root/configs" ]; then rm -r /root/configs; fi
if [ -d "/root/.gem" ]; then rm -r /root/.gem; fi
if [ -d "/root/sensu" ]; then rm -r /root/sensu; fi
if [ -d "/root/tp" ]; then rm -r /root/tp; fi
if [ -d "/etc/puppet" ]; then rm -r /etc/puppet; fi
if [ -d "/etc/puppetlabs" ]; then rm -r /etc/puppetlabs; fi
if [ -d "/etc/puppetdb" ]; then rm -r /etc/puppetdb; fi
if [ -d "/var/lib/puppet" ]; then rm -r /var/lib/puppet; fi
if [ -d "/var/lib/gems" ]; then rm -r /var/lib/gems; fi
if [ -e "/root/master-support" ]; then rm /root/master-support; fi
if [ -e "/root/puppet_3.8.7-1puppetlabs1~ubuntu16.04.1_all.deb" ]; then rm /root/*.deb; fi
if [ -e "/root/puppet_run_init.log" ]; then rm /root/*.log; fi
if [ -e "/root/.gitconfig" ]; then rm /root/.gitconfig; fi
if [ -e "/etc/hiera.yaml" ]; then rm /etc/hiera.yaml; fi
sed -i 's/umask 027/umask 022/' /etc/profile
sed -i 's/umask 027/umask 022/' /etc/bash.bashrc
sed -i 's/umask 027/umask 022/' /etc/profile.d/*
umask 0022
hostnamectl set-hostname TPA02-PRD-SF1
echo "Done"
