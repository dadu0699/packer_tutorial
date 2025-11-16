#!/usr/bin/env pwsh
<#
 Script: Automated AWS EC2 Deployment

 This script executes the entire continuous deployment process for the Node.js
 application built with Packer.

 Process steps:
 1. Execute 'packer build' to generate the Amazon Machine Image (AMI).
 2. Read the AMI ID from the generated manifest file.
 3. Ensure necessary AWS infrastructure (Key Pair and Security Group) exists.
 4. Launch a new EC2 instance based on the golden AMI.
 5. Wait for the instance to be running and display the public URL.

 Prerequisites:
 - PowerShell 5+ or PowerShell 7.
 - AWS CLI installed and configured (aws configure).
 - Packer installed and available in the PATH.
#>

# ==== CONFIGURATION VARIABLES ====
$AwsRegion = "us-east-1"         # Target AWS region
$InstanceType = "t2.micro"          # Instance size for deployment
$KeyName = "devops-node-key"   # Key Pair name for SSH access
$SecurityGroupName = "devops-node-sg"    # Security Group name
$InstanceTagName = "node-nginx-packer" # Name tag for the deployed EC2 instance
$PackerTemplatePath = "ubuntu.pkr.hcl"    # Path to the Packer template
$ManifestPath = "packer-manifest.json"# Path to the manifest created by Packer

# Set PowerShell to stop execution immediately upon any error (best practice)
$ErrorActionPreference = "Stop"

Write-Host "[Deploy] AWS Region: $AwsRegion"
Write-Host "[Deploy] Packer Template: $PackerTemplatePath"
Write-Host ""

# ==== 1. BUILD AMI WITH PACKER ====
Write-Host "[Deploy] Executing 'packer build' to create AMI..."
# The provisioner script handles all application setup inside the image.
& packer build -var "aws_region=$AwsRegion" $PackerTemplatePath

Write-Host "[Deploy] Reading Packer manifest file: $ManifestPath"
if (-not (Test-Path $ManifestPath)) {
    Write-Error "Manifest file not found. Did 'packer build' succeed?"
    exit 1
}

# Read the manifest and extract the latest AMI ID
$manifestJson = Get-Content $ManifestPath -Raw
$manifest = $manifestJson | ConvertFrom-Json

# Get the latest artifact ID (e.g., "us-east-1:ami-0123...")
$artifactId = $manifest.builds[-1].artifact_id
$amiId = $artifactId.Split(':')[1] # Extract the AMI ID part

if ([string]::IsNullOrWhiteSpace($amiId)) {
    Write-Error "Could not retrieve AMI ID from the manifest."
    exit 1
}

Write-Host "[Deploy] Successfully retrieved AMI ID: $amiId"
Write-Host ""

# ==== 2. KEY PAIR SETUP ====
Write-Host "[Deploy] Verifying Key Pair '$KeyName'..."

# Attempt to retrieve the Key Pair
$KeyExists = $null
try {
    $KeyExists = aws ec2 describe-key-pairs `
        --key-names $KeyName `
        --region $AwsRegion `
        --query "KeyPairs[0].KeyName" `
        --output text 2>$null
}
catch {
    $KeyExists = $null
}

if ([string]::IsNullOrWhiteSpace($KeyExists) -or $KeyExists -eq "None") {
    Write-Host "[Deploy] Key Pair '$KeyName' not found. Creating a new one..."
    $pemFile = "$KeyName.pem"

    # Create the Key Pair and save the private key locally
    aws ec2 create-key-pair `
        --key-name $KeyName `
        --region $AwsRegion `
        --query "KeyMaterial" `
        --output text | Out-File -FilePath $pemFile -Encoding ASCII

    # Permisos seguros al .pem
    icacls $pemFile /inheritance:r | Out-Null
    icacls $pemFile /grant:r "$($env:USERNAME):(R)" | Out-Null

    Write-Host "[Deploy] Key Pair created and saved to $pemFile."
}
else {
    Write-Host "[Deploy] Key Pair '$KeyName' already exists. Reusing it."
}
Write-Host ""

# ==== 3. SECURITY GROUP SETUP ====
Write-Host "[Deploy] Verifying Security Group '$SecurityGroupName'..."

# Attempt to retrieve the Security Group ID
$sgId = $null
try {
    $sgId = aws ec2 describe-security-groups `
        --group-names $SecurityGroupName `
        --region $AwsRegion `
        --query "SecurityGroups[0].GroupId" `
        --output text 2>$null
}
catch {
    $sgId = $null
}

if ([string]::IsNullOrWhiteSpace($sgId) -or $sgId -eq "None") {
    Write-Host "[Deploy] Security Group does not exist. Creating '$SecurityGroupName'..."

    # Create the Security Group
    $sgId = aws ec2 create-security-group `
        --group-name $SecurityGroupName `
        --description "SG for Node+Nginx Packer instance" `
        --region $AwsRegion `
        --query "GroupId" `
        --output text

    Write-Host "[Deploy] Security Group created with ID: $sgId"

    # Authorize SSH ingress (port 22) from everywhere
    Write-Host "[Deploy] Authorizing port 22 (SSH) ingress..."
    aws ec2 authorize-security-group-ingress `
        --group-id $sgId `
        --protocol tcp `
        --port 22 `
        --cidr 0.0.0.0/0 `
        --region $AwsRegion | Out-Null

    # Authorize HTTP ingress (port 80) from everywhere
    Write-Host "[Deploy] Authorizing port 80 (HTTP) ingress..."
    aws ec2 authorize-security-group-ingress `
        --group-id $sgId `
        --protocol tcp `
        --port 80 `
        --cidr 0.0.0.0/0 `
        --region $AwsRegion | Out-Null
}
else {
    Write-Host "[Deploy] Security Group '$SecurityGroupName' already exists. Reusing ID: $sgId"
}
Write-Host ""

# ==== 4. LAUNCH EC2 INSTANCE ====
Write-Host "[Deploy] Launching EC2 instance using AMI $amiId..."

# Launch the instance with required parameters (Key Pair, SG, Image ID)
# The application starts automatically because the service is enabled in the AMI.
$instanceId = aws ec2 run-instances `
    --region $AwsRegion `
    --image-id $amiId `
    --instance-type $InstanceType `
    --key-name $KeyName `
    --security-group-ids $sgId `
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$InstanceTagName}]" `
    --query "Instances[0].InstanceId" `
    --output text

Write-Host "[Deploy] Instance successfully created with ID: $instanceId"
Write-Host "[Deploy] Waiting for the instance to reach 'running' state..."

# Wait for the instance to be ready before trying to get its IP
aws ec2 wait instance-running `
    --region $AwsRegion `
    --instance-ids $instanceId

Write-Host "[Deploy] Instance is now 'running'. Retrieving Public IP Address..."

$publicIp = aws ec2 describe-instances `
    --region $AwsRegion `
    --instance-ids $instanceId `
    --query "Reservations[0].Instances[0].PublicIpAddress" `
    --output text

Write-Host ""
Write-Host "======================================================================="
Write-Host "   AUTOMATED DEPLOYMENT COMPLETE"
Write-Host "-----------------------------------------------------------------------"
Write-Host " INSTANCE ID : $instanceId"
Write-Host " PUBLIC IP   : $publicIp"
Write-Host " APPLICATION : http://$publicIp/"
Write-Host "-----------------------------------------------------------------------"
Write-Host " Verification: You can now access the Node.js app via Nginx on port 80."
Write-Host "======================================================================="