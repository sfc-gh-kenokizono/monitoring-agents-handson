import streamlit as st
import altair as alt
import pandas as pd

st.set_page_config(layout="wide", page_title="Alarm Dashboard")

try:
    from snowflake.snowpark.context import get_active_session
    session = get_active_session()
except:
    from snowflake.snowpark import Session
    session = Session.builder.config('connection_name', 'default').create()

st.title("📊 Operations Monitoring Dashboard")

@st.cache_data(ttl=300)
def load_alarm_summary():
    return session.sql("""
        SELECT 
            COUNT(*) as total_alarms,
            COUNT_IF(STATUS = 'OPEN') as open_alarms,
            COUNT_IF(SEVERITY = 'CRITICAL') as critical_alarms,
            COUNT_IF(SEVERITY = 'WARNING') as warning_alarms
        FROM OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.ALARMS
    """).to_pandas()

@st.cache_data(ttl=300)
def load_daily_alarms():
    return session.sql("""
        SELECT 
            DATE(TIMESTAMP) as alarm_date,
            CATEGORY,
            COUNT(*) as alarm_count
        FROM OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.ALARMS
        GROUP BY 1, 2
        ORDER BY 1
    """).to_pandas()

@st.cache_data(ttl=300)
def load_hourly_alarms():
    return session.sql("""
        SELECT 
            HOUR(TIMESTAMP) as hour_of_day,
            COUNT(*) as alarm_count
        FROM OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.ALARMS
        GROUP BY 1
        ORDER BY 1
    """).to_pandas()

@st.cache_data(ttl=300)
def load_category_distribution():
    return session.sql("""
        SELECT CATEGORY, COUNT(*) as count
        FROM OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.ALARMS
        GROUP BY 1
        ORDER BY 2 DESC
    """).to_pandas()

@st.cache_data(ttl=300)
def load_severity_distribution():
    return session.sql("""
        SELECT SEVERITY, COUNT(*) as count
        FROM OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.ALARMS
        GROUP BY 1
        ORDER BY 2 DESC
    """).to_pandas()

@st.cache_data(ttl=300)
def load_recent_alarms(limit=20):
    return session.sql(f"""
        SELECT 
            ALARM_ID,
            TIMESTAMP,
            SYSTEM_TYPE,
            SEVERITY,
            CATEGORY,
            STATUS,
            SUBSTRING(ALARM_MESSAGE, 1, 100) || '...' as MESSAGE_PREVIEW
        FROM OPERATIONS_MONITORING_DEMO.INCIDENT_RESPONSE.ALARMS
        ORDER BY TIMESTAMP DESC
        LIMIT {limit}
    """).to_pandas()

summary = load_alarm_summary()
col1, col2, col3, col4 = st.columns(4)
with col1:
    st.metric("Total Alarms", f"{summary['TOTAL_ALARMS'].iloc[0]:,}")
with col2:
    st.metric("Open Alarms", f"{summary['OPEN_ALARMS'].iloc[0]:,}")
with col3:
    st.metric("Critical", f"{summary['CRITICAL_ALARMS'].iloc[0]:,}")
with col4:
    st.metric("Warning", f"{summary['WARNING_ALARMS'].iloc[0]:,}")

st.divider()

daily_df = load_daily_alarms()
daily_df['ALARM_DATE'] = pd.to_datetime(daily_df['ALARM_DATE'])

top_categories = daily_df.groupby('CATEGORY')['ALARM_COUNT'].sum().nlargest(5).index.tolist()
filtered_df = daily_df[daily_df['CATEGORY'].isin(top_categories)]

st.subheader("📈 Daily Alarm Trend (Top 5 Categories)")
chart = alt.Chart(filtered_df).mark_line(point=True).encode(
    x=alt.X('ALARM_DATE:T', title='Date'),
    y=alt.Y('ALARM_COUNT:Q', title='Alarm Count'),
    color=alt.Color('CATEGORY:N', title='Category'),
    tooltip=['ALARM_DATE:T', 'CATEGORY:N', 'ALARM_COUNT:Q']
).properties(height=350)
st.altair_chart(chart, use_container_width=True)

col1, col2 = st.columns(2)

with col1:
    st.subheader("🏷️ Alarms by Category")
    cat_df = load_category_distribution()
    pie_chart = alt.Chart(cat_df).mark_arc(innerRadius=50).encode(
        theta=alt.Theta('COUNT:Q'),
        color=alt.Color('CATEGORY:N', title='Category'),
        tooltip=['CATEGORY:N', 'COUNT:Q']
    ).properties(height=300)
    st.altair_chart(pie_chart, use_container_width=True)

with col2:
    st.subheader("⚠️ Alarms by Severity")
    sev_df = load_severity_distribution()
    severity_colors = {'CRITICAL': '#e74c3c', 'WARNING': '#f39c12', 'ALERT': '#e67e22', 'NOTICE': '#3498db', 'INFO': '#2ecc71'}
    bar_chart = alt.Chart(sev_df).mark_bar().encode(
        x=alt.X('SEVERITY:N', title='Severity', sort='-y'),
        y=alt.Y('COUNT:Q', title='Count'),
        color=alt.Color('SEVERITY:N', scale=alt.Scale(domain=list(severity_colors.keys()), range=list(severity_colors.values()))),
        tooltip=['SEVERITY:N', 'COUNT:Q']
    ).properties(height=300)
    st.altair_chart(bar_chart, use_container_width=True)

st.subheader("🕐 Hourly Distribution")
hourly_df = load_hourly_alarms()
hourly_chart = alt.Chart(hourly_df).mark_bar().encode(
    x=alt.X('HOUR_OF_DAY:O', title='Hour of Day'),
    y=alt.Y('ALARM_COUNT:Q', title='Alarm Count'),
    tooltip=['HOUR_OF_DAY:O', 'ALARM_COUNT:Q']
).properties(height=200)
st.altair_chart(hourly_chart, use_container_width=True)

st.subheader("📋 Recent Alarms")
recent_df = load_recent_alarms()
st.dataframe(recent_df, use_container_width=True)
