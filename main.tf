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
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "key" {
  content  = tls_private_key.key.private_key_pem
  filename = "keypair"
  file_permission = "400"
}

resource "aws_key_pair" "key" {
  key_name   = "keypair"
  public_key = tls_private_key.key.public_key_openssh
}