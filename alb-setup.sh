#!/bin/bash
set -euo pipefail

# ================= CONFIG =================
CLUSTER_NAME="demo-cluster"
AWS_REGION="us-east-1"
ACCOUNT_ID="992382567166"

NAMESPACE="kube-system"
SERVICE_ACCOUNT="aws-load-balancer-controller"

POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"

HELM_RELEASE="aws-load-balancer-controller"
HELM_REPO_NAME="eks"
HELM_REPO_URL="https://aws.github.io/eks-charts"

POLICY_FILE="iam-policy.json"
# =========================================

echo "🚀 Starting AWS Load Balancer Controller setup"

# ---------- STEP 0: Check EKS cluster ----------
echo "🔍 Checking if EKS cluster exists..."

aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  >/dev/null

echo "✅ EKS cluster found"

# ---------- STEP 1: Fetch VPC ID ----------
VPC_ID=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text)

echo "📌 Cluster VPC ID: $VPC_ID"

# ---------- STEP 2: Associate OIDC provider ----------
echo "🔗 Associating IAM OIDC provider (idempotent)..."

eksctl utils associate-iam-oidc-provider \
  --cluster "$CLUSTER_NAME" \
  --approve

# ---------- STEP 3: Download IAM policy ----------
echo "📥 Downloading AWS Load Balancer Controller IAM policy..."

curl -fsSL \
https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json \
-o "$POLICY_FILE"

# ---------- STEP 4: Create or update IAM policy ----------
echo "🛡️ Creating or updating IAM policy..."

POLICY_ARN=$(aws iam list-policies \
  --scope Local \
  --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn | [0]" \
  --output text)

if [[ "$POLICY_ARN" != "None" && -n "$POLICY_ARN" ]]; then
  echo "✅ Policy exists. Creating new version..."
  aws iam create-policy-version \
    --policy-arn "$POLICY_ARN" \
    --policy-document file://"$POLICY_FILE" \
    --set-as-default
else
  echo "🆕 Policy does not exist. Creating..."
  POLICY_ARN=$(aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document file://"$POLICY_FILE" \
    --query "Policy.Arn" \
    --output text)
fi

echo "📌 Using policy ARN: $POLICY_ARN"

# ---------- STEP 5: Create IAM ServiceAccount (IRSA) ----------
echo "👤 Creating / updating IAM ServiceAccount..."

eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" \
  --namespace "$NAMESPACE" \
  --name "$SERVICE_ACCOUNT" \
  --attach-policy-arn "$POLICY_ARN" \
  --override-existing-serviceaccounts \
  --approve

# ---------- STEP 6: Install / Upgrade Helm chart ----------
echo "📦 Installing / upgrading AWS Load Balancer Controller..."

helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL" || true
helm repo update

helm upgrade --install "$HELM_RELEASE" eks/aws-load-balancer-controller \
  -n "$NAMESPACE" \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name="$SERVICE_ACCOUNT" \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID"

# ---------- STEP 7: Verify rollout ----------
echo "⏳ Waiting for controller rollout..."

kubectl rollout status deployment/aws-load-balancer-controller -n "$NAMESPACE"

echo "🎉 SUCCESS: AWS Load Balancer Controller is fully configured!"
