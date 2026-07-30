-- ============================================
-- LICENSE ADMIN TOOL — run in Supabase SQL Editor
-- Keys are LIFETIME (no expiration) by default
-- ============================================

-- ============================================
-- 1. GENERATE A NEW LICENSE KEY (lifetime)
-- ============================================

INSERT INTO licenses (license_key, is_active)
VALUES (
  upper(
    'RESTROPOS-'
    || substr(md5(random()::text), 1, 4) || '-'
    || substr(md5(random()::text), 1, 4) || '-'
    || substr(md5(random()::text), 1, 4)
  ),
  true
)
RETURNING id, license_key, created_at;

-- ============================================
-- 2. GENERATE MULTIPLE KEYS AT ONCE (lifetime)
-- ============================================
-- Change the number after "FROM generate_series(1, 5)" to your desired count:

INSERT INTO licenses (license_key, is_active)
SELECT
  upper(
    'RESTROPOS-'
    || substr(md5(random()::text || gs::text), 1, 4) || '-'
    || substr(md5(random()::text || gs::text), 1, 4) || '-'
    || substr(md5(random()::text || gs::text), 1, 4)
  ),
  true
FROM generate_series(1, 5) AS gs
RETURNING id, license_key, created_at;

-- ============================================
-- 3. LIST ALL LICENSES
-- ============================================

SELECT
  license_key,
  is_active,
  CASE WHEN device_id IS NOT NULL THEN 'Yes' ELSE 'No' END AS is_activated,
  device_id,
  activated_at,
  CASE WHEN expires_at IS NULL THEN 'Lifetime' WHEN expires_at < NOW() THEN 'Expired' ELSE 'Valid' END AS status,
  created_at
FROM licenses
ORDER BY created_at DESC;

-- ============================================
-- 4. CHECK IF A SPECIFIC KEY IS USED
-- ============================================
-- Replace 'RESTROPOS-XXXX-XXXX-XXXX' with the actual key:

SELECT
  license_key,
  is_active,
  CASE WHEN device_id IS NOT NULL THEN 'Yes' ELSE 'No' END AS is_activated,
  device_id,
  activated_at,
  last_validated_at,
  CASE
    WHEN device_id IS NOT NULL THEN 'Activated on ' || activated_at::text
    ELSE 'Available — not yet used'
  END AS status,
  CASE WHEN expires_at IS NULL THEN 'Lifetime' ELSE expires_at::text END AS expiration,
  created_at
FROM licenses
WHERE license_key = 'RESTROPOS-XXXX-XXXX-XXXX';

-- ============================================
-- 5. DISABLE / REVOKE A KEY
-- ============================================
-- Replace the license_key value:

UPDATE licenses
SET is_active = false
WHERE license_key = 'RESTROPOS-XXXX-XXXX-XXXX'
RETURNING license_key, is_active;

-- ============================================
-- 6. DELETE A KEY
-- ============================================

DELETE FROM licenses
WHERE license_key = 'RESTROPOS-XXXX-XXXX-XXXX'
RETURNING license_key;

-- ============================================
-- 7. COUNT SUMMARY
-- ============================================

SELECT
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE is_active = true) AS active,
  COUNT(*) FILTER (WHERE device_id IS NOT NULL) AS activated,
  COUNT(*) FILTER (WHERE device_id IS NULL AND is_active = true) AS available,
  COUNT(*) FILTER (WHERE expires_at IS NULL) AS lifetime
FROM licenses;
