# SecureVerify — QR Code Product Authentication

A static website frontend with Supabase authentication and PostgreSQL backend.

**Start here:** read `SETUP-GUIDE.md` and run `supabase/schema.sql` before deploying. Configure `js/config.js` with the Supabase project URL and anon/publishable key. Never expose a service-role key.

The website includes admin login, product registration, QR generation and PNG download, public camera/manual verification, product revocation, scan counts, and administrator scan logs. The database verifies QR tokens server-side by comparing SHA-256 token digests.

The project has not been connected to a user's Supabase account or deployed by this package. It requires the one-time setup described in the guide. The scan threshold is a basic anomaly heuristic, not guaranteed physical clone detection.
