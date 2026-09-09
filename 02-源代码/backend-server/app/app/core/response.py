"""Unified success envelope: ``{code: 0, message, data}``."""


def success(data=None, message: str = "ok") -> dict:
    return {"code": 0, "message": message, "data": data}
