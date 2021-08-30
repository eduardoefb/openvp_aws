provider "aws"{
   region = "sa-east-1"
   shared_credentials_file = "/home/eduabati/.aws/credentials"
   profile = "default"
}

data "aws_ami" "latest_images" {
  owners = ["099720109477"]
  most_recent = true
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20210430"]
  }
}

resource "aws_instance" "ec2instance"{   
   ami = data.aws_ami.latest_images.id
   instance_type = "t2.micro"
   key_name = aws_key_pair.my-key.key_name
   security_groups = [ aws_security_group.allow_ssh.name ]

   provisioner "local-exec" {
      command =  "echo \"[openvpn]\" > hosts"
   }
   provisioner "local-exec" {
      command =  "echo \"\n${aws_instance.ec2instance.public_dns}\" >> hosts&"
   }


}

resource "aws_key_pair" "my-key" {
   key_name = "my-key01"
   public_key = file("id_rsa.pub")
}

resource "aws_security_group" "allow_ssh"{
   name = "allow_ssh"   
   ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
   }
   
   ingress {
      from_port = 8000
      to_port = 8000
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
   }
      
   egress {
      from_port = 0
      to_port = 0
      protocol = -1
      cidr_blocks = ["0.0.0.0/0"]
   }
}

#data "aws_route53_zone" zone1{
#   name = "foo.click"
#}

#resource "aws_route53_record" "ec2instance" {  
#  zone_id = data.aws_route53_zone.zone1.zone_id
#  name    = "ec2instance"
#  type    = "A"
#  ttl     = "300"
#  records = [aws_instance.ec2instance.public_ip]
#}

  ##Create Masters Inventory

output "vpn_public_dns"{
   value = "${aws_instance.ec2instance.public_dns}"
}   