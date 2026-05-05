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