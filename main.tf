#checkov
resource "null_resource" "checkov_scan" {
  provisioner "local-exec" {
    command = "./checkov_scan.sh"
    interpreter = [ "bash", "-c"]
  }
provisioner "local-exec" {
when = destroy
command = "rm -f checkov_output.json"
}
  triggers = {
    always_run = timestamp()
  }
}
output "checkov_scan_status" {
value = "checkov scan completed check the output.json file for details"
}

#Creating a VPC
resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"

    tags = {
        Name ="main"
    }
}

#Ceating Pub Subnet 1
resource "aws_subnet" "pubsub-1" {

    vpc_id =aws_vpc.main.vpc_id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-west-1a"

    tags = {
    Name = "pubsub-1"
  }
}

#Creating Pub subnet 2
resource "aws_subnet" "pubsub-2"{

    vpc_id =aws_vpc.main.vpc_id
    cidr_block = "10.0.2.0/24"
    availability_zone = "eu-west-1b"

    tags = {
    Name = "pubsub-2"
 }

}

#Creating Pri Subnet 1
resource "aws_subnet" "prisub-1" {

    vpc_id =aws_vpc.main.vpc_id
    cidr_block = "10.0.3.0/24"
    availability_zone = "eu-west-1a"

    tags = {
        Name = "prisub-1"
    }
}

#Creating Pri Subnet 2
resource "aws_subnet" "prisub-2" {

    vpc_id =aws_vpc.main.vpc_id
    cidr_block = "10.0.4.0/24"
    availability_zone = "eu-west-1b"

    tags = {
        Name = "prisub-2"
    }
}

#Creating Internet Gateway
resource "aws_internet_gateway" "igw-main"{
    vpc_id = aws_vpc.main.vpc_id

    tags ={
        Name = "igw-main"
    }
}

#Creating elastic IP for NAT Gateway
resource "aws_eip" "nat-eip"{
    domain = "vpc"

    tags ={
        Name = "nat-eip"
    }

}

#Creating NAT Gateway
resource "aws_nat_gateway" "nat-gw"{
    allocation_id = aws_eip.nat-eip.id
    subnet_id = aws_subnet.prisub-1.id

    tags ={
        Name = "nat-gw"
    }
}

#Creating Route table for public subnets
resource "aws_route_table" "pub-rt"{
    vpc_id = aws_vpc.main.vpc_id

    tags ={
        Name = "pub-rt"
    }
}

#Creating route table for private subnets
resource "aws_route_table" "pri-rt"{
    vpc_id = aws_vpc.main.vpc_id

    tags ={
        Name = "pri-rt"
    }
}

#Creating Public route association
resource "aws_route_table_association" "pub-rt-association"{
    subnet_id = aws_subnet.pubsub-1.id
    route_table_id = aws_route_table.pub-rt.id
}

#Creating Private route association
resource "aws_route_table_association" "pri-rt-association"{
    subnet_id = aws_subnet.prisub-1.id
    route_table_id = aws_route_table.pri-rt.id
}

#Creating security group for Frontend
resource "aws_security_group" "frontend-sg"{
    vpc_id = aws_vpc.main.vpc_id
    description = "Frontend security group"

    ingress{
        description = "ssh access"
        protocol = "tcp"
        from_port = 22
        to_port = 22
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress{
        description = "http access"
        protocol = "tcp"
        from_port = 80
        to_port = 80
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress{
        description = "https access"
        protocol = "tcp"
        from_port = 443
        to_port = 443
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    egress{
        description = "all outbound traffic"
        protocol = "-1"
        from_port = 0
        to_port = 0
        cidr_blocks = ["0.0.0.0/0"]
    } 
}

#Creating security group for Backend
resource "aws_security_group" "backend-sg"{
    vpc_id = aws_vpc.main.vpc_id
    description = "Database Backend security group"

    ingress{
        description = "MySQL-Aurora access from frontend"
        protocol = "tcp"
        from_port = 3306
        to_port = 3306
        security_groups = [aws_security_group.frontend-sg.id] #Allowing access from frontend security group
    }

    egress{
        description = "all outbound traffic"
        protocol = "-1"
        from_port = 0
        to_port = 0
        cidr_blocks = ["0.0.0.0/0"]
    } 
}

#Key pair for ssh into the instance
#Creating a private key
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#Saving the private key to a local file
resource "local_file" "key" {
  content  = tls_private_key.key.private_key_pem
  filename = "keypair"
  file_permission = "400"
}

#Creating Public key pair for ssh access to the instance
resource "aws_key_pair" "key" {
  key_name   = "keypair"
  public_key = tls_private_key.key.public_key_openssh
}

#Creating subnet group for database
resource "aws_db_subnet_group" "db-subnet-group" {
    name = "db-subnet-group"
    subnet_ids = [aws_subnet.prisub-1.id, aws_subnet.prisub-2.id]
    tags = {
        Name = "db-subnet-group"
    }
}

# AWS Secrets Manager____used to securely store, manage, and retrieve sensitive data
#1. Creating a secret in AWS Secrets Manager to store database credentials
resource "aws_secretsmanager_secret" "rds_credentials" {
    name = "rds_credentials"
    description = "Database credentials for the private subnet RDS instance"

    #Optional: Automatic rotation of the secret, or set recovery windows
    recovery_window_in_days = 7

    tags = {
        Name = "rds_credentials"
        Environment = "production"
    }
}

#2. Storing the database credentials as a secret value in AWS Secrets Manager
resource "aws_secretsmanager_secret_version" "rds_credentials_version" {
    secret_id = aws_secretsmanager_secret.rds_credentials.id

    #Storing DB credentials as a JSON object is an AWS best practice

    secret_string = jsonencode({
        username = "admin"
        password = "admin123"
        engine = "mysql"
        port = 3306
    })

}

#Creating RDS
resource "aws_db_instance" "rds-instance" {
    identifier = "rds-instance"
    allocated_storage = 20
    max_allocated_storage = 100 #Allows RDS to automatically scale storage up to 100 GB as needed
    storage_type = "gp2"
    engine = "mysql"
    engine_version = "8.0" 
    instance_class = "db.t3.micro"
    username = "admin" #The username for the database instance. This is required when creating a new RDS instance.
    password = "admin123" #The password for the database instance. This is required when creating a new RDS instance.
    parameter_group_name = "default.mysql8.0" #The name of the DB parameter group to associate with this instance. If you don't specify a value, then the default DB parameter group for the specified engine and version is used.
    db_subnet_group_name = aws_db_subnet_group.db-subnet-group.name
    vpc_security_group_ids = [aws_security_group.backend-sg.id] #The VPC security groups to associate with the RDS instance.
    skip_final_snapshot = true #Whether to skip the final DB snapshot when the DB instance is deleted.
    deletion_protection = true
    publicly_accessible = false
    backup_retention_period = 3
    backup_window = "03:00-06:00"
    db_name =var.db_name
    tags = {
        Name = "rds-instance"
        Environment = "production"
    }
}

#Creating code bucket for storing application code
resource "aws_s3_bucket" "code-bucket" {
    bucket = "code-bucket-1234567890" 

    tags = {
        Name = "code-bucket"
        Environment = "production"
    }
}

#Block all public access
resource "aws_s3_bucket_public_access_block" "public_access" {
    bucket = aws_s3_bucket.code-bucket.id

    block_public_acls = true
    block_public_policy = false
    ignore_public_acls = true
    restrict_public_buckets = true
}

#Create IAM Role for EC2 to access S3
resource "aws_iam_role" "ec2_role" {
    name = "ec2_s3_role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "ec2.amazonaws.com"
                }
            }
        ]
    })

    tags = {
        Name = "ec2_s3_role"
        Environment = "production"
    }
}

#Creating media bucket iam policy
resource "aws_iam_policy" "media_iam_policy" {
    name = "media_iam_policy"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = ["s3:*"]
                Effect = "Allow"
                Resource = ["*"]
            },
        ]
    })

    tags = {
        Name = "media_iam_policy"
        Environment = "production"
    }
}

#Creating iam role policy attachment for s3 bucket
resource "aws_iam_role_policy_attachment" "iam_s3_attachment" {
    role = aws_iam_role.ec2_role.name
    policy_arn = aws_iam_policy.media_iam_policy.arn
}

#Creating IAM instance profile
resource "aws_iam_instance_profile" "iam_instance_profile1" {
    name = "instance_profile12"
    role = aws_iam_role.ec2_role.name
}

#Creating the wordpress server

resource "aws_instance" "ec2-instance" {
    ami = "ami-02efa8fd15663fc12" 
    instance_type = "t3.micro"
    subnet_id = aws_subnet.pubsub-1.id
    vpc_security_group_ids = [aws_security_group.frontend-sg.id, aws_security_group.backend-sg.id]
    key_name = aws_key_pair.key.id
    iam_instance_profile = aws_iam_instance_profile.iam_instance_profile1.name
    associate_public_ip_address = true
    user_data = local.wordpress_script

    tags = {
        Name = "ec2-instance"
        
    }
}

#Creating S3 bucket for media uploads
resource "aws_s3_bucket" "media-bucket" {
    bucket = "media-bucket-1234567890" 

    tags = {
        Name = "media-bucket"
        Environment = "production"
    }
}

#Creating S3 bucket for logs
resource "aws_s3_bucket" "logs-bucket" {
    bucket = "logs-bucket-1234567890" 

    tags = {
        Name = "logs-bucket"
        Environment = "production"
    }
}

resource "aws_s3_bucket_public_access_block" "logs-bucket"{
    bucket = aws_s3_bucket.logs-bucket.id

    block_public_acls = false # Prevents making objects public via ACLs (Access Control Lists are outdated and messy)
    block_public_policy = false # we need to make bucket public via policy
    ignore_public_acls = false # ignore if trying to set a public ACL, good security practice.
    restrict_public_buckets = false # does not restrict public policies
}

#Add public access control
#This is required for public access to work

resource "aws_s3_bucket_public_access_block" "media-bucket" {
    bucket = aws_s3_bucket.media-bucket.id

    block_public_acls = false # Prevents making objects public via ACLs (Access Control Lists are outdated and messy)
    block_public_policy = false # we need to make bucket public via policy
    ignore_public_acls = true 
    restrict_public_buckets = false # does not restrict public policies
}
  
#Media bucket policy
resource "aws_s3_bucket_policy" "media_bucket_policy" {
    bucket = aws_s3_bucket.media-bucket.id

    policy = data.aws_iam_policy_document.media_bucket_policy.json
}

data "aws_iam_policy_document" "media_bucket_policy" {
    statement {
        
        principals {
            type = "AWS"
            identifiers = ["*"]
        }
        actions = [
            "s3:*"
        ]
        resources = [
            aws_s3_bucket.media-bucket.arn, # Allow access to the bucket itself
            "${aws_s3_bucket.media-bucket.arn}/*"
        ] 
    }
}

#Creating Elastic Load Balancer
resource "aws_lb" "app-elb" {
    name = "app-elb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.frontend-sg.id]
    subnets = [aws_subnet.pubsub-1.id, aws_subnet.pubsub-2.id]
    enable_deletion_protection = false

    tags = {
        Name = "app-elb"
        Environment = "production"
    }
}

resource "aws_lb_target_group" "target-group-lb-HTTP" {

  name = "tg-http"

  port = 80

  protocol = "HTTP"

  target_type = "instance"

  vpc_id = aws_vpc.main.id

  health_check {

    path = "/indextest.html"

    interval = 60

    timeout = 30

    healthy_threshold = 3

    unhealthy_threshold = 5

    port = 80

  }

  tags = {

    Name = "http-target-group"

  }

}

resource "aws_lb_target_group" "target-group-lb-HTTPS" {

  name = "tg-https"

  port = 443

  protocol = "HTTPS"

  target_type = "instance"

  vpc_id = aws_vpc.main.id

  health_check {

    path = "/indextest.html"

    interval = 60

    timeout = 30

    healthy_threshold = 3

    unhealthy_threshold = 5

    port = 443

  }

  tags = {

    Name = "https-target-group"

  }

}

# Load balancer attachement

resource "aws_lb_target_group_attachment" "lb_attachment_http" {

  target_group_arn = aws_lb_target_group.target-group-lb-HTTP.arn

  target_id = aws_instance.ec2-instance.id

  port = 80

}

resource "aws_lb_target_group_attachment" "lb_attachment_https" {

  target_group_arn = aws_lb_target_group.target-group-lb-HTTPS.arn

  target_id = aws_instance.ec2-instance.id

  port = 443

}

resource "aws_launch_template" "capstone-app-lt" {

  name_prefix = "app-lt-"

  image_id = "ami-02efa8fd15663fc12" # Amazon Linux 2023 AMI 2023.11.20260406.2 x86_64 HVM kernel-6.1 paris region

  instance_type = "t3.micro" #free tier instance type

  key_name = aws_key_pair.key.key_name # to be defined when keypair is made

  iam_instance_profile {

    name = aws_iam_instance_profile.iam-instance-profile1.id

  }

  network_interfaces {

    associate_public_ip_address = true

    security_groups = [aws_security_group.frontend-sg.id]

  }

  user_data = base64encode(local.wordpress_script)

}

#auto scaling policy

resource "aws_autoscaling_policy" "capstone-asg-policy" {

  name = "scale-out-policy"

  scaling_adjustment = 1

  adjustment_type = "ChangeInCapacity"

  cooldown = 300

  autoscaling_group_name = aws_autoscaling_group.capstone-asg.name

}

# Autoscaling group

resource "aws_autoscaling_group" "capstone-asg" {

  name = "capstone-asg"

  desired_capacity = 2

  max_size = 5

  min_size = 1

  health_check_grace_period = 300

  health_check_type = "EC2"

  force_delete = true


  launch_template {

    id = aws_launch_template.capstone-app-lt.id

    version = "$Latest"

  }

  vpc_zone_identifier = [

    aws_subnet.team-2-pubsub-1.id,

    aws_subnet.team-2-pubsub-2.id

  ]

  target_group_arns = [aws_lb_target_group.target-group-lb-HTTP.arn, aws_lb_target_group.target-group-lb-HTTPS.arn]

}

#Creating Load balancer listener
resource "aws_lb_listener" "http_listener" {

  load_balancer_arn = aws_lb.app-lb.arn

  port = 80

  protocol = "HTTP"

  default_action {

    type = "forward"

    target_group_arn = aws_lb_target_group.target-group-lb-HTTP.arn

  }

}

#creating acm certificate for ssl

resource "aws_acm_certificate" "acm-cert" {

  domain_name = "gatsby-devops.com"

  validation_method = "DNS"

  lifecycle {

    create_before_destroy = true

  }

}

# Create a listener for HTTPS

resource "aws_lb_listener" "https_listener" {

  load_balancer_arn = aws_lb.app-lb.arn

  port = 443

  protocol = "HTTPS"

  certificate_arn = aws_acm_certificate.acm-cert.arn

  ssl_policy = "ELBSecurityPolicy-2016-08"

  default_action {

    type = "forward"

    target_group_arn = aws_lb_target_group.target-group-lb-HTTPS.arn

  }


}

#creat another target group listener for https


resource "aws_route53_record" "validate-record" {

  for_each = {

    for dvo in aws_acm_certificate.acm-cert.domain_validation_options : dvo.domain_name => {

      name = dvo.resource_record_name

      record = dvo.resource_record_value

      type = dvo.resource_record_type

    }

  }

  allow_overwrite = true

  name = each.value.name

  records = [each.value.record]

  ttl = 60

  type = each.value.type

  zone_id = data.aws_route53_zone.primary.zone_id

}

resource "aws_acm_certificate_validation" "cert-validation" {

  certificate_arn = aws_acm_certificate.acm-cert.arn

  validation_record_fqdns = [for record in aws_route53_record.validate-record : record.fqdn]

}

# creating a hosted zone

data "aws_route53_zone" "primary" {

  name = "gatsby-devops.com."

}


#creating aws_cloudfront_distribution

resource "aws_cloudfront_distribution" "cdn" {

  origin {

    domain_name = aws_s3_bucket.media-bucket.bucket_regional_domain_name #Points CloudFront to your S3 bucket endpoint

    origin_id = local.s3_origin_id

  }

  enabled = true


  # Default cache behavior configuration for serving images

  default_cache_behavior {

    allowed_methods = ["GET", "HEAD"]

    cached_methods = ["GET", "HEAD"]

    target_origin_id = local.s3_origin_id

    forwarded_values {

      query_string = false # Disable query string forwarding as images don't need them

      cookies {

        forward = "none" # No need to forward cookies for serving static images

      }

    }

    viewer_protocol_policy = "redirect-to-https" # Allow requests to HTTPS and HTTP

    min_ttl = 3600 # Minimum TTL (1 hour) for caching

    default_ttl = 86400 # Default TTL (1 day) for caching

    max_ttl = 31536000 # Maximum TTL (1 year) for caching

  }

  # Using the most cost-effective CloudFront price class

  price_class = "PriceClass_100"

  # Restrictions (no geo restrictions applied)

  restrictions {

    geo_restriction {

      restriction_type = "none"

    }

  }

  # Dependency to ensure scanning is completed before distribution

  #depends_on = [null_resource.pre_scan]

  # Tagging for identification

  tags = {

    Name = "cloudfront"

  }

  # Default CloudFront SSL certificate (you can configure a custom certificate if needed)

  viewer_certificate {

    cloudfront_default_certificate = true

  }

}

# Data block to retrieve the CloudFront distribution information

data "aws_cloudfront_distribution" "cdn" {

  id = aws_cloudfront_distribution.cdn.id

}