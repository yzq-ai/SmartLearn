from types import SimpleNamespace
from app.services.ai_service import analyze_wrong_answer_rules, optimize_resume_rules, analyze_wrong_answer, optimize_resume


def test_wrong_answer_rules_are_deterministic():
    result = analyze_wrong_answer_rules('2+2=?', '5', '4', '数学')
    assert result['source'] == 'rules'
    assert result['cause_category']
    assert result['knowledge_points'] == ['数学']


def test_resume_rules_preserve_original():
    items = optimize_resume_rules('做了项目\n\n负责 API 开发并提升性能 30%')
    assert items[0]['original'] == '做了项目'
    assert all(set(('original', 'suggestion', 'reason', 'type')) <= set(x) for x in items)


def test_llm_callback_used_without_personal_data_leak():
    seen = []
    def fake(prompt):
        seen.append(prompt)
        return {'cause_category':'计算错误','analysis':'a','suggestions':['b'],'knowledge_points':['c']}
    result = analyze_wrong_answer(SimpleNamespace(question='邮箱 a@b.com', answer='x', correct_answer='y', subject=None), fake)
    assert result['source'] == 'llm' and 'a@b.com' not in seen[0]


def test_resume_llm_fallback():
    result = optimize_resume(SimpleNamespace(resume='项目经历', target_role=None), lambda _: None)
    assert result['source'] == 'rules'
