#!/bin/bash
set -x

if ! which eksctl &> /dev/null; then
    echo "eksctl not found. Installing eksctl..."
    ARCH=$(uname -m)
    PLATFORM=$(uname -s)_$ARCH
    curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
    tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
    sudo mv /tmp/eksctl /usr/local/bin
else
    echo "** eksctl ** has already been successfully installed."
fi


# Region
REGION="eu-west-2"

# Define the create function
create_function() {
    echo "Creating the EKS cluster..."

    eksctl create cluster --node-type=t3.medium --name=$2 --nodes-min=3
    eksctl utils associate-iam-oidc-provider --region=$REGION--cluster=$2 --approve
    eksctl create iamserviceaccount \
        --name ebs-csi-controller-sa \
        --namespace kube-system \
        --cluster $2 \
        --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
        --approve  \
        --role-only  \
        --role-name AmazonEKS_EBS_CSI_DriverRole

    eksctl create addon \
    --name aws-ebs-csi-driver \
    --cluster $2 \
    --service-account-role-arn arn:aws:iam::$(aws sts get-caller-identity \
    --query Account \
    --output text):role/AmazonEKS_EBS_CSI_DriverRole \
    --force
}

# Define the delete function
delete_function() {
    echo "Deleting the EKS cluster..."
    eksctl delete cluster --name=$2
}

# Check the first argument
case "$1" in
    create)
        create_function "$@"
        ;;
    delete)
        delete_function "$@"
        ;;
    *)
        echo "Usage: $0 {create|delete}"
        exit 1
        ;;
esac

