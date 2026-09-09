"""考试结果落地：错题归集、掌握度更新、画像刷新。"""
from __future__ import annotations

import json
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    ExamRecord, KnowledgePoint, Question, StudentKpMastery, StudentProfile, WrongQuestion,
)
from app.services.mastery_service import build_radar_data, build_skill_scores, calc_mastery_pct


def _answer_str(value) -> str:
    if isinstance(value, (list, tuple, set, dict)):
        return json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    return "" if value is None else str(value)


async def apply_exam_results(
    db: AsyncSession,
    record: ExamRecord,
    questions: list[Question],
    answer_map: dict[int, object],
    result: dict,
) -> None:
    """把判分结果写回答题明细，并归集错题、更新掌握度与画像。"""
    detail_map = {d["question_id"]: d for d in result["details"]}
    question_map = {q.id: q for q in questions}

    # 1) 写回答题明细的 is_correct / score。
    for answer in record.answers:
        detail = detail_map.get(answer.question_id)
        if detail is None:
            continue
        if detail["correct"] is None:
            answer.is_correct = None
        else:
            answer.is_correct = 1 if detail["correct"] else 0
        answer.score = detail["earned"]

    # 2) 错题归集 + 知识点掌握度聚合。
    kp_updates: dict[int, dict[str, int]] = {}
    for detail in result["details"]:
        question = question_map.get(detail["question_id"])
        if question is None:
            continue
        if detail["correct"] is False:
            await _upsert_wrong_question(
                db, record.user_id, question, answer_map.get(question.id), "EXAM", record.exam_id,
            )
        if detail["correct"] is None:
            continue
        for kp_id in (question.kp_ids or []):
            agg = kp_updates.setdefault(kp_id, {"correct": 0, "total": 0})
            agg["total"] += 1
            if detail["correct"]:
                agg["correct"] += 1

    await _upsert_mastery(db, record.user_id, kp_updates)
    await refresh_profile(db, record.user_id)


async def _upsert_wrong_question(
    db: AsyncSession, user_id: int, question: Question, my_answer, source_type: str, source_id: int | None,
) -> None:
    existing = await db.scalar(
        select(WrongQuestion).where(
            WrongQuestion.user_id == user_id,
            WrongQuestion.question_id == question.id,
            WrongQuestion.source_type == source_type,
        )
    )
    if existing:
        existing.wrong_count = (existing.wrong_count or 0) + 1
        existing.is_mastered = 0
        existing.mastered_at = None
        existing.my_answer = _answer_str(my_answer)
    else:
        db.add(WrongQuestion(
            user_id=user_id, question_id=question.id,
            my_answer=_answer_str(my_answer),
            source_type=source_type, source_id=source_id,
        ))


async def _upsert_mastery(db: AsyncSession, user_id: int, kp_updates: dict[int, dict[str, int]]) -> None:
    for kp_id, agg in kp_updates.items():
        row = await db.scalar(
            select(StudentKpMastery).where(
                StudentKpMastery.user_id == user_id,
                StudentKpMastery.kp_id == kp_id,
            )
        )
        if row:
            row.correct_cnt = (row.correct_cnt or 0) + agg["correct"]
            row.total_cnt = (row.total_cnt or 0) + agg["total"]
        else:
            row = StudentKpMastery(user_id=user_id, kp_id=kp_id, correct_cnt=agg["correct"], total_cnt=agg["total"])
            db.add(row)
        row.mastery_pct = calc_mastery_pct(row.correct_cnt, row.total_cnt)


async def refresh_profile(db: AsyncSession, user_id: int) -> StudentProfile:
    """基于知识点掌握度重建技能分与六维雷达。"""
    mastery_rows = (
        await db.execute(select(StudentKpMastery).where(StudentKpMastery.user_id == user_id))
    ).scalars().all()
    kp_names: dict[int, str] = {}
    kp_ids = [m.kp_id for m in mastery_rows]
    if kp_ids:
        kps = (await db.execute(select(KnowledgePoint).where(KnowledgePoint.id.in_(kp_ids)))).scalars().all()
        kp_names = {k.id: k.name for k in kps}

    skill_scores = build_skill_scores(
        [{"kp_id": m.kp_id, "correct_cnt": m.correct_cnt, "total_cnt": m.total_cnt} for m in mastery_rows],
        kp_names,
    )

    profile = await db.scalar(select(StudentProfile).where(StudentProfile.user_id == user_id))
    if not profile:
        profile = StudentProfile(user_id=user_id)
        db.add(profile)
    profile.skill_scores = skill_scores
    profile.radar_data = build_radar_data(skill_scores)
    profile.match_version = (profile.match_version or 0) + 1
    profile.updated_at = datetime.utcnow()
    await db.flush()
    return profile
