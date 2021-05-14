#! /bin/bash
yum update
yum install -y httpd
sudo systemctl start httpd
echo "<h1>Hello from `curl http://169.254.169.254/latest/meta-data/public-ipv4` </h1>" | sudo tee /var/www/html/index.html
