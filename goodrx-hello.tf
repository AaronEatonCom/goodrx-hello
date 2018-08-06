# Deploy Environment can be changed via these variables.
variable "region" {
  default = "us-west-2"
}

variable "vpc_id" {
  default = "vpc-989558e1"
}

variable "subnet_ids" {
  default = ["subnet-11b69b59","subnet-94212cf2","subnet-e0bf46ba"]
}

provider "aws" {
  region     = "${var.region}"
}

# Our "Codebase" is small enough that we can load it using cloud-config.
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

# Instance Security Group
resource "aws_security_group" "goodrx-hello-instance-sg" {
  name        = "goodrx-hello-instance-sg"
  description = "Allow SSH to World, port 80 to ELB."
  vpc_id      = "${var.vpc_id}"

  # Uncomment to allow SSH access to the instance.
  # ingress {
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

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

# ELB Security Group
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

# AWS Instance Definition.
resource "aws_instance" "goodrx-hello-instance" {
  ami                         = "ami-f2d3638a"
  instance_type               = "t2.nano"
  key_name                    = "${aws_key_pair.goodrx-hello-keypair.key_name}"
  subnet_id                   = "${var.subnet_ids[0]}"
  user_data_base64            = "${data.template_cloudinit_config.config.rendered}"
  vpc_security_group_ids      = ["${aws_security_group.goodrx-hello-instance-sg.id}"]
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

output "ELB ID" {
  value = "${aws_elb.goodrx-hello-elb.id}"
}


output "ELB DNS Name" {
  value = "${aws_elb.goodrx-hello-elb.dns_name}"
}
