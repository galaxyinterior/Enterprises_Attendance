const { Client } = require('pg');

const connectionString = 'postgresql://postgres.txvxgxcdkqrzfatinrqa:EAS-Merchant-X@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres';

const sql = `
CREATE OR REPLACE FUNCTION onboard_admin(p_store_name TEXT)
RETURNS UUID AS \$\$
DECLARE
    v_store_id UUID;
    v_user_id UUID;
BEGIN
    -- Get the currently authenticated user's ID
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Check if user already has a profile
    IF EXISTS (SELECT 1 FROM profiles WHERE id = v_user_id) THEN
        RAISE EXCEPTION 'User already has a profile';
    END IF;

    -- 1. Create the store
    INSERT INTO stores (store_name, status)
    VALUES (p_store_name, 'active')
    RETURNING id INTO v_store_id;

    -- 2. Create the profile for the user as 'admin'
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
    console.log("RPC onboard_admin created successfully.");
  } catch (err) {
    console.error("Error:", err);
  } finally {
    await client.end();
  }
}

run();
