#!/bin/bash

terraform init

terraform plan -out plan
terraform apply plan

rm -rf plan

