# Overview

This is a template for management station hosted on aws cloud. Management station used to manage environment by envronment management project [pip-templates-env-master](https://github.com/pip-templates/pip-templates-env-master). 

# Usage

- Download this repository
- Copy *config.example.json* and create own config file
- Set the required values in own config file
- Run root scripts (*create_mgmt.ps1*/*destroy_mgmt.ps1*)

# Config parameters

Config variables description

| Variable | Default value | Description |
|----|----|---|
| aws_access_id | XXX | AWS id for access resources |
| aws_access_key | XXX | AWS key for access resources |
| aws_region | us-east-1 | AWS region where resources will be created |
| env_name | pip-templates-stage | Name of environment |
| vpc | vpc-bb755cc1 | Amazon Virtual Private Cloud name where resources will be created |
| mgmt_subnet_cidr | 172.31.100.0/28 | MGMT station subnet address pool |
| mgmt_subnet_zone | us-east-1a | MGMT station subnet zone |
| mgmt_ssh_allowed_cidr_blocks | [109.254.10.81/32, 46.219.209.174/32] | MGMT station address pool allowed to SSH |
| mgmt_instance_type | t2.medium | MGMT station vm type |
| mgmt_instance_keypair_new | true | Switch for creation new ssh key. If set to *true* - then key pair will be added to AWS |
| mgmt_instance_keypair_name | ecommerce | MGMT station vm keypair |
| mgmt_instance_username | ubuntu | MGMT station vm username |
| mgmt_instance_ami | ami-43a15f3e | MGMT station vm aws image |
