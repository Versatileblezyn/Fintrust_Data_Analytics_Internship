-- FinTrust Week 4: Final SQL Validation
-- Purpose: Independently verify the six headline KPIs used in the final dashboard.
-- Tables: fintrust_customer, fintrust_transaction
-- Run in the PostgreSQL database containing the FinTrust tables.

SELECT
    (SELECT COUNT(DISTINCT customer_id)
     FROM fintrust_customer) AS total_customers,
    COUNT(DISTINCT transaction_id) AS total_transactions,
    ROUND(SUM(amount_ngn), 2) AS total_transaction_value_ngn,
    ROUND(SUM(amount_ngn) / COUNT(DISTINCT transaction_id), 2) AS average_transaction_value_ngn,
    ROUND(100.0 * COUNT(*) FILTER (WHERE transaction_status = 'Successful') / COUNT(*), 2) AS transaction_success_rate_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE risk_review_flag = 'Yes') / COUNT(*), 2) AS risk_review_rate_pct
FROM fintrust_transaction;

-- Expected results from the completed validation:
-- total_customers: 1500
-- total_transactions: 12000
-- total_transaction_value_ngn: 560477354.85
-- average_transaction_value_ngn: 46706.45
-- transaction_success_rate_pct: 90.47
-- risk_review_rate_pct: 19.60

-- Additional integrity checks:

-- 1. Confirm transaction IDs are unique.
SELECT COUNT(*) AS transaction_rows,
       COUNT(DISTINCT transaction_id) AS distinct_transaction_ids
FROM fintrust_transaction;

-- 2. Confirm there are no transaction records without a matching customer.
SELECT COUNT(*) AS orphan_transaction_customer_ids
FROM fintrust_transaction t
LEFT JOIN fintrust_customer c ON t.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- 3. Confirm transaction status distribution.
SELECT transaction_status,
       COUNT(*) AS transaction_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM fintrust_transaction
GROUP BY transaction_status
ORDER BY transaction_count DESC;
