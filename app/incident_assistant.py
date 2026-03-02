import streamlit as st
import json

st.set_page_config(
    page_title="インシデント対応アシスタント",
    page_icon="🚨",
    layout="wide"
)

try:
    from snowflake.snowpark.context import get_active_session
    session = get_active_session()
except:
    from snowflake.snowpark import Session
    session = Session.builder.config('connection_name', 'default').create()

DATABASE = "OPERATIONS_MONITORING_DEMO"
SCHEMA = "INCIDENT_RESPONSE"
AGENT_NAME = "INCIDENT_RESPONSE_AGENT"

def call_agent(user_message: str, thread_id: str = None, parent_message_id: str = "0"):
    if thread_id is None:
        result = session.sql("SELECT SNOWFLAKE.CORTEX.CREATE_THREAD()").collect()
        thread_data = json.loads(result[0][0])
        thread_id = thread_data["thread_id"]
    
    escaped_message = user_message.replace("'", "''")
    query = f"""
    SELECT SNOWFLAKE.CORTEX.RUN_AGENT(
        '{DATABASE}.{SCHEMA}.{AGENT_NAME}',
        {{
            'messages': [{{
                'role': 'user',
                'content': [{{'type': 'text', 'text': '{escaped_message}'}}]
            }}],
            'thread_id': '{thread_id}',
            'parent_message_id': '{parent_message_id}'
        }}
    )
    """
    
    result = session.sql(query).collect()
    response_data = json.loads(result[0][0])
    return response_data, thread_id

st.title("🚨 インシデント対応アシスタント")
st.markdown("**Cortex Agent** がアラーム情報を分析し、最適な対応マニュアルと手順を提案します")

if "thread_id" not in st.session_state:
    st.session_state.thread_id = None
if "messages" not in st.session_state:
    st.session_state.messages = []
if "parent_message_id" not in st.session_state:
    st.session_state.parent_message_id = "0"

col1, col2 = st.columns([1, 2])

with col1:
    st.subheader("📋 アクティブアラーム")
    
    alarms_df = session.sql(f"""
        SELECT ALARM_ID, TIMESTAMP, SYSTEM_TYPE, ALARM_HOST, ALARM_MESSAGE, SEVERITY, CATEGORY
        FROM {DATABASE}.{SCHEMA}.ALARMS 
        WHERE STATUS = 'OPEN'
        ORDER BY 
            CASE SEVERITY 
                WHEN 'CRITICAL' THEN 1 
                WHEN 'WARNING' THEN 2 
                WHEN 'ALERT' THEN 3 
                WHEN 'NOTICE' THEN 4 
            END,
            TIMESTAMP DESC
        LIMIT 15
    """).collect()
    
    severity_colors = {
        "CRITICAL": "🔴",
        "WARNING": "🟡", 
        "ALERT": "🟠",
        "NOTICE": "🔵",
        "INFO": "🟢"
    }
    
    for row in alarms_df:
        alarm_id = row['ALARM_ID']
        ts = row['TIMESTAMP']
        sys_type = row['SYSTEM_TYPE']
        host = row['ALARM_HOST']
        msg = row['ALARM_MESSAGE']
        severity = row['SEVERITY']
        category = row['CATEGORY']
        icon = severity_colors.get(severity, "⚪")
        
        with st.expander(f"{icon} {host}", expanded=False):
            st.caption(f"**ID:** {alarm_id} | **時刻:** {ts}")
            st.caption(f"**種別:** {sys_type} | **カテゴリ:** {category}")
            st.text(msg[:100] + "..." if len(msg) > 100 else msg)
            if st.button("🔍 このアラームを分析", key=alarm_id):
                query = f"""以下のアラームが発生しました。対応方法を教えてください。

アラームID: {alarm_id}
システム種別: {sys_type}
カテゴリ: {category}
重要度: {severity}
発生ホスト: {host}
アラームメッセージ: {msg}"""
                st.session_state.pending_query = query

with col2:
    st.subheader("💬 エージェントとの対話")
    
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])
    
    if "pending_query" in st.session_state:
        user_input = st.session_state.pending_query
        del st.session_state.pending_query
        
        st.session_state.messages.append({"role": "user", "content": user_input})
        with st.chat_message("user"):
            st.markdown(user_input)
        
        with st.chat_message("assistant"):
            with st.spinner("分析中..."):
                try:
                    response, thread_id = call_agent(
                        user_input, 
                        st.session_state.thread_id,
                        st.session_state.parent_message_id
                    )
                    st.session_state.thread_id = thread_id
                    
                    if "message" in response and "content" in response["message"]:
                        content_list = response["message"]["content"]
                        assistant_text = ""
                        for item in content_list:
                            if item.get("type") == "text":
                                assistant_text += item.get("text", "")
                        
                        if "message_id" in response["message"]:
                            st.session_state.parent_message_id = response["message"]["message_id"]
                    else:
                        assistant_text = str(response)
                    
                    st.markdown(assistant_text)
                    st.session_state.messages.append({"role": "assistant", "content": assistant_text})
                except Exception as e:
                    error_msg = f"エラーが発生しました: {str(e)}"
                    st.error(error_msg)
                    st.session_state.messages.append({"role": "assistant", "content": error_msg})
        
        st.rerun()
    
    user_input = st.chat_input("アラームについて質問してください...")
    
    if user_input:
        st.session_state.messages.append({"role": "user", "content": user_input})
        with st.chat_message("user"):
            st.markdown(user_input)
        
        with st.chat_message("assistant"):
            with st.spinner("分析中..."):
                try:
                    response, thread_id = call_agent(
                        user_input, 
                        st.session_state.thread_id,
                        st.session_state.parent_message_id
                    )
                    st.session_state.thread_id = thread_id
                    
                    if "message" in response and "content" in response["message"]:
                        content_list = response["message"]["content"]
                        assistant_text = ""
                        for item in content_list:
                            if item.get("type") == "text":
                                assistant_text += item.get("text", "")
                        
                        if "message_id" in response["message"]:
                            st.session_state.parent_message_id = response["message"]["message_id"]
                    else:
                        assistant_text = str(response)
                    
                    st.markdown(assistant_text)
                    st.session_state.messages.append({"role": "assistant", "content": assistant_text})
                except Exception as e:
                    error_msg = f"エラーが発生しました: {str(e)}"
                    st.error(error_msg)
                    st.session_state.messages.append({"role": "assistant", "content": error_msg})
        
        st.rerun()

with st.sidebar:
    st.markdown("---")
    st.subheader("ℹ️ このデモについて")
    st.markdown("""
    **Cortex Agent** を使用したインシデント対応支援システムです。
    
    **機能:**
    - 📊 アラームデータの集計・分析・グラフ化
    - 🔍 アラームからマニュアルを意味検索
    - 🤖 AIが状況を分析し最適な手順を提案
    - 💬 対話形式で追加質問が可能
    
    **技術スタック:**
    - Snowflake Cortex Agent
    - Cortex Analyst (セマンティックビュー)
    - Cortex Search (RAG)
    - Claude Sonnet 4.5
    """)
    
    if st.button("🔄 会話をリセット"):
        st.session_state.thread_id = None
        st.session_state.messages = []
        st.session_state.parent_message_id = "0"
        st.rerun()
