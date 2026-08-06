-- ============================================
-- PAYMENT FUNNEL ANALYSIS
-- Authorization -> Clearing -> Settlement
-- ============================================

-- 1. Overall funnel counts
SELECT
    COUNT(*) AS total_attempts,
    SUM(CASE WHEN auth_status = 'Approved' THEN 1 ELSE 0 END) AS authorized,
    SUM(CASE WHEN clearing_status = 'Cleared' THEN 1 ELSE 0 END) AS cleared,
    SUM(CASE WHEN settlement_status = 'Settled' THEN 1 ELSE 0 END) AS settled
FROM transactions;

-- 2. Funnel as percentages (conversion rate at each stage)
SELECT
    ROUND(SUM(CASE WHEN auth_status = 'Approved' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS auth_rate_pct,
    ROUND(SUM(CASE WHEN clearing_status = 'Cleared' THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(SUM(CASE WHEN auth_status = 'Approved' THEN 1 ELSE 0 END), 0), 1) AS clearing_rate_pct,
    ROUND(SUM(CASE WHEN settlement_status = 'Settled' THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(SUM(CASE WHEN clearing_status = 'Cleared' THEN 1 ELSE 0 END), 0), 1) AS settlement_rate_pct
FROM transactions;

-- 3. Where exactly are transactions being lost? (classification, same logic as your reconciliation exercise)
SELECT
    CASE
        WHEN auth_status = 'Declined' THEN CONCAT('Declined at Authorization (', decline_code, ')')
        WHEN clearing_status = 'Not Cleared' THEN 'Capture Failure (Approved but never cleared)'
        WHEN settlement_status = 'Not Settled' THEN 'Settlement Failure (Cleared but never settled)'
        WHEN settlement_amount IS NOT NULL AND settlement_amount <> auth_amount THEN 'Amount Mismatch at Settlement'
        ELSE 'Fully Matched'
    END AS status,
    COUNT(*) AS transaction_count
FROM transactions
GROUP BY status
ORDER BY transaction_count DESC;

-- 4. Decline reasons breakdown (only declined transactions)
SELECT
    decline_code,
    CASE decline_code
        WHEN '05' THEN 'Do Not Honor'
        WHEN '51' THEN 'Insufficient Funds'
        WHEN '54' THEN 'Expired Card'
        WHEN '61' THEN 'Exceeds Limit'
        WHEN '14' THEN 'Invalid Card'
    END AS decline_reason,
    COUNT(*) AS count
FROM transactions
WHERE auth_status = 'Declined'
GROUP BY decline_code
ORDER BY count DESC;

-- 5. Performance by card network (where does each network lose transactions?)
SELECT
    network,
    COUNT(*) AS total,
    SUM(CASE WHEN auth_status = 'Approved' THEN 1 ELSE 0 END) AS authorized,
    SUM(CASE WHEN settlement_status = 'Settled' THEN 1 ELSE 0 END) AS settled,
    ROUND(SUM(CASE WHEN settlement_status = 'Settled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS end_to_end_success_pct
FROM transactions
GROUP BY network
ORDER BY end_to_end_success_pct DESC;

-- 6. Daily trend (transactions and settled amount per day)
SELECT
    txn_date,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN settlement_status = 'Settled' THEN 1 ELSE 0 END) AS settled_transactions,
    ROUND(SUM(settlement_amount), 2) AS total_settled_amount
FROM transactions
GROUP BY txn_date
ORDER BY txn_date;

-- 7. Total value lost at each stage (this is the number that gets a manager's attention)
SELECT
    ROUND(SUM(CASE WHEN auth_status = 'Declined' THEN auth_amount ELSE 0 END), 2) AS value_lost_at_authorization,
    ROUND(SUM(CASE WHEN auth_status = 'Approved' AND clearing_status = 'Not Cleared' THEN auth_amount ELSE 0 END), 2) AS value_lost_at_clearing,
    ROUND(SUM(CASE WHEN clearing_status = 'Cleared' AND settlement_status = 'Not Settled' THEN auth_amount ELSE 0 END), 2) AS value_lost_at_settlement,
    ROUND(SUM(CASE WHEN settlement_amount IS NOT NULL AND settlement_amount <> auth_amount
        THEN auth_amount - settlement_amount ELSE 0 END), 2) AS value_lost_to_mismatches
FROM transactions;

-- 8. Merchant-level view (which merchants have the most drop-off?)
SELECT
    merchant,
    COUNT(*) AS total_attempts,
    SUM(CASE WHEN settlement_status = 'Settled' THEN 1 ELSE 0 END) AS settled,
    ROUND(SUM(CASE WHEN settlement_status = 'Settled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS success_rate_pct
FROM transactions
GROUP BY merchant
ORDER BY success_rate_pct ASC;
