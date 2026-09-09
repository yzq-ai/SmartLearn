"""Pydantic contracts for AI assistance endpoints.

Inputs are deliberately bounded and responses retain original text; clients must
choose whether to apply suggestions.
"""
from pydantic import BaseModel, Field


class WrongAnswerInput(BaseModel):
    question: str = Field(min_length=1, max_length=10000)
    answer: str = Field(min_length=1, max_length=5000)
    correct_answer: str = Field(min_length=1, max_length=5000)
    subject: str | None = Field(default=None, max_length=200)


class WrongAnswerAnalysis(BaseModel):
    cause_category: str
    analysis: str
    suggestions: list[str]
    knowledge_points: list[str]
    source: str = "rules"


class ResumeItem(BaseModel):
    original: str = Field(min_length=1, max_length=5000)
    suggestion: str
    reason: str
    type: str


class ResumeOptimizeRequest(BaseModel):
    resume: str = Field(min_length=1, max_length=30000)
    target_role: str | None = Field(default=None, max_length=200)


class ResumeOptimizeResponse(BaseModel):
    items: list[ResumeItem]
    source: str = "rules"
    note: str = "建议仅供参考，不会自动覆盖原文。"


class JobExplainRequest(BaseModel):
    """岗位推荐解释：规则引擎已算出匹配分与标签，LLM 仅润色不改变数值。

    传 job_id 时后端自动取真实岗位 JD/技能权重与学生画像，组装完整上下文给真实 AI。
    """

    job_title: str = Field(min_length=1, max_length=100)
    required_skills: list[str] = Field(default_factory=list)
    match_score: float = 0
    matched_tags: list[str] = Field(default_factory=list)
    gap_tags: list[str] = Field(default_factory=list)
    job_id: int | None = None


class JobExplainResponse(BaseModel):
    explanation: str
    suggestions: list[str]
    match_score: float
    source: str = "rules"


class SummaryRequest(BaseModel):
    text: str = Field(min_length=1, max_length=50000)


class SummaryResponse(BaseModel):
    summary: str
    key_points: list[str]
    source: str = "rules"


class PlanRequest(BaseModel):
    goal: str = Field(default="", max_length=200)
    daily_minutes: int = Field(default=60, ge=10, le=600)
    weak_kps: list[str] = Field(default_factory=list)
    days: int = Field(default=7, ge=1, le=30)


class PlanTask(BaseModel):
    kp: str
    minutes: int


class PlanDay(BaseModel):
    date: str
    tasks: list[PlanTask]


class PlanResponse(BaseModel):
    plan: list[PlanDay]
    source: str = "rules"


class InterviewStartRequest(BaseModel):
    job_title: str = Field(min_length=1, max_length=100)
    required_skills: list[str] = Field(default_factory=list)


class InterviewStartResponse(BaseModel):
    question: str
    turn: int = 1
    max_turns: int = 8


class InterviewTurnRequest(BaseModel):
    job_title: str = Field(min_length=1, max_length=100)
    question: str = Field(min_length=1)
    answer: str = Field(min_length=1, max_length=5000)
    turn: int = Field(default=1, ge=1)


class InterviewTurnResponse(BaseModel):
    feedback: str
    next_question: str | None = None
    done: bool = False
    scores: dict[str, float] | None = None


class QuestionGenRequest(BaseModel):
    """题目生成：生成题进入 DRAFT，教师采纳后才 PUBLISHED。"""

    kp_names: list[str] = Field(default_factory=list)
    type: str = "SINGLE"  # SINGLE/MULTI/JUDGE/BLANK
    count: int = Field(default=1, ge=1, le=20)
    difficulty: int = Field(default=3, ge=1, le=5)
    course_id: int | None = None


class GeneratedQuestion(BaseModel):
    type: str
    content: str
    options: list[str] | None = None
    answer: str
    analysis: str
    difficulty: int
    kp_names: list[str]


class QuestionGenResponse(BaseModel):
    questions: list[GeneratedQuestion]
    source: str = "rules"


class CourseQaRequest(BaseModel):
    course_id: int
    query: str = Field(min_length=1, max_length=1000)


class QaRef(BaseModel):
    source: str
    snippet: str


class CourseQaResponse(BaseModel):
    answer: str
    refs: list[QaRef] = Field(default_factory=list)
    grounded: bool = True
    source: str = "rules"
