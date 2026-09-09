"""Backward-compatible auth facade.

All implementations live in ``app.core.security`` and ``app.core.deps``; this
module keeps the original import surface for existing routes and tests.
"""
from app.core.deps import get_current_user, get_optional_user, oauth2_scheme, require_perm, require_roles
from app.core.security import create_refresh_token, decode_token, hash_password, verify_password

current_user = get_current_user


def create_access_token(user) -> str:
    from app.core.security import create_access_token as _create_access_token

    return _create_access_token(str(user.id), user.role)


__all__ = [
    "hash_password",
    "verify_password",
    "create_access_token",
    "create_refresh_token",
    "decode_token",
    "current_user",
    "get_optional_user",
    "require_roles",
    "require_perm",
    "oauth2_scheme",
]
