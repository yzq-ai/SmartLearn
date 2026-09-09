from __future__ import annotations

from app.database import Base  # noqa: F401
from app.models.user import User, SysLoginLog, SysAuditLog, SysConfig, SensitiveWord
from app.models.course import Course, Chapter, Resource, Section, CourseEnrollment, CourseSkillTag
from app.models.exam import (
    KnowledgePoint, Question, ExamPaper, ExamPaperQuestion, Exam,
    ExamRecord, ExamAnswer, Assignment, AssignmentSubmission,
    WrongQuestion, StudentKpMastery, Progress, ExamAttempt,
)
from app.models.job import (
    Company, JobSkillTag, JobPosting, StudentProfile, Resume,
    JobApplication, JobFavorite, CareerEvent, CareerEventSignup,
)
from app.models.notify import (
    Notification, NotificationRead, SignTask, SignRecord,
    DiscussionPost, DiscussionReply, DiscussionLike, DiscussionReplyLike,
)
from app.models.contact import Friendship, ChatMessage
from app.models.ai_stat import AiChatLog, StudyPlan, StatDailyLearning
from app.models.feedback import Feedback

__all__ = [
    "Base",
    # 用户域
    "User", "SysLoginLog", "SysAuditLog", "SysConfig", "SensitiveWord",
    # 课程域
    "Course", "Chapter", "Resource", "Section", "CourseEnrollment", "CourseSkillTag",
    # 测评域
    "KnowledgePoint", "Question", "ExamPaper", "ExamPaperQuestion", "Exam",
    "ExamRecord", "ExamAnswer", "Assignment", "AssignmentSubmission",
    "WrongQuestion", "StudentKpMastery",
    # 就业域
    "Company", "JobSkillTag", "JobPosting", "StudentProfile", "Resume",
    "JobApplication", "JobFavorite", "CareerEvent", "CareerEventSignup",
    # 服务域
    "Notification", "NotificationRead", "SignTask", "SignRecord",
    "DiscussionPost", "DiscussionReply", "DiscussionLike", "DiscussionReplyLike",
    # 联系人域（好友/师生/私聊）
    "Friendship", "ChatMessage",
    # AI 与统计域
    "AiChatLog", "StudyPlan", "StatDailyLearning",
    # 反馈域
    "Feedback",
    # 兼容
    "Progress", "ExamAttempt",
]
