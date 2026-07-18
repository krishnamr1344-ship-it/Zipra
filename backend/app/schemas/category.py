import re
from typing import Optional
from pydantic import BaseModel, field_validator

NAME_REGEX = r"^[a-zA-Z\s.\-]{2,50}$"
NAME_REGEX_MSG = "Invalid name format (only letters, spaces, dots, hyphens; 2-50 chars)"
MAX_NAME_LENGTH = 100
DESC_LENGTH = 2000


class CategoryCreate(BaseModel):
    name: str
    description: Optional[str] = None
    image: Optional[str] = None

    @field_validator("name")
    @classmethod
    def valid_name(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Category name is required")
        if len(v) > MAX_NAME_LENGTH:
            raise ValueError(f"Name must not exceed {MAX_NAME_LENGTH} characters")
        if not re.match(NAME_REGEX, v):
            raise ValueError(NAME_REGEX_MSG)
        return v

    @field_validator("description")
    @classmethod
    def valid_desc(cls, v):
        if v and len(v) > DESC_LENGTH:
            raise ValueError(f"Description must not exceed {DESC_LENGTH} characters")
        return v


class CategoryResponse(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    image: Optional[str] = None

    class Config:
        from_attributes = True
