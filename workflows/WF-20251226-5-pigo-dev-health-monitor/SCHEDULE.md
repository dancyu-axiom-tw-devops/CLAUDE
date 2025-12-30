# K8s Health Monitor 排程時間表

所有時間均為 UTC+8 (Asia/Taipei)

## PIGO Cluster (tp-hkidc)
| 環境 | 時間 | Namespace |
|------|------|-----------|
| pigo-prod | 08:00 | pigo-prod |
| pigo-rel | 08:05 | pigo-rel |
| pigo-stg | 08:10 | pigo-stg |
| pigo-dev | 08:15 | pigo-dev |

## WAAS2 Cluster (tp-hkidc)
| 環境 | 時間 | Namespace |
|------|------|-----------|
| waas-prod | 08:20 | waas-prod |
| waas-rel | 08:25 | waas-rel |
| waas-dev | 08:30 | waas-dev |

## Forex Cluster
| 環境 | 時間 | Namespace |
|------|------|-----------|
| forex-prod | 08:35 | forex-prod |
| forex-rel | 08:40 | forex-rel |
| forex-stage | 08:45 | forex-stage |
| forex-dev | 08:50 | forex-dev |

## JuanCash Cluster
| 環境 | 時間 | Namespace |
|------|------|-----------|
| juancash-prod | 08:55 | jc-prod |
| juancash-dev | 09:00 | jc-dev |

---

## Cron Schedule Format

```yaml
# PIGO
pigo-prod:  schedule: "0 8 * * *"   timeZone: "Asia/Taipei"
pigo-rel:   schedule: "5 8 * * *"   timeZone: "Asia/Taipei"
pigo-stg:   schedule: "10 8 * * *"  timeZone: "Asia/Taipei"
pigo-dev:   schedule: "15 8 * * *"  timeZone: "Asia/Taipei"

# WAAS2
waas-prod:  schedule: "20 8 * * *"  timeZone: "Asia/Taipei"
waas-rel:   schedule: "25 8 * * *"  timeZone: "Asia/Taipei"
waas-dev:   schedule: "30 8 * * *"  timeZone: "Asia/Taipei"

# Forex
forex-prod:  schedule: "35 8 * * *"  timeZone: "Asia/Taipei"
forex-rel:   schedule: "40 8 * * *"  timeZone: "Asia/Taipei"
forex-stage: schedule: "45 8 * * *"  timeZone: "Asia/Taipei"
forex-dev:   schedule: "50 8 * * *"  timeZone: "Asia/Taipei"

# JuanCash
juancash-prod: schedule: "55 8 * * *"  timeZone: "Asia/Taipei"
juancash-dev:  schedule: "0 9 * * *"   timeZone: "Asia/Taipei"
```

## Notes

- 每個環境間隔 5 分鐘，避免同時上傳 GitHub 產生衝突
- 所有腳本已使用 `git pull --rebase` 解決並行提交問題
- GitHub App ID: 2539631 (共用於 pigo/waas2)
- **pigo-prod image**: 從線下 Harbor 複製到 GCR，不需另外編譯

## Docker Build Note

在 Mac (ARM) 環境編譯 Docker image 給 x86 K8s 使用時，必須指定平台：

```bash
docker buildx build --platform linux/amd64 --no-cache -t <image>:<tag> .
docker push <image>:<tag>
```

否則會出現 `exec format error` 錯誤。
