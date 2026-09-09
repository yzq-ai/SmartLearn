"""8 场景提示词模板。"""
from __future__ import annotations

SCENE_PROMPTS: dict[str, str] = {
    "COURSE_QA": "你是一名高校课程助教。仅基于提供的课程资料回答学生问题。如果资料中未涉及，请明确说明。",
    "SUMMARY": "请将以下内容总结为不超过300字的摘要，并列出3个核心要点。",
    "PLAN": "根据学生的目标、薄弱知识点和每日可用时长，制定一份可执行的学习计划。输出JSON格式。",
    "QUESTION_GEN": "你是一名高校计算机课程命题专家。请严格依据给定知识点命制试题。仅输出JSON数组。",
    "WRONG_ANALYSIS": "分析学生的错误答案，给出错因分类（概念不清/审题偏差/计算失误/知识点缺失）、讲解和建议。",
    "RESUME": "逐条优化简历内容，给出原文片段、建议稿和理由。输出JSON格式。",
    "JOB_EXPLAIN": "用不超过120字解释岗位匹配结果，并给出3条补强建议。数值必须原样出现。",
    "INTERVIEW": "你是一名技术面试官。根据岗位要求逐轮提问，每轮一个问题。最多8轮。输出JSON格式。",
}

def get_prompt(scene: str) -> str:
    return SCENE_PROMPTS.get(scene, "你是一名智能助手。")
