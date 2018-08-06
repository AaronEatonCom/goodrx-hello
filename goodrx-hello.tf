# Deploy Environment can be changed via these variables.
variable "region" {
  default = "us-west-2"
}

variable "vpc_id" {
  default = "vpc-d6936dae"
}

variable "subnet_ids" {
  default = ["subnet-13eda66a","subnet-1deecb47","subnet-2446326f"]
}

provider "aws" {
  region     = "${var.region}"
}

# Template Data for cloud-config of code
# Because our codebase consists of one file and three config files, we 
# can fit it into the user_data for the ec2 instance using a template.

# data "template_file" "user_data" {
#   template = "${file("./user-data.tpl")}"

#   vars {
#     bundle_file = "${file("./bundle.tar.gz")}"
#   }
# }

data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = <<EOF
#cloud-config
repo_update: true
repo_upgrade: all

packages:
- nginx

write_files:
- content: |-
    ${base64encode(file("./conf/nginx.conf"))}
  encoding: b64
  path: /tmp/goodrx-hello/nginx.conf
  permissions: '0644'
- content: |-
    ${base64encode(file("./conf/nginx-vhost.conf"))}
  encoding: b64
  path: /tmp/goodrx-hello/vhost.conf
  permissions: '0644'
- content: |-
    ${base64encode(file("./app/goodrx-hello.py"))}
  encoding: b64
  path: /tmp/goodrx-hello/goodrx-hello.py
  permissions: '0644'
- content: |-
    ${base64encode(file("./app/requirements.txt"))}
  encoding: b64
  path: /tmp/goodrx-hello/requirements.txt
  permissions: '0644'

EOF
  }

  part {
    filename     = "goodrx-hello.conf"
    content_type = "text/upstart-job"
    content      = "${file("./conf/upstart.conf")}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${file("${path.module}/conf/deploy.sh")}"
  }

}

# Private key access not handled in repo, for obvious reasons.
resource "aws_key_pair" "goodrx-hello-keypair" {
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCdZP+Ge/i7mQM+U8s3QI9F7j1Ruilvyzv9+jN5isgkfwgxnKilK8C2xm3xDfi4niGYC2dPbQlZiAiIxSBbcjrw2JN85L05rIQy9ynr13zqul8kNZ/xwIQkpj4O7CA45Dy0PgcJxF/F5JqzwB8w4Es+BDgunzuxi7uS1yrfDUZqaDEK9EGFlDR8WgnlZhTXiMGVLspe0rYOQ92UPTcR4KaZ+uR0B7F8Zyml6rwwkIwPAVn7XdqluczmmnVULrEa5Gntf/n5zGGoMau7WnSylFp++xDqIXSkA4Nbi1aCPNxyujHcL4M3eW2NvInPwjFDM/+RZ0zhTcCJ2w9LNb3NZarDRl9OLNrgx5POb8g48Iy1rQ0ebwe5CkvW3zFbUtWGsruxwNGTewiJcSTCClKoRZlzeBM9SAVYcTUnbt9i7FYgtm14Vs4IZqQdUb3Rg68IWzmlQQrIgim7/GtjQHuYbAA1vt/aXz4D2wS5E89Lz4uGci6VHj5ZLgsGAVx1bgZyEnGnO/55rDci7wK/CwJWDop3YroM6rljsz790vwtu6WrTxBJfSLxzeO3awtca6AO3RQSp91Ig4bk09TfWuXLw31ftrCh+Bn+3vvXnwFgGwdLGGvElZUczfIvrbUaxAXdXW5kTS3SjpRglyLNyfKMIR1nfGfSVcfO8PytqJhlpmrYQQ== your_email@example.com"

}

# AWS Security Group Definitions. 

/* Instance Security Group
Although the instructions say to lock the instance to the elb, I found the need to open port 22
to use the terraform file provisioners and the remote-exec.
Assuming another form of provisioning (chef,puppet) was available, or a bastion, this port could be closed.
Alternatively, app and config files could be synced to s3 and the deploy script run from the ec2 userdata.
*/
resource "aws_security_group" "goodrx-hello-instance-sg" {
  name        = "goodrx-hello-instance-sg"
  description = "Allow SSH to World, port 80 to ELB."
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${aws_security_group.goodrx-hello-elb-sg.id}"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Name = "goodrx-hello-instance-sg"
  }

}

resource "aws_security_group" "goodrx-hello-elb-sg" {
  name        = "goodrx-hello-elb-sg"
  description = "Port 80 open to the World."
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "goodrx-hello-elb-sg"
  }

}

/* AWS Instance Definition.
Public IP Address Association is enabled to allow Terraform provisioning.
  If this is not desirable, the deploy script can be modified to pull code from github (not ideal),
  s3 (also not ideal but can be updated from local git repos if github is down),
  deployed as a custom package from a local repo,
  or rsynced directly from an available fileserver.

*/
resource "aws_instance" "goodrx-hello-instance" {
  ami                         = "ami-f2d3638a"
  associate_public_ip_address = true
  instance_type               = "t2.nano"
  key_name                    = "${aws_key_pair.goodrx-hello-keypair.key_name}"
  subnet_id                   = "${var.subnet_ids[0]}"
  user_data_base64            = "${data.template_cloudinit_config.config.rendered}"
  vpc_security_group_ids      = ["${aws_security_group.goodrx-hello-instance-sg.id}"]
  # provisioner "remote-exec" {
  #   inline = [
  #     "mkdir -p /home/ec2-user/{goodrx-hello,deploy}",
  #   ]

  #   connection {
  #     type     = "ssh"
  #     user     = "ec2-user"
  #   }

  # }

  # provisioner "file" {
  #   source      = "app/"
  #   destination = "/home/ec2-user/goodrx-hello/"

  #   connection {
  #     type     = "ssh"
  #     user     = "ec2-user"
  #   }

  # }

  # provisioner "file" {
  #   source      = "conf/"
  #   destination = "/home/ec2-user/deploy"

  #   connection {
  #     type     = "ssh"
  #     user     = "ec2-user"
  #   }

  # }

  # provisioner "remote-exec" {
  #   inline = [
  #     "sudo chmod +x /home/ec2-user/deploy/deploy.sh",
  #     "sudo /home/ec2-user/deploy/deploy.sh",
  #   ]

  #   connection {
  #     type     = "ssh"
  #     user     = "ec2-user"
  #   }
  # }

}

resource "aws_elb" "goodrx-hello-elb" {
  subnets            = "${var.subnet_ids}"
  security_groups    = ["${aws_security_group.goodrx-hello-elb-sg.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  instances                   = ["${aws_instance.goodrx-hello-instance.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

}

output "user-data-base64" {
  value = "${data.template_cloudinit_config.config.rendered}"
}


