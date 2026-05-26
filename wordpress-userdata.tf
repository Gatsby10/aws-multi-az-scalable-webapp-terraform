locals {
  wordpress_script = <<-EOF
#!/bin/bash
sudo yum update -y
sudo yum upgrade -y
#Download and install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo yum install unzip -y
unzip awscliv2.zip
sudo ./aws/install
#Install Apache, PHP, MySQL packages, and ssl
sudo yum install httpd php php-mysqlnd -y
sudo yum install -y mod_ssl
cd /var/www/html
touch indextest.html
echo "This is a test file" > indextest.html
#Install wget, download and extract WordPress
sudo yum install wget -y
wget https://wordpress.org/wordpress-6.3.1.tar.gz
tar -xzf wordpress-6.3.1.tar.gz
cp -r wordpress/* /var/www/html/
rm -rf wordpress
rm -rf wordpress-6.3.1.tar.gz
chmod -R 755 wp-content
chown -R apache:apache wp-content
cd /var/www/html && mv wp-config-sample.php wp-config.php
#Configure the WordPress database connection
sed -i "s@define( 'DB_NAME', 'database_name_here' )@define( 'DB_NAME', '${var.db_name}' )@g" /var/www/html/wp-config.php
sed -i "s@define( 'DB_USER', 'username_here' )@define( 'DB_USER', '${var.db_username}' )@g" /var/www/html/wp-config.php
sed -i "s@define( 'DB_PASSWORD', 'password_here' )@define( 'DB_PASSWORD', '${var.db_password}' )@g" /var/www/html/wp-config.php
sed -i "s@define( 'DB_HOST', 'localhost' )@define( 'DB_HOST', '${element(split(":", aws_db_instance.team-2-rds.endpoint), 0)}')@g" /var/www/html/wp-config.php
sudo sed -i  -e '154aAllowOverride All' -e '154d' /etc/httpd/conf/httpd.conf
cat <<EOT > /var/www/html/.htaccess
Options +FollowSymlinks
RewriteEngine on
RewriteRule ^wp-content/uploads/(.*)$ https://${data.aws_cloudfront_distribution.team-2-cdn.domain_name}/$1 [r=301,NC,L]
# BEGIN WordPress
# END WordPress
EOT
aws s3 cp --recursive /var/www/html/ s3://team-2-code-bucket
aws s3 sync /var/www/html/ s3://team-2-code-bucket
echo "* * * * * ec2-user /usr/local/bin/aws s3 sync s3://team-2-code-bucket /var/www/html/" | sudo tee -a /etc/crontab
echo "* * * * * ec2-user /usr/local/bin/aws s3 sync /var/www/html/wp-content/uploads/ s3://team-2-media-bucket" | sudo tee -a /etc/crontab
sudo systemctl enable httpd
sudo systemctl start httpd
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
sudo hostnamectl set-hostname webserver
EOF
}
