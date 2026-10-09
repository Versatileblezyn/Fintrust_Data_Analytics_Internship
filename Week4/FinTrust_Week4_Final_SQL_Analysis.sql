/*
FINTRUST DIGITAL BANK — WEEK 4 FINAL SQL ANALYSIS
Track: Data Analytics
Purpose: Final review, analysis, validation and business decision support.

IMPORTANT NOTES
1. Run this script in the PostgreSQL database containing fintrust_customer
   and fintrust_transaction.
2. The dataset is synthetic and covers 1 January 2026 to 31 March 2026.
3. Risk_Review_Flag is a synthetic educational review label, NOT a real fraud
   determination or production banking risk decision.
4. Amounts are in Nigerian naira (NGN).
5. The script is organised into separate queries. Execute each query separately
   if your SQL editor does not support running the entire file at once.

CONTENTS
A. Core KPI validation
B. Data integrity checks
C. Customer segment profile
D. Transaction type performance
E. Channel performance
F. Transaction status performance
G. Monthly transaction trends
H. Customer frequency and value
I. Segment and channel behaviour
J. Success rate by transaction type and channel
K. High-value transaction concentration
L. Risk-review patterns by scope, type and channel
M. Unsuccessful transaction concentration
N. Customer ranking using window functions
O. Digital engagement validation
P. Transaction value by status
Q. KPI and finding validation summary
*/


/* A1. CORE KPI VALIDATION
Business question: Do the core dashboard KPIs reproduce directly from PostgreSQL?
Expected: 1,500 customers; 12,000 transactions; total value NGN 560,477,354.85;
average transaction value NGN 46,706.45; success 90.47%; review 19.60%.
*/
SELECT
    (SELECT COUNT(DISTINCT customer_id)
     FROM fintrust_customer) AS total_customers,
    COUNT(DISTINCT transaction_id) AS total_transactions,
    ROUND(SUM(amount_ngn), 2) AS total_transaction_value_ngn,
    ROUND(SUM(amount_ngn) / COUNT(DISTINCT transaction_id), 2)
        AS average_transaction_value_ngn,
    ROUND(100.0 * COUNT(*) FILTER (
        WHERE transaction_status = 'Successful'
    ) / COUNT(*), 2) AS transaction_success_rate_pct,
    ROUND(100.0 * COUNT(*) FILTER (
        WHERE risk_review_flag = 'Yes'
    ) / COUNT(*), 2) AS risk_review_rate_pct
FROM fintrust_transaction;


/* B1. DATA INTEGRITY: ROW COUNTS AND UNIQUE TRANSACTION IDS */
SELECT
    COUNT(*) AS transaction_rows,
    COUNT(DISTINCT transaction_id) AS distinct_transaction_ids,
    COUNT(*) - COUNT(DISTINCT transaction_id) AS duplicate_id_count
FROM fintrust_transaction;


/* B2. DATA INTEGRITY: TRANSACTIONS WITHOUT A MATCHING CUSTOMER */
SELECT COUNT(*) AS orphan_transaction_customer_ids
FROM fintrust_transaction t
LEFT JOIN fintrust_customer c ON t.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


/* B3. DATA QUALITY: MISSING DEVICE AND LOCATION VALUES
Use this against the raw table if missing values were preserved there.
If running against cleaned data, 'Unknown' values are reported separately.
*/
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE device_type IS NULL OR TRIM(device_type) = ''
    ) AS missing_device_type,
    COUNT(*) FILTER (
        WHERE location IS NULL OR TRIM(location) = ''
    ) AS missing_location,
    COUNT(*) FILTER (
        WHERE device_type = 'Unknown'
    ) AS device_type_unknown,
    COUNT(*) FILTER (
        WHERE location = 'Unknown'
    ) AS location_unknown
FROM fintrust_transaction;


/* C1. CUSTOMER DISTRIBUTION BY SEGMENT
Business meaning: Establishes the size of each segment before comparing behaviour.
*/
SELECT
    customer_segment,
    COUNT(DISTINCT customer_id) AS customers,
    ROUND(
        100.0 * COUNT(DISTINCT customer_id)
        / SUM(COUNT(DISTINCT customer_id)) OVER (), 2
    ) AS customer_share_pct
FROM fintrust_customer
GROUP BY customer_segment
ORDER BY customers DESC;


/* C2. TRANSACTION ACTIVITY AND VALUE BY CUSTOMER SEGMENT
Uses JOIN, GROUP BY and aggregates.
*/
SELECT
    c.customer_segment,
    COUNT(DISTINCT c.customer_id) AS customers,
    COUNT(DISTINCT t.transaction_id) AS transactions,
    ROUND(SUM(t.amount_ngn), 2) AS total_transaction_value_ngn,
    ROUND(AVG(t.amount_ngn), 2) AS average_transaction_value_ngn,
    ROUND(
        COUNT(DISTINCT t.transaction_id)::numeric
        / NULLIF(COUNT(DISTINCT c.customer_id), 0), 2
    ) AS average_transactions_per_customer
FROM fintrust_customer c
JOIN fintrust_transaction t ON c.customer_id = t.customer_id
GROUP BY c.customer_segment
ORDER BY total_transaction_value_ngn DESC;


/* D1. TRANSACTION TYPE PERFORMANCE
Business question: Which transaction types contribute the most activity and value?
*/
SELECT
    transaction_type,
    COUNT(*) AS transactions,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2
    ) AS transaction_share_pct,
    ROUND(SUM(amount_ngn), 2) AS total_value_ngn,
    ROUND(AVG(amount_ngn), 2) AS average_value_ngn
FROM fintrust_transaction
GROUP BY transaction_type
ORDER BY transactions DESC;


/* E1. CHANNEL PERFORMANCE
Compare channel volume, value, average transaction amount and success rate.
*/
SELECT
    channel,
    COUNT(*) AS transactions,
    ROUND(SUM(amount_ngn), 2) AS total_value_ngn,
    ROUND(AVG(amount_ngn), 2) AS average_value_ngn,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE transaction_status = 'Successful'
        ) / COUNT(*), 2
    ) AS success_rate_pct
FROM fintrust_transaction
GROUP BY channel
ORDER BY transactions DESC;


/* F1. TRANSACTION STATUS DISTRIBUTION */
SELECT
    transaction_status,
    COUNT(*) AS transactions,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS transaction_share_pct,
    ROUND(SUM(amount_ngn), 2) AS total_value_ngn,
    ROUND(
        100.0 * SUM(amount_ngn) / SUM(SUM(amount_ngn)) OVER (), 2
    ) AS value_share_pct
FROM fintrust_transaction
GROUP BY transaction_status
ORDER BY transactions DESC;


/* F2. STATUS RATES BY TRANSACTION TYPE
CASE provides explicit status counts for business comparison.
*/
SELECT
    transaction_type,
    COUNT(*) AS total_transactions,
    COUNT(*) FILTER (WHERE transaction_status = 'Successful') AS successful,
    COUNT(*) FILTER (WHERE transaction_status = 'Failed') AS failed,
    COUNT(*) FILTER (WHERE transaction_status = 'Reversed') AS reversed,
    COUNT(*) FILTER (WHERE transaction_status = 'Pending') AS pending,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE transaction_status = 'Successful')
        / COUNT(*), 2
    ) AS success_rate_pct,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE transaction_status = 'Failed')
        / COUNT(*), 2
    ) AS failure_rate_pct
FROM fintrust_transaction
GROUP BY transaction_type
ORDER BY failure_rate_pct DESC;


/* G1. MONTHLY TRANSACTION TRENDS */
SELECT
    DATE_TRUNC('month', transaction_datetime)::date AS transaction_month,
    COUNT(*) AS transactions,
    ROUND(SUM(amount_ngn), 2) AS total_value_ngn,
    ROUND(AVG(amount_ngn), 2) AS average_value_ngn,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE transaction_status = 'Successful'
        ) / COUNT(*), 2
    ) AS success_rate_pct
FROM fintrust_transaction
GROUP BY DATE_TRUNC('month', transaction_datetime)
ORDER BY transaction_month;


/* H1. CUSTOMER TRANSACTION FREQUENCY AND TOTAL VALUE
CTE aggregates at customer level, then groups customers by transaction frequency.
*/
WITH customer_activity AS (
    SELECT
        c.customer_id,
        c.customer_segment,
        COUNT(t.transaction_id) AS transaction_count,
        COALESCE(SUM(t.amount_ngn), 0) AS total_customer_value
    FROM fintrust_customer c
    LEFT JOIN fintrust_transaction t ON c.customer_id = t.customer_id
    GROUP BY c.customer_id, c.customer_segment
),
frequency_groups AS (
    SELECT *,
        CASE
            WHEN transaction_count BETWEEN 1 AND 5 THEN '1-5 transactions'
            WHEN transaction_count BETWEEN 6 AND 10 THEN '6-10 transactions'
            WHEN transaction_count BETWEEN 11 AND 15 THEN '11-15 transactions'
            ELSE '16-20 transactions'
        END AS frequency_group
    FROM customer_activity
)
SELECT
    frequency_group,
    COUNT(*) AS customers,
    ROUND(AVG(transaction_count), 2) AS average_transactions_per_customer,
    ROUND(AVG(total_customer_value), 2) AS average_customer_value_ngn,
    ROUND(SUM(total_customer_value), 2) AS group_total_value_ngn
FROM frequency_groups
GROUP BY frequency_group
ORDER BY MIN(transaction_count);


/* I1. CHANNEL SHARE WITHIN EACH CUSTOMER SEGMENT */
WITH segment_channel AS (
    SELECT
        c.customer_segment,
        t.channel,
        COUNT(*) AS transactions
    FROM fintrust_customer c
    JOIN fintrust_transaction t ON c.customer_id = t.customer_id
    GROUP BY c.customer_segment, t.channel
)
SELECT
    customer_segment,
    channel,
    transactions,
    ROUND(
        100.0 * transactions
        / SUM(transactions) OVER (PARTITION BY customer_segment), 2
    ) AS channel_share_within_segment_pct,
    RANK() OVER (
        PARTITION BY customer_segment ORDER BY transactions DESC
    ) AS channel_volume_rank
FROM segment_channel
ORDER BY customer_segment, channel_volume_rank;


/* J1. SUCCESS RATE BY TRANSACTION TYPE AND CHANNEL */
SELECT
    transaction_type,
    channel,
    COUNT(*) AS transactions,
    COUNT(*) FILTER (
        WHERE transaction_status = 'Successful'
    ) AS successful_transactions,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE transaction_status = 'Successful'
        ) / COUNT(*), 2
    ) AS success_rate_pct
FROM fintrust_transaction
GROUP BY transaction_type, channel
ORDER BY transaction_type, success_rate_pct DESC;


/* K1. HIGH-VALUE TRANSACTION CONCENTRATION
High-value means Amount_NGN at or above the dataset's 90th percentile.
This is a value-concentration analysis, not a fraud-risk test.
*/
WITH threshold AS (
    SELECT PERCENTILE_CONT(0.90) WITHIN GROUP (
        ORDER BY amount_ngn
    ) AS high_value_threshold
    FROM fintrust_transaction
),
classified AS (
    SELECT
        t.*,
        CASE
            WHEN t.amount_ngn >= th.high_value_threshold
                THEN 'High-value (top 10%)'
            ELSE 'Regular'
        END AS value_group
    FROM fintrust_transaction t
    CROSS JOIN threshold th
)
SELECT
    value_group,
    COUNT(*) AS transactions,
    ROUND(SUM(amount_ngn), 2) AS total_value_ngn,
    ROUND(AVG(amount_ngn), 2) AS average_value_ngn,
    ROUND(
        100.0 * SUM(amount_ngn)
        / SUM(SUM(amount_ngn)) OVER (), 2
    ) AS share_of_total_transaction_value_pct
FROM classified
GROUP BY value_group
ORDER BY total_value_ngn DESC;


/* K2. SHOW THE HIGH-VALUE THRESHOLD USED */
SELECT
    ROUND(
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY amount_ngn)::numeric,
        2
    ) AS 90th_percentile_threshold_ngn
FROM fintrust_transaction;


/* L1. RISK-REVIEW RATE BY INTERNATIONAL / DOMESTIC SCOPE
The flag is synthetic and must not be interpreted as fraud.
*/
SELECT
    CASE
        WHEN international_transaction = 'Yes' THEN 'International'
        WHEN international_transaction = 'No' THEN 'Domestic'
        ELSE 'Unknown'
    END AS transaction_scope,
    COUNT(*) AS transactions,
    COUNT(*) FILTER (WHERE risk_review_flag = 'Yes') AS review_label_yes,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE risk_review_flag = 'Yes')
        / COUNT(*), 2
    ) AS observed_review_rate_pct
FROM fintrust_transaction
GROUP BY
    CASE
        WHEN international_transaction = 'Yes' THEN 'International'
        WHEN international_transaction = 'No' THEN 'Domestic'
        ELSE 'Unknown'
    END
ORDER BY observed_review_rate_pct DESC;


/* L2. INTERNATIONAL VS DOMESTIC REVIEW RATE BY TRANSACTION TYPE */
SELECT
    transaction_type,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE international_transaction = 'Yes'
              AND risk_review_flag = 'Yes'
        ) / NULLIF(COUNT(*) FILTER (
            WHERE international_transaction = 'Yes'
        ), 0), 2
    ) AS international_review_rate_pct,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE international_transaction = 'No'
              AND risk_review_flag = 'Yes'
        ) / NULLIF(COUNT(*) FILTER (
            WHERE international_transaction = 'No'
        ), 0), 2
    ) AS domestic_review_rate_pct,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE international_transaction = 'Yes'
              AND risk_review_flag = 'Yes'
        ) / NULLIF(COUNT(*) FILTER (
            WHERE international_transaction = 'Yes'
        ), 0)
        -
        100.0 * COUNT(*) FILTER (
            WHERE international_transaction = 'No'
              AND risk_review_flag = 'Yes'
        ) / NULLIF(COUNT(*) FILTER (
            WHERE international_transaction = 'No'
        ), 0), 2
    ) AS difference_percentage_points
FROM fintrust_transaction
GROUP BY transaction_type
ORDER BY difference_percentage_points DESC;


/* L3. RISK-REVIEW RATE BY CHANNEL */
SELECT
    channel,
    COUNT(*) AS transactions,
    COUNT(*) FILTER (WHERE risk_review_flag = 'Yes') AS review_label_yes,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE risk_review_flag = 'Yes')
        / COUNT(*), 2
    ) AS observed_review_rate_pct
FROM fintrust_transaction
GROUP BY channel
ORDER BY observed_review_rate_pct DESC;


/* M1. UNSUCCESSFUL TRANSACTION VOLUME AND RATE BY TYPE + CHANNEL
Unsuccessful is defined for this analysis as Failed, Reversed or Pending.
*/
WITH combination_summary AS (
    SELECT
        transaction_type,
        channel,
        COUNT(*) AS total_transactions,
        COUNT(*) FILTER (
            WHERE transaction_status IN ('Failed', 'Reversed', 'Pending')
        ) AS unsuccessful_transactions
    FROM fintrust_transaction
    GROUP BY transaction_type, channel
)
SELECT
    transaction_type,
    channel,
    total_transactions,
    unsuccessful_transactions,
    ROUND(
        100.0 * unsuccessful_transactions / NULLIF(total_transactions, 0), 2
    ) AS unsuccessful_rate_pct,
    ROUND(
        100.0 * unsuccessful_transactions
        / SUM(unsuccessful_transactions) OVER (), 2
    ) AS share_of_all_unsuccessful_pct
FROM combination_summary
ORDER BY unsuccessful_transactions DESC;


/* N1. CUSTOMER RANKING: FREQUENCY VS TOTAL VALUE
Window functions show that frequency and value rankings may differ.
*/
WITH customer_activity AS (
    SELECT
        c.customer_id,
        c.customer_segment,
        COUNT(t.transaction_id) AS transaction_count,
        COALESCE(SUM(t.amount_ngn), 0) AS total_customer_value,
        COALESCE(AVG(t.amount_ngn), 0) AS average_transaction_value
    FROM fintrust_customer c
    LEFT JOIN fintrust_transaction t ON c.customer_id = t.customer_id
    GROUP BY c.customer_id, c.customer_segment
)
SELECT
    customer_id,
    customer_segment,
    transaction_count,
    ROUND(total_customer_value, 2) AS total_customer_value_ngn,
    ROUND(average_transaction_value, 2) AS average_transaction_value_ngn,
    RANK() OVER (ORDER BY transaction_count DESC) AS transaction_count_rank,
    RANK() OVER (ORDER BY total_customer_value DESC) AS total_value_rank
FROM customer_activity
ORDER BY total_value_rank
LIMIT 25;


/* O1. DIGITAL ENGAGEMENT QUARTILES AND CUSTOMER ACTIVITY
NTILE creates four similarly sized groups. Treat results as descriptive.
*/
WITH customer_activity AS (
    SELECT
        c.customer_id,
        c.digital_engagement_score,
        COUNT(t.transaction_id) AS transaction_count,
        COALESCE(SUM(t.amount_ngn), 0) AS total_customer_value
    FROM fintrust_customer c
    LEFT JOIN fintrust_transaction t ON c.customer_id = t.customer_id
    GROUP BY c.customer_id, c.digital_engagement_score
),
engagement_quartiles AS (
    SELECT *,
        NTILE(4) OVER (ORDER BY digital_engagement_score) AS engagement_quartile
    FROM customer_activity
)
SELECT
    engagement_quartile,
    COUNT(*) AS customers,
    ROUND(AVG(digital_engagement_score), 2) AS average_engagement_score,
    ROUND(AVG(transaction_count), 2) AS average_transactions_per_customer,
    ROUND(AVG(total_customer_value), 2) AS average_customer_value_ngn
FROM engagement_quartiles
GROUP BY engagement_quartile
ORDER BY engagement_quartile;


/* O2. DIGITAL ENGAGEMENT CORRELATION CHECK
PostgreSQL corr() returns Pearson correlation. Values near zero indicate a weak
linear relationship in this dataset; correlation does not establish causation.
*/
WITH customer_activity AS (
    SELECT
        c.customer_id,
        c.digital_engagement_score,
        COUNT(t.transaction_id) AS transaction_count,
        COALESCE(SUM(t.amount_ngn), 0) AS total_customer_value
    FROM fintrust_customer c
    LEFT JOIN fintrust_transaction t ON c.customer_id = t.customer_id
    GROUP BY c.customer_id, c.digital_engagement_score
)
SELECT
    COUNT(*) AS customers,
    ROUND(CORR(digital_engagement_score, transaction_count)::numeric, 4)
        AS engagement_vs_transaction_count_correlation,
    ROUND(CORR(digital_engagement_score, total_customer_value)::numeric, 4)
        AS engagement_vs_total_value_correlation
FROM customer_activity;


/* P1. TRANSACTION VALUE BY STATUS */
SELECT
    transaction_status,
    COUNT(*) AS transactions,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS transaction_share_pct,
    ROUND(SUM(amount_ngn), 2) AS total_value_ngn,
    ROUND(
        100.0 * SUM(amount_ngn) / SUM(SUM(amount_ngn)) OVER (), 2
    ) AS value_share_pct,
    ROUND(AVG(amount_ngn), 2) AS average_transaction_value_ngn
FROM fintrust_transaction
GROUP BY transaction_status
ORDER BY total_value_ngn DESC;


/* Q1. VALIDATION SUMMARY: KEY TOTALS USED IN THE PROJECT */
SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT transaction_id) AS distinct_transaction_ids,
    ROUND(SUM(amount_ngn), 2) AS total_transaction_value_ngn,
    COUNT(*) FILTER (
        WHERE transaction_status IN ('Failed', 'Reversed', 'Pending')
    ) AS unsuccessful_transactions,
    COUNT(*) FILTER (WHERE risk_review_flag = 'Yes') AS review_label_yes,
    COUNT(*) FILTER (WHERE international_transaction = 'Yes')
        AS international_transactions,
    COUNT(*) FILTER (WHERE international_transaction = 'No')
        AS domestic_transactions
FROM fintrust_transaction;


/* Q2. VALIDATION: TRANSACTION STATUS TOTALS
Expected: 10,856 successful; 630 failed; 326 reversed; 188 pending;
1,144 unsuccessful in total.
*/
SELECT
    transaction_status,
    COUNT(*) AS transactions
FROM fintrust_transaction
GROUP BY transaction_status
ORDER BY transaction_status;


/* Q3. VALIDATION: CUSTOMER TRANSACTION COVERAGE
Checks whether each customer has at least one transaction and shows frequency range.
*/
WITH activity AS (
    SELECT
        c.customer_id,
        COUNT(t.transaction_id) AS transaction_count
    FROM fintrust_customer c
    LEFT JOIN fintrust_transaction t ON c.customer_id = t.customer_id
    GROUP BY c.customer_id
)
SELECT
    COUNT(*) AS customers,
    COUNT(*) FILTER (WHERE transaction_count = 0) AS customers_without_transactions,
    MIN(transaction_count) AS minimum_transactions_per_customer,
    MAX(transaction_count) AS maximum_transactions_per_customer,
    ROUND(AVG(transaction_count), 2) AS average_transactions_per_customer
FROM activity;


/*
FINAL INTERPRETATION GUIDANCE
- Mobile App is the highest-volume channel in each customer segment in the
  completed analysis; use this to prioritise monitoring, not to claim it is
  universally the most successful channel.
- Top 10% of transactions represented 56.15% of total value. This is value
  concentration, not evidence of suspicious or fraudulent behaviour.
- International observed review rate was 36.88%, versus 18.88% domestic.
  International sample size was 480 compared with 11,520 domestic transactions.
- Digital engagement correlations were approximately 0.0380 for transaction
  count and 0.0241 for total customer value: very weak linear relationships.
- Transfer + Mobile App had 167 unsuccessful transactions; Card Purchase +
  Mobile App had 134. Review both volume and rate when prioritising investigation.
- The data is synthetic and covers three months only. Findings are descriptive,
  not causal, and must not be presented as production banking conclusions.
*/
