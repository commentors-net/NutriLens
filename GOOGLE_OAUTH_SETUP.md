# Google OAuth 2.0 Setup Guide

This guide explains how to set up Google OAuth 2.0 for the NutriLens and Leave Tracker applications.

## Prerequisites

- Access to Google Cloud Console
- Project ID: `leave-tracker-2025` (or your GCP project)

## Step 1: Access Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select or create your project: `leave-tracker-2025`

## Step 2: Enable Required APIs

1. Navigate to **APIs & Services** → **Library**
2. Search for and enable these APIs if not already enabled:
   - **Google+ API** (for user profile information)
   - **People API** (optional, for extended profile data)

## Step 3: Configure OAuth Consent Screen

1. Go to **APIs & Services** → **OAuth consent screen**
2. Choose **External** user type (or Internal if using Google Workspace)
3. Fill in the required information:
   - **App name:** NutriLens & Leave Tracker
   - **User support email:** Your email
   - **Developer contact email:** Your email
   - **App logo:** (optional)
   - **Authorized domains:** (Add your production domain if deploying)
4. Click **Save and Continue**
5. On the **Scopes** page, add the following scopes:
   - `.../auth/userinfo.email`
   - `.../auth/userinfo.profile`
   - `openid`
6. Click **Save and Continue**
7. Add test users if using External user type (your email addresses)
8. Click **Save and Continue**

## Step 4: Create OAuth 2.0 Client ID

1. Go to **APIs & Services** → **Credentials**
2. Click **+ CREATE CREDENTIALS** → **OAuth client ID**
3. Choose **Application type:** Web application
4. Set the **Name:** NutriLens Web Client (or any descriptive name)
5. Under **Authorized JavaScript origins**, add:
   ```
   http://localhost:5173
   http://localhost:5174
   http://127.0.0.1:5173
   http://127.0.0.1:5174
   ```
   (Add your production URL when deploying, e.g., `https://yourdomain.com`)

6. Under **Authorized redirect URIs**, you can leave this empty for now
   (The @react-oauth/google library handles this automatically)

7. Click **CREATE**
8. **IMPORTANT:** Copy the **Client ID** that appears in the modal
   - It will look like: `123456789-abcdefghijk.apps.googleusercontent.com`
   - Save this securely - you'll need it for the next step

## Step 5: Configure Backend Environment

1. Open `backend/.env`
2. Find the `GOOGLE_CLIENT_ID` line
3. Replace the placeholder with your actual Client ID:
   ```bash
   GOOGLE_CLIENT_ID=123456789-abcdefghijk.apps.googleusercontent.com
   ```
4. Save the file
5. **Restart your backend server** for the changes to take effect

## Step 6: Configure Frontend Environment

1. Open `frontend/.env.development`
2. Find the `VITE_GOOGLE_CLIENT_ID` line
3. Replace the placeholder with your actual Client ID:
   ```bash
   VITE_GOOGLE_CLIENT_ID=123456789-abcdefghijk.apps.googleusercontent.com
   ```
4. Save the file
5. **Restart your frontend dev server** for the changes to take effect

## Step 7: Test Google SSO

1. Make sure both backend and frontend servers are running:
   ```powershell
   # Terminal 1 - Backend
   cd backend
   ..\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload

   # Terminal 2 - Frontend
   cd frontend
   npm run dev
   ```

2. Open your browser and navigate to:
   - NutriLens: http://localhost:5173/nutrilens/login
   - Leave Tracker: http://localhost:5173/leave-tracker/login

3. You should see:
   - Traditional login form (username/password/2FA)
   - A divider with "OR"
   - **"Continue with Google"** button

4. Click the Google button and sign in with your Google account

5. After successful authentication:
   - The backend will create a user account automatically if it doesn't exist
   - You'll be granted access to both `nutrilens` and `leave-tracker` systems
   - You'll be redirected to the app selection screen

## Troubleshooting

### "Google SSO is disabled" message appears

- **Cause:** `VITE_GOOGLE_CLIENT_ID` is not set or is empty
- **Solution:** Make sure you've added the Client ID to `frontend/.env.development` and restarted the dev server

### "Google SSO is not configured" error (503)

- **Cause:** `GOOGLE_CLIENT_ID` is not set in backend `.env`
- **Solution:** Make sure you've added the Client ID to `backend/.env` and restarted uvicorn

### "Invalid Google token" error (401)

- **Possible causes:**
  1. Client ID mismatch between frontend and backend
  2. Token expired or invalid
  3. Authorized JavaScript origins not configured correctly
- **Solution:** 
  - Verify both frontend and backend use the **same** Client ID
  - Check Google Cloud Console → Credentials → Your OAuth Client → Authorized JavaScript origins includes your localhost URLs

### Google button doesn't appear

- **Cause:** Client ID not loaded or invalid
- **Solution:** 
  - Check browser console for errors
  - Verify `config.googleClientId` has a value
  - Make sure you restarted the frontend server after editing `.env.development`

### "redirect_uri_mismatch" error

- **Cause:** The redirect URI is not authorized
- **Solution:** In Google Cloud Console, add the redirect URI to your OAuth client's Authorized redirect URIs
  - Usually not needed with @react-oauth/google, but if it persists, add: `http://localhost:5173`

## Security Notes

1. **Never commit your Client ID to public repositories** (it's in `.env` files which are gitignored)
2. **For production:** 
   - Add your production domain to Authorized JavaScript origins
   - Consider using a separate OAuth client for production
   - Publish your OAuth consent screen if External user type
3. **Client Secret:** Not needed for web applications using OIDC/OAuth 2.0 implicit flow
4. **Token Security:** ID tokens are validated server-side using Google's public keys

## Production Deployment

When deploying to production (Cloud Run):

1. Create a **separate OAuth 2.0 Client ID** for production
2. Add your Cloud Run URL to Authorized JavaScript origins:
   ```
   https://nutrilens-api-2ajzj2dbrq-uc.a.run.app
   ```
3. Update production environment variables:
   ```bash
   # In Google Cloud Console → Cloud Run → nutrilens-api → Edit → Environment Variables
   GOOGLE_CLIENT_ID=your-production-client-id.apps.googleusercontent.com
   ```
4. Update frontend production config (if hosting frontend separately)
5. Publish your OAuth consent screen if using External user type

## References

- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [Google Sign-In for Web](https://developers.google.com/identity/gsi/web/guides/overview)
- [@react-oauth/google Documentation](https://www.npmjs.com/package/@react-oauth/google)
