from app.api.v1.auth import router as auth_router
from app.api.v1.users import router as users_router
from app.api.v1.courses import router as courses_router
from app.api.v1.assignments import router as assignments_router
from app.api.v1.questions import router as questions_router
from app.api.v1.exams import router as exams_router
from app.api.v1.wrong import router as wrong_router
from app.api.v1.jobs import router as jobs_router
from app.api.v1.resumes import router as resumes_router
from app.api.v1.profile import router as profile_router
from app.api.v1.notify import router as notify_router
from app.api.v1.sign import router as sign_router
from app.api.v1.discussion import router as discussion_router
from app.api.v1.ai import router as ai_router
from app.api.v1.admin import router as admin_router
from app.api.v1.stats import router as stats_router
from app.api.v1.contact import router as contact_router
from app.api.v1.feedback import router as feedback_router

all_routers = [
    auth_router,
    users_router,
    courses_router,
    assignments_router,
    questions_router,
    exams_router,
    wrong_router,
    jobs_router,
    resumes_router,
    profile_router,
    notify_router,
    sign_router,
    discussion_router,
    ai_router,
    admin_router,
    stats_router,
    contact_router,
    feedback_router,
]
