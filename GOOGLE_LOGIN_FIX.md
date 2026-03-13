# 🔐 Quick Fix: Enable Google Sign-In for Frontend

## Problem
Google Sign-In button is not showing in the deployed frontend because `VITE_GOOGLE_CLIENT_ID` is not configured in production.

---

## ✅ Solution (5 Minutes)

### Step 1: Get Your Google OAuth Client ID

1. **Go to:** https://console.cloud.google.com/apis/credentials?project=leave-tracker-2025

2. **Look for an existing OAuth 2.0 Client ID:**
   - If you already have one, click on it and copy the **Client ID**
   - It looks like: `123456789-abcdefg.apps.googleusercontent.com`

3. **If you don't have one, create it:**
   - Click **+ CREATE CREDENTIALS** → **OAuth 2.0 Client ID**
   - Application type: **Web application**
   - Name: **Leave Tracker Frontend**
   - **Authorized JavaScript origins:**
     ```
     https://storage.googleapis.com
     http://localhost:5173
     http://localhost:5174
     ```
   - Click **CREATE**
   - Copy the **Client ID** from the popup

### Step 2: Add Client ID to Frontend Config

Open `frontend/.env.production` and add your Client ID:

```bash
VITE_API_URL=https://leave-tracker-api-2ajzj2dbrq-uc.a.run.app
VITE_ENABLE_REGISTRATION=false
VITE_GOOGLE_CLIENT_ID=YOUR-CLIENT-ID-HERE.apps.googleusercontent.com
```

**Replace `YOUR-CLIENT-ID-HERE` with your actual Client ID!**

### Step 3: Add Client ID to Backend Config (Optional)

If not already configured, add to `backend/.env`:

```bash
GOOGLE_CLIENT_ID=YOUR-CLIENT-ID-HERE.apps.googleusercontent.com
```

### Step 4: Redeploy Frontend

```powershell
.\deploy-leave-tracker-frontend.ps1
```

This will:
- Build the frontend with the new environment variable
- Upload to Google Cloud Storage
- Make Google Sign-In button appear

---

## ✅ Verify It Works

1. Open: https://storage.googleapis.com/leave-tracker-2025-frontend/index.html
2. Click **Leave Tracker** → **Login**
3. You should now see: **"Continue with Google"** button

---

## 🔧 If Google Sign-In Still Doesn't Work

### Check OAuth Consent Screen
1. Go to: https://console.cloud.google.com/apis/credentials/consent?project=leave-tracker-2025
2. Make sure:
   - ✅ App status is **Published** or **Testing** (with test users added)
   - ✅ Scopes include: `email`, `profile`, `openid`
   - ✅ Your email is added to **Test users** (if status is Testing)

### Check Authorized Origins
1. Go to: https://console.cloud.google.com/apis/credentials?project=leave-tracker-2025
2. Click your OAuth 2.0 Client ID
3. Make sure **Authorized JavaScript origins** includes:
   ```
   https://storage.googleapis.com
   ```

### Check Browser Console
1. Open browser DevTools (F12)
2. Check Console tab for errors
3. Common errors:
   - **"invalid_client"** → Wrong Client ID (check .env.production)
   - **"redirect_uri_mismatch"** → Add origin to Google Console
   - **"access_blocked"** → Add your email to Test users

---

## 📋 Quick Commands

```powershell
# 1. Check current environment variables
Get-Content frontend\.env.production

# 2. Edit the file (add VITE_GOOGLE_CLIENT_ID)
notepad frontend\.env.production

# 3. Redeploy
.\deploy-leave-tracker-frontend.ps1

# 4. Test in browser
Start-Process "https://storage.googleapis.com/leave-tracker-2025-frontend/index.html"
```

---

## 🎯 What Happens After Fix

**Before Fix:**
```
[ Username ]
[ Password ]
[ Login Button ]
```

**After Fix:**
```
[ Username ]
[ Password ]
[ Login Button ]
─────────── OR ───────────
[ 🔵 Continue with Google ]
```

---

## 📞 Need Help?

See the full setup guide: [GOOGLE_OAUTH_SETUP.md](GOOGLE_OAUTH_SETUP.md)

Or check if backend is configured properly:
```powershell
# Check backend environment
Get-Content backend\.env | Select-String "GOOGLE_CLIENT_ID"

# Test backend Google login endpoint
Invoke-WebRequest -Uri "https://leave-tracker-api-2ajzj2dbrq-uc.a.run.app/auth/google-login" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"id_token":"test"}' `
  -UseBasicParsing
```

---

**That's it!** Once you add the Client ID and redeploy, Google Sign-In will be visible. 🚀
