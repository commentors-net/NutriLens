"""
Password encryption using the password itself as the encryption key.
The username is encrypted using a key derived from the password.
This means the password is never stored, and cannot be recovered.
"""
import os
import base64
import hashlib
from datetime import datetime, timedelta
from typing import Optional
from cryptography.fernet import Fernet
from jose import JWTError, jwt
from dotenv import load_dotenv
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

# Load environment variables
load_dotenv()

# JWT Configuration from environment variables
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-this-in-production-use-openssl-rand-hex-32")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))

# Security scheme for JWT Bearer token
security = HTTPBearer()


def derive_key_from_password(password: str) -> bytes:
    """
    Derive a Fernet-compatible key from a password.
    Uses SHA-256 to create a 32-byte key, then base64 encodes it.
    """
    # Hash the password to get a 32-byte key
    key = hashlib.sha256(password.encode()).digest()
    # Fernet requires base64-encoded 32-byte key
    return base64.urlsafe_b64encode(key)


def encrypt_username_with_password(username: str, password: str) -> str:
    """
    Encrypt the username using the password as the key.
    Returns the encrypted string (stored in password column).
    """
    key = derive_key_from_password(password)
    fernet = Fernet(key)
    encrypted = fernet.encrypt(username.encode())
    return encrypted.decode()


def verify_password(username: str, password: str, stored_encrypted: str) -> bool:
    """
    Verify if the password is correct by attempting to decrypt the stored value
    and checking if it matches the username.
    
    Args:
        username: The username attempting to log in
        password: The password provided by the user
        stored_encrypted: The encrypted value stored in the database
    
    Returns:
        True if decryption succeeds and produces the correct username
    """
    try:
        key = derive_key_from_password(password)
        fernet = Fernet(key)
        decrypted = fernet.decrypt(stored_encrypted.encode()).decode()
        return decrypted == username
    except Exception:
        # Decryption failed or wrong key
        return False


def change_password(username: str, old_password: str, new_password: str, stored_encrypted: str) -> str:
    """
    Change password by verifying old password and creating new encrypted value.
    
    Args:
        username: The username
        old_password: Current password to verify
        new_password: New password to set
        stored_encrypted: Current encrypted value in database
    
    Returns:
        New encrypted string to store
        
    Raises:
        ValueError: If old password is incorrect
    """
    if not verify_password(username, old_password, stored_encrypted):
        raise ValueError("Old password is incorrect")
    
    return encrypt_username_with_password(username, new_password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    Create a JWT access token.
    
    Args:
        data: Data to encode in the token (typically {"sub": username})
        expires_delta: Optional expiration time delta
    
    Returns:
        Encoded JWT token string
    """
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def verify_token(token: str) -> Optional[str]:
    """
    Verify and decode a JWT token.
    
    Args:
        token: JWT token string
    
    Returns:
        Username from token if valid, None otherwise
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            return None
        return username
    except JWTError:
        return None


def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    """
    FastAPI dependency to get current authenticated user from JWT token.
    
    Args:
        credentials: HTTP Authorization credentials (Bearer token)
    
    Returns:
        Username from validated token
    
    Raises:
        HTTPException: If token is invalid or missing
    """
    token = credentials.credentials
    username = verify_token(token)
    if username is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return username
