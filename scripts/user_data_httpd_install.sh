#!/bin/bash
yum update -y
yum install -y httpd
systemctl enable httpd
systemctl start httpd
now=$(date)
echo “Hello World from $(hostname -f) @ $now” > /var/www/html/index.html
