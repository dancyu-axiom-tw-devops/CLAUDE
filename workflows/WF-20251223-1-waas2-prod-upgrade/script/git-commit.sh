#!/bin/sh
# Git commit and push for Waas2 production upgrade
# Usage: ./git-commit.sh

set -e

DEPLOY_DIR="/Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy"
BRANCH_NAME="20251225-waas-prod-upgrade"
COMMIT_MESSAGE="20251225_WaaS_PRO_Release_Note_ 黑U检测+Exchange服务宕机修复+一对多子管理员+提款订单强制设置成功按钮+提款到合约

新增功能
1. 黑U检测多源风控集成方案
2. 由一个运营账号开多个商户子管理员账号
3. waas 后台提现订单列表新增设置成功按钮
4. 冻结的用户由审核人员决定后续是否继续冻结
5. 提款到合约
6. chainAnalysis开关

功能修正
1. exchange 服务宕机问题处理

升级镜像版本:
- service-search-rel: 60 → 6
- service-exchange-rel: 75 → 8
- service-tron-rel: 4 (from service-tron-v2-rel:70)
- service-eth-rel: 28 → 2
- service-user-rel: 72 → 1
- service-waas-admin-rel: 82 → 1"

cd "$DEPLOY_DIR"

echo "=== Waas2 Production Git Commit ==="
echo ""
echo "Current directory: $(pwd)"
echo "Branch name: $BRANCH_NAME"
echo ""

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

# Create and checkout new branch if not already on it
if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
  echo ""
  echo "Creating new branch: $BRANCH_NAME"
  git checkout -b "$BRANCH_NAME" 2>/dev/null || git checkout "$BRANCH_NAME"
else
  echo "Already on branch: $BRANCH_NAME"
fi

echo ""
echo "=== Git Status ==="
git status --short

echo ""
echo "=== Git Diff Summary ==="
git diff --stat

echo ""
echo "=== Changed Files ==="
git diff --name-only

echo ""
echo "Press Enter to continue with commit, or Ctrl+C to cancel..."
read dummy

# Add modified kustomization files
echo ""
echo "Adding modified kustomization.yml files..."
git add service-*/kustomization.yml

echo ""
echo "=== Commit Message ==="
echo "$COMMIT_MESSAGE"
echo ""

echo "Creating commit..."
git commit -m "$COMMIT_MESSAGE"

echo ""
echo "=== Commit Created ==="
git log -1 --oneline

echo ""
echo "Push to remote? (y/N)"
read push_confirm

if [ "$push_confirm" = "y" ] || [ "$push_confirm" = "Y" ]; then
  echo "Pushing to origin/$BRANCH_NAME..."
  git push -u origin "$BRANCH_NAME"
  echo ""
  echo "=== Push Completed ==="
  echo "Branch pushed to: origin/$BRANCH_NAME"
else
  echo "Skipped push. You can push later with:"
  echo "  git push -u origin $BRANCH_NAME"
fi

echo ""
echo "=== Next Steps ==="
echo "1. Create Merge Request in GitLab"
echo "2. Review and merge to main/master"
echo "3. Deploy using kubectl apply"
