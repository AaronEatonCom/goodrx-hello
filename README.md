# goodrx-hello

## Deploy

Run 'launch.sh' to deploy the app. (This requires terraform to be installed and the private key to be added to your ssh-agent).

## App

A python app which responds to '/hello/<name>'' and returns "Hello, <name>."

A call to '/' will receive a 200 OK (for health check).

Most other calls will receive a 400 Bad Request.

## Terraform

The app is deployed to aws using terraform. The 'launch.sh' script will install the necessary plugin (aws, template), create a plan, then apply the plan to your environment.

You can modify the target vpc and subnets for the deployment by editing the variables in goodrx-hello.tf.
