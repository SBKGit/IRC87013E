#!bin/bash
yum install httpd -y
echo "hello world $(hostname -f)" > /var/www/html/index.html
service httpd start
chkconfig httpd on
