-- ============================================================================
-- 【Internal】全環境一括セットアップ
-- ============================================================================
-- このスクリプトは、ハンズオン環境を一発で構築するための内部用SQLです。
-- Step 1-5 の全てを自動で作成します（GUI操作不要）。
-- 
-- 用途:
--   - デモ環境の事前準備
--   - 講師用の検証環境構築
--   - トラブルシューティング時の再構築
-- ============================================================================

-- ロール設定
USE ROLE ACCOUNTADMIN;

-- ============================================
-- Step 1: データベース・スキーマのセットアップ
-- ============================================

CREATE DATABASE IF NOT EXISTS OPERATIONS_MONITORING_DEMO;
USE DATABASE OPERATIONS_MONITORING_DEMO;

CREATE SCHEMA IF NOT EXISTS INCIDENT_RESPONSE;
USE SCHEMA INCIDENT_RESPONSE;

-- ウェアハウスの確認（存在しない場合は作成）
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

USE WAREHOUSE COMPUTE_WH;

-- ファイルフォーマットの作成
CREATE OR REPLACE FILE FORMAT JSON_FORMAT
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = TRUE;

-- Git連携のため、API統合を作成
CREATE OR REPLACE API INTEGRATION GIT_API_INTEGRATION
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-kenokizono/')
    ENABLED = TRUE;

-- Git統合の作成
CREATE OR REPLACE GIT REPOSITORY GIT_REPO_MONITORING_HANDSON
    API_INTEGRATION = GIT_API_INTEGRATION
    ORIGIN = 'https://github.com/sfc-gh-kenokizono/monitoring-agents-handson.git';

-- チェック
LS @GIT_REPO_MONITORING_HANDSON/branches/main;

-- データロード用の内部ステージを作成
CREATE OR REPLACE STAGE DATA_STAGE
    FILE_FORMAT = JSON_FORMAT;

-- GitからJSONファイルをコピー
COPY FILES INTO @DATA_STAGE
    FROM @GIT_REPO_MONITORING_HANDSON/branches/main/data/
    PATTERN = '.*\\.json$';

-- ステージ内容を確認
LS @DATA_STAGE;


-- ============================================
-- Step 2: テーブルの作成とデータロード
-- ============================================

-- アラームテーブル
CREATE OR REPLACE TABLE ALARMS (
    ALARM_ID VARCHAR(50) PRIMARY KEY,
    TIMESTAMP TIMESTAMP_NTZ,
    SYSTEM_TYPE VARCHAR(100),
    MONITORING_HOST VARCHAR(100),
    ALARM_HOST VARCHAR(100),
    ALARM_MESSAGE TEXT,
    STATUS VARCHAR(20),
    SEVERITY VARCHAR(20),
    CATEGORY VARCHAR(50),
    MANUAL_ID INT
);

-- マニュアルテーブル
CREATE OR REPLACE TABLE MANUALS (
    MANUAL_ID INT PRIMARY KEY,
    TITLE VARCHAR(500),
    CATEGORY VARCHAR(100),
    SYSTEM_TYPE VARCHAR(100),
    KEYWORDS TEXT,
    SERVICE_CHECK TEXT,
    RECOVERY_PROCEDURE TEXT,
    FULL_CONTENT TEXT
);

-- マニュアルデータのロード
COPY INTO MANUALS (MANUAL_ID, TITLE, CATEGORY, SYSTEM_TYPE, KEYWORDS, SERVICE_CHECK, RECOVERY_PROCEDURE, FULL_CONTENT)
FROM (
    SELECT 
        $1:manual_id::INT,
        $1:title::VARCHAR,
        $1:category::VARCHAR,
        $1:system_type::VARCHAR,
        $1:keywords::TEXT,
        $1:service_check::TEXT,
        $1:recovery_procedure::TEXT,
        $1:full_content::TEXT
    FROM @DATA_STAGE/sample_manuals.json
);

-- アラームデータのロード
COPY INTO ALARMS (ALARM_ID, TIMESTAMP, SYSTEM_TYPE, MONITORING_HOST, ALARM_HOST, ALARM_MESSAGE, STATUS, SEVERITY, CATEGORY, MANUAL_ID)
FROM (
    SELECT 
        $1:alarm_id::VARCHAR,
        $1:timestamp::TIMESTAMP_NTZ,
        $1:system_type::VARCHAR,
        $1:monitoring_host::VARCHAR,
        $1:alarm_host::VARCHAR,
        $1:alarm_message::TEXT,
        $1:status::VARCHAR,
        $1:severity::VARCHAR,
        $1:category::VARCHAR,
        $1:manual_id::INT
    FROM @DATA_STAGE/sample_alarms.json
);

-- データ確認
SELECT 'Manuals' as table_name, COUNT(*) as record_count FROM MANUALS
UNION ALL
SELECT 'Alarms', COUNT(*) FROM ALARMS;

-- クロスリージョン設定（Claude等のモデルを使用するために必要）
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'AWS_US';


-- ============================================
-- Step 3-1: Snowflake Intelligence オブジェクトの作成
-- ============================================

CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;
GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE ACCOUNTADMIN;
GRANT MODIFY ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE ACCOUNTADMIN;


-- ============================================
-- Step 3-2: セマンティックビューの作成
-- ============================================

CREATE OR REPLACE SEMANTIC VIEW OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.ALARMS_SV

TABLES (
    ALARMS AS OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.ALARMS
        PRIMARY KEY (ALARM_ID)
        WITH SYNONYMS ('アラーム', '警報', '監視アラーム', 'アラートデータ', '障害通知')
        COMMENT = '監視システムから発生したアラームデータ'
)

FACTS (
    ALARMS.alarm_count AS 1
        COMMENT = 'アラーム件数（カウント用）'
)

DIMENSIONS (
    ALARMS.alarm_id AS ALARMS.ALARM_ID
        WITH SYNONYMS ('アラームID', '警報ID', 'アラート番号')
        COMMENT = 'アラームの一意識別子',
    
    ALARMS.timestamp AS ALARMS.TIMESTAMP
        WITH SYNONYMS ('発生日時', 'タイムスタンプ', '日時', '発生時刻', '時刻')
        COMMENT = 'アラームが発生した日時',
    
    ALARMS.system_type AS ALARMS.SYSTEM_TYPE
        WITH SYNONYMS ('システム種別', 'システムタイプ', 'システム', '機器種別', 'サーバ種別')
        COMMENT = 'アラーム発生元のシステム種別（APP-SERVER, DB-CLUSTER等）',
    
    ALARMS.monitoring_host AS ALARMS.MONITORING_HOST
        WITH SYNONYMS ('監視ホスト', '監視サーバ', '監視元')
        COMMENT = 'アラームを検知した監視ホスト',
    
    ALARMS.alarm_host AS ALARMS.ALARM_HOST
        WITH SYNONYMS ('発生ホスト', '障害ホスト', '対象ホスト', '対象サーバ')
        COMMENT = 'アラームが発生したホスト',
    
    ALARMS.alarm_message AS ALARMS.ALARM_MESSAGE
        WITH SYNONYMS ('アラームメッセージ', '警報メッセージ', 'メッセージ', '内容', '詳細')
        COMMENT = 'アラームの詳細メッセージ',
    
    ALARMS.status AS ALARMS.STATUS
        WITH SYNONYMS ('ステータス', '状態', 'アラーム状態')
        COMMENT = 'アラームの状態（OPEN/CLOSE）',
    
    ALARMS.severity AS ALARMS.SEVERITY
        WITH SYNONYMS ('重要度', '深刻度', 'セベリティ', '優先度', '緊急度')
        COMMENT = 'アラームの重要度（CRITICAL/WARNING/ALERT/NOTICE/INFO）',
    
    ALARMS.category AS ALARMS.CATEGORY
        WITH SYNONYMS ('カテゴリ', '分類', '種類', 'アラーム種別', 'タイプ')
        COMMENT = 'アラームのカテゴリ（NETWORK/DATABASE/SECURITY等）'
)

METRICS (
    ALARMS.total_alarms AS COUNT(*)
        WITH SYNONYMS ('アラーム件数', 'アラーム数', '総アラーム数', '件数', '発生件数', 'カウント')
        COMMENT = 'アラームの総件数',
    
    ALARMS.open_alarms AS COUNT_IF(ALARMS.STATUS = 'OPEN')
        WITH SYNONYMS ('オープン件数', '未対応件数', '対応中件数', 'OPEN件数')
        COMMENT = 'ステータスがOPENのアラーム件数',
    
    ALARMS.critical_alarms AS COUNT_IF(ALARMS.SEVERITY = 'CRITICAL')
        WITH SYNONYMS ('クリティカル件数', '緊急件数', 'CRITICAL件数', '重大アラーム数')
        COMMENT = '重要度がCRITICALのアラーム件数',
    
    ALARMS.warning_alarms AS COUNT_IF(ALARMS.SEVERITY = 'WARNING')
        WITH SYNONYMS ('ワーニング件数', '警告件数', 'WARNING件数')
        COMMENT = '重要度がWARNINGのアラーム件数'
)

COMMENT = '監視アラームデータのセマンティックビュー';


-- ============================================
-- Step 4: Cortex Search サービスの作成
-- ============================================

CREATE OR REPLACE CORTEX SEARCH SERVICE OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.MANUAL_SEARCH
    ON FULL_CONTENT
    ATTRIBUTES CATEGORY, SYSTEM_TYPE, TITLE, KEYWORDS
    WAREHOUSE = COMPUTE_WH
    TARGET_LAG = '1 hour'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    AS (
        SELECT * FROM OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.MANUALS
    );

-- Cortex Search の動作確認
SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.MANUAL_SEARCH',
    '{
        "query": "CPU使用率が高い",
        "columns": ["TITLE", "CATEGORY", "SYSTEM_TYPE"],
        "limit": 3
    }'
);


-- ============================================
-- Step 5: Cortex Agent の作成
-- ============================================

CREATE OR REPLACE AGENT OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.INCIDENT_RESPONSE_AGENT
    MODEL = 'claude-sonnet-4-5'
    TOOLS = (
        ANALYST_TOOL(
            SEMANTIC_VIEW => 'OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.ALARMS_SV',
            NAME => 'analyze_alarms',
            DESCRIPTION => 'アラームデータを分析します。カテゴリ別・重要度別・日次の件数集計、傾向分析、グラフ作成などが可能です。'
        ),
        CORTEX_SEARCH_TOOL(
            CORTEX_SEARCH_SERVICE => 'OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.MANUAL_SEARCH',
            NAME => 'search_manuals',
            DESCRIPTION => '運用マニュアルをセマンティック検索します。アラームの種類やシステム種別に応じた対応手順、サービス確認方法、復旧手順を検索できます。',
            ID_COLUMN => 'MANUAL_ID',
            TITLE_COLUMN => 'TITLE',
            MAX_RESULTS => 5
        )
    )
    ORCHESTRATION_CONFIG = (
        INSTRUCTIONS => 'ユーザーの質問に応じて適切なツールを選択してください：
- アラームの集計・分析・グラフ作成 → analyze_alarms ツール
- 対応マニュアルの検索 → search_manuals ツール
両方のツールを組み合わせて回答することも可能です。'
    )
    RESPONSE_CONFIG = (
        INSTRUCTIONS => 'あなたは運用監視システムのインシデント対応を支援するAIアシスタントです。

【役割】
- アラームデータを分析（集計・グラフ化）し、傾向を把握する
- アラーム情報から適切な対応マニュアルを検索して提案する
- 対応手順をわかりやすく説明する

【ツールの使い分け】
- analyze_alarms: アラームの集計、件数推移、カテゴリ別分析、グラフ作成など
- search_manuals: アラームに対応するマニュアルの検索、対応手順の取得など

【回答形式】
- 日本語で回答
- 対応手順は番号付きリストで明確に
- 重要な注意点は強調して表示
- グラフや集計結果がある場合は見やすく整理
- 参照したマニュアル情報を明記'
    )
    COMMENT = '運用監視システムのインシデント対応を支援するAIエージェント';


-- ============================================
-- セットアップ完了確認
-- ============================================

-- 作成されたオブジェクトの確認
SELECT 'Database' as object_type, 'OPERATIONS_MONITORING_DEMO' as object_name, 'OK' as status
UNION ALL SELECT 'Schema', 'INCIDENT_RESPONSE', 'OK'
UNION ALL SELECT 'Table', 'ALARMS (' || (SELECT COUNT(*) FROM ALARMS) || ' rows)', 'OK'
UNION ALL SELECT 'Table', 'MANUALS (' || (SELECT COUNT(*) FROM MANUALS) || ' rows)', 'OK'
UNION ALL SELECT 'Semantic View', 'ALARMS_SV', 'OK'
UNION ALL SELECT 'Cortex Search', 'MANUAL_SEARCH', 'OK'
UNION ALL SELECT 'Cortex Agent', 'INCIDENT_RESPONSE_AGENT', 'OK';

SELECT '🎉 Full setup completed! All objects have been created.' AS status;


-- ============================================
-- エージェント動作確認（オプション）
-- ============================================

/*
-- スレッドを作成
SELECT SNOWFLAKE.CORTEX.CREATE_THREAD() as thread_info;

-- エージェントに問い合わせ（thread_idを置き換え）
SELECT SNOWFLAKE.CORTEX.RUN_AGENT(
    'OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.INCIDENT_RESPONSE_AGENT',
    {
        'messages': [{
            'role': 'user',
            'content': [{'type': 'text', 'text': '2026年1月のカテゴリ別アラーム件数を教えてください'}]
        }],
        'thread_id': '<YOUR_THREAD_ID>',
        'parent_message_id': '0'
    }
);
*/


-- ============================================
-- クリーンアップ（環境削除時に実行）
-- ============================================

/*

USE ROLE ACCOUNTADMIN;

-- Cortex Agent
DROP AGENT IF EXISTS OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.INCIDENT_RESPONSE_AGENT;

-- Cortex Search サービス
DROP CORTEX SEARCH SERVICE IF EXISTS OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.MANUAL_SEARCH;

-- セマンティックビュー
DROP SEMANTIC VIEW IF EXISTS OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.ALARMS_SV;

-- Snowflake Intelligence オブジェクト
DROP SNOWFLAKE INTELLIGENCE IF EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

-- データベース（テーブル、ステージ、Git統合も削除）
DROP DATABASE IF EXISTS OPERATIONS_MONITORING_DEMO;

-- Git連携
DROP API INTEGRATION IF EXISTS GIT_API_INTEGRATION;

SELECT 'Cleanup completed successfully!' AS status;

*/
