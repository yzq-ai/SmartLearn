from __future__ import annotations

from datetime import datetime

from sqlalchemy import JSON, Boolean, Float, Integer, String, Text, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class KnowledgePoint(Base):
    __tablename__ = "knowledge_point"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    course_id: Mapped[int | None] = mapped_column(ForeignKey("course.id"), nullable=True)
    parent_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    __table_args__ = (UniqueConstraint("name", "course_id", name="uq_name_course"),)


class Question(Base):
    __tablename__ = "question"

    id: Mapped[int] = mapped_column(primary_key=True)
    course_id: Mapped[int | None] = mapped_column(ForeignKey("course.id"), nullable=True)
    exam_id: Mapped[int | None] = mapped_column(ForeignKey("exam.id"), nullable=True)
    type: Mapped[str] = mapped_column(String(10))
    text: Mapped[str] = mapped_column("content", Text)
    options: Mapped[list | None] = mapped_column(JSON, nullable=True)
    answer: Mapped[str] = mapped_column(String(255))
    analysis: Mapped[str | None] = mapped_column(Text, nullable=True)
    difficulty: Mapped[int] = mapped_column(Integer, default=3)
    score: Mapped[float] = mapped_column(Float, default=5)
    kp_ids: Mapped[list | None] = mapped_column(JSON, nullable=True)
    source: Mapped[str] = mapped_column(String(10), default="MANUAL")
    status: Mapped[str] = mapped_column(String(10), default="PUBLISHED")
    created_by: Mapped[int | None] = mapped_column(ForeignKey("sys_user.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class ExamPaper(Base):
    __tablename__ = "exam_paper"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(100))
    course_id: Mapped[int] = mapped_column(ForeignKey("course.id"))
    total_score: Mapped[int] = mapped_column(Integer, default=100)
    created_by: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class ExamPaperQuestion(Base):
    __tablename__ = "exam_paper_question"

    id: Mapped[int] = mapped_column(primary_key=True)
    paper_id: Mapped[int] = mapped_column(ForeignKey("exam_paper.id"))
    question_id: Mapped[int] = mapped_column(ForeignKey("question.id"))
    score: Mapped[float] = mapped_column(Float, default=5)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    __table_args__ = (UniqueConstraint("paper_id", "question_id", name="uk_paper_que"),)


class Exam(Base):
    __tablename__ = "exam"

    id: Mapped[int] = mapped_column(primary_key=True)
    course_id: Mapped[int | None] = mapped_column(ForeignKey("course.id"), nullable=True)
    paper_id: Mapped[int | None] = mapped_column(ForeignKey("exam_paper.id"), nullable=True)
    title: Mapped[str] = mapped_column(String(200))
    total_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    pass_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    duration_min: Mapped[int] = mapped_column(Integer, default=60)
    start_time: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    end_time: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    max_switch_cnt: Mapped[int] = mapped_column(Integer, default=3)
    show_score_mode: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[int] = mapped_column(Integer, default=0)
    created_by: Mapped[int | None] = mapped_column(ForeignKey("sys_user.id"), nullable=True)
    questions = relationship("Question", cascade="all, delete-orphan")


class ExamRecord(Base):
    __tablename__ = "exam_record"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"), index=True)
    exam_id: Mapped[int] = mapped_column(ForeignKey("exam.id"), index=True)
    paper_snapshot: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="IN_PROGRESS", index=True)
    started_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    deadline_at: Mapped[datetime] = mapped_column(DateTime)
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    submit_type: Mapped[str | None] = mapped_column(String(10), nullable=True)
    score: Mapped[float | None] = mapped_column(Float, nullable=True)
    objective_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    total: Mapped[float | None] = mapped_column(Float, nullable=True)
    passed: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    switch_count: Mapped[int] = mapped_column(Integer, default=0)
    version: Mapped[int] = mapped_column(Integer, default=0)
    answers = relationship("ExamAnswer", cascade="all, delete-orphan", back_populates="record")
    __table_args__ = (UniqueConstraint("user_id", "exam_id", name="uq_exam_record_user_exam"),)


class ExamAnswer(Base):
    __tablename__ = "exam_answer"

    id: Mapped[int] = mapped_column(primary_key=True)
    record_id: Mapped[int] = mapped_column(ForeignKey("exam_record.id", ondelete="CASCADE"), index=True)
    question_id: Mapped[int] = mapped_column(ForeignKey("question.id"))
    answer: Mapped[str] = mapped_column(Text)
    is_correct: Mapped[int | None] = mapped_column(Integer, nullable=True)
    score: Mapped[float | None] = mapped_column(Float, nullable=True)
    ai_suggest_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    teacher_comment: Mapped[str | None] = mapped_column(String(200), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    record = relationship("ExamRecord", back_populates="answers")
    __table_args__ = (UniqueConstraint("record_id", "question_id", name="uq_exam_answer_record_question"),)


class Assignment(Base):
    __tablename__ = "assignment"

    id: Mapped[int] = mapped_column(primary_key=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("course.id"))
    chapter_id: Mapped[int | None] = mapped_column(ForeignKey("chapter.id"), nullable=True)
    title: Mapped[str] = mapped_column(String(100))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    resource_ids: Mapped[list | None] = mapped_column(JSON, nullable=True)
    max_score: Mapped[int] = mapped_column(Integer, default=100)
    deadline: Mapped[datetime] = mapped_column(DateTime)
    status: Mapped[int] = mapped_column(Integer, default=0)
    created_by: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class AssignmentSubmission(Base):
    __tablename__ = "assignment_submission"

    id: Mapped[int] = mapped_column(primary_key=True)
    assignment_id: Mapped[int] = mapped_column(ForeignKey("assignment.id"))
    student_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))
    content: Mapped[str | None] = mapped_column(Text, nullable=True)
    resource_ids: Mapped[list | None] = mapped_column(JSON, nullable=True)
    submitted_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    is_late: Mapped[int] = mapped_column(Integer, default=0)
    score: Mapped[float | None] = mapped_column(Float, nullable=True)
    feedback: Mapped[str | None] = mapped_column(Text, nullable=True)
    graded_by: Mapped[int | None] = mapped_column(ForeignKey("sys_user.id"), nullable=True)
    graded_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    status: Mapped[str] = mapped_column(String(10), default="SUBMITTED")
    version: Mapped[int] = mapped_column(Integer, default=1)
    __table_args__ = (UniqueConstraint("assignment_id", "student_id", name="uq_asg_stu"),)


class WrongQuestion(Base):
    __tablename__ = "wrong_question"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"), index=True)
    question_id: Mapped[int] = mapped_column(ForeignKey("question.id"), index=True)
    my_answer: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_type: Mapped[str | None] = mapped_column(String(10), nullable=True)
    source_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    wrong_count: Mapped[int] = mapped_column(Integer, default=1)
    is_mastered: Mapped[int] = mapped_column(Integer, default=0)
    mastered_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    question = relationship("Question")
    __table_args__ = (UniqueConstraint("user_id", "question_id", "source_type", name="uq_user_que_src"),)


class StudentKpMastery(Base):
    __tablename__ = "student_kp_mastery"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"), index=True)
    kp_id: Mapped[int] = mapped_column(ForeignKey("knowledge_point.id"), index=True)
    correct_cnt: Mapped[int] = mapped_column(Integer, default=0)
    total_cnt: Mapped[int] = mapped_column(Integer, default=0)
    mastery_pct: Mapped[float] = mapped_column(Float, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    __table_args__ = (UniqueConstraint("user_id", "kp_id", name="uq_user_kp"),)


class Progress(Base):
    """MVP 学习进度表（文档后续合并进 course_enrollment）。"""

    __tablename__ = "progress"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("sys_user.id"))
    course_id: Mapped[int] = mapped_column(ForeignKey("course.id"))
    chapter_id: Mapped[int | None] = mapped_column(ForeignKey("chapter.id"), nullable=True)
    section_id: Mapped[int | None] = mapped_column(ForeignKey("section.id"), nullable=True)
    percent: Mapped[float] = mapped_column(Float, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    __table_args__ = (UniqueConstraint("user_id", "course_id", name="uq_progress"),)


ExamAttempt = ExamRecord

__all__ = [
    "KnowledgePoint", "Question", "ExamPaper", "ExamPaperQuestion", "Exam",
    "ExamRecord", "ExamAnswer", "Assignment", "AssignmentSubmission",
    "WrongQuestion", "StudentKpMastery", "Progress", "ExamAttempt",
]
