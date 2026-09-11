const { Client } = require('pg');

const connectionString = 'postgresql://postgres.txvxgxcdkqrzfatinrqa:EAS-Merchant-X@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres';

const sql = `
-- 1. Add column if it doesn't exist (ignore error if it does)
ALTER TABLE stores ADD COLUMN IF NOT EXISTS store_code TEXT;

-- 2. Update the RPC to accept store_code
CREATE OR REPLACE FUNCTION onboard_admin(p_store_name TEXT, p_store_code TEXT)
RETURNS UUID AS \$\$
DECLARE
    v_store_id UUID;
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF EXISTS (SELECT 1 FROM profiles WHERE id = v_user_id) THEN
        RAISE EXCEPTION 'User already has a profile';
    END IF;

    INSERT INTO stores (store_name, store_code, status)
    VALUES (p_store_name, p_store_code, 'active')
    RETURNING id INTO v_store_id;

    INSERT INTO profiles (id, role, store_id)
    VALUES (v_user_id, 'admin', v_store_id);

    RETURN v_store_id;
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;
`;

async function run() {
  const client = new Client({ connectionString });
  try {
    await client.connect();
    await client.query(sql);
    console.log("Migration executed successfully.");
  } catch (err) {
    console.error("Error:", err);
  } finally {
    await client.end();
  }
}

run();
