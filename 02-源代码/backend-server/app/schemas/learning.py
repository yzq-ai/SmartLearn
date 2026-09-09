from datetime import datetime

from pydantic import BaseModel, Field, model_validator


class SectionRead(BaseModel):
    id: int
    title: str
    content: str = ""
    video_url: str | None = None
    duration_minutes: int = 0
    position: int

    model_config = {"from_attributes": True}


class ChapterRead(BaseModel):
    id: int
    title: str
    description: str = ""
    position: int
    sections: list[SectionRead] = Field(default_factory=list)

    model_config = {"from_attributes": True}


class CourseDetail(BaseModel):
    id: int
    title: str
    description: str
    teacher: str
    chapters: list[ChapterRead] = Field(default_factory=list)

    model_config = {"from_attributes": True}


class ProgressUpdate(BaseModel):
    percent: float = Field(ge=0, le=100)
    chapter_id: int | None = None
    section_id: int | None = None

    @model_validator(mode="after")
    def section_requires_chapter(self):
        if self.section_id is not None and self.chapter_id is None:
            raise ValueError("section_id 需要同时提供 chapter_id")
        return self


class ProgressRead(BaseModel):
    id: int
    user_id: int
    course_id: int
    chapter_id: int | None = None
    section_id: int | None = None
    percent: float
    updated_at: datetime

    model_config = {"from_attributes": True}
