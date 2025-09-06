#!/bin/bash

# variables
RESOURCE_GROUP="task-manager-rg"
LOCATION="eastus"
ACR_NAME="tm44acr"
ACR_SKU="Basic"
FRONTEND_IMAGE_NAME="tm44frontend"
BACKEND_IMAGE_NAME="tm44backend"
DB_IMAGE_NAME="tm44db"
REDIS_IMAGE_NAME="tm44redis"
ACR_LOGIN_SERVER="$ACR_NAME.azurecr.io"

# Check if resource group exists, if not create it
if ! az group show --name $RESOURCE_GROUP &> /dev/null; then
    echo "Creating resource group: $RESOURCE_GROUP"
    az group create --name $RESOURCE_GROUP --location $LOCATION
else
    echo "Resource group $RESOURCE_GROUP already exists"
fi

# Check if ACR exists, if not create it
if ! az acr show --name $ACR_NAME &> /dev/null; then
    echo "Creating Azure Container Registry: $ACR_NAME"
    az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku $ACR_SKU --admin-enabled true
else
    echo "Azure Container Registry $ACR_NAME already exists"
fi

# Login to ACR
echo "Logging into Azure Container Registry: $ACR_NAME"
az acr login --name $ACR_NAME 

# Build and push Docker images to ACR
echo "Building and pushing Docker images to ACR"
docker buildx build --platform linux/amd64 -t $ACR_LOGIN_SERVER/$FRONTEND_IMAGE_NAME:latest -f ./frontend/Dockerfile ./frontend --push
docker buildx build --platform linux/amd64 -t $ACR_LOGIN_SERVER/$BACKEND_IMAGE_NAME:latest -f ./backend/Dockerfile ./backend --push
docker pull postgres:13-alpine --platform linux/amd64
docker tag postgres:13-alpine $ACR_LOGIN_SERVER/$DB_IMAGE_NAME:latest
docker push $ACR_LOGIN_SERVER/$DB_IMAGE_NAME:latest
docker pull redis:6-alpine --platform linux/amd64
docker tag redis:6-alpine $ACR_LOGIN_SERVER/$REDIS_IMAGE_NAME:latest
docker push $ACR_LOGIN_SERVER/$REDIS_IMAGE_NAME:latest

# If container instance exists, delete it
if az container show --name taskmanager-app --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo "Deleting existing container instance: taskmanager-app"
    az container delete --name taskmanager-app --resource-group $RESOURCE_GROUP --yes
    sleep 30
fi

# Generating group-deploy.yml 
echo "Generating group-deploy.yml" 

cat <<EOF > group-deploy.yml
apiVersion: '2019-12-01'
location: $LOCATION
name: taskmanager-app
properties:
  containers:
  - name: frontend
    properties:
      image: $ACR_LOGIN_SERVER/$FRONTEND_IMAGE_NAME:latest
      resources:
        requests:
          cpu: 0.5
          memoryInGb: 1.0
      ports:
      - port: 80
  - name: backend
    properties:
      image: $ACR_LOGIN_SERVER/$BACKEND_IMAGE_NAME:latest
      resources:
        requests:
          cpu: 0.5
          memoryInGb: 1.0
      environmentVariables:
      - name: DATABASE_URL
        value: postgres://taskmanager:password@localhost:5432/taskmanager
      - name: REDIS_URL
        value: redis://localhost:6379
      ports:
      - port: 5000
  - name: db
    properties:
      image: $ACR_LOGIN_SERVER/$DB_IMAGE_NAME:latest
      resources:
        requests:
          cpu: 0.5
          memoryInGb: 1.0
      environmentVariables:
      - name: POSTGRES_DB
        value: taskmanager
      - name: POSTGRES_USER
        value: taskmanager
      - name: POSTGRES_PASSWORD
        value: password
      ports:
      - port: 5432
  - name: redis
    properties:
      image: $ACR_LOGIN_SERVER/$REDIS_IMAGE_NAME:latest
      resources:
        requests:
          cpu: 0.5
          memoryInGb: 1.0
      ports:
      - port: 6379
  osType: Linux
  ipAddress:
    type: Public
    ports: 
    - protocol: tcp
      port: 80
    - protocol: tcp
      port: 5000
  imageRegistryCredentials:
  - server: $ACR_LOGIN_SERVER
    username: $(az acr credential show --name $ACR_NAME --query "username" -o tsv)
    password: $(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)
 
EOF

# Deploy container instance
echo "Deploying container instance: taskmanager-app"
az container create --resource-group $RESOURCE_GROUP --file group-deploy.yml
echo "Deployment complete. You can check the status with: az container show --name taskmanager-app --resource-group $RESOURCE_GROUP"
echo "Fetching the public IP address of the container instance..."
PUBLIC_IP=""
while [ -z "$PUBLIC_IP" ]; do
    PUBLIC_IP=$(az container show --name taskmanager-app --resource-group $RESOURCE_GROUP --query ipAddress.ip --output tsv)
    if [ -z "$PUBLIC_IP" ]; then
        echo "Waiting for public IP address..."
        sleep 10
    fi
done
echo "Public IP address: $PUBLIC_IP"
echo "You can access the application at http://$PUBLIC_IP"