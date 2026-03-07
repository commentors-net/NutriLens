from fastapi import APIRouter, Depends, HTTPException
import pyotp, qrcode, io, base64
import os
from datetime import timedelta
from .. import schemas
from ..db_factory import db
from ..core.security import (
    encrypt_username_with_password, 
    verify_password, 
    change_password,
    create_access_token,
    ACCESS_TOKEN_EXPIRE_MINUTES
)

router = APIRouter()

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

    otp_uri = pyotp.totp.TOTP(secret).provisioning_uri(name=data.username, issuer_name="TeamTracker")
    qr = qrcode.make(otp_uri)
    buffer = io.BytesIO()
    qr.save(buffer, format="PNG")
    img_b64 = base64.b64encode(buffer.getvalue()).decode()
    return {"qr": img_b64, "secret": secret, "username": user["username"], "id": user["id"]}

@router.post("/login")
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
    
    return {
        "success": True,
        "access_token": access_token,
        "token_type": "bearer",
        "username": user["username"]
    }

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
