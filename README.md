# goodrx-hello

## Deploy

Run 'launch.sh' to deploy. *(This requires terraform to be installed and appropriate aws credentials configured.).*

Terraform will output the ELB Id and ELB Dns Name.

## App

A python app which responds to '/hello/<name>'' and returns "Hello, <name>."

A call to '/' will receive a 200 OK (for health check).

Most other calls will receive a 400 Bad Request.

## Terraform

The app is deployed using terraform.

The 'launch.sh' script will:
- Run terraform init to ensure plugins are installed
- Create a terraform plan
- Apply the plan
- Delete the plan

You can modify the target vpc and subnets by editing the variables in goodrx-hello.tf.
