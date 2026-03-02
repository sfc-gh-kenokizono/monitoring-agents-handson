# Cortex Agent × Cortex Search × Cortex Analyst Hands-on
## 監視オペレーション向けインシデント対応アシスタント

Snowflake の **Cortex Agent**、**Cortex Search**、**Cortex Analyst** を使って、監視アラームの分析と対応マニュアルの検索・提案を行うAIアシスタントを構築するハンズオンです。

---

## 概要

### ユースケース
運用監視システムでアラームが発生した際、オペレーターは適切な対応マニュアルを探し、手順に従って対応する必要があります。このハンズオンでは、AIがアラームデータの分析（集計・傾向把握）と、関連するマニュアルの自動検索・提案を行うシステムを構築します。

### 学べること
- **Cortex Search**: セマンティック検索でマニュアルを検索（非構造化データ）
- **Cortex Analyst**: セマンティックビューでアラームデータを分析（構造化データ）
- **Cortex Agent**: 複数ツールを組み合わせてユーザーと対話
- **Snowflake Intelligence**: エージェント管理オブジェクト
- **Streamlit in Snowflake**: インタラクティブなUIの構築

---

## 前提条件

### 必要な権限
- `ACCOUNTADMIN` または同等の権限
- Cortex Agent/Search/Analyst の利用が可能なアカウント

### 必要なリソース
- Warehouse（`COMPUTE_WH` など）

### サポートされるリージョン
Cortex Agent は以下のリージョンで利用可能です：
- AWS US East (N. Virginia)
- AWS US West 2 (Oregon)
- AWS EU Central 1 (Frankfurt)
- AWS AP Northeast 1 (Tokyo)
- Azure East US 2
- Azure West Europe

---

## ファイル構成

```
.
├── README.md                                # このファイル
├── sql/
│   └── step1-3_setup.sql                   # Step 1-3: 環境セットアップ（まとめて実行）
├── docs/
│   ├── step4_create_cortex_search.md       # Step 4: Cortex Search作成手順（GUI）
│   ├── step5_create_cortex_agent.md        # Step 5: Cortex Agent作成手順（GUI）
│   └── step5_ref_response_instructions.md  # Step 5で使用: Response Instructions
├── app/
│   ├── incident_assistant.py               # Streamlitアプリ
│   └── dashboard.py                        # ダッシュボード
└── data/
    ├── sample_alarms.json                  # アラームデータ（3000件）
    └── sample_manuals.json                 # マニュアルデータ（100件）
```

---

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                    Streamlit Application                         │
│  ┌─────────────────┐    ┌──────────────────────────────────┐   │
│  │  Alarm List     │    │      Chat Interface               │   │
│  │  (Active)       │───▶│      with Cortex Agent           │   │
│  └─────────────────┘    └──────────────────────────────────┘   │
└────────────────────────────────┬────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Cortex Agent                                │
│              (Claude Sonnet 4.5)                                 │
│                         │                                        │
│         ┌───────────────┴───────────────┐                       │
│         ▼                               ▼                       │
│  ┌──────────────────┐         ┌──────────────────┐              │
│  │  Cortex Analyst  │         │  Cortex Search   │              │
│  │  (ALARMS_SV)     │         │  (MANUAL_SEARCH) │              │
│  │  構造化データ分析 │         │  マニュアル検索   │              │
│  └────────┬─────────┘         └────────┬─────────┘              │
│           │                            │                        │
└───────────┼────────────────────────────┼────────────────────────┘
            │                            │
            ▼                            ▼
     ┌───────────────┐           ┌───────────────┐
     │    ALARMS     │           │   MANUALS     │
     │    (3000件)   │           │   (100件)     │
     └───────────────┘           └───────────────┘
```

---

## ハンズオン手順

### Step 1-3: 環境セットアップ

`sql/step1-3_setup.sql` を Snowsight で実行します。

このスクリプトは以下を自動で行います：
- データベース・スキーマの作成
- Git連携の設定（GitHubからデータを自動取得）
- テーブルの作成とサンプルデータのロード
- **Snowflake Intelligence オブジェクトの作成**
- **セマンティックビュー（ALARMS_SV）の作成**

```sql
-- 主要な処理内容
USE ROLE ACCOUNTADMIN;

-- データベース・スキーマの作成
CREATE DATABASE IF NOT EXISTS OPERATIONS_MONITORING_DEMO;
CREATE SCHEMA IF NOT EXISTS INCIDENT_RESPONSE;

-- Git連携の設定
CREATE OR REPLACE API INTEGRATION GIT_API_INTEGRATION ...
CREATE OR REPLACE GIT REPOSITORY GIT_REPO_MONITORING_HANDSON ...

-- テーブル作成とデータロード
-- （詳細はSQLファイルを参照）

-- Snowflake Intelligence オブジェクトの作成
CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

-- セマンティックビューの作成（Cortex Analyst用）
CREATE OR REPLACE SEMANTIC VIEW ALARMS_SV ...
```

---

### Step 4: Cortex Search サービスの作成（GUI）

**SnowsightのGUIから作成します。**

詳細な手順は [`docs/step4_create_cortex_search.md`](./docs/step4_create_cortex_search.md) を参照してください。

#### UIナビゲーション

```
Snowsight → AIとML → Cortex検索
 → データベース: OPERATIONS_MONITORING_DEMO、スキーマ: INCIDENT_RESPONSE を選択
 → 作成
```

#### 設定値

| 項目 | 値 |
|------|-----|
| サービス名 | `MANUAL_SEARCH` |
| 検索対象テーブル | `OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.MANUALS` |
| 検索列 | `FULL_CONTENT` |
| 属性列 | `CATEGORY`, `SYSTEM_TYPE`, `TITLE`, `KEYWORDS` |
| 埋め込みモデル | `snowflake-arctic-embed-l-v2.0` |

---

### Step 5: Cortex Agent の作成（GUI）

**SnowsightのGUIから作成します。**

詳細な手順は [`docs/step5_create_cortex_agent.md`](./docs/step5_create_cortex_agent.md) を参照してください。

#### UIナビゲーション

```
Snowsight → AIとML → エージェント → Snowflake Intelligence（タブ）
 → Create agent
```

#### 基本設定

| 項目 | 値 |
|------|-----|
| エージェント名 | `INCIDENT_RESPONSE_AGENT` |
| データベース・スキーマ | `OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE` |

#### ツール設定

| ツール | 名前 | 用途 |
|--------|------|------|
| Cortex Analyst | `analyze_alarms` | ALARMSテーブルの集計・分析・グラフ作成 |
| Cortex Search | `search_manuals` | マニュアルのセマンティック検索 |

#### Response Instructions

[`docs/step5_ref_response_instructions.md`](./docs/step5_ref_response_instructions.md) の内容を貼り付けてください。

---

### Step 6: 動作確認

エージェント作成後、Snowsightのエージェントページから直接チャットでテストできます。

#### テスト質問例

```
2026年1月のアラーム件数が多いカテゴリTOP5について、日次アラーム数を時系列でグラフにしてください
```

```
[DB] [TRAP] [linkUp] (OID=1.3.6.1.6.3.1.1.5.4) Interface link restored - IF=bond0 ifIndex=48 ifDescr="To_AccessSwitch-4" ifAdminStatus=up(1) ifOperStatus=up(1) HOST=db-node53 ifSpeed=40000Mbps DowntimeDuration=2872sec AutoNegotiation=ENABLED　このアラームの該当マニュアル探してください
```

```
DoS攻撃の疑いがあるアラームが出ています。初動対応と該当マニュアルを教えてください
```

---

### Step 7: Streamlitアプリの作成（オプション）

#### 7.1 Snowsightでアプリを作成

1. Snowsight で **Projects** → **Streamlit** に移動
2. **+ Streamlit App** をクリック
3. 以下を設定：
   - App name: `Incident_Response_Assistant`
   - Database: `OPERATIONS_MONITORING_DEMO`
   - Schema: `INCIDENT_RESPONSE`
   - Warehouse: `COMPUTE_WH`

#### 7.2 コードを貼り付け

`app/incident_assistant.py` の内容をエディタに貼り付けます。

#### 7.3 アプリを実行

**Run** をクリックしてアプリを起動します。

---

## デモシナリオ

### シナリオ1: アラームデータの分析

チャットで以下のような分析を依頼：
- 「今月のカテゴリ別アラーム件数を教えて」
- 「CRITICALアラームの日別推移をグラフで見せて」
- 「NETWORKカテゴリのアラームが多い日はいつ？」

### シナリオ2: マニュアル検索

アラームメッセージを貼り付けて対応手順を検索：
- 「このアラームの対応マニュアルを探して」
- 「DoS攻撃の初動対応を教えて」

### シナリオ3: 複合的な質問

- 「SECURITYカテゴリのアラームが増えている原因と対応方法を教えて」
- 「今週発生したCRITICALアラームの傾向と、それぞれの対応マニュアルを教えて」

---

## クリーンアップ

ハンズオン終了後、リソースを削除する場合は、`sql/step1-3_setup.sql` の末尾にあるクリーンアップセクションを実行してください：

```sql
USE ROLE ACCOUNTADMIN;

-- Step 5で作成したCortex Agent
DROP AGENT IF EXISTS OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.INCIDENT_RESPONSE_AGENT;

-- Step 4で作成したCortex Search サービス
DROP CORTEX SEARCH SERVICE IF EXISTS OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.MANUAL_SEARCH;

-- Step 3-2で作成したセマンティックビュー
DROP SEMANTIC VIEW IF EXISTS OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.ALARMS_SV;

-- Step 3-1で作成したSnowflake Intelligence オブジェクト
DROP SNOWFLAKE INTELLIGENCE IF EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

-- データベースごと削除（テーブル、ステージ、Git統合も削除されます）
DROP DATABASE IF EXISTS OPERATIONS_MONITORING_DEMO;

-- Git連携
DROP API INTEGRATION IF EXISTS GIT_API_INTEGRATION;
```

---

## 参考リンク

- [Cortex Search Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search)
- [Cortex Agent Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agent)
- [Semantic Views Documentation](https://docs.snowflake.com/en/user-guide/views-semantic/overview)
- [Snowflake Intelligence Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-intelligence)
- [Streamlit in Snowflake](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit)

---

## 注意事項

- このハンズオンで使用するデータはサンプルデータです
- 本番環境で使用する場合は、セキュリティ・権限設定を適切に行ってください
- Cortex Agent/Search/Analyst の利用にはクレジットが消費されます

---

**Happy Hacking!**
