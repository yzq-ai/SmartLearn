from typing import Any

from datetime import datetime

from pydantic import BaseModel, Field

from .ai import WrongAnswerAnalysis, WrongAnswerInput, ResumeItem, ResumeOptimizeRequest, ResumeOptimizeResponse
from .auth import LoginRequest, LoginResponse, PasswordChange, RefreshRequest, RegisterRequest, UserRead
from .jobs import JobApplicationRead, JobFavoriteRead, JobRead
from .learning import ChapterRead, CourseDetail, ProgressRead, ProgressUpdate, SectionRead

User = UserRead


class Answer(BaseModel):
    question_id: int
    answer: str | list[str]


class ExamSubmitRequest(BaseModel):
    answers: list[Answer]


class ExamAnswersSaveRequest(BaseModel):
    answers: list[Answer]


class Course(BaseModel):
    """Legacy course shape retained for list endpoint compatibility."""

    id: int
    title: str
    description: str
    teacher: str
    chapters: list[str]


class CourseCreate(BaseModel):
    """创建课程请求体（教师/管理员）。"""

    title: str = Field(min_length=1, max_length=100)
    description: str = ""
    teacher: str | None = None


class QuestionCreate(BaseModel):
    """题库新增/编辑请求体（教师）。"""

    type: str = Field(min_length=1)
    content: str = Field(min_length=1)
    answer: str = Field(min_length=1)
    options: list[str] | None = None
    analysis: str | None = None
    difficulty: int = Field(default=3, ge=1, le=5)
    score: float = Field(default=5, ge=0)
    kp_ids: list[int] | None = None
    course_id: int | None = None


class JobCreate(BaseModel):
    """岗位创建请求体（教师/管理员，先审后发）。"""

    title: str = Field(min_length=1, max_length=100)
    company: str = Field(min_length=1, max_length=200)
    description: str = Field(min_length=1)
    required_skills: list[str] = Field(default_factory=list)
    city: str | None = None
    job_type: str = "INTERNSHIP"


class CompanyCreate(BaseModel):
    """企业创建请求体（先审后发）。"""

    name: str = Field(min_length=1, max_length=100)
    industry: str | None = None
    scale: str | None = None
    intro: str | None = None


class CareerEventCreate(BaseModel):
    """招聘活动创建请求体（教师/管理员：宣讲会/双选会/实习实践）。"""

    title: str = Field(min_length=1, max_length=100)
    event_type: str = Field(default="TALK")  # TALK / FAIR / INTERNSHIP
    company_id: int | None = None
    description: str | None = None
    location: str | None = Field(default=None, max_length=100)
    start_time: datetime
    end_time: datetime


class ReviewDecision(BaseModel):
    """审核决定（管理端审核工作台）。"""

    target_type: str = Field(min_length=1)  # JOB / COMPANY / POST / REPLY
    target_id: int
    action: str = Field(min_length=1)  # APPROVE / REJECT
    reason: str | None = None


class DiscussionCreate(BaseModel):
    """讨论帖创建。"""

    course_id: int
    title: str | None = None
    content: str = Field(min_length=1)


class ReplyCreate(BaseModel):
    """讨论回复。"""

    content: str = Field(min_length=1)
    reply_to_id: int | None = None


class ReportCreate(BaseModel):
    """举报（让内容重新进入审核队列）。"""

    target_type: str = Field(min_length=1)  # POST / REPLY
    target_id: int
    reason: str | None = None


class SignTaskCreate(BaseModel):
    """签到任务创建。"""

    course_id: int
    geo_enabled: int = 0
    geo_lat: float | None = None
    geo_lng: float | None = None
    expire_min: int = 5


class SignScan(BaseModel):
    """扫码签到（旧二维码模式，兼容保留）。"""

    task_id: int
    token: str = Field(min_length=1)


class SignCheckin(BaseModel):
    """数字码签到：学生输入教师发起的 4 位数字码。"""

    task_id: int
    code: str = Field(min_length=4, max_length=4, pattern=r"^\d{4}$")


class AssignmentCreate(BaseModel):
    """作业发布（教师）。"""

    course_id: int
    title: str = Field(min_length=1, max_length=100)
    description: str | None = None
    max_score: int = Field(default=100, ge=1)
    deadline: datetime


class AssignmentSubmit(BaseModel):
    """作业提交（学生）。"""

    content: str | None = None
    resource_ids: list[int] | None = None


class GradeSubmission(BaseModel):
    """作业批改（教师）。"""

    score: float = Field(ge=0)
    feedback: str | None = None
    return_for_redo: bool = False


class SensitiveWordCreate(BaseModel):
    word: str = Field(min_length=1, max_length=100)
    level: int = Field(default=1, ge=1, le=2)


class ConfigUpsert(BaseModel):
    cfg_key: str = Field(min_length=1, max_length=50)
    cfg_value: str
    remark: str | None = None


class SkillTagCreate(BaseModel):
    name: str = Field(min_length=1, max_length=50)
    category: str | None = None


class UserImportItem(BaseModel):
    username: str = Field(min_length=1, max_length=50)
    real_name: str = Field(min_length=1, max_length=50)
    role: str = Field(default="STUDENT")
    password: str | None = None


class UserImportRequest(BaseModel):
    users: list[UserImportItem]


class UserStatusUpdate(BaseModel):
    status: int = Field(ge=0, le=1)


class UserPasswordReset(BaseModel):
    new_password: str = Field(min_length=8, max_length=64)


class ResumeCreate(BaseModel):
    """简历创建/更新（内容为 JSON 分区块）。"""

    title: str = Field(default="我的简历", max_length=100)
    content: dict


class ResourceCreate(BaseModel):
    """资源元数据登记（教师，上传后调用）。"""

    file_name: str = Field(min_length=1, max_length=200)
    file_type: str | None = None
    file_size: int | None = None
    oss_key: str = Field(min_length=1, max_length=255)
    duration: int | None = None


class Job(BaseModel):
    """Legacy job recommendation shape retained for existing clients."""

    id: int
    title: str
    company: str
    required_skills: list[str]
    match_score: float | None = None
    matched_tags: list[str] = Field(default_factory=list)
    gap_tags: list[str] = Field(default_factory=list)


class ExamResult(BaseModel):
    exam_id: int
    score: float
    total: float
    passed: bool
    details: list[dict[str, Any]]


class ExamCreate(BaseModel):
    """教师建考试（选题组卷）。"""

    course_id: int
    title: str = Field(min_length=1, max_length=100)
    duration_min: int = Field(default=60, ge=1)
    pass_score: int = Field(default=60, ge=0)
    question_ids: list[int] = Field(default_factory=list)


class JobStatusUpdate(BaseModel):
    """投递状态流转（教师/管理员）。"""

    status: str = Field(min_length=1)  # VIEWED/INTERVIEW/OFFER/REJECTED
    reject_reason: str | None = None


class PaperRandomRequest(BaseModel):
    """规则抽题组卷。"""

    course_id: int
    title: str = Field(min_length=1, max_length=100)
    type: str | None = None
    difficulty: int | None = Field(default=None, ge=1, le=5)
    count: int = Field(default=10, ge=1, le=50)
    kp_ids: list[int] | None = None


class AiFeedbackRequest(BaseModel):
    """AI 结果赞踩。"""

    log_id: int
    feedback: int = Field(ge=-1, le=1)
