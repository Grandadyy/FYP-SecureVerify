# SecureVerify — Complete deployment package

This version keeps the original SecureVerify visual style and adds a shared Supabase/PostgreSQL backend, real QR generation and PNG download, phone-camera scanning, server-side token verification, administrator authentication, product revocation, and persistent scan logs.

## Important: one-time account setup is still required

I cannot create a Supabase project, accept its terms, or deploy to your GitHub account from this ZIP. The app is complete in code, but it will not connect to a live shared database until you complete the setup below. Do not publish it as a working live system before these steps and the tests are complete.

## 1. Create the database

1. Create a free project at https://supabase.com/ and save the database password safely.
2. Open the project's **SQL Editor**.
3. Open `supabase/schema.sql` from this package, copy the entire file, paste it into SQL Editor, and run it.
4. Confirm that `admin_users`, `products`, and `scan_logs` tables exist under **Table Editor**.

The SQL creates row-level security policies. Public users can only call the verification function; administrator accounts explicitly allowlisted in `admin_users` manage product records and view scan logs.

## 2. Create your administrator account

1. In Supabase, open **Authentication → Users → Add user**.
2. Create your administrator with an email and a strong password. Confirm the user if the dashboard offers that option.
3. Copy the new user's UUID from the Users table.
4. In SQL Editor, run this query, replacing the UUID and display name:

```sql
insert into public.admin_users (user_id, display_name)
values ('PASTE-AUTH-USER-UUID-HERE', 'SecureVerify Administrator');
```

Only users in `admin_users` can open the dashboard. Do not use the old demo credentials; they have been removed.

## 3. Connect the website to Supabase

1. In Supabase, open **Project Settings → API** (or **Data API** depending on the dashboard version).
2. Copy the Project URL.
3. Copy the **anon / publishable** key. It is intended for browser use when Row Level Security is enabled.
4. Open `js/config.js` and replace the two placeholder values:

```js
window.SECUREVERIFY_CONFIG = {
  SUPABASE_URL: 'https://YOUR-PROJECT-REF.supabase.co',
  SUPABASE_ANON_KEY: 'YOUR-ANON-OR-PUBLISHABLE-KEY'
};
```

**Never put the `service_role` or secret key in `js/config.js`, HTML, GitHub Pages, or any browser code.** This package does not need the service-role key.

## 4. Publish on GitHub Pages

1. Upload the contents of this folder to the root of your existing GitHub Pages repository, keeping the `js/` and `supabase/` folders.
2. Keep these files at the same level: `index.html`, `admin-login.html`, `dashboard.html`, `verify.html`, `scan-log.html`.
3. In GitHub, open **Settings → Pages** and publish the intended branch/folder.
4. In Supabase **Authentication → URL Configuration**, add your deployed GitHub Pages URL to the allowed Site URL / Redirect URLs, for example `https://YOUR-USERNAME.github.io/YOUR-REPOSITORY/`.
5. Wait for GitHub Pages deployment to finish. Open the website using its HTTPS URL.

Camera scanning requires HTTPS (GitHub Pages provides HTTPS) and permission to use the phone camera.

## 5. Test the complete workflow

1. Open `admin-login.html` and sign in with the administrator account created in step 2.
2. Register a test product with a unique batch number and valid dates.
3. The QR modal should appear. Download the PNG and keep it.
4. Open the public website on a second phone, scan the printed/displayed QR using **Verify Product → Start camera scanner**, or open the QR link.
5. The first five valid scans are shown as **Authentic**. From scan six onward, the system flags the code as **Suspicious**. This threshold is configurable in `supabase/schema.sql` (currently `v_count > 5`).
6. Enter a made-up product ID/token or alter a QR token; it should return **Invalid / Unregistered**.
7. Return to the dashboard and confirm scan counts. Open **Scan Logs** to confirm each attempt is recorded.
8. Use **Revoke** on a test product and confirm that its QR is rejected afterward.

## QR token handling

The raw verification token is generated randomly in the browser and only its SHA-256 digest is stored in the database. The QR code contains a verification URL with its token in the URL fragment (`#...`), so the fragment is not sent to the web server in the HTTP request. For security, the original token cannot be recovered from the database. If an existing QR image is lost, use the dashboard's QR Code button to rotate the token and download a replacement; this invalidates the old QR image.

## What the counterfeit detection means (important for your report/defence)

- **Counterfeit / invalid:** the product ID is not registered, its token does not match, or the product has been revoked.
- **Authentic:** the token matches an active product record and the scan count has not crossed the configured threshold.
- **Suspicious:** the token is valid but the configured repeated-scan threshold has been crossed.

A copied genuine QR code can still be attached to a counterfeit physical item. Repeated-scan monitoring can flag suspicious reuse, but it cannot guarantee detection of every clone or prove that the physical packaging has not been replaced. A stronger commercial system would need tamper-evident labels, one-time challenge/response, trusted manufacturing integration, and/or per-item physical security features. Do not claim “100% clone detection”.

The current threshold is a simple research prototype heuristic: it counts total scans, not distinct people or verified locations. It can flag legitimate repeated scans too. The app intentionally does not collect precise user location.

## Troubleshooting

- **“not connected yet” message:** check `js/config.js` for the correct project URL and anon/publishable key; redeploy after editing.
- **Login succeeds but dashboard redirects:** check that the exact Auth user UUID was inserted into `public.admin_users`.
- **Permission / RLS error:** rerun the complete `supabase/schema.sql` and confirm the user exists in `admin_users`.
- **QR verification cannot reach the database:** confirm the SQL function `public.verify_product` exists and that the project URL/key are correct.
- **Camera does not open:** use the HTTPS GitHub Pages URL, allow camera permission, close other apps using the camera, or use the manual QR URL input.
- **Old QR stopped working:** token rotation invalidates previously printed QR codes. Print the newly generated code.

## Project files

- `index.html` — public landing page
- `admin-login.html` — Supabase administrator sign-in
- `dashboard.html` — product registration, QR generation/download, product list, QR rotation and revocation
- `verify.html` — camera scanning, manual code entry and public verification
- `scan-log.html` — administrator scan history
- `js/config.js` — your public Supabase project URL and anon/publishable key
- `js/supabase-client.js` — shared Supabase client setup
- `supabase/schema.sql` — database tables, RLS policies and verification function

## Academic honesty / testing note

Do not report measured speed, accuracy, clone-detection percentage, or usability scores unless you have actually measured them in a documented test. The project demonstrates a QR-token verification workflow and a repeat-scan anomaly rule; its real performance must be evaluated with your own test data.
