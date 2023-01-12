#!bin/bash
sudo apt-get -y update
sudo service nginx start
echo "<h1>Hello World</h1>" | sudo tee /var/www/html/index.ht
