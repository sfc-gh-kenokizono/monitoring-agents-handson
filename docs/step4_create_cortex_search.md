# Step 4: Cortex Search サービスの作成

## 目的

運用マニュアル（MANUALS テーブル）の全文コンテンツをセマンティック検索できるようにします。

## UIナビゲーション

```
Snowsight → AIとML → Cortex検索
 → データベース: OPERATIONS_MONITORING_DEMO、スキーマ: INCIDENT_RESPONSE を選択
 → 作成
```

---

## 設定値

| 項目 | 値 |
|------|-----|
| サービスデータベースとスキーマ | `OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE` |
| サービス名 | `MANUAL_SEARCH` |
| インデックスを作成するデータを選択 | `OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.MANUALS` |
| 検索列 | `FULL_CONTENT` |
| 属性列 | `CATEGORY`, `SYSTEM_TYPE`, `TITLE`, `KEYWORDS` |
| サービスに含む列を選択 | Select all |
| ターゲットラグ | 1 時間 |
| 埋め込みモデル | `snowflake-arctic-embed-l-v2.0` |
| インデックス作成用のウェアハウス | `COMPUTE_WH`（ご自身の Warehouse に変更可） |

→ **作成** をクリック
