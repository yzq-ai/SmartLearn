from datetime import datetime

from pydantic import BaseModel, Field


class JobRead(BaseModel):
    id: int
    title: str
    company: str
    description: str = ""
    required_skills: list[str] = Field(default_factory=list)
    match_score: float | None = None
    matched_tags: list[str] = Field(default_factory=list)
    gap_tags: list[str] = Field(default_factory=list)
    is_favorite: bool = False
    application_status: str | None = None


class JobApplicationRead(BaseModel):
    id: int
    job_id: int
    status: str
    applied_at: datetime

    model_config = {"from_attributes": True}


class JobFavoriteRead(BaseModel):
    job_id: int
    favorited: bool
