"""向量检索：内存关键词回退 + Qdrant 真实向量检索 + OpenAI 兼容嵌入。

``VECTOR_BACKEND=memory``（默认）走关键词检索；``=qdrant`` 时用 Qdrant 客户端，
文档向量经 OpenAI 兼容 ``/embeddings`` 接口生成（bge-large-zh 等模型）。
"""
from __future__ import annotations

import json
import urllib.request
from typing import Iterable

from app.core.config import settings
from app.services.rag import retrieve_top


def embed_texts(texts: list[str]) -> list[list[float]] | None:
    """OpenAI 兼容嵌入接口；未配置返回 None。"""
    if not (settings.embedding_api_key and settings.embedding_base_url):
        return None
    body = json.dumps({"model": settings.embedding_model, "input": texts}).encode()
    req = urllib.request.Request(
        (settings.embedding_base_url or "").rstrip("/") + "/embeddings",
        data=body,
        headers={"Authorization": f"Bearer {settings.embedding_api_key}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read())
        return [item["embedding"] for item in data["data"]]
    except Exception:
        return None


def _qdrant_client():
    from qdrant_client import QdrantClient
    from qdrant_client.models import Distance, VectorParams

    client = QdrantClient(url=settings.qdrant_url)
    client.get_collection(settings.qdrant_collection)  # 触发存在性检查
    return client


class VectorStore:
    def __init__(self, backend: str | None = None):
        self.backend = (backend or settings.vector_backend or "memory").lower()

    def search(self, passages: Iterable[dict], query: str, top_k: int = 4) -> list[dict]:
        passages = list(passages)
        if self.backend == "qdrant" and settings.qdrant_url:
            result = self._search_qdrant(passages, query, top_k)
            if result is not None:
                return result
        if self.backend == "milvus":
            return self._search_milvus(passages, query, top_k)
        return retrieve_top(passages, query, top_k)

    def _search_qdrant(self, passages: list[dict], query: str, top_k: int) -> list[dict] | None:
        try:
            from qdrant_client import QdrantClient
            from qdrant_client.models import Distance, PointStruct, VectorParams
        except ImportError:
            return None
        vectors = embed_texts([query] + [p.get("content", "") for p in passages])
        if not vectors:
            return None
        query_vec, doc_vecs = vectors[0], vectors[1:]
        try:
            client = QdrantClient(url=settings.qdrant_url)
            try:
                client.get_collection(settings.qdrant_collection)
            except Exception:
                client.recreate_collection(
                    collection_name=settings.qdrant_collection,
                    vectors_config=VectorParams(size=len(query_vec), distance=Distance.COSINE),
                )
            points = [
                PointStruct(id=i, vector=vec, payload={"source": p.get("source", ""), "snippet": (p.get("content") or "")[:200]})
                for i, (p, vec) in enumerate(zip(passages, doc_vecs))
            ]
            if points:
                client.upsert(collection_name=settings.qdrant_collection, points=points)
            hits = client.query_points(
                collection_name=settings.qdrant_collection, query=query_vec, limit=top_k,
            ).points
            return [
                {"source": h.payload.get("source", "课程资料"), "snippet": h.payload.get("snippet", "")}
                for h in hits
            ]
        except Exception:
            return None

    def _search_milvus(self, passages: list[dict], query: str, top_k: int) -> list[dict]:
        try:
            import pymilvus  # noqa: F401
        except ImportError:
            return retrieve_top(passages, query, top_k)
        return retrieve_top(passages, query, top_k)


_vector_store: VectorStore | None = None


def get_vector_store() -> VectorStore:
    global _vector_store
    if _vector_store is None:
        _vector_store = VectorStore()
    return _vector_store


def check_vector() -> dict:
    if settings.vector_backend == "memory":
        return {"configured": False, "reachable": True, "reason": "VECTOR_BACKEND=memory（关键词检索兜底）"}
    if settings.vector_backend == "qdrant":
        if not settings.qdrant_url:
            return {"configured": False, "reachable": False, "reason": "未配置 QDRANT_URL"}
        try:
            _qdrant_client()
            return {"configured": True, "reachable": True, "backend": "qdrant"}
        except Exception as exc:  # noqa: BLE001
            return {"configured": True, "reachable": False, "reason": type(exc).__name__}
    return {"configured": False, "reachable": False, "reason": f"未知 VECTOR_BACKEND={settings.vector_backend}"}
