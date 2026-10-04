/*
FINTRUST DIGITAL BANK
WEEK 3 - ADVANCED SQL ANALYSIS
DATA ANALYTICS TRACK

Purpose:
This file develops the Week 2 SQL work into deeper, decision-focused
analysis for Week 3.

IMPORTANT:
- Keep FinTrust_Week2_SQL_Analysis.sql unchanged.
- Run these queries against the same fintrust database.
- Do NOT invent results. Record the actual output from pgAdmin.
- Risk_Review_Flag is a synthetic review indicator. It must not be
  described as a real fraud determination.

Tables:
  fintrust_customer
  fintrust_transaction

Week 3 improvement areas addressed:
1. Deeper customer-level analysis
2. More decision-focused SQL analysis
3. Validation of Week 2 patterns
4. Evidence for business recommendations
*/

-- ================================================================
-- 0. DATA / MODEL CHECK
-- ================================================================

/*
Purpose:
Confirm that the expected datasets are being analysed before running
Week 3 queries.
*/

SELECT 'Customers' AS dataset, COUNT(*) AS record_count
FROM fintrust_customer
UNION ALL
SELECT 'Transactions', COUNT(*)
FROM fintrust_transaction;

/* Expected based on Week 2:
Customers    = 1,500
Transactions = 12,000
*/


-- ================================================================
-- ANALYSIS 1: CUSTOMER-LEVEL TRANSACTION BEHAVIOUR
-- ================================================================

/*
Business Question:
How does transaction frequency and transaction value vary at the
individual customer level?

Why this analysis matters:
Week 2 mainly compared customer segments. This analysis moves down to
individual customer behaviour and tests whether customers with more
transactions also generate higher total transaction value.

TECHNIQUES:
JOIN, GROUP BY, CASE, CTE, aggregation.
*/

-- 1A. Customer-level summary by transaction-frequency group

WITH customer_activity AS (
    SELECT
        c.Customer_ID,
        c.Customer_Segment,
        c.Account_Type,
        c.Digital_Engagement_Score,
        COUNT(t.Transaction_ID) AS transaction_count,
        SUM(t.Amount_NGN) AS total_transaction_value,
        AVG(t.Amount_NGN) AS average_transaction_value,
        SUM(
            CASE
                WHEN t.Transaction_Status = 'Successful' THEN 1
                ELSE 0
            END
        ) AS successful_transactions,
        SUM(
            CASE
                WHEN t.Transaction_Status IN ('Failed', 'Reversed', 'Pending')
                THEN 1 ELSE 0
            END
        ) AS unsuccessful_transactions
    FROM fintrust_customer c
    LEFT JOIN fintrust_transaction t
        ON c.Customer_ID = t.Customer_ID
    GROUP BY
        c.Customer_ID,
        c.Customer_Segment,
        c.Account_Type,
        c.Digital_Engagement_Score
),
frequency_groups AS (
    SELECT
        *,
        CASE
            WHEN transaction_count BETWEEN 1 AND 5 THEN '1-5 Transactions'
            WHEN transaction_count BETWEEN 6 AND 10 THEN '6-10 Transactions'
            WHEN transaction_count BETWEEN 11 AND 15 THEN '11-15 Transactions'
            ELSE '16-20 Transactions'
        END AS transaction_frequency_group
    FROM customer_activity
)
SELECT
    transaction_frequency_group,
    COUNT(*) AS number_of_customers,
    ROUND(AVG(transaction_count), 2)
        AS average_transactions_per_customer,
    ROUND(AVG(total_transaction_value), 2)
        AS average_customer_transaction_value,
    ROUND(AVG(average_transaction_value), 2)
        AS average_transaction_value,
    ROUND(
        100.0 * SUM(unsuccessful_transactions)
        / NULLIF(SUM(transaction_count), 0),
        2
    ) AS unsuccessful_rate
FROM frequency_groups
GROUP BY transaction_frequency_group
ORDER BY MIN(
    CASE
        WHEN transaction_frequency_group = '1-5 Transactions' THEN 1
        WHEN transaction_frequency_group = '6-10 Transactions' THEN 6
        WHEN transaction_frequency_group = '11-15 Transactions' THEN 11
        ELSE 16
    END
);

/*
Week 3 evidence already observed from this query:
1-5  transactions: 293 customers; average value ₦198,182.09
6-10 transactions: 917 customers; average value ₦362,920.41
11-15 transactions: 270 customers; average value ₦568,667.75
16-20 transactions: 20 customers; average value ₦803,584.72

Use the actual pgAdmin result when documenting the finding.
Do not describe the relationship as causal.
*/


-- 1B. Customer-level detail for the highest-value customers

WITH customer_activity AS (
    SELECT
        c.Customer_ID,
        c.Customer_Segment,
        c.Account_Type,
        c.Digital_Engagement_Score,
        COUNT(t.Transaction_ID) AS transaction_count,
        SUM(t.Amount_NGN) AS total_transaction_value,
        AVG(t.Amount_NGN) AS average_transaction_value,
        SUM(
            CASE WHEN t.Transaction_Status = 'Successful' THEN 1 ELSE 0 END
        ) AS successful_transactions,
        SUM(
            CASE
                WHEN t.Transaction_Status IN ('Failed', 'Reversed', 'Pending')
                THEN 1 ELSE 0
            END
        ) AS unsuccessful_transactions
    FROM fintrust_customer c
    JOIN fintrust_transaction t
        ON c.Customer_ID = t.Customer_ID
    GROUP BY
        c.Customer_ID,
        c.Customer_Segment,
        c.Account_Type,
        c.Digital_Engagement_Score
)
SELECT
    Customer_ID,
    Customer_Segment,
    Account_Type,
    transaction_count,
    ROUND(total_transaction_value, 2) AS total_transaction_value,
    ROUND(average_transaction_value, 2) AS average_transaction_value,
    successful_transactions,
    unsuccessful_transactions,
    ROUND(
        100.0 * successful_transactions
        / NULLIF(transaction_count, 0),
        2
    ) AS success_rate
FROM customer_activity
ORDER BY total_transaction_value DESC
LIMIT 20;


-- ================================================================
-- ANALYSIS 2: CUSTOMER SEGMENT + CHANNEL BEHAVIOUR
-- ================================================================

/*
Business Question:
How does channel usage and transaction value differ across customer
segments?

Why this analysis matters:
A raw segment/channel table can be difficult to interpret. This query
also calculates each channel's share of activity within its segment.
*/

WITH segment_channel AS (
    SELECT
        c.Customer_Segment,
        t.Channel,
        COUNT(*) AS transaction_count,
        SUM(t.Amount_NGN) AS total_transaction_value,
        AVG(t.Amount_NGN) AS average_transaction_value,
        SUM(
            CASE WHEN t.Transaction_Status = 'Successful' THEN 1 ELSE 0 END
        ) AS successful_transactions
    FROM fintrust_customer c
    JOIN fintrust_transaction t
        ON c.Customer_ID = t.Customer_ID
    GROUP BY c.Customer_Segment, t.Channel
)
SELECT
    Customer_Segment,
    Channel,
    transaction_count,
    ROUND(total_transaction_value, 2) AS total_transaction_value,
    ROUND(average_transaction_value, 2) AS average_transaction_value,
    ROUND(
        100.0 * transaction_count
        / SUM(transaction_count) OVER (PARTITION BY Customer_Segment),
        2
    ) AS segment_transaction_share_pct,
    ROUND(
        100.0 * successful_transactions
        / NULLIF(transaction_count, 0),
        2
    ) AS success_rate
FROM segment_channel
ORDER BY Customer_Segment, segment_transaction_share_pct DESC;


-- ================================================================
-- ANALYSIS 3: TRANSACTION SUCCESS BY TYPE AND CHANNEL
-- ================================================================

/*
Business Question:
Which transaction type/channel combinations show different
transaction-status outcomes?

Why this analysis matters:
Week 2 identified overall status differences. This query identifies
where those differences occur when transaction type and channel are
considered together.

A minimum of 50 transactions is used to avoid over-interpreting very
small combinations.
*/

SELECT
    Transaction_Type,
    Channel,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN Transaction_Status = 'Successful' THEN 1 ELSE 0 END)
        AS successful_transactions,
    SUM(CASE WHEN Transaction_Status = 'Failed' THEN 1 ELSE 0 END)
        AS failed_transactions,
    SUM(CASE WHEN Transaction_Status = 'Reversed' THEN 1 ELSE 0 END)
        AS reversed_transactions,
    SUM(CASE WHEN Transaction_Status = 'Pending' THEN 1 ELSE 0 END)
        AS pending_transactions,
    ROUND(
        100.0 * SUM(
            CASE WHEN Transaction_Status = 'Successful' THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS success_rate,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN Transaction_Status IN ('Failed', 'Reversed', 'Pending')
                THEN 1 ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS unsuccessful_rate
FROM fintrust_transaction
GROUP BY Transaction_Type, Channel
HAVING COUNT(*) >= 50
ORDER BY unsuccessful_rate DESC, total_transactions DESC;


-- ================================================================
-- ANALYSIS 4: MONTHLY TRANSACTION TRENDS
-- ================================================================

/*
Business Question:
How did transaction volume, value and success rate change from
January to March 2026?

Why this analysis matters:
This validates whether transaction performance was stable or changed
across the three-month observation period.
*/

SELECT
    DATE_TRUNC('month', Transaction_DateTime)::DATE AS transaction_month,
    COUNT(*) AS total_transactions,
    ROUND(SUM(Amount_NGN), 2) AS total_transaction_value,
    ROUND(AVG(Amount_NGN), 2) AS average_transaction_value,
    SUM(CASE WHEN Transaction_Status = 'Successful' THEN 1 ELSE 0 END)
        AS successful_transactions,
    ROUND(
        100.0 * SUM(
            CASE WHEN Transaction_Status = 'Successful' THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS success_rate
FROM fintrust_transaction
GROUP BY DATE_TRUNC('month', Transaction_DateTime)
ORDER BY transaction_month;


-- ================================================================
-- ANALYSIS 5: HIGH-VALUE TRANSACTION PATTERNS
-- ================================================================

/*
Business Question:
What transaction types, channels and customer segments are associated
with high-value transactions?

Method:
High-value = transactions at or above the 90th percentile of
Amount_NGN. The threshold is data-driven rather than arbitrary.
*/

-- ================================================================
-- ANALYSIS 5: HIGH-VALUE TRANSACTION PATTERNS
-- ================================================================

/*
Business Question:
What transaction characteristics are associated with high-value
transactions?

Purpose:
Identify transactions in the top 10% of transaction values and
compare their type, channel and status patterns with the overall
transaction population.

Method:
The high-value threshold is defined as the 90th percentile of
transaction amount rather than using an arbitrary monetary threshold.
*/

WITH high_value_threshold AS (
    SELECT
        PERCENTILE_CONT(0.90)
        WITHIN GROUP (
            ORDER BY Amount_NGN
        )::NUMERIC AS threshold
    FROM fintrust_transaction
),

classified_transactions AS (
    SELECT
        t.Transaction_ID,
        t.Transaction_Type,
        t.Channel,
        t.Transaction_Status,
        t.Amount_NGN,

        CASE
            WHEN t.Amount_NGN >= h.threshold
            THEN 'High-Value'
            ELSE 'Regular'
        END AS value_group,

        h.threshold

    FROM fintrust_transaction t
    CROSS JOIN high_value_threshold h
),

overall_summary AS (
    SELECT
        COUNT(*) AS total_transactions,
        SUM(
            CASE
                WHEN value_group = 'High-Value'
                THEN 1
                ELSE 0
            END
        ) AS high_value_transactions,
        MAX(threshold) AS high_value_threshold
    FROM classified_transactions
)

SELECT
    c.value_group,

    COUNT(*) AS transaction_count,

    ROUND(
        SUM(c.Amount_NGN),
        2
    ) AS total_transaction_value,

    ROUND(
        AVG(c.Amount_NGN),
        2
    ) AS average_transaction_value,

    ROUND(
        COUNT(*)::NUMERIC
        / s.total_transactions * 100,
        2
    ) AS transaction_share_pct,

    ROUND(
        SUM(c.Amount_NGN)
        / NULLIF(
            (
                SELECT SUM(Amount_NGN)
                FROM classified_transactions
            ),
            0
        ) * 100,
        2
    ) AS transaction_value_share_pct,

    ROUND(
        s.high_value_threshold,
        2
    ) AS high_value_threshold

FROM classified_transactions c
CROSS JOIN overall_summary s

GROUP BY
    c.value_group,
    s.total_transactions,
    s.high_value_threshold

ORDER BY
    CASE
        WHEN c.value_group = 'High-Value'
        THEN 1
        ELSE 2
    END;


-- ================================================================
-- ANALYSIS 6: MULTI-DIMENSIONAL RISK-REVIEW ANALYSIS
-- ================================================================

/*
Business Question:
How does the observed risk-review rate vary across transaction type
and international/domestic status?

Why this analysis matters:
Week 2 showed an overall international/domestic difference. This query
checks whether that pattern is consistent across transaction types.

Important:
Risk_Review_Flag is synthetic and is not a real fraud determination.
*/

WITH type_scope AS (
    SELECT
        Transaction_Type,
        CASE
            WHEN International_Transaction = 'Yes' THEN 'International'
            ELSE 'Domestic'
        END AS transaction_scope,
        COUNT(*) AS total_transactions,
        SUM(CASE WHEN Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END)
            AS risk_reviewed_transactions
    FROM fintrust_transaction
    GROUP BY
        Transaction_Type,
        CASE
            WHEN International_Transaction = 'Yes' THEN 'International'
            ELSE 'Domestic'
        END
),
pivoted AS (
    SELECT
        Transaction_Type,
        MAX(CASE WHEN transaction_scope = 'International'
            THEN total_transactions END) AS international_transactions,
        MAX(CASE WHEN transaction_scope = 'Domestic'
            THEN total_transactions END) AS domestic_transactions,
        MAX(CASE WHEN transaction_scope = 'International'
            THEN risk_reviewed_transactions END) AS international_reviews,
        MAX(CASE WHEN transaction_scope = 'Domestic'
            THEN risk_reviewed_transactions END) AS domestic_reviews
    FROM type_scope
    GROUP BY Transaction_Type
)
SELECT
    Transaction_Type,
    international_transactions,
    domestic_transactions,
    ROUND(
        100.0 * international_reviews
        / NULLIF(international_transactions, 0),
        2
    ) AS international_risk_review_rate,
    ROUND(
        100.0 * domestic_reviews
        / NULLIF(domestic_transactions, 0),
        2
    ) AS domestic_risk_review_rate,
    ROUND(
        100.0 * international_reviews
        / NULLIF(international_transactions, 0)
        - 100.0 * domestic_reviews
        / NULLIF(domestic_transactions, 0),
        2
    ) AS international_minus_domestic_pp
FROM pivoted
ORDER BY international_minus_domestic_pp DESC;


-- ================================================================
-- ANALYSIS 7: CUSTOMER TRANSACTION RANKING
-- ================================================================

/*
Business Question:
Which customers have the highest transaction volume and transaction
value?

Technique:
Window functions (RANK).

Why this analysis matters:
It identifies high-value/high-activity customers without assuming that
transaction frequency and value are the same thing.
*/

WITH customer_summary AS (
    SELECT
        c.Customer_ID,
        c.Customer_Segment,
        c.Account_Type,
        COUNT(t.Transaction_ID) AS transaction_count,
        SUM(t.Amount_NGN) AS total_transaction_value,
        AVG(t.Amount_NGN) AS average_transaction_value
    FROM fintrust_customer c
    JOIN fintrust_transaction t
        ON c.Customer_ID = t.Customer_ID
    GROUP BY
        c.Customer_ID,
        c.Customer_Segment,
        c.Account_Type
),
ranks AS (
    SELECT
        *,
        RANK() OVER (ORDER BY transaction_count DESC) AS transaction_count_rank,
        RANK() OVER (ORDER BY total_transaction_value DESC) AS value_rank
    FROM customer_summary
)
SELECT
    Customer_ID,
    Customer_Segment,
    Account_Type,
    transaction_count,
    ROUND(total_transaction_value, 2) AS total_transaction_value,
    ROUND(average_transaction_value, 2) AS average_transaction_value,
    transaction_count_rank,
    value_rank
FROM ranks
WHERE transaction_count_rank <= 20
   OR value_rank <= 20
ORDER BY value_rank, transaction_count_rank;


-- ================================================================
-- ANALYSIS 8: DIGITAL ENGAGEMENT AND CUSTOMER BEHAVIOUR
-- ================================================================

/*
Business Question:
Is higher digital engagement associated with greater transaction
activity or value at customer level?

Technique:
NTILE quartiles + correlation.

Important:
Association is not causation. The purpose is to validate the Week 2
observation rather than claim that engagement causes transactions.
*/

WITH customer_activity AS (
    SELECT
        c.Customer_ID,
        c.Digital_Engagement_Score,
        COUNT(t.Transaction_ID) AS transaction_count,
        SUM(t.Amount_NGN) AS total_transaction_value,
        AVG(t.Amount_NGN) AS average_transaction_value
    FROM fintrust_customer c
    LEFT JOIN fintrust_transaction t
        ON c.Customer_ID = t.Customer_ID
    GROUP BY
        c.Customer_ID,
        c.Digital_Engagement_Score
),
engagement_groups AS (
    SELECT
        *,
        NTILE(4) OVER (
            ORDER BY Digital_Engagement_Score
        ) AS engagement_quartile
    FROM customer_activity
)
SELECT
    engagement_quartile,
    COUNT(*) AS customers,
    ROUND(AVG(Digital_Engagement_Score), 2)
        AS average_engagement_score,
    ROUND(AVG(transaction_count), 2)
        AS average_transactions_per_customer,
    ROUND(AVG(total_transaction_value), 2)
        AS average_total_value_per_customer,
    ROUND(AVG(average_transaction_value), 2)
        AS average_transaction_value
FROM engagement_groups
GROUP BY engagement_quartile
ORDER BY engagement_quartile;


-- 8B. Correlation check

WITH customer_activity AS (
    SELECT
        c.Customer_ID,
        c.Digital_Engagement_Score,
        COUNT(t.Transaction_ID) AS transaction_count,
        SUM(t.Amount_NGN) AS total_transaction_value
    FROM fintrust_customer c
    LEFT JOIN fintrust_transaction t
        ON c.Customer_ID = t.Customer_ID
    GROUP BY
        c.Customer_ID,
        c.Digital_Engagement_Score
)
SELECT
    ROUND(CORR(Digital_Engagement_Score, transaction_count)::NUMERIC, 4)
        AS engagement_transaction_count_correlation,
    ROUND(CORR(Digital_Engagement_Score, total_transaction_value)::NUMERIC, 4)
        AS engagement_transaction_value_correlation
FROM customer_activity;


-- ================================================================
-- ANALYSIS 9: UNSUCCESSFUL TRANSACTION CONCENTRATION
-- ================================================================

/*
Business Question:
Which transaction types and channels account for the greatest number
of unsuccessful transactions?

Definition:
Unsuccessful = Failed + Reversed + Pending.

Why this analysis matters:
A high rate and a high number are different things. This query reports
both so that operational priorities are not based on rate alone.
*/

WITH unsuccessful AS (
    SELECT
        t.Transaction_Type,
        t.Channel,
        COUNT(*) AS total_transactions,
        SUM(
            CASE
                WHEN t.Transaction_Status IN ('Failed', 'Reversed', 'Pending')
                THEN 1 ELSE 0
            END
        ) AS unsuccessful_transactions
    FROM fintrust_transaction t
    GROUP BY t.Transaction_Type, t.Channel
)
SELECT
    Transaction_Type,
    Channel,
    total_transactions,
    unsuccessful_transactions,
    ROUND(
        100.0 * unsuccessful_transactions
        / NULLIF(total_transactions, 0),
        2
    ) AS unsuccessful_rate,
    ROUND(
        100.0 * unsuccessful_transactions
        / NULLIF(SUM(unsuccessful_transactions) OVER (), 0),
        2
    ) AS share_of_all_unsuccessful_transactions
FROM unsuccessful
ORDER BY unsuccessful_transactions DESC, unsuccessful_rate DESC;


-- ================================================================
-- ANALYSIS 10: TRANSACTION VALUE BY STATUS
-- ================================================================

/*
Business Question:
How does transaction value differ between successful, failed,
reversed and pending transactions?

Why this analysis matters:
Transaction counts alone may not show the monetary significance of each
status. This analysis compares both count and value.
*/

WITH status_summary AS (
    SELECT
        Transaction_Status,
        COUNT(*) AS transaction_count,
        SUM(Amount_NGN) AS total_transaction_value,
        AVG(Amount_NGN) AS average_transaction_value,
        MIN(Amount_NGN) AS minimum_transaction_value,
        MAX(Amount_NGN) AS maximum_transaction_value
    FROM fintrust_transaction
    GROUP BY Transaction_Status
)
SELECT
    Transaction_Status,
    transaction_count,
    ROUND(
        100.0 * transaction_count
        / SUM(transaction_count) OVER (),
        2
    ) AS transaction_share_pct,
    ROUND(total_transaction_value, 2) AS total_transaction_value,
    ROUND(
        100.0 * total_transaction_value
        / SUM(total_transaction_value) OVER (),
        2
    ) AS transaction_value_share_pct,
    ROUND(average_transaction_value, 2) AS average_transaction_value,
    ROUND(minimum_transaction_value, 2) AS minimum_transaction_value,
    ROUND(maximum_transaction_value, 2) AS maximum_transaction_value
FROM status_summary
ORDER BY total_transaction_value DESC;


-- ================================================================
-- WEEK 3 VALIDATION CROSS-CHECKS
-- ================================================================

/*
Run these after the main analyses.
The purpose is to make sure Week 3 analysis still agrees with the
validated Week 2 totals.
*/

-- Validation 1: Overall transaction count/value

SELECT
    COUNT(*) AS total_transactions,
    ROUND(SUM(Amount_NGN), 2) AS total_transaction_value,
    ROUND(AVG(Amount_NGN), 2) AS average_transaction_value
FROM fintrust_transaction;

/* Week 2 reference:
12,000 transactions
₦560,477,354.85 total value
₦46,706.45 average transaction value
*/


-- Validation 2: Overall success rate

SELECT
    ROUND(
        100.0 * SUM(
            CASE WHEN Transaction_Status = 'Successful' THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS success_rate
FROM fintrust_transaction;

/* Week 2 reference: 90.47% */


-- Validation 3: Overall risk-review rate

SELECT
    ROUND(
        100.0 * SUM(
            CASE WHEN Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS risk_review_rate
FROM fintrust_transaction;

/* Week 2 reference: 19.60% */


-- Validation 4: Orphan Customer_ID check

SELECT COUNT(*) AS orphan_transaction_records
FROM fintrust_transaction t
LEFT JOIN fintrust_customer c
    ON t.Customer_ID = c.Customer_ID
WHERE c.Customer_ID IS NULL;

/* Expected: 0 */


-- Validation 5: Transaction_ID uniqueness

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT Transaction_ID) AS unique_transaction_ids
FROM fintrust_transaction;

/* Expected: 12,000 rows and 12,000 unique Transaction_IDs */


-- Validation 6: Customer transaction coverage

SELECT
    COUNT(DISTINCT c.Customer_ID) AS customers_in_customer_table,
    COUNT(DISTINCT t.Customer_ID) AS customers_with_transactions
FROM fintrust_customer c
LEFT JOIN fintrust_transaction t
    ON c.Customer_ID = t.Customer_ID;

/* Week 2 reference:
1,500 customers in customer table
1,500 customers with transactions
*/


/*
================================================================
WEEK 3 RESULT-RECORDING GUIDE
================================================================

For each analysis, record:

1. Business Question
2. SQL Query
3. Actual Result
4. Interpretation
5. Validation / limitation
6. Business implication

Do not copy all raw rows into the Week 3 report. Summarise the
patterns that matter for decision-making and retain screenshots or
exports as evidence.

Recommended Week 3 finding format:

Finding:
What pattern did the analysis identify?

Evidence:
What numbers from the SQL output support it?

Validation:
Was the pattern checked using another query, Python or Power BI?

Business Meaning:
Why does the pattern matter to FinTrust?

Recommendation:
What action could management consider, if supported by the evidence?

Important limitation:
Observed relationships in this synthetic dataset are associations,
not proof of causation. Risk_Review_Flag is synthetic and should not
be presented as real fraud or real-world banking-risk classification.
*/
