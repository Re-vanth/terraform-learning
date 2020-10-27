provider "aws" {
    region = "ap-south-1"
    access_key = "ACCESS_KEY!"  
    secret_key = "SECRET_KEY!!"
}




# create a vpc

resource "aws_vpc" "test-vpc1" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "aws vpc 1"
  }

}


# create an internet gateway

resource "aws_internet_gateway" "test-gw1" {
  vpc_id = aws_vpc.test-vpc1.id

  tags = {
    Name = "aws gateway 1"
  }

}

# create a custom route table 

resource "aws_route_table" "test-routetable1" {
  vpc_id = aws_vpc.test-vpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test-gw1.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.test-gw1.id
  }

  tags = {
    Name = "aws route table 1"
  }
}

# create a subnet

resource "aws_subnet" "test-subnet1"{
    vpc_id = aws_vpc.test-vpc1.id
    cidr_block = "10.0.0.0/24"
    availability_zone = var.availability_zone_aws  

    tags = {
        Name = "aws test subnet1"
    }
}

# associate a subnet with a route table

resource "aws_route_table_association" "test-routetable-association1" {
  subnet_id      = aws_subnet.test-subnet1.id
  route_table_id = aws_route_table.test-routetable1.id

  
}

# create a security group to allow port 22,80,443

resource "aws_security_group" "test-securitygroup1" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.test-vpc1.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "test security group "
  }
}

# create a network interface with an IP in the subnet that was previously created 

resource "aws_network_interface" "test-network-interface1" {
  subnet_id       = aws_subnet.test-subnet1.id
  private_ips     = ["10.0.0.21"]
  security_groups = [aws_security_group.test-securitygroup1.id]

  tags = {
      Name = "test network interface"
  }

}

# assign an elastic ip to the network interface created previously

resource "aws_eip" "test-elasticip1" {
  vpc                       = true
  network_interface         = aws_network_interface.test-network-interface1.id
  associate_with_private_ip = "10.0.0.21"
  depends_on = [
      "aws_internet_gateway.test-gw1"
      ]
}

# create ubuntu server and install/enable apache2

resource "aws_instance" "web-server-instance" {
    ami = "ami-03f0fd1a2ba530e75"
    instance_type = "t2.micro"
    availability_zone = var.availability_zone_aws 
    key_name = "revanth_aws" #NAME OF THE KEY USED TO CONNECT TO THE INSTANCE

    network_interface {

        device_index = 0    
        network_interface_id = aws_network_interface.test-network-interface1.id

    } 

    user_data = <<-EOF
                #! /bin/bash
                sudo apt update -y
                sudo apt install -y vim apache2
                sudo systemctl start apache2 
                sudo bash -c 'echo revanth terraform test 1 > /var/www/html/index.html'
                EOF 

    tags = {
        Name = "test web server"
    }
}


output "server_public_ip" {
  value = aws_eip.test-elasticip1.public_ip
}
