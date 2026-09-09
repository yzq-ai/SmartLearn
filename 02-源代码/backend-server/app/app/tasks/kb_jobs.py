"""资源上传后知识库重建。"""
from __future__ import annotations

import logging

from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.kb_jobs.rebuild_course_kb")
def rebuild_course_kb(course_id: int) -> dict:
    """重建指定课程的知识库向量索引。"""
    logger.info("Rebuilding knowledge base for course_id=%d", course_id)
    try:
        from app.services.vector_store import vector_store
        vector_store.rebuild_collection(course_id)
        return {"course_id": course_id, "rebuilt": True}
    except Exception as e:
        logger.error("KB rebuild failed: %s", e)
        return {"course_id": course_id, "error": str(e)}
