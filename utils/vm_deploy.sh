#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONFIG_FILE="config.json"
SSH_KEY_PATH="$PWD/azure_vm_key"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."

    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install it first."
        exit 1
    fi

    if ! az account show &> /dev/null; then
        print_error "You are not logged in to Azure. Please run 'az login' first."
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Function to load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file '$CONFIG_FILE' not found."
        exit 1
    fi

    # Load all config values
    RESOURCE_GROUP_NAME=$(jq -r '.resourceGroupName' "$CONFIG_FILE")
    LOCATION=$(jq -r '.location' "$CONFIG_FILE")
    VM_NAME=$(jq -r '.vmName' "$CONFIG_FILE")
    VM_SIZE=$(jq -r '.vmSize' "$CONFIG_FILE")
    OS_DISTRIBUTION=$(jq -r '.osDistribution' "$CONFIG_FILE")
    OS_VERSION=$(jq -r '.osVersion' "$CONFIG_FILE")
    ADMIN_USERNAME=$(jq -r '.adminUsername' "$CONFIG_FILE")
    STORAGE_ACCOUNT_NAME=$(jq -r '.storageAccountName' "$CONFIG_FILE" | sed "s/\$(date +%s)/$(date +%s)/g")
    VNET_NAME=$(jq -r '.vnetName' "$CONFIG_FILE")
    SUBNET_NAME=$(jq -r '.subnetName' "$CONFIG_FILE")
    NSG_NAME=$(jq -r '.nsgName' "$CONFIG_FILE")
    SSH_KEY_NAME=$(jq -r '.sshKeyName' "$CONFIG_FILE")
    MANAGED_IDENTITY_NAME=$(jq -r '.managedIdentityName' "$CONFIG_FILE")

    # Set OS image based on distribution
    case "$OS_DISTRIBUTION" in
        "Ubuntu")
            OS_IMAGE="Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest"
            ;;
        "CentOS")
            OS_IMAGE="OpenLogic:CentOS:8_5:latest"
            ;;
        "RHEL")
            OS_IMAGE="RedHat:RHEL:8-lvm-gen1:latest"
            ;;
        *)
            print_error "Unsupported OS distribution: $OS_DISTRIBUTION"
            exit 1
            ;;
    esac

    print_success "Configuration loaded successfully"
}

# Function to generate SSH key pair
generate_ssh_key() {
    print_status "Generating SSH key pair..."

    if [[ -f "$SSH_KEY_PATH" ]]; then
        print_warning "SSH key already exists at $SSH_KEY_PATH"
        return
        #read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        #echo
        #if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        #    print_status "Using existing SSH key"
        #    return
        #fi
    fi

    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "azure-vm-key"
    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "${SSH_KEY_PATH}.pub"

    print_success "SSH key pair generated at $SSH_KEY_PATH"
}



# Function to check if resources already exist
check_existing_resources() {
    print_status "Checking for existing resources..."

    # Check if resource group exists
    if az group exists --name "$RESOURCE_GROUP_NAME" --output tsv | grep -q "true"; then
        print_warning "Resource group '$RESOURCE_GROUP_NAME' already exists"
        RG_EXISTS=true

        # Set it as default since it exists
        az configure --defaults group="$RESOURCE_GROUP_NAME"

        # Check if storage account exists
        if az storage account show --name "$STORAGE_ACCOUNT_NAME" &>/dev/null; then
            print_warning "Storage account '$STORAGE_ACCOUNT_NAME' already exists"
            STORAGE_EXISTS=true

            # Check if container exists
            CONTAINER_EXISTS=$(az storage container exists \
                --name "data" \
                --account-name "$STORAGE_ACCOUNT_NAME" \
                --auth-mode login \
                --query "exists" \
                --output tsv 2>/dev/null || echo "false")

            if [[ "$CONTAINER_EXISTS" == "true" ]]; then
                print_warning "Blob container 'data' already exists"
            fi
        else
            STORAGE_EXISTS=false
        fi


        # Check if network resources exist
        if az network vnet show --name "$VNET_NAME" &>/dev/null; then
            print_warning "Virtual network '$VNET_NAME' already exists"
            VNET_EXISTS=true
        else
            VNET_EXISTS=false
        fi


        # Check if VM exists
        if az vm show --name "$VM_NAME" &>/dev/null; then
            print_warning "VM '$VM_NAME' already exists"
            VM_EXISTS=true
        else
            VM_EXISTS=false
        fi

    else
        RG_EXISTS=false
        STORAGE_EXISTS=false
        NET_EXISTS=false
        VM_EXISTS=false
        CONTAINER_EXISTS=false
    fi
}


# Function to create resources
create_resources() {
    print_status "Starting resource creation..."

    # check if steps were run
    check_existing_resources


    if [[ ! "$RG_EXISTS" == "true" ]]; then
        # Create resource group
        print_status "Creating resource group '$RESOURCE_GROUP_NAME'..."
        az group create \
            --name "$RESOURCE_GROUP_NAME" \
            --location "$LOCATION" \
            --output none
        print_success "Resource group created"

        # Give current user full access to the resource group
        print_status "Assigning Contributor role to current user on resource group..."
        CURRENT_USER_ID=$(az ad signed-in-user show --query id --output tsv)
        az role assignment create \
            --assignee-object-id "$CURRENT_USER_ID" \
            --assignee-principal-type User \
            --role "Contributor" \
            --scope "/subscriptions/$(az account show --query id --output tsv)/resourceGroups/$RESOURCE_GROUP_NAME" \
            --output none
        print_success "Full access granted to current user"



        # set resource group as default
        az configure --defaults group="$RESOURCE_GROUP_NAME"

        # Create managed identity
        print_status "Creating managed identity..."
        az identity create \
            --name "$MANAGED_IDENTITY_NAME" \
            --output none
        print_success "Managed identity created"

        # Get managed identity details
        MANAGED_IDENTITY_ID=$(az identity show \
            --name "$MANAGED_IDENTITY_NAME" \
            --query id \
            --output tsv)

        MANAGED_IDENTITY_PRINCIPAL_ID=$(az identity show \
            --name "$MANAGED_IDENTITY_NAME" \
            --query principalId \
            --output tsv)

        print_status "Granting Contributor access to managed identity on resource group..."
        RG_SCOPE="/subscriptions/$(az account show --query id --output tsv)/resourceGroups/$RESOURCE_GROUP_NAME"

        az role assignment create \
            --assignee-object-id "$MANAGED_IDENTITY_PRINCIPAL_ID" \
            --assignee-principal-type ServicePrincipal \
            --role "Contributor" \
            --scope "$RG_SCOPE" \
            --output none
        print_success "Contributor access granted to managed identity"
    fi


    if [[ ! "$STORAGE_EXISTS" == "true" ]]; then
        # Create storage account
        print_status "Creating storage account '$STORAGE_ACCOUNT_NAME'..."
        az storage account create \
            --name "$STORAGE_ACCOUNT_NAME" \
            --location "$LOCATION" \
            --sku Standard_LRS \
            --access-tier Hot \
            --allow-blob-public-access true \
            --public-network-access Enabled \
            --default-action Allow
           # --allow-blob-public-access false \
           # --public-network-access Enabled \
           # --output none
        print_success "Storage account created"

        # Create blob container
        print_status "Creating blob container..."
        az storage container create \
            --name "data" \
            --account-name "$STORAGE_ACCOUNT_NAME" \
            --output none
        print_success "Blob container created"



        #az role assignment create \
        #    --assignee-object-id "$MANAGED_IDENTITY_PRINCIPAL_ID" \
        #    --assignee-principal-type ServicePrincipal \
        #    --role "Storage Blob Data Contributor" \
        #    --scope "$STORAGE_ACCOUNT_ID" \
        #    --output none
        #print_success "Storage permissions assigned to managed identity"

        # Wait for managed identity role assignment to propagate
        print_status "Waiting for managed identity permissions to propagate..."
        sleep 30

        # Now disable public network access to make storage private
        #print_status "Disabling public network access to storage account..."
        #az storage account update \
        #    --name "$STORAGE_ACCOUNT_NAME" \
        #    --public-network-access Disabled \
        #    --output none
        #print_success "Storage account is now private"
    fi



    if [[ ! "$VNET_EXISTS" == "true" ]]; then
        # Create virtual network
        print_status "Creating virtual network..."
        az network vnet create \
            --name "$VNET_NAME" \
            --address-prefix 10.0.0.0/16 \
            --subnet-name "$SUBNET_NAME" \
            --subnet-prefix 10.0.1.0/24 \
            --output none
        print_success "Virtual network created"

        # Create network security group
        print_status "Creating network security group..."
        az network nsg create \
            --name "$NSG_NAME" \
            --output none

        # Create SSH rule
        az network nsg rule create \
            --nsg-name "$NSG_NAME" \
            --name "SSH" \
            --protocol tcp \
            --priority 1001 \
            --destination-port-range 22 \
            --access allow \
            --output none
        print_success "Network security group created"

        # Associate NSG with subnet
        az network vnet subnet update \
            --vnet-name "$VNET_NAME" \
            --name "$SUBNET_NAME" \
            --network-security-group "$NSG_NAME" \
            --output none

        # Create public IP
        print_status "Creating public IP..."
        az network public-ip create \
            --name "${VM_NAME}-pip" \
            --allocation-method Static \
            --sku Standard \
            --output none
        print_success "Public IP created"
    fi




    #if [[ ! "$VM_EXISTS" == "true" ]]; then
        # Create VM
        print_status "Creating virtual machine '$VM_NAME'..."
        az vm create \
            --name "$VM_NAME" \
            --image "$OS_IMAGE" \
            --size "$VM_SIZE" \
            --admin-username "$ADMIN_USERNAME" \
            --ssh-key-values "${SSH_KEY_PATH}.pub" \
            --vnet-name "$VNET_NAME" \
            --subnet "$SUBNET_NAME" \
            --nsg "$NSG_NAME" \
            --public-ip-address "${VM_NAME}-pip" \
            --assign-identity $MANAGED_IDENTITY_NAME \
            --output none
        print_success "Virtual machine created"

        az network vnet subnet update \
            --vnet-name "$VNET_NAME" \
            --name  "$SUBNET_NAME" \
            --service-endpoints Microsoft.Storage

        az storage account network-rule add \
            --account-name "$STORAGE_ACCOUNT_NAME" \
            --vnet-name "$VNET_NAME" \
            --subnet "$SUBNET_NAME"

    #fi

        # Get public IP address (already retrieved above)
        # PUBLIC_IP already set
        PUBLIC_IP=$(az network public-ip show \
            --name "${VM_NAME}-pip" \
            --query ipAddress \
            --output tsv 2>/dev/null)

        #az storage account network-rule add \
        #    --account-name $STORAGE_ACCOUNT_NAME \
        #    --ip-address "$PUBLIC_IP" \
        #    --output none



        print_success "Deployment completed successfully!"
        echo
        echo "=== Connection Information ==="
        echo "SSH Command: ssh -i $SSH_KEY_PATH $ADMIN_USERNAME@$PUBLIC_IP"
        echo "Public IP: $PUBLIC_IP"
        echo "Private Key: $SSH_KEY_PATH"
        echo "Public Key: ${SSH_KEY_PATH}.pub"
        echo "Storage Account: $STORAGE_ACCOUNT_NAME"
        echo "Blob Container: data"
        echo
}

# Function to delete resources
delete_resources() {
    print_warning "This will delete the entire resource group '$RESOURCE_GROUP_NAME' and all its resources."
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deletion cancelled"
        return
    fi

    print_status "Deleting resource group '$RESOURCE_GROUP_NAME'..."
    az group delete \
        --name "$RESOURCE_GROUP_NAME" \
        --yes \
        --no-wait

    print_success "Resource group deletion initiated (running in background)"
    print_status "You can check the progress with: az group show --name $RESOURCE_GROUP_NAME"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 {create|delete}"
    echo "  create  - Create all Azure resources"
    echo "  delete  - Delete the resource group and all resources"
}

# Main script logic
main() {
    case "$1" in
        "create")
            check_prerequisites
            load_config
            generate_ssh_key
            create_resources
            ;;
        "delete")
            load_config
            delete_resources
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
