from app.services.match_engine import calc_match
from app.services.mastery_service import build_radar_data, build_skill_scores, calc_mastery_pct


def test_calc_match_weighted_and_gap_detection():
    profile = {"Java": 85, "SpringBoot": 40, "MySQL": 78}
    result = calc_match(profile, ["Java", "SpringBoot", "MySQL"], {"Java": 0.4, "SpringBoot": 0.3, "MySQL": 0.3})
    assert result["match_score"] == round((85 * 0.4 + 40 * 0.3 + 78 * 0.3), 1)
    assert result["matched_tags"] == ["Java", "MySQL"]
    assert result["gap_tags"] == ["SpringBoot"]


def test_calc_match_empty_required():
    assert calc_match({"Java": 85}, []) == {"match_score": 0.0, "matched_tags": [], "gap_tags": []}


def test_calc_mastery_pct():
    assert calc_mastery_pct(3, 4) == 75.0
    assert calc_mastery_pct(0, 0) == 0.0


def test_build_skill_scores_averages_same_kp():
    scores = build_skill_scores(
        [{"kp_id": 1, "correct_cnt": 3, "total_cnt": 4}, {"kp_id": 2, "correct_cnt": 2, "total_cnt": 4}],
        {1: "Python", 2: "Python"},
    )
    assert scores["Python"] == round(((75.0 + 50.0) / 2), 2)


def test_build_radar_has_six_dims():
    radar = build_radar_data({"Python": 85, "FastAPI": 72})
    assert len(radar) == 6
    assert radar["专业基础"] == 85
