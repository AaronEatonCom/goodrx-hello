#!/bin/bash

yum groupinstall -y "Development Tools"

pip install -r /tmp/goodrx-hello/requirements.txt

mkdir -p /var/www/goodrx-hello
cp /tmp/goodrx-hello/goodrx-hello.py /var/www/goodrx-hello/goodrx-hello.py

chown -R nginx:nginx /var/www/goodrx-hello
chown -R nginx:nginx /var/log/nginx

rm -rf /etc/nginx/conf.d/*
cp /tmp/goodrx-hello/nginx.conf /etc/nginx/nginx.conf
cp /tmp/goodrx-hello/vhost.conf /etc/nginx/conf.d/goodrx-hello.conf

initctl start goodrx-hello
service nginx start