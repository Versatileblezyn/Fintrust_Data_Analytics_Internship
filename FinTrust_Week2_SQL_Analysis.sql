-- FinTrust Digital Bank | AnalystLab Africa Experience Lab | Week 2 SQL Analysis
-- Data Analytics Track
-- Structure: Business Question -> SQL Query -> Result -> Business Interpretation
-- Risk_Review_Flag is a synthetic review indicator, not confirmed fraud.

-- ============================================================
-- Q1. CUSTOMER SEGMENT TRANSACTION ACTIVITY
-- ============================================================
-- Business Question:
-- How does transaction activity differ across FinTrust's customer segments?

SELECT
    c.Customer_Segment,
    COUNT(t.Transaction_ID) AS Transaction_Count,
    ROUND(
        COUNT(t.Transaction_ID)::NUMERIC / COUNT(DISTINCT c.Customer_ID),
        2
    ) AS Avg_Transactions_Per_Customer,
    ROUND(SUM(t.Amount_NGN), 2) AS Total_Transaction_Value_NGN
FROM fintrust_customer c
JOIN fintrust_transaction t
    ON c.Customer_ID = t.Customer_ID
GROUP BY c.Customer_Segment
ORDER BY Transaction_Count DESC;

-- Result:
-- Everyday customers generated the highest transaction volume and total
-- transaction value. SME customers had the highest average transaction value
-- per transaction in the supporting segment analysis.
--
-- Business Interpretation:
-- Transaction activity is not evenly distributed across customer segments.
-- Everyday customers contribute the largest overall activity, while segment
-- differences should be considered alongside segment size.

-- ============================================================
-- Q2. DIGITAL ENGAGEMENT AND TRANSACTION ACTIVITY
-- ============================================================
-- Business Question:
-- Is higher digital engagement associated with greater transaction activity?

WITH customer_activity AS (
    SELECT
        c.Customer_ID,
        c.Digital_Engagement_Score,
        COUNT(t.Transaction_ID) AS Transaction_Count
    FROM fintrust_customer c
    LEFT JOIN fintrust_transaction t
        ON c.Customer_ID = t.Customer_ID
    GROUP BY c.Customer_ID, c.Digital_Engagement_Score
),
engagement_groups AS (
    SELECT *,
        NTILE(4) OVER (ORDER BY Digital_Engagement_Score) AS Engagement_Quartile
    FROM customer_activity
)
SELECT
    Engagement_Quartile,
    COUNT(*) AS Customer_Count,
    ROUND(AVG(Digital_Engagement_Score), 2) AS Avg_Engagement_Score,
    ROUND(AVG(Transaction_Count), 2) AS Avg_Transactions_Per_Customer,
    SUM(Transaction_Count) AS Total_Transactions
FROM engagement_groups
GROUP BY Engagement_Quartile
ORDER BY Engagement_Quartile;

-- Result:
-- Q1: 375 customers; avg engagement 45.13; avg 7.96 transactions.
-- Q2: 375 customers; avg engagement 62.09; avg 7.88 transactions.
-- Q3: 375 customers; avg engagement 74.45; avg 7.90 transactions.
-- Q4: 375 customers; avg engagement 90.15; avg 8.26 transactions.
--
-- Business Interpretation:
-- The highest-engagement quartile shows somewhat higher transaction activity,
-- but the relationship is not consistently increasing across all quartiles.
-- This indicates an observed association rather than a causal relationship.

-- ============================================================
-- Q3. TRANSACTION TYPE ACTIVITY AND VALUE
-- ============================================================
-- Business Question:
-- Which transaction types generate the highest number of transactions and
-- overall transaction value?

SELECT
    Transaction_Type,
    COUNT(*) AS Transaction_Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS Percentage,
    ROUND(SUM(Amount_NGN), 2) AS Total_Transaction_Value_NGN
FROM fintrust_transaction
GROUP BY Transaction_Type
ORDER BY Transaction_Count DESC;

-- Result:
-- Transfer: 3,549 (29.58%), NGN 237,916,700.41
-- Card Purchase: 3,033 (25.28%), NGN 85,863,413.78
-- Bill Payment: 1,475 (12.29%), NGN 28,163,647.51
-- Cash Withdrawal: 1,430 (11.92%), NGN 67,772,362.11
-- Deposit: 1,328 (11.07%), NGN 130,985,059.85
-- Airtime/Data: 1,185 (9.88%), NGN 9,776,171.19
--
-- Business Interpretation:
-- Transfers dominate transaction frequency and total transaction value.
-- Deposits have fewer transactions than Card Purchases but substantially
-- higher total value, showing why frequency and value should be considered
-- together.

-- ============================================================
-- Q4. TRANSACTION VALUE BY CUSTOMER SEGMENT AND TYPE
-- ============================================================
-- Business Question:
-- How does transaction value vary across customer segments and transaction types?

SELECT
    c.Customer_Segment,
    t.Transaction_Type,
    COUNT(t.Transaction_ID) AS Transaction_Count,
    ROUND(SUM(t.Amount_NGN), 2) AS Total_Transaction_Value_NGN,
    ROUND(AVG(t.Amount_NGN), 2) AS Average_Transaction_Value_NGN
FROM fintrust_customer c
JOIN fintrust_transaction t
    ON c.Customer_ID = t.Customer_ID
GROUP BY c.Customer_Segment, t.Transaction_Type
ORDER BY c.Customer_Segment, Total_Transaction_Value_NGN DESC;

-- Result:
-- The analysis produced 24 customer-segment/transaction-type combinations
-- (4 customer segments x 6 transaction types).
-- Transfer generated the highest total transaction value within every
-- customer segment.
-- Everyday Transfer transactions contributed the highest segment/type
-- total value: NGN 114,072,916.25.
-- SME Deposit transactions recorded the highest average transaction value
-- among the segment/type combinations: NGN 105,341.70.
--
-- Business Interpretation:
-- Transaction value is influenced by both customer segment and transaction
-- type. Transfers are the major contributor to total transaction value
-- across all customer segments, while deposits show substantially higher
-- average transaction values in several segments. This indicates that
-- transaction frequency and transaction size provide different perspectives
-- on customer value.

-- ============================================================
-- Q5. CHANNEL USAGE AND PERFORMANCE
-- ============================================================
-- Business Question:
-- Which transaction channels are most frequently used, and how does
-- transaction performance differ across them?

SELECT
    Channel,
    COUNT(*) AS Transaction_Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS Percentage,
    ROUND(SUM(Amount_NGN), 2) AS Total_Transaction_Value_NGN
FROM fintrust_transaction
GROUP BY Channel
ORDER BY Transaction_Count DESC;

SELECT
    Channel,
    COUNT(*) AS Total_Transactions,
    SUM(CASE WHEN Transaction_Status = 'Successful' THEN 1 ELSE 0 END)
        AS Successful_Transactions,
    ROUND(
        SUM(CASE WHEN Transaction_Status = 'Successful' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS Success_Rate_Percentage
FROM fintrust_transaction
GROUP BY Channel
ORDER BY Success_Rate_Percentage DESC;

-- Result:
-- Mobile App: 5,102 transactions (42.52%), NGN 240,104,365.19.
-- Success rates range from 89.75% (Mobile App) to 91.70% (ATM).
--
-- Business Interpretation:
-- Mobile App is the dominant channel by transaction activity and value.
-- Channel success rates are relatively close, although Mobile App has the
-- lowest observed success rate among the channels.

-- ============================================================
-- Q6. TRANSACTION STATUS BY TRANSACTION TYPE
-- ============================================================
-- Business Question:
-- Which transaction types have the highest proportions of failed, pending
-- or reversed transactions?

SELECT
    Transaction_Type,
    COUNT(*) AS Total_Transactions,
    ROUND(
        SUM(CASE WHEN Transaction_Status = 'Successful' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS Success_Rate_Percentage,
    ROUND(
        SUM(CASE WHEN Transaction_Status = 'Failed' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS Failure_Rate_Percentage,
    ROUND(
        SUM(CASE WHEN Transaction_Status = 'Pending' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS Pending_Rate_Percentage,
    ROUND(
        SUM(CASE WHEN Transaction_Status = 'Reversed' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS Reversal_Rate_Percentage
FROM fintrust_transaction
GROUP BY Transaction_Type
ORDER BY Failure_Rate_Percentage DESC;

-- Result:
-- Bill Payment: highest failure rate (5.83%).
-- Airtime/Data: highest reversal rate (3.63%).
-- Transfer: highest pending rate (1.75%).
-- Deposit: highest success rate (91.19%).
--
-- Business Interpretation:
-- Different transaction types show different unsuccessful-transaction
-- patterns, suggesting that operational investigation may need to be
-- transaction-type specific.

-- ============================================================
-- Q7. RISK REVIEW BY TRANSACTION TYPE AND CHANNEL
-- ============================================================
-- Business Question:
-- How does the proportion of transactions marked for risk review vary
-- across transaction types and channels?

SELECT
    Transaction_Type,
    COUNT(*) AS Total_Transactions,
    SUM(CASE WHEN Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END)
        AS Risk_Review_Count,
    ROUND(
        SUM(CASE WHEN Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS Risk_Review_Rate_Percentage
FROM fintrust_transaction
GROUP BY Transaction_Type
ORDER BY Risk_Review_Rate_Percentage DESC;

SELECT
    Channel,
    COUNT(*) AS Total_Transactions,
    SUM(CASE WHEN Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END)
        AS Risk_Review_Count,
    ROUND(
        SUM(CASE WHEN Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS Risk_Review_Rate_Percentage
FROM fintrust_transaction
GROUP BY Channel
ORDER BY Risk_Review_Rate_Percentage DESC;

-- Result:
-- By type: Transfer 28.49%; Cash Withdrawal 25.31%; Deposit 16.19%;
-- Airtime/Data 15.19%; Card Purchase 13.02%; Bill Payment 12.81%.
-- By channel: Web 21.35%; ATM 21.18%; Mobile App 19.40%;
-- POS 18.35%; USSD 17.32%.
--
-- Business Interpretation:
-- Risk-review rates vary more across transaction types than across channels.
-- Transfers and Cash Withdrawals have the highest observed rates by type,
-- while Web and ATM have the highest observed rates by channel.

-- ============================================================
-- Q8. RISK REVIEW: INTERNATIONAL VS DOMESTIC
-- ============================================================
-- Business Question:
-- How does the proportion of transactions marked for risk review vary
-- between international and domestic transactions?

SELECT
    International_Transaction,
    COUNT(*) AS Total_Transactions,
    SUM(CASE WHEN Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END)
        AS Risk_Review_Count,
    ROUND(
        SUM(CASE WHEN Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS Risk_Review_Rate_Percentage
FROM fintrust_transaction
GROUP BY International_Transaction
ORDER BY Risk_Review_Rate_Percentage DESC;

-- Result:
-- International: 480 total; 177 risk reviews; 36.88%.
-- Domestic: 11,520 total; 2,175 risk reviews; 18.88%.
--
-- Business Interpretation:
-- International transactions have a substantially higher observed
-- risk-review rate, a difference of 18.00 percentage points. This is a
-- pattern for further investigation, not evidence of inherent risk or fraud.

-- ============================================================
-- Q9. RISK REVIEW BY CUSTOMER SEGMENT AND ACCOUNT TYPE
-- ============================================================
-- Business Question:
-- Are there noticeable differences in risk-review patterns across customer
-- segments and account types?

SELECT
    c.Customer_Segment,
    COUNT(t.Transaction_ID) AS Total_Transactions,
    SUM(CASE WHEN t.Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END)
        AS Risk_Review_Count,
    ROUND(
        SUM(CASE WHEN t.Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(t.Transaction_ID), 2
    ) AS Risk_Review_Rate_Percentage
FROM fintrust_customer c
JOIN fintrust_transaction t
    ON c.Customer_ID = t.Customer_ID
GROUP BY c.Customer_Segment
ORDER BY Risk_Review_Rate_Percentage DESC;

SELECT
    c.Account_Type,
    COUNT(t.Transaction_ID) AS Total_Transactions,
    SUM(CASE WHEN t.Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END)
        AS Risk_Review_Count,
    ROUND(
        SUM(CASE WHEN t.Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(t.Transaction_ID), 2
    ) AS Risk_Review_Rate_Percentage
FROM fintrust_customer c
JOIN fintrust_transaction t
    ON c.Customer_ID = t.Customer_ID
GROUP BY c.Account_Type
ORDER BY Risk_Review_Rate_Percentage DESC;

-- Result:
-- Segment: Premium 20.33%; Student 19.75%; SME 19.40%; Everyday 19.29%.
-- Account type: Savings 20.14%; Premium 20.08%; Current 18.03%.
--
-- Business Interpretation:
-- Risk-review rates are relatively consistent across customer segments and
-- account types, showing less variation than transaction type or international
-- status in this dataset.

-- ============================================================
-- Q10. RISK REVIEW BY DIGITAL ENGAGEMENT
-- ============================================================
-- Business Question:
-- Are there noticeable differences in risk-review patterns across
-- digital-engagement levels?

WITH customer_engagement AS (
    SELECT
        Customer_ID,
        Digital_Engagement_Score,
        NTILE(4) OVER (ORDER BY Digital_Engagement_Score)
            AS Engagement_Quartile
    FROM fintrust_customer
)
SELECT
    ce.Engagement_Quartile,
    COUNT(t.Transaction_ID) AS Total_Transactions,
    SUM(CASE WHEN t.Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END)
        AS Risk_Review_Count,
    ROUND(
        SUM(CASE WHEN t.Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(t.Transaction_ID), 2
    ) AS Risk_Review_Rate_Percentage
FROM customer_engagement ce
JOIN fintrust_transaction t
    ON ce.Customer_ID = t.Customer_ID
GROUP BY ce.Engagement_Quartile
ORDER BY ce.Engagement_Quartile;

-- Result:
-- Q1: 18.79%; Q2: 18.85%; Q3: 20.70%; Q4: 20.05%.
--
-- Business Interpretation:
-- Risk-review rates show only modest variation across engagement quartiles.
-- Digital engagement does not show a strong or consistently increasing
-- relationship with risk-review activity in this dataset.

-- END OF WEEK 2 SQL ANALYSIS
