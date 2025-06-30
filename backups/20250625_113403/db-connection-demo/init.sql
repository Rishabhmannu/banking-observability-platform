-- Initialize banking demo database schema

-- Create accounts table (demo only - you still use CSV)
CREATE TABLE IF NOT EXISTS demo_accounts (
    account_id SERIAL PRIMARY KEY,
    account_number VARCHAR(20) UNIQUE NOT NULL,
    balance DECIMAL(12, 2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create transactions table (demo only)
CREATE TABLE IF NOT EXISTS demo_transactions (
    transaction_id SERIAL PRIMARY KEY,
    from_account VARCHAR(20),
    to_account VARCHAR(20),
    amount DECIMAL(12, 2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create audit log table (demo only)
CREATE TABLE IF NOT EXISTS demo_audit_log (
    log_id SERIAL PRIMARY KEY,
    action VARCHAR(50) NOT NULL,
    user_id VARCHAR(20),
    details JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert some demo data
INSERT INTO demo_accounts (account_number, balance) VALUES
    ('ACC1001', 5000.00),
    ('ACC1002', 10000.00),
    ('ACC1003', 7500.00),
    ('ACC1004', 3000.00),
    ('ACC1005', 15000.00)
ON CONFLICT (account_number) DO NOTHING;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_transactions_from ON demo_transactions(from_account);
CREATE INDEX IF NOT EXISTS idx_transactions_to ON demo_transactions(to_account);
CREATE INDEX IF NOT EXISTS idx_audit_user ON demo_audit_log(user_id);

-- Create a view for connection monitoring
CREATE OR REPLACE VIEW connection_stats AS
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    state_change,
    wait_event_type,
    wait_event
FROM pg_stat_activity
WHERE datname = current_database();