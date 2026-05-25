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

#CREATING RDS
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

