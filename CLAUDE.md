# AGENTS.md

## AI Agent Preferences

- **Language**: 繁體中文 (Traditional Chinese)
- **Response Style**: 精簡、技術導向
- **Code Comments**: English
- **Error Messages / Logs**: English

## Work Session Management

### Session Continuity Strategy

為避免 token 限制中斷工作：

1. 規劃時，分割為小型可完成的工作單元
2. 先寫規劃檔，記錄完整前情提要
3. 每完成一個動作即更新工作進度

### Documentation Structure

所有 AI 協作相關文檔統一存放於 `~/CLAUDE/` 目錄：

```
~/CLAUDE/
├── AGENTS.md                    # 本文件 - AI 協作規範
├── README.md                    # 文檔目錄說明
├── workflows/                   # 可重複使用的 SOP 或獨立工作
│   └── WF-YYYYMMDD-n-description/ # 以日期+英文簡述命名,同一天有多個任務時,n 為1~9
│       ├── *.md                 # 計劃、文件
│       ├── script/              # 工作產生的腳本
│       ├── data/                # 工作產生的資料檔
│       └── worklogs/            # 工作日誌
│           ├── WORKLOG-YYYYMMDD-*.md
│           └── completed/YYYY-MM/  # 已完成歸檔
└── templates/                   # 文檔範本
```

個別git 的專案目錄下的docs 以顯示精簡的文件說明，不需顯示變更歷程。

### Document Header

每個 workflow md 檔開頭需包含：

```markdown
---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
status: 進行中 | 已完成 | 暫停
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

## Shell 規範

- 禁用 ANSI color codes（輸出不帶顏色）
- 所有輸出不要出現色碼
- 優先使用 POSIX 相容語法

## Git 規範

做任何推送前先 pull 
針對以下目錄的專案，使用 `git-tp` 取代 `git` 指令
- /Users/user/PIGO-project/gitlab.axiom-infra.com/pigo-prod-k8s-deploy
- /Users/user/PIGO-project/gitlab.axiom-infra.com/pigo-prod-k8s-infra-deploy
- /Users/user/PIGO-project/gitlab.axiom-infra.com/pigo-prod-k8s-nacos
- /Users/user/PIGO-project/gitlab.axiom-infra.com/pigo-prod-k8s-sqlexec-deploy
- /Users/user/FOREX-project/gitlab.axiom-infra.com/forex-prod-k8s-deploy
- /Users/user/FOREX-project/gitlab.axiom-infra.com/forex-prod-k8s-infra-deploy
- /Users/user/FOREX-project/gitlab.axiom-infra.com/forex-prod-k8s-nacos-config
- /Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-prod-dns-record-mgmt
- /Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy
- /Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-nacos-deploy
- /Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-sensitive-k8s-deploy

## 權限規範

- 允許 `/Users/user/` 目錄下的操作，無需額外確認

## Credentials 處理規範

### 敏感資訊管理原則

**絕對禁止將以下資訊提交至 git**:
- API Keys / Access Keys / Secret Keys
- Passwords / Tokens / Credentials
- SSH Private Keys (.key, .pem)
- Service Account JSON files
- Webhook URLs
- Database connection strings
- 任何包含敏感資訊的配置檔

### 標準處理流程

#### 1. Credentials 存放位置

所有敏感資訊統一存放於：

```
~/CLAUDE/credentials/
├── README.md                    # 說明文件
├── <project>-<service>-credentials.env    # 環境變數格式
├── <project>-<service>-key.json           # JSON 格式 credentials
└── <project>-<service>-webhook.txt        # Webhook URLs
```

#### 2. .gitignore 配置

確保專案根目錄的 `.gitignore` 包含：

```gitignore
# Credentials and Secrets
credentials/
*.json
*.key
*.pem
*-credentials.yml
*-secrets.yml

# Environment files
.env
.env.*
*.env

# Temporary files
*.tmp
*.log
```

#### 3. 範本檔案規範

在版控中使用範本檔案，包含：
- 占位符 (`<PLACEHOLDER>`) 而非實際值
- 詳細的使用說明
- 指向實際 credentials 位置的註解

**範例** - `secret-template.yml`:
```yaml
# Secret Template - DO NOT commit actual secrets to git
#
# Create the actual secret using:
# kubectl create secret generic my-secret \
#   --from-literal=key=<YOUR_VALUE> \
#   -n namespace
#
# Actual credentials stored in: ~/CLAUDE/credentials/my-secret.env

apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque
stringData:
  api-key: ""         # Replace with actual API key
  webhook-url: ""     # Replace with actual webhook URL
```

#### 4. 文檔中的 Credentials 引用

在 README、WORKLOG 等文檔中：
- ✅ 使用變數名稱: `${ALIYUN_ACCESS_KEY_ID}`
- ✅ 使用占位符: `<ALIYUN_ACCESS_KEY_SECRET>`
- ❌ 絕不直接寫入實際值

**範例**:
```markdown
**Secrets Created**:
\`\`\`bash
kubectl create secret generic arms-prometheus-credentials \
  --from-literal=username=<ALIYUN_ACCESS_KEY_ID> \
  --from-literal=password=<ALIYUN_ACCESS_KEY_SECRET> \
  -n forex-prod
\`\`\`

Note: Actual credentials stored in `~/CLAUDE/credentials/arms-prometheus.env` (not in version control)
```

#### 5. 意外提交處理流程

如果不慎將 secrets 提交到 git：

1. **立即從 git 歷史移除**:
   ```bash
   # 從追蹤中移除
   git rm --cached <sensitive-file>

   # 修改 commit (如果是最新的)
   git commit --amend --no-edit

   # 強制推送 (謹慎使用)
   git push --force
   ```

2. **將敏感資訊移至 credentials 目錄**:
   ```bash
   mv <sensitive-file> ~/CLAUDE/credentials/
   ```

3. **更新 .gitignore**:
   確保該類型檔案已被排除

4. **輪換被洩漏的 credentials**:
   - 立即在服務商後台撤銷舊的 keys
   - 生成新的 credentials
   - 更新所有使用該 credentials 的系統

#### 6. Credentials 使用方式

**從檔案載入**:
```bash
# 載入環境變數
source ~/CLAUDE/credentials/service-name.env

# 使用變數創建 secret
kubectl create secret generic my-secret \
  --from-literal=username=${USERNAME} \
  --from-literal=password=${PASSWORD} \
  -n namespace
```

**直接從檔案讀取**:
```bash
# 從文字檔讀取
kubectl create secret generic my-secret \
  --from-literal=token="$(cat ~/CLAUDE/credentials/token.txt)" \
  -n namespace

# 從 JSON 檔案創建
kubectl create secret generic gcr-credentials \
  --from-file=key.json=~/CLAUDE/credentials/gcr-service-account.json \
  -n namespace
```

### 安全檢查清單

提交代碼前務必確認：

- [ ] 所有 API keys / tokens 已移至 `~/CLAUDE/credentials/`
- [ ] `.gitignore` 已正確配置
- [ ] 文檔中使用占位符而非實際值
- [ ] 範本檔案包含使用說明
- [ ] `git status` 不顯示任何敏感檔案
- [ ] GitHub/GitLab push protection 未觸發

### 常見敏感資訊模式

需特別注意以下格式的資訊：

| 類型 | 模式範例 | 處理方式 |
|------|---------|---------|
| Aliyun AccessKey | `LTAI...` (24 chars) | 環境變數檔 |
| AWS Access Key | `AKIA...` (20 chars) | 環境變數檔 |
| Slack Webhook | `https://hooks.slack.com/services/...` | 文字檔 |
| Google Cloud SA | `*.json` with `private_key` | JSON 檔案 |
| GitHub Token | `ghp_...` | 文字檔 |
| JWT Token | `eyJ...` | 文字檔 |
| SSH Key | `-----BEGIN ... KEY-----` | .pem/.key 檔案 |

### 參考資源

- GitHub Secret Scanning: https://docs.github.com/code-security/secret-scanning
- GitLab Secret Detection: https://docs.gitlab.com/ee/user/application_security/secret_detection/
- Git Filter-Repo: https://github.com/newren/git-filter-repo (清理歷史)