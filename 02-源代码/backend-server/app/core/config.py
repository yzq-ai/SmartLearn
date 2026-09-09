"""Application settings loaded from environment / ``.env``.

Field names use ``validation_alias`` so the same variables from the deployment
guide and ``docker-compose.yml`` map directly onto these fields.
"""
from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = Field(default="sqlite+aiosqlite:///./smartlearn.db", validation_alias="DATABASE_URL")
    jwt_secret_key: str = Field(default="change-this-secret-in-production", validation_alias="JWT_SECRET")
    jwt_algorithm: str = Field(default="HS256", validation_alias="JWT_ALGORITHM")
    access_token_expire_minutes: int = Field(default=60, validation_alias="ACCESS_TOKEN_EXPIRE_MINUTES")
    refresh_token_expire_days: int = Field(default=7, validation_alias="REFRESH_TOKEN_EXPIRE_DAYS")
    redis_url: str = Field(default="", validation_alias="REDIS_URL")
    exam_duration_minutes: int = Field(default=60, validation_alias="EXAM_DURATION_MINUTES")
    ai_requests_per_minute: int = Field(default=10, validation_alias="AI_REQUESTS_PER_MINUTE")
    ai_daily_limit: int = Field(default=200, validation_alias="AI_DAILY_LIMIT")
    cors_origins: str = Field(default="*", validation_alias="CORS_ORIGINS")
    celery_broker_url: str = Field(default="memory://", validation_alias="CELERY_BROKER_URL")
    celery_backend_url: str = Field(default="cache+memory://", validation_alias="CELERY_BACKEND_URL")
    celery_always_eager: bool = Field(default=True, validation_alias="CELERY_ALWAYS_EAGER")
    # OBS 对象存储（华为云 OBS，S3 兼容协议）
    obs_ak: str = Field(default="", validation_alias="OBS_AK")
    obs_sk: str = Field(default="", validation_alias="OBS_SK")
    obs_bucket: str = Field(default="", validation_alias="OBS_BUCKET")
    obs_endpoint: str = Field(default="", validation_alias="OBS_ENDPOINT")
    # 本地文件存储（未配置 OBS 时的真实落盘目录）
    local_storage_dir: str = Field(default="./storage", validation_alias="LOCAL_STORAGE_DIR")
    # 向量库（默认内存关键词检索；生产用 qdrant / milvus）
    vector_backend: str = Field(default="memory", validation_alias="VECTOR_BACKEND")
    qdrant_url: str = Field(default="", validation_alias="QDRANT_URL")
    qdrant_collection: str = Field(default="smartlearn_kb", validation_alias="QDRANT_COLLECTION")
    embedding_api_key: str = Field(default="", validation_alias="EMBEDDING_API_KEY")
    embedding_base_url: str = Field(default="", validation_alias="EMBEDDING_BASE_URL")
    embedding_model: str = Field(default="bge-large-zh", validation_alias="EMBEDDING_MODEL")
    # 推送（默认日志占位；生产用 AGC Push Kit）
    push_backend: str = Field(default="log", validation_alias="PUSH_BACKEND")
    agc_client_id: str = Field(default="", validation_alias="AGC_CLIENT_ID")
    agc_client_secret: str = Field(default="", validation_alias="AGC_CLIENT_SECRET")
    agc_token_url: str = Field(default="https://oauth-login.cloud.huawei.com/oauth2/v3/token", validation_alias="AGC_TOKEN_URL")
    agc_push_url: str = Field(default="https://push-api.cloud.huawei.com/v1/{app_id}/messages:send", validation_alias="AGC_PUSH_URL")
    agc_app_id: str = Field(default="", validation_alias="AGC_APP_ID")
    llm_api_key: str = Field(default="", validation_alias="LLM_API_KEY")
    llm_base_url: str = Field(default="https://api.openai.com/v1", validation_alias="LLM_BASE_URL")
    llm_model: str = Field(default="gpt-4o-mini", validation_alias="LLM_MODEL")

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    @property
    def cors_origin_list(self) -> list[str]:
        return [item.strip() for item in self.cors_origins.split(",") if item.strip()]

    def security_risks(self) -> list[str]:
        """启动期安全体检：返回生产部署风险项（写入启动日志与管理端展示）。"""
        risks: list[str] = []
        if self.jwt_secret_key in ("change-this-secret-in-production", "change-me-in-production", "test-secret"):
            risks.append("JWT_SECRET 为默认值，生产必须改为强随机串（openssl rand -hex 32）")
        if self.cors_origins.strip() == "*":
            risks.append("CORS_ORIGINS 为 *，生产应收敛为 App/前端域名白名单")
        if self.database_url.startswith("sqlite"):
            risks.append("DATABASE_URL 为 SQLite 单机库，生产建议切换 MySQL（docker-compose 提供）")
        return risks

    @property
    def sync_database_url(self) -> str:
        """把异步驱动 URL 转为 Celery worker 可用的同步驱动 URL。"""
        return (
            self.database_url.replace("sqlite+aiosqlite", "sqlite")
            .replace("mysql+aiomysql", "mysql+pymysql")
            .replace("mysql+asyncmy", "mysql+pymysql")
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
