# Step 5: Cortex Agent の作成

## 目的

運用マニュアルを検索するCortex Searchと、アラームデータを分析するCortex Analyst（セマンティックビュー）をツールとして持つAIエージェントを作成し、インシデント対応を支援します。

## UIナビゲーション

```
Snowsight → AIとML → エージェント → Snowflake Intelligence（タブ）
 → Create agent
```

---

## 基本設定

| 項目 | 値 |
|------|-----|
| データベースとスキーマ | `OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE` |
| エージェントオブジェクト名 | `INCIDENT_RESPONSE_AGENT` |
| 表示名 | `INCIDENT_RESPONSE_AGENT` |

### 説明

```
運用監視システムのインシデント対応を支援するAIエージェントです。
アラームデータの分析（集計・可視化）と、関連する対応マニュアルの検索を行い、最適な対応手順を提案します。
ユーザーは日本語でアラーム分析や対応方法について問い合わせます。
```

### Example questions（1つずつ入力）

1. `2026年1月のアラーム件数が多いカテゴリTOP5について、日次アラーム数を時系列でグラフにしてください`
2. `[DB] [TRAP] [linkUp] (OID=1.3.6.1.6.3.1.1.5.4) Interface link restored - IF=bond0 ifIndex=48 ifDescr="To_AccessSwitch-4" ifAdminStatus=up(1) ifOperStatus=up(1) HOST=db-node53 ifSpeed=40000Mbps DowntimeDuration=2872sec AutoNegotiation=ENABLED　このアラームの該当マニュアル探してください`
3. `DoS攻撃の疑いがあるアラームが出ています。初動対応と該当マニュアルを教えてください`

---

## ツール① Cortex Analyst（セマンティックビュー） → + 追加

| 項目 | 値 |
|------|-----|
| データベースとスキーマ | `OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE` |
| プルダウン | `OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.ALARMS_SV` |
| 名前 | `analyze_alarms` |

### 説明

```
アラームデータを分析します。
カテゴリ別・重要度別・日次の件数集計、傾向分析、グラフ作成などが可能です。
```

→ **追加** をクリック

---

## ツール② Cortex検索サービス → + 追加

| 項目 | 値 |
|------|-----|
| データベースとスキーマ | `OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE` |
| プルダウン | `OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.MANUAL_SEARCH` |
| Max results | `5` |
| ID列 | `MANUAL_ID` |
| タイトル列 | `TITLE` |
| 検索結果フィルター | 追加なし（何も操作しない） |
| 名前 | `search_manuals` |

### 説明

```
運用マニュアルをセマンティック検索します。
アラームの種類やシステム種別に応じた対応手順、サービス確認方法、復旧手順を検索できます。
```

→ **追加** をクリック

---

## オーケストレーション

| 項目 | 値 |
|------|-----|
| Model | `Claude Sonnet 4.5` を選択 |
| Time Limit (seconds) | No limit |
| Token Limit | No limit |

### Orchestration instructions

```
ユーザーの質問に応じて適切なツールを選択してください：
- アラームの集計・分析・グラフ作成 → analyze_alarms ツール
- 対応マニュアルの検索 → search_manuals ツール
両方のツールを組み合わせて回答することも可能です。
```

### Response instructions

別ファイル [`step5_ref_response_instructions.md`](./step5_ref_response_instructions.md) の内容を貼り付けてください。

---

## アクセス

| 項目 | 値 |
|------|-----|
| ロール | `ACCOUNTADMIN` または必要なロール |

→ **保存** をクリック
