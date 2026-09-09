# -*- coding: utf-8 -*-
"""SmartLearn 三端全功能 API 实测 v2：全部对齐真实路由"""
import sys, io, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import httpx

BASE = "http://127.0.0.1:8000/api/v1"
PASS, FAIL = [], []

def check(name, cond, detail=""):
    (PASS if cond else FAIL).append(name)
    print(f"[{'PASS' if cond else 'FAIL'}] {name}" + ("" if cond else f"  ── {str(detail)[:140]}"))

def login(u, p="1015401x"):
    r = httpx.post(f"{BASE}/auth/login", json={"username": u, "password": p}, timeout=15)
    d = r.json()["data"]
    return {"Authorization": f"Bearer {d['access_token']}"}, d["user"]

sh, stu = login("student02")
th, tea = login("teacher1")
ah, adm = login("admin")
def role_of(u): return u.get("role_code") or u.get("role") or ""
check("三角色登录", role_of(stu) == "STUDENT" and role_of(tea) == "TEACHER" and role_of(adm) == "ADMIN",
      f"{role_of(stu)}/{role_of(tea)}/{role_of(adm)}")
r = httpx.post(f"{BASE}/auth/login", json={"username": "student02", "password": "wrong"}, timeout=10)
check("错误密码拒绝", r.status_code != 200 or r.json().get("code") != 0)

print("\n═══════════ 学生端 ═══════════")
courses = httpx.get(f"{BASE}/courses", headers=sh).json()["data"]
check("课程列表", isinstance(courses, list) and len(courses) >= 5, f"n={len(courses) if isinstance(courses,list) else courses}")
cid = courses[0]["id"]
det = httpx.get(f"{BASE}/courses/{cid}", headers=sh).json()["data"]
check("课程详情(章节)", bool(det.get("chapters") or det.get("sections")), str(det)[:120])

pr = httpx.get(f"{BASE}/progress", headers=sh).json()["data"]
check("我的进度", isinstance(pr, list), str(pr)[:90])
r2 = httpx.put(f"{BASE}/progress/{cid}", headers=sh, json={"percent": 66}, timeout=10)
check("更新进度", r2.status_code == 200, str(r2.json())[:110])

exs = httpx.get(f"{BASE}/exams", headers=sh).json()["data"]
done = [e for e in exs if e.get("status") == 2]
live = [e for e in exs if e.get("status") in (0, 1)]
check("考试列表", len(exs) >= 3, f"n={len(exs)}")
if done:
    st = httpx.get(f"{BASE}/exams/{done[0]['id']}/state", headers=sh)
    check("已结束考试状态/成绩", st.status_code == 200, f"{done[0]['id']} → {str(st.json())[:120]}")
if live:
    eid = live[0]["id"]
    qs = httpx.get(f"{BASE}/exams/{eid}", headers=sh)
    check("考试题目(不含答案)", qs.status_code == 200 and "answer" not in json.dumps(qs.json()), str(qs.json())[:110])
    st = httpx.get(f"{BASE}/exams/{eid}/state", headers=sh)
    check("考试断点恢复", st.status_code == 200, str(st.json())[:110])

wq = httpx.get(f"{BASE}/wrong-questions", headers=sh).json()["data"]
check("错题本", isinstance(wq, list) and len(wq) > 0, f"n={len(wq) if isinstance(wq,list) else wq}")
if wq:
    wid = wq[0]["id"] if isinstance(wq[0], dict) else wq[0]
    m = httpx.put(f"{BASE}/wrong-questions/{wid}/mastered", headers=sh, timeout=10)
    check("错题标记掌握", m.status_code == 200, str(m.json())[:100])

pf = httpx.get(f"{BASE}/profile/me", headers=sh)
check("能力画像", pf.status_code == 200 and pf.json()["data"], str(pf.json())[:110])

asg = httpx.get(f"{BASE}/assignments", headers=sh).json()["data"]
check("作业列表", isinstance(asg, list) or isinstance(asg, dict), str(asg)[:100])

dp = httpx.get(f"{BASE}/discussions", headers=sh, params={"page": 1, "page_size": 10}).json()
dd = dp.get("data", {})
tot = dd.get("total") if isinstance(dd, dict) else None
check("讨论广场分页", dp.get("code") == 0 and (tot or 0) >= 20, str(dd)[:120])

fr = httpx.get(f"{BASE}/contacts/friends", headers=sh).json()["data"]
check("好友列表", isinstance(fr, list) and len(fr) > 0, f"n={len(fr) if isinstance(fr,list) else fr}")
if fr:
    f0 = fr[0]
    fid = f0["user"]["id"] if isinstance(f0, dict) and isinstance(f0.get("user"), dict) else (f0["friend_id"] if isinstance(f0, dict) else f0)
    cm = httpx.get(f"{BASE}/chat/history/{fid}", headers=sh).json()["data"]
    check("私聊历史", isinstance(cm, list), f"n={len(cm) if isinstance(cm,list) else cm}")

nt = httpx.get(f"{BASE}/notifications", headers=sh).json()["data"]
check("通知中心", isinstance(nt, list) and len(nt) > 0, f"n={len(nt) if isinstance(nt,list) else nt}")
ur = httpx.get(f"{BASE}/notifications/unread-count", headers=sh).json()["data"]
check("未读数", ur is not None, str(ur)[:80])

fb = httpx.post(f"{BASE}/feedback", headers=sh, json={"category": "BUG", "title": "三端实测-学生提交", "content": "自动化测试 v2"}, timeout=10)
check("学生提交反馈", fb.status_code == 200 and fb.json().get("code") == 0, str(fb.json())[:110])
myfb = httpx.get(f"{BASE}/feedback/my", headers=sh).json()["data"]
check("我的反馈", isinstance(myfb, list) and len(myfb) > 0, f"n={len(myfb) if isinstance(myfb,list) else myfb}")

jr = httpx.get(f"{BASE}/jobs/recommendations", headers=sh)
check("岗位列表(推荐流)", jr.status_code == 200 and jr.json().get("code") == 0, str(jr.json())[:110])
jd = jr.json()["data"]
jlist = jd.get("items") if isinstance(jd, dict) else jd
check("岗位推荐有数据", (jlist and len(jlist) > 0) if jlist is not None else bool(jd), str(jd)[:120])
apps = httpx.get(f"{BASE}/jobs/applications", headers=sh).json()["data"]
check("我的投递", isinstance(apps, (list, dict)), str(apps)[:100])
fav = httpx.get(f"{BASE}/jobs/favorites", headers=sh).json()["data"]
check("收藏岗位", isinstance(fav, list), f"n={len(fav) if isinstance(fav,list) else fav}")

ai = httpx.post(f"{BASE}/ai/plan", headers=sh, json={"message": "帮我制定学习计划"}, timeout=30)
check("AI 学习计划(降级)", ai.status_code == 200 and ai.json().get("code") == 0, str(ai.json())[:110])

d1 = httpx.get(f"{BASE}/admin/users", headers=sh)
check("学生访问管理接口403", d1.status_code == 403, str(d1.status_code))

print(f"\n═══ 学生端: {len(PASS)} PASS / {len(FAIL)} FAIL ═══")
sfs = list(FAIL)
for n in FAIL: print(f"  ✗ {n}")
FAIL.clear()

print("\n═══════════ 教师端 ═══════════")
mc = httpx.get(f"{BASE}/courses", headers=th).json()["data"]
mcl = mc.get("items") if isinstance(mc, dict) else mc
check("我的授课", mcl and len(mcl) > 0, str(mc)[:110])
if mcl:
    t0 = mcl[0]
    tcid = t0["id"] if isinstance(t0, dict) else t0
    chs = httpx.get(f"{BASE}/courses/manage/{tcid}/chapters", headers=th).json()["data"]
    check("章节列表", chs is not None, str(chs)[:100])
    ch = httpx.post(f"{BASE}/courses/manage/{tcid}/chapters", headers=th, json={"title": "测试章节-三端实测"}, timeout=10)
    check("创建章节", ch.status_code == 200, str(ch.json())[:110])
    if ch.status_code == 200:
        cd = ch.json()["data"]
        chid = cd["id"] if isinstance(cd, dict) else cd
        up = httpx.put(f"{BASE}/courses/manage/chapters/{chid}", headers=th, json={"title": "测试章节-改"}, timeout=10)
        check("改章节", up.status_code == 200, str(up.json())[:100])
        sec = httpx.post(f"{BASE}/courses/manage/{chid}/sections", headers=th,
                         json={"title": "测试小节", "type": "VIDEO", "content": "说明", "duration_minutes": 10}, timeout=10)
        check("建小节", sec.status_code == 200, str(sec.json())[:110])
        if sec.status_code == 200:
            sd = sec.json()["data"]
            sid = sd["id"] if isinstance(sd, dict) else sd
            httpx.delete(f"{BASE}/courses/manage/sections/{sid}", headers=th, timeout=10)
        dl = httpx.delete(f"{BASE}/courses/manage/chapters/{chid}", headers=th, timeout=10)
        check("删章节", dl.status_code == 200, str(dl.json())[:100])

ros = httpx.get(f"{BASE}/progress", headers=th, params={"course_id": cid})
check("教师查进度(学生列表)", ros.status_code == 200, str(ros.json())[:100])

na = httpx.post(f"{BASE}/assignments", headers=th, json={"course_id": cid, "title": "三端实测作业", "description": "测试", "max_score": 100, "deadline": "2026-12-31T23:59:59"}, timeout=10)
check("发布作业", na.status_code == 200, str(na.json())[:110])
if na.status_code == 200:
    nd = na.json()["data"]
    aid = nd["id"] if isinstance(nd, dict) else nd
    subs = httpx.get(f"{BASE}/assignments/{aid}/submissions", headers=th).json()["data"]
    check("提交名单", subs is not None, str(subs)[:100])
    rm = httpx.post(f"{BASE}/assignments/{aid}/remind", headers=th, timeout=10)
    check("催交提醒", rm.status_code == 200, str(rm.json())[:100])

qs = httpx.get(f"{BASE}/questions", headers=th, params={"course_id": cid}).json()["data"]
ql = qs.get("items") if isinstance(qs, dict) else qs
check("题库", ql and len(ql) > 0, str(qs)[:110])

st = httpx.post(f"{BASE}/sign/tasks", headers=th, json={"course_id": cid, "duration": 300}, timeout=10)
check("发起签到", st.status_code == 200, str(st.json())[:110])
if st.status_code == 200:
    sd = st.json()["data"]
    tid = sd["id"] if isinstance(sd, dict) else sd
    att = httpx.get(f"{BASE}/sign/tasks/{tid}/attendance", headers=th).json()["data"]
    check("签到名单", att is not None, str(att)[:100])

tp = httpx.post(f"{BASE}/discussions/teacher-room", headers=th, json={"title": "三端实测-教研帖", "content": "教研讨论"}, timeout=10)
check("发教研帖", tp.status_code == 200, str(tp.json())[:110])
tr = httpx.get(f"{BASE}/discussions/teacher-room", headers=th).json()["data"]
check("教研区列表", tr is not None, str(tr)[:100])

trm = httpx.get(f"{BASE}/discussions/teacher-room", headers=sh)
check("学生访问教研区403", trm.status_code == 403, str(trm.status_code))

tfb = httpx.get(f"{BASE}/admin/feedback", headers=th)
check("教师访问反馈管理403", tfb.status_code == 403, str(tfb.status_code))

print(f"\n═══ 教师端: {len(PASS)} PASS / {len(FAIL)} FAIL ═══")
tfs = list(FAIL)
for n in FAIL: print(f"  ✗ {n}")
FAIL.clear()

print("\n═══════════ 管理端 ═══════════")
db = httpx.get(f"{BASE}/admin/stats/dashboard", headers=ah).json()["data"]
check("控制台大屏", db and len(str(db)) > 10, str(db)[:120])

us = httpx.get(f"{BASE}/admin/users", headers=ah, params={"page": 1, "page_size": 10}).json()["data"]
check("用户管理", us and (us.get("items") if isinstance(us, dict) else True), str(us)[:110])

ust = httpx.get(f"{BASE}/admin/users", headers=ah).json()["data"]
if isinstance(ust, dict) and ust.get("items"):
    target_u = ust["items"][-1]
    rs = httpx.put(f"{BASE}/admin/users/{target_u['id']}/status", headers=ah, json={"status": "DISABLED"}, timeout=10)
    check("禁用用户", rs.status_code == 200, str(rs.json())[:100])
    httpx.put(f"{BASE}/admin/users/{target_u['id']}/status", headers=ah, json={"status": "ACTIVE"}, timeout=10)

pj = httpx.get(f"{BASE}/admin/reviews/pending", headers=ah)
check("待审列表", pj.status_code == 200, str(pj.json())[:110])

fl = httpx.get(f"{BASE}/admin/feedback", headers=ah, params={"status": "PENDING", "page": 1, "page_size": 20}).json()["data"]
check("反馈待办", fl and fl.get("items"), str(fl)[:110])
tgt = next((f for f in fl["items"] if f["title"] == "三端实测-学生提交"), None) if fl and fl.get("items") else None
if tgt:
    hd = httpx.put(f"{BASE}/admin/feedback/{tgt['id']}", headers=ah, json={"status": "RESOLVED", "reply": "测试处理完成"}, timeout=10)
    check("处理反馈闭环", hd.status_code == 200 and hd.json()["data"].get("status") == "RESOLVED", str(hd.json())[:110])
stats = httpx.get(f"{BASE}/admin/feedback/stats", headers=ah).json()["data"]
check("反馈统计", stats and stats.get("total", 0) > 0, str(stats)[:100])

pn = httpx.post(f"{BASE}/notifications", headers=ah, json={"title": "三端实测通知", "content": "系统维护", "type": "SYSTEM", "target_role": "ALL"}, timeout=10)
check("发布通知", pn.status_code == 200, str(pn.json())[:110])

al = httpx.get(f"{BASE}/admin/audit-logs", headers=ah, params={"page": 1, "page_size": 5}).json()["data"]
check("审计日志", al is not None, str(al)[:100])

cfg = httpx.get(f"{BASE}/admin/configs", headers=ah).json()["data"]
check("系统配置", cfg, str(cfg)[:100])

sw = httpx.get(f"{BASE}/admin/sensitive-words", headers=ah).json()["data"]
check("敏感词库", sw is not None, str(sw)[:90])

stt = httpx.get(f"{BASE}/admin/stats/trend", headers=ah)
check("活跃趋势", stt.status_code == 200, str(stt.json())[:100])
fn = httpx.get(f"{BASE}/admin/stats/funnel", headers=ah)
check("转化漏斗", fn.status_code == 200, str(fn.json())[:100])

print(f"\n═══ 管理端: {len(PASS)} PASS / {len(FAIL)} FAIL ═══")
afs = list(FAIL)
for n in FAIL: print(f"  ✗ {n}")

total_fail = len(sfs) + len(tfs) + len(afs)
print(f"\n════════════ 总计: {len(PASS)} PASS / {total_fail} FAIL ════════════")
