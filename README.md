# Overview

This is a template for management station hosted on aws cloud. Management station used to manage environment by envronment management project [pip-templates-env-master](https://github.com/pip-templates/pip-templates-env-master). 

# Usage

- Download this repository
- Add content of *config/config.mgmt.json.add* to json config file from master template and set the required values
- Copy *mangement-station* folder to master template
- Run root scripts (*create_hw.ps1*/*delete_hw.ps1*)

# Config parameters

Config variables description

| Variable | Default value | Description |
|----|----|---|
| environment.type | onprem | Type of the environment |
| environment.name | pip-onprem-demo | Name of the environment. Will be used for resources names |
| environment.version | 1.0.0 | Version of the environment |
| hw.cloud | aws | Type of cloud |
| copy_project_to_mgmt_station | true | Indicate is required to copy project folder to mgmt station |
| hw.aws.access_id | XXX | AWS id for access resources |
| hw.aws.access_key | XXX | AWS key for access resources |
| hw.aws.region | us-east-1 | AWS region where resources will be created |
| hw.aws.vpc | vpc-bb755cc1 | Amazon Virtual Private Cloud name where resources will be created |
| hw.mgmt.subnet_cidr | 172.31.100.0/28 | MGMT station subnet address pool |
| hw.mgmt.subnet_zone | us-east-1a | MGMT station subnet zone |
| hw.mgmt.allowed_cidr_blocks | [109.254.10.81/32, 46.219.209.174/32] | MGMT station address pool allowed to SSH |
| hw.mgmt.type | t2.medium | MGMT station vm type |
| hw.mgmt.keypair_new | true | Switch for creation new ssh key. If set to *true* - then key pair will be added to AWS |
| hw.mgmt.keypair_name | ecommerce | MGMT station vm keypair |
| hw.mgmt.username | ubuntu | MGMT station vm username |
| hw.mgmt.ami | ami-43a15f3e | MGMT station vm aws image |
