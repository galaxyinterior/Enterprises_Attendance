const { Client } = require('pg');

const connectionString = 'postgresql://postgres.txvxgxcdkqrzfatinrqa:EAS-Merchant-X@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres';

const sql = `
CREATE TABLE IF NOT EXISTS store_applications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_name TEXT NOT NULL,
    store_name TEXT NOT NULL,
    mobile_no TEXT NOT NULL,
    address TEXT NOT NULL,
    email TEXT NOT NULL,
    estimated_staff INT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE store_applications ENABLE ROW LEVEL SECURITY;

-- Drop policy if exists to recreate
DROP POLICY IF EXISTS "Anyone can insert store application" ON store_applications;
CREATE POLICY "Anyone can insert store application" ON store_applications
FOR INSERT WITH CHECK (true);
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
