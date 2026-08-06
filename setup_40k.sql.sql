-- ============================================
-- PAYMENT FUNNEL PROJECT — 40,000 TRANSACTIONS
-- Setup: create table, then bulk-load the CSV
-- ============================================

CREATE DATABASE IF NOT EXISTS payment_funnel;
USE payment_funnel;

DROP TABLE IF EXISTS transactions;
CREATE TABLE transactions (
    txn_id VARCHAR(10) PRIMARY KEY,
    network VARCHAR(20),
    merchant VARCHAR(50),
    txn_date DATE,
    auth_amount DECIMAL(10,2),
    auth_status VARCHAR(20),
    decline_code VARCHAR(5),
    clearing_status VARCHAR(20),
    clearing_amount DECIMAL(10,2),
    settlement_status VARCHAR(20),
    settlement_amount DECIMAL(10,2)
);

-- ============================================
-- STEP 1: Check if local file loading is enabled
-- ============================================
-- Run this first:
SHOW VARIABLES LIKE 'local_infile';
-- If it shows OFF, run this (needs admin rights):
-- SET GLOBAL local_infile = 1;
-- Then reconnect your MySQL client before continuing.

-- ============================================
-- STEP 2: Load the CSV
-- ============================================
-- Replace the file path below with wherever you saved funnel_data_40k.csv
-- On Windows, use double backslashes or forward slashes, e.g.:
--   'C:/Users/YourName/Downloads/funnel_data_40k.csv'
-- On Mac/Linux:
--   '/Users/YourName/Downloads/funnel_data_40k.csv'

LOAD DATA LOCAL INFILE '/full/path/to/funnel_data_40k.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(txn_id, network, merchant, txn_date, auth_amount, auth_status, decline_code,
 clearing_status, @clearing_amount, settlement_status, @settlement_amount)
SET
  clearing_amount = NULLIF(@clearing_amount, ''),
  settlement_amount = NULLIF(@settlement_amount, '');

-- ============================================
-- STEP 3: Verify the load worked
-- ============================================
SELECT COUNT(*) AS total_rows FROM transactions;
-- Should return 40000

SELECT * FROM transactions LIMIT 10;

-- ============================================
-- TROUBLESHOOTING
-- ============================================
-- Error "Loading local data is disabled"?
--   -> You skipped Step 1, or your client also needs a flag.
--   -> If using the mysql command line, reconnect with:
--      mysql --local-infile=1 -u root -p
--
-- Error "File not found"?
--   -> Your file path is wrong, or MySQL doesn't have permission
--      to read that folder. Try moving the CSV to your Desktop
--      and using that full path instead.
--
-- Getting 0 rows loaded but no error?
--   -> Check LINES TERMINATED BY — Windows-saved CSVs sometimes
--      use '\r\n' instead of '\n'. If rows look merged/empty,
--      change LINES TERMINATED BY '\n' to LINES TERMINATED BY '\r\n'.
