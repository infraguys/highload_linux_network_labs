## IaC labs for Workshop

```mermaid

flowchart LR

B(one public_ip)
B --> C{"Gateway (DC Router)"}
C -->|SSH port 20001->22| D[instance_0]
C -->|SSH port 20002->22| E[instance_1]
```

### Run fleet of labs:

```bash
terraform init

# copy VARS.example and fill it
. VARS

terraform apply
```

### Parameters

See in `variables.tf`

### Get data for workshop

```
# port:password table of labs
terraform output -json | jq .instance_listing.value

# public ip
terraform output -raw public_ip

```
