from fastapi import APIRouter, Depends, HTTPException
import pyotp, qrcode, io, base64
import os
import secrets
from datetime import timedelta
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from .. import schemas
from ..db_factory import db
from ..core.security import (
    encrypt_username_with_password, 
    verify_password, 
    change_password,
    create_access_token,
    ACCESS_TOKEN_EXPIRE_MINUTES,
    get_current_user,
)

router = APIRouter()


def _build_login_response(username: str, allowed_systems: list[str]) -> dict:
    systems = allowed_systems or ["leave-tracker"]
    return {
        "allowed_systems": systems,
        "default_system": systems[0],
        "username": username,
    }


def _require_access_admin(current_user: str) -> None:
    """Restrict user-access management to users with is_admin flag in database.

    Falls back to ADMIN_USERS env var for backward compatibility during transition.
    """
    # Check database first
    user = db.get_user_by_username(current_user)
    if user and user.get("is_admin"):
        return

    # Fallback to env var for backward compatibility
    configured = os.getenv("ADMIN_USERS", "").strip()
    if not configured:
        # If no env var and no db is_admin flag, deny access
        raise HTTPException(status_code=403, detail="Admin access required")

    admin_users = {u.strip() for u in configured.split(",") if u.strip()}
    if current_user not in admin_users:
        raise HTTPException(status_code=403, detail="Admin access required")


def _normalize_allowed_systems(systems: list[str]) -> list[str]:
    allowed = []
    for name in systems:
        normalized = name.strip().lower()
        if normalized in {"leave-tracker", "nutrilens"} and normalized not in allowed:
            allowed.append(normalized)

    if not allowed:
        raise HTTPException(status_code=400, detail="At least one valid system is required")

    return allowed

@router.post("/register", response_model=schemas.RegisterResponse)
def register(data: schemas.UserCreate):
    # Check if user already exists
    existing_user = db.get_user_by_username(data.username)
    if existing_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    
    # Encrypt username with password as the key - password itself is never stored
    encrypted_password = encrypt_username_with_password(data.username, data.password)
    
    secret = pyotp.random_base32()
    user = db.create_user(data.username, encrypted_password, secret)
    db.set_user_system_access(user["id"], ["leave-tracker", "nutrilens"])

    otp_uri = pyotp.totp.TOTP(secret).provisioning_uri(name=data.username, issuer_name="TeamTracker")
    qr = qrcode.make(otp_uri)
    buffer = io.BytesIO()
    qr.save(buffer, format="PNG")
    img_b64 = base64.b64encode(buffer.getvalue()).decode()
    return {"qr": img_b64, "secret": secret, "username": user["username"], "id": user["id"]}

@router.post("/login", response_model=schemas.LoginResponse)
def login(data: schemas.TokenData):
    user = db.get_user_by_username(data.username)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Verify password by attempting to decrypt the stored encrypted username
    if not verify_password(data.username, data.password, user["password"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    # Check if running in development mode (bypass 2FA for localhost)
    is_dev_mode = os.getenv("ENVIRONMENT", "production").lower() == "development"
    
    if is_dev_mode:
        # Skip 2FA verification in development mode
        pass
    else:
        # Verify 2FA token in production
        totp = pyotp.TOTP(user["otp_secret"])
        if not totp.verify(data.token):
            raise HTTPException(status_code=401, detail="Invalid token")
    
    # Create JWT access token
    access_token = create_access_token(
        data={"sub": user["username"]},
        expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )

    allowed_systems = db.get_user_system_access(user["id"])
    login_payload = _build_login_response(user["username"], allowed_systems)
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        **login_payload,
    }


@router.post("/google-login", response_model=schemas.LoginResponse)
def google_login(data: schemas.GoogleLoginRequest):
    client_id = os.getenv("GOOGLE_CLIENT_ID", "").strip()
    if not client_id:
        raise HTTPException(status_code=503, detail="Google SSO is not configured")

    try:
        idinfo = google_id_token.verify_oauth2_token(
            data.id_token,
            google_requests.Request(),
            client_id,
        )
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=401, detail=f"Invalid Google token: {exc}")

    email = idinfo.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="Google account email is required")

    user = db.get_user_by_username(email)
    if not user:
        temp_password = secrets.token_urlsafe(32)
        encrypted_password = encrypt_username_with_password(email, temp_password)
        otp_secret = pyotp.random_base32()
        user = db.create_user(email, encrypted_password, otp_secret)
        db.set_user_system_access(user["id"], ["leave-tracker", "nutrilens"])

    allowed_systems = db.get_user_system_access(user["id"])
    access_token = create_access_token(
        data={"sub": user["username"]},
        expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),
    )
    login_payload = _build_login_response(user["username"], allowed_systems)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        **login_payload,
    }


@router.get("/me", response_model=schemas.UserSystemsResponse)
def get_me(current_user: str = Depends(get_current_user)):
    user = db.get_user_by_username(current_user)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    allowed_systems = db.get_user_system_access(user["id"])
    return _build_login_response(user["username"], allowed_systems)


@router.get("/user-access", response_model=list[schemas.UserAccessItem])
def list_user_access(current_user: str = Depends(get_current_user)):
    _require_access_admin(current_user)
    users = db.get_all_users()

    result: list[schemas.UserAccessItem] = []
    for user in users:
        systems = db.get_user_system_access(user["id"])
        result.append(
            schemas.UserAccessItem(
                user_id=user["id"],
                username=user["username"],
                allowed_systems=systems,
            )
        )

    return result


@router.put("/user-access/{username}", response_model=schemas.UserAccessItem)
def update_user_access(
    username: str,
    payload: schemas.UserAccessUpdate,
    current_user: str = Depends(get_current_user),
):
    _require_access_admin(current_user)
    user = db.get_user_by_username(username)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    systems = _normalize_allowed_systems(payload.allowed_systems)
    db.set_user_system_access(user["id"], systems)

    return schemas.UserAccessItem(
        user_id=user["id"],
        username=user["username"],
        allowed_systems=systems,
    )


@router.get("/user/{username}", response_model=schemas.UserDetailResponse)
def get_user_detail(
    username: str,
    current_user: str = Depends(get_current_user),
):
    """Get user details including admin status. Only admins can view other users."""
    if current_user != username:
        _require_access_admin(current_user)
    
    user = db.get_user_by_username(username)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    systems = db.get_user_system_access(user["id"])
    is_admin = bool(user.get("is_admin", 0))
    
    return schemas.UserDetailResponse(
        user_id=user["id"],
        username=user["username"],
        allowed_systems=systems,
        is_admin=is_admin,
    )


@router.put("/user/{username}/admin", response_model=schemas.UserDetailResponse)
def update_user_admin_status(
    username: str,
    payload: schemas.UserAdminUpdate,
    current_user: str = Depends(get_current_user),
):
    """Update user admin status. Only admins can grant/revoke admin rights."""
    _require_access_admin(current_user)
    
    user = db.get_user_by_username(username)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Prevent self-demotion
    if current_user == username and not payload.is_admin:
        raise HTTPException(
            status_code=400,
            detail="Cannot remove admin status from yourself"
        )
    
    db.update_user_admin_status(user["id"], payload.is_admin)
    updated_user = db.get_user_by_username(username)
    systems = db.get_user_system_access(user["id"])
    
    return schemas.UserDetailResponse(
        user_id=updated_user["id"],
        username=updated_user["username"],
        allowed_systems=systems,
        is_admin=bool(payload.is_admin),
    )

@router.post("/change-password")
def change_user_password(data: schemas.PasswordChange):
    """
    Change user password. Requires old password verification.
    Since password is used as encryption key, we re-encrypt with new password.
    """
    user = db.get_user_by_username(data.username)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    try:
        # This will verify old password and create new encrypted value
        new_encrypted = change_password(
            data.username, 
            data.old_password, 
            data.new_password, 
            user["password"]
        )
        # Update user password in database
        db.update_user_password(user["id"], new_encrypted)
        return {"success": True, "message": "Password changed successfully"}
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))


# ==================== NUTRILENS PROFILE ====================

@router.get("/nutrilens-profile", response_model=schemas.NutriLensProfileResponse)
def get_nutrilens_profile(current_user: str = Depends(get_current_user)):
    """Get NutriLens profile for current user (dietary goals and preferences)."""
    user = db.get_user_by_username(current_user)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    profile = db.get_nutrilens_profile(user["id"])
    return schemas.NutriLensProfileResponse(
        username=current_user,
        **profile
    )


@router.patch("/nutrilens-profile", response_model=schemas.NutriLensProfileResponse)
def update_nutrilens_profile(
    profile_update: schemas.NutriLensProfile,
    current_user: str = Depends(get_current_user)
):
    """Update NutriLens profile for current user."""
    user = db.get_user_by_username(current_user)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    updated = db.update_nutrilens_profile(user["id"], profile_update.dict())
    return schemas.NutriLensProfileResponse(
        username=current_user,
        **updated
    )
