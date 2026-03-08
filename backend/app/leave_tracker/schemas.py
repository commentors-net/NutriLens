
from pydantic import BaseModel
from datetime import date

class UserBase(BaseModel):
    username: str

class UserCreate(UserBase):
    password: str

class User(UserBase):
    id: str

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str


class LoginResponse(Token):
    username: str
    allowed_systems: list[str]
    default_system: str

class TokenData(BaseModel):
    username: str
    password: str
    token: str


class GoogleLoginRequest(BaseModel):
    id_token: str

class RegisterResponse(BaseModel):
    qr: str
    secret: str
    username: str
    id: str


class UserSystemsResponse(BaseModel):
    username: str
    allowed_systems: list[str]
    default_system: str


class UserAccessItem(BaseModel):
    user_id: str
    username: str
    allowed_systems: list[str]


class UserAccessUpdate(BaseModel):
    allowed_systems: list[str]


class UserAdminUpdate(BaseModel):
    is_admin: bool


class UserDetailResponse(BaseModel):
    user_id: str
    username: str
    allowed_systems: list[str]
    is_admin: bool

class PasswordChange(BaseModel):
    username: str
    old_password: str
    new_password: str

class AbsenceBase(BaseModel):
    date: date
    duration: str
    reason: str
    type_id: str
    person_id: str

class AbsenceCreate(AbsenceBase):
    applied: int = 0

class AbsenceUpdate(BaseModel):
    applied: int

class Absence(AbsenceBase):
    id: str
    applied: int = 0

    class Config:
        from_attributes = True

class PeopleBase(BaseModel):
    name: str

class PeopleCreate(PeopleBase):
    pass

class People(PeopleBase):
    id: str

    class Config:
        from_attributes = True

class TypeBase(BaseModel):
    name: str

class TypeCreate(TypeBase):
    pass

class Type(TypeBase):
    id: str

    class Config:
        from_attributes = True

# Smart Identification Schemas
class SmartIdentificationRequest(BaseModel):
    conversation: str

class ParsedLeaveEntry(BaseModel):
    person_name: str
    date: str
    leave_type: str
    reason: str
    confidence: str

class SmartIdentificationResponse(BaseModel):
    entries: list[ParsedLeaveEntry]
    raw_analysis: str

# AI Instructions Schemas
class AIInstructionsBase(BaseModel):
    instructions: str

class AIInstructionsCreate(AIInstructionsBase):
    pass

class AIInstructionsUpdate(AIInstructionsBase):
    pass

class AIInstructions(AIInstructionsBase):
    id: str
    created_at: str
    updated_at: str

    class Config:
        from_attributes = True
