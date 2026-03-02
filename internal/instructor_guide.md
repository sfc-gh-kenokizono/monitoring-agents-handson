# ハンズオン講師ガイド

このドキュメントは、監視オペレーション向けインシデント対応アシスタントのハンズオンを実施する講師向けのガイドです。

---

## 事前準備チェックリスト

### 1. 環境確認（ハンズオン前日まで）

- [ ] 使用するSnowflakeアカウントが対応リージョンにあることを確認
  - AWS US East / West / Frankfurt / Tokyo
  - Azure East US 2 / West Europe
- [ ] ACCOUNTADMINロールでログインできることを確認
- [ ] Cortex Agent / Search / Analyst が利用可能なことを確認
- [ ] ウェアハウス（COMPUTE_WH等）が存在することを確認

### 2. デモ環境の事前構築（オプション）

講師デモ用の環境を事前に構築する場合は、`full_setup.sql` を使用してください。
これにより、全てのオブジェクトが一括で作成されます。

```sql
-- internal/full_setup.sql を実行
```

### 3. 既存環境のクリーンアップ

前回のハンズオンデータが残っている場合は、クリーンアップを実行：

```sql
USE ROLE ACCOUNTADMIN;
DROP DATABASE IF EXISTS OPERATIONS_MONITORING_DEMO;
DROP API INTEGRATION IF EXISTS GIT_API_INTEGRATION;
DROP SNOWFLAKE INTELLIGENCE IF EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;
```

---

## ハンズオン当日の流れ

### 推奨タイムテーブル（90分版）

| 時間 | 内容 | 備考 |
|------|------|------|
| 0:00-0:10 | イントロダクション | ユースケース説明、アーキテクチャ解説 |
| 0:10-0:25 | Step 1-3: 環境セットアップ | SQL実行、データ確認 |
| 0:25-0:40 | Step 4: Cortex Search作成 | GUI操作、検索テスト |
| 0:40-1:00 | Step 5: Cortex Agent作成 | GUI操作、ツール設定 |
| 1:00-1:20 | Step 6: 動作確認・デモ | サンプル質問で動作確認 |
| 1:20-1:30 | Q&A・まとめ | 質疑応答、次のステップ |

### 推奨タイムテーブル（60分版）

| 時間 | 内容 | 備考 |
|------|------|------|
| 0:00-0:05 | イントロダクション | 簡潔に |
| 0:05-0:15 | Step 1-3: 環境セットアップ | |
| 0:15-0:25 | Step 4: Cortex Search作成 | |
| 0:25-0:40 | Step 5: Cortex Agent作成 | |
| 0:40-0:55 | Step 6: 動作確認 | |
| 0:55-1:00 | まとめ | |

---

## 各ステップのポイント

### Step 1-3: 環境セットアップ

**説明ポイント:**
- Git連携によるデータ取得の利便性
- Snowflake Intelligence オブジェクトの役割（エージェント管理基盤）
- セマンティックビューの概念（構造化データへの自然言語アクセス）

**よくある質問:**
- Q: Git連携は必須？
- A: いいえ。手動でステージにアップロードも可能です。

**トラブルシューティング:**
- Git連携でエラーが出る場合 → API_ALLOWED_PREFIXES の設定を確認
- COPY FILESが失敗する場合 → リポジトリがPublicになっているか確認

### Step 4: Cortex Search作成

**説明ポイント:**
- セマンティック検索と従来のキーワード検索の違い
- 埋め込みモデルの役割
- TARGET_LAGの意味（データ更新の反映タイミング）

**デモのコツ:**
- 検索テストで「CPU高負荷」「メモリ不足」など日本語で検索して見せる
- 従来のLIKE検索との違いを強調

### Step 5: Cortex Agent作成

**説明ポイント:**
- 2つのツールの役割分担
  - `analyze_alarms`: 構造化データ分析（Cortex Analyst）
  - `search_manuals`: 非構造化データ検索（Cortex Search）
- Orchestration vs Response Instructions の違い

**GUI操作の注意点:**
- ツールの追加は「+ 追加」ボタンをクリック
- Example questionsは1つずつ入力
- Response Instructionsは別ファイルからコピペ

### Step 6: 動作確認

**推奨デモシナリオ:**

1. **分析系の質問**（Cortex Analyst）
   ```
   2026年1月のカテゴリ別アラーム件数を教えてください
   ```
   → グラフが生成されることを確認

2. **検索系の質問**（Cortex Search）
   ```
   DoS攻撃の疑いがあるアラームが出ています。初動対応を教えてください
   ```
   → マニュアルから対応手順が返ることを確認

3. **複合的な質問**
   ```
   SECURITYカテゴリのアラーム傾向と、対応マニュアルを教えて
   ```
   → 両方のツールが使われることを確認

---

## よくあるトラブルと対処法

### 1. Git連携が失敗する

**症状:** `CREATE GIT REPOSITORY` でエラー

**対処:**
```sql
-- API統合の設定を確認
DESCRIBE API INTEGRATION GIT_API_INTEGRATION;

-- リポジトリがPublicかPrivateか確認
-- Privateの場合は認証設定が必要
```

### 2. Cortex Searchが作成できない

**症状:** 「サービスを作成できません」エラー

**対処:**
- リージョンがサポートされているか確認
- ウェアハウスが起動しているか確認
- テーブルにデータが入っているか確認

### 3. Agentが応答しない

**症状:** タイムアウトや空の応答

**対処:**
- Cortex Searchサービスが正常に作成されているか確認
- セマンティックビューが正常に作成されているか確認
- ウェアハウスサイズを大きくしてみる

### 4. 日本語の応答が英語になる

**症状:** Response Instructionsで日本語指定しても英語で返る

**対処:**
- Response Instructionsに「必ず日本語で回答してください」を追加
- モデルをClaude系に変更（日本語が得意）

---

## 参加者からの想定質問

### 技術的な質問

**Q: Cortex AgentとCortex Assistantの違いは？**
A: Cortex Assistantは非推奨。Cortex Agentが後継で、ツール統合や会話履歴管理が強化されています。

**Q: セマンティックビューとセマンティックモデル（YAML）の違いは？**
A: セマンティックビューはDDLで定義する新しい方式。YAMLはステージにファイルを置く従来方式。機能は同等ですが、セマンティックビューの方が管理しやすいです。

**Q: 本番で使う場合のコスト目安は？**
A: Cortex Agent/Analyst/Searchそれぞれでクレジットを消費します。Cortex Agentの場合、1リクエストあたり約0.01-0.05クレジット程度（モデルとトークン数による）。

### ビジネス的な質問

**Q: どんなユースケースに向いている？**
A: 
- 社内ナレッジ検索（FAQ、マニュアル）
- 構造化データの自然言語分析
- カスタマーサポート支援
- 運用監視（今回のデモ）

**Q: 既存のRAGシステムとの違いは？**
A: Snowflake内で完結するため、データ移動が不要。ガバナンス・セキュリティをSnowflakeで一元管理できる点が強み。

---

## クリーンアップ

ハンズオン終了後、参加者に環境削除を案内：

```sql
-- 参加者向けクリーンアップ手順
USE ROLE ACCOUNTADMIN;

DROP AGENT IF EXISTS OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.INCIDENT_RESPONSE_AGENT;
DROP CORTEX SEARCH SERVICE IF EXISTS OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.MANUAL_SEARCH;
DROP SEMANTIC VIEW IF EXISTS OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.ALARMS_SV;
DROP SNOWFLAKE INTELLIGENCE IF EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;
DROP DATABASE IF EXISTS OPERATIONS_MONITORING_DEMO;
DROP API INTEGRATION IF EXISTS GIT_API_INTEGRATION;
```

---

## 連絡先

問題が発生した場合やフィードバックは以下まで：
- [ここに連絡先を記載]
