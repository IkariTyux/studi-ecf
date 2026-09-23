#!/bin/bash

source .env

# Variables
REGION="northeurope"
RG="mmotors"
## Ressources
STORAGE="${RG}store"
REGISTERY="${RG}acr"
ID="${RG}id"
CT_ENV="${RG}ctenv"
VNET="${RG}vnet"
### Objects
FRONT_SC="$RG-frontend-sc"
BACK_SC="$RG-backend-sc"
CT="$RG-ct"
DB="$RG-db"
VM="$RG-vm"
SUBNET="$RG-prod-subnet"
SUBNET_ADDR="10.10.1.0/24"


# Env. preparation
az group create -n "$RG" -l "$REGION"
az storage account create -n "$STORAGE" -g "$RG" -l "$REGION" --allow-blob-public-access true --sku Standard_LRS
az acr create -n "$REGISTRY" -g "$RG" -l "$REGION"
az identity create -n "$ID" -g "$RG"
az containerapp env create -n "$CT_ENV" -g "$RG" -l "$REGION"
az acr build -t "$RG-img:v2" ~/code/move2cloud
az network vnet create -n "$VNET" -g "$RG" --address-prefix "10.10.0.0/16" 
az network vnet subnet create -n "$SUBNET" -g "$RG" --address-prefix "$SUBNET_ADDR" --delegations "Microsoft.DBforPostgreSQL/flexibleServers"
az network private-dns zone create -n "$RG.private.postgres.database.azure.com" -g "$RG"

# Objects creation
## Storage Containers
az storage container create -n "$FRONT_SC" -g "$RG" --account-name "$STORAGE" --public-access container -o table
az storage share-rm create -n "$BACK_SC" -g "$RG" --account-name "$STORAGE" -o table

## App Container
az containerapp create \
  -n "$CT" \
  -g "$RG" \
  --environment "$CT_ENV" \
  --image "$REGISTRY.azurecr.io/test-img:v4" \
  --target-port 80 \
  --ingress external \
  --registry-server "$REGISTRY.azurecr.io" \
  --user-assigned "$ID" \

az containerapp env storage set \
  -n "$CT_ENV" \
  -g "$RG" \
  --storage-name "$BACK_SC" \
  --azure-file-account-name "$STORAGE" \
  --azure-file-account-key "$STOREAGE_AccountKey" \
  --azure-file-share-name data \
  --access-mode ReadWrite

cat < EOF > ct-update.yml
properties:
  template:
    volumes:
      - name: data
        storageType: AzureFile
        storageName: $BACK_SC

    containers:
      - name: test-ct
        image: $REGISTRY.azurecr.io/test-img:v4
        volumeMounts:
          - volumeName: data
            mountPath: /var/www/backend/data
EOF

az containerapp update \
  -n "$CT"  \
  -g "$RG"  \
  --yaml ct-update.yml

## Database
az postgres flexible-server create \
  --resource-group "$RG" \
  --name "$DB" \
  --location "$REGION" \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --storage-size 32 \
  --vnet "$VNET" \
  --subnet "$SUBNET"
  --private-dns-zone "$DNS_ZONE"
  --admin-user "$DBUser" \
  --admin-password "$DBPassword" \

## VM
az vm create \
    -n "$VM"
    -g "$RG"
    --image debian-13 \
    --size Standard_DC1_v3
    --public-ip-sku Standard \
    --vnet "$VNET" \
    --subnet "$SUBNET"
