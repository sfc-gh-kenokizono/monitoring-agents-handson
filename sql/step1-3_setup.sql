-- ============================================================================
-- Step 1-3: 環境セットアップ
-- ============================================================================
-- データベース、スキーマ、テーブルを作成し、Git連携でサンプルデータをロードします。
-- Snowflake Intelligence オブジェクトとセマンティックビューも作成します。
-- ============================================================================

-- ロール設定（必要に応じて変更）
USE ROLE ACCOUNTADMIN;

-- ============================================
-- Step 1: データベース・スキーマのセットアップ
-- ============================================

CREATE DATABASE IF NOT EXISTS OPERATIONS_MONITORING_DEMO;
USE DATABASE OPERATIONS_MONITORING_DEMO;

CREATE SCHEMA IF NOT EXISTS INCIDENT_RESPONSE;
USE SCHEMA INCIDENT_RESPONSE;

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

-- アラームテーブル：監視アラームデータを格納
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

-- マニュアルテーブル：対応マニュアルを格納
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

-- 期待される結果:
-- | TABLE_NAME | RECORD_COUNT |
-- |------------|--------------|
-- | Manuals    | 100          |
-- | Alarms     | 3000         |


-- ============================================
-- Step 3-1: Snowflake Intelligence オブジェクトの作成
-- ============================================
-- Cortex Agentを使用するために必要なオブジェクトです

CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;
GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE ACCOUNTADMIN;
GRANT MODIFY ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE ACCOUNTADMIN;


-- ============================================
-- Step 3-2: セマンティックビューの作成
-- ============================================
-- ALARMSテーブルに対するCortex Analyst用のセマンティックビューです。
-- 「カテゴリ別アラーム数」「月別推移」などの分析クエリを自然言語で実行できます。

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
-- セットアップ完了
-- ============================================
SELECT 'Setup completed! Next: Create Cortex Search (Step 4)' AS status;


-- ============================================
-- クリーンアップ（ハンズオン終了後に実行）
-- ============================================
-- 注意: 以下のコマンドはハンズオン環境を完全に削除します。
-- 必要な場合のみ、ACCOUNTADMINロールで実行してください。
-- ============================================

/*

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

SELECT 'Cleanup completed successfully!' AS status;

*/
