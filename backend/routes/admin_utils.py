from fastapi import HTTPException, Request, status


def require_admin(request: Request) -> str:
    role = getattr(request.state, "user_role", None)
    user_id = getattr(request.state, "user_id", None)
    if role != "admin" or not user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user_id
