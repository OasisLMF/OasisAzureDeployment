# Install standalone VM for testing OasisLMF MDK in an azure environment 

Intended as debugging script to quickly spin up a single VM with attached BlobStorage


## Files Created:

1. **`config.json`** - Configuration file with all settings
2. **`vm_deploy.sh`** - Main deployment script

## Key Features:

**Configuration Management:**
- All settings in a single JSON file
- Default Ubuntu 22.04 LTS
- VM size set to Standard_D16s_v5 (16 vCPUs, 64GB RAM)
- Configurable resource group name to avoid collisions
- Storage account name includes timestamp to ensure uniqueness

**Security Setup:**
- SSH key pair generated locally in `~/.ssh/azure_vm_key`
- Storage account is private (no public access)
- VM uses managed identity to access storage (no connection strings needed)
- Network Security Group with SSH access from internet

**Two Commands:**
- `./deploy.sh create` - Creates everything
- `./deploy.sh delete` - Deletes the entire resource group

## To use this:

1. **Make the script executable:**
   ```bash
   chmod +x deploy.sh
   ```

2. **Install prerequisites:**
   ```bash
   # Azure CLI and jq are required
   az login
   ```

3. **Customize config.json** (optional - defaults work fine)

4. **Deploy:**
   ```bash
   ./deploy.sh create
   ```

5. **Connect to your VM:**
   ```bash
   ssh -i ~/.ssh/azure_vm_key azureuser@<public-ip>
   ```

6. **Clean up when done:**
   ```bash
   ./deploy.sh delete
   ```

The script includes error handling, colored output, and will show you the SSH connection command when deployment completes. The VM will be able to access the blob storage using its managed identity without any additional configuration.

Would you like me to modify anything or add additional features?



test bucket access 

# Login using managed identity
az login --identity

# Now use Azure CLI normally
az storage blob list \
    --container-name data \
    --account-name mystorageacctoasis \
    --auth-mode login
