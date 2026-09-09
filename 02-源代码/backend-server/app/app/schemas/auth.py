from pydantic import BaseModel, Field, field_validator


class LoginRequest(BaseModel):
    username: str = Field(min_length=1)
    password: str = Field(min_length=1)
    # 注册时可选携带；登录接口忽略这些字段。
    real_name: str | None = Field(default=None, max_length=64)
    role: str | None = None


class RegisterRequest(BaseModel):
    """注册请求：用户名 3-32 位字母数字下划线，密码 8-64 位须含字母与数字。"""

    username: str = Field(min_length=3, max_length=32, pattern=r"^[A-Za-z0-9_]+$")
    password: str = Field(min_length=8, max_length=64)
    real_name: str | None = Field(default=None, max_length=64)

    @field_validator("password")
    @classmethod
    def _password_strength(cls, v: str) -> str:
        if not (any(c.isalpha() for c in v) and any(c.isdigit() for c in v)):
            raise ValueError("密码需同时包含字母和数字")
        return v


class UserRead(BaseModel):
    id: int
    username: str
    role: str
    model_config = {"from_attributes": True}


class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    pwd_changed: int = 0
    user: UserRead


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=1)


class PasswordChange(BaseModel):
    old_password: str = Field(min_length=1)
    new_password: str = Field(min_length=8, max_length=64)

    @field_validator("new_password")
    @classmethod
    def _has_letter_and_digit(cls, v: str) -> str:
        if not (any(c.isalpha() for c in v) and any(c.isdigit() for c in v)):
            raise ValueError("密码需包含字母和数字")
        return v
