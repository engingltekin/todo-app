terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "aws_access" {
  name = "awsrole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess", "arn:aws:iam::aws:policy/AmazonEC2FullAccess", "arn:aws:iam::aws:policy/IAMFullAccess"]

}

resource "aws_iam_instance_profile" "ec2-profile" {
  name = "jenkins-project-profile"
  role = aws_iam_role.aws_access.name
}

resource "aws_instance" "tf-jenkins-server" {
  ami = var.myami
  instance_type = var.instancetype
  key_name      = var.mykey
  vpc_security_group_ids = [aws_security_group.tf-jenkins-sec-gr.id]
  iam_instance_profile = aws_iam_instance_profile.ec2-profile.name
  tags = {
    Name = var.tag
  }
  user_data = file("jenkins.sh")

}

resource "aws_security_group" "tf-jenkins-sec-gr" {
  name = var.jenkins-sg
  tags = {
    Name = var.jenkins-sg
  }
  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    protocol    = "tcp"
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "null_resource" "config" {
  depends_on = [aws_instance.tf-jenkins-server]
  connection {
    host = aws_instance.tf-jenkins-server.public_ip
    type = "ssh"
    user = "ec2-user"
    private_key = file("~/.ssh/Engin_Linux.pem")
  }

  provisioner "file" {
    source = "./ansible.cfg"
    destination = "/home/ec2-user/ansible.cfg"
  }

  provisioner "file" {
    source = "./inventory_aws_ec2.yml"
    destination = "/home/ec2-user/inventory_aws_ec2.yml"
  }

  provisioner "file" {
    source = "~/.ssh/Engin_Linux.pem"
    destination = "/home/ec2-user/Engin_Linux.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname Ansible_control",
      "sudo yum install -y python3",
      "pip3 install --user ansible",
      "pip3 install --user boto3",
      "chmod 400 Engin_Linux.pem"
    ]
  }

}

output "jenkins-server" {
  value = "http://${aws_instance.tf-jenkins-server.public_dns}:8080"
}