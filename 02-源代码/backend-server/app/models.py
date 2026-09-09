"""Compatibility exports for the canonical ``app.models`` package.

Python resolves the package directory in normal imports; this file is kept for
older tooling that loads it directly.
"""

from app.models import (  # noqa: F401
    Base,
    Chapter,
    Course,
    Exam,
    ExamAnswer,
    ExamAttempt,
    ExamRecord,
    Progress,
    Question,
    User,
)

__all__ = [
    "Base", "User", "Course", "Chapter", "Exam", "Question", "Progress",
    "ExamRecord", "ExamAnswer", "ExamAttempt",
]
