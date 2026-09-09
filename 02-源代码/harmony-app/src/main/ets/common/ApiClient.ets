import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
import preferences from '@ohos.data.preferences';
import { router } from '@kit.ArkUI';
import { Context } from '@kit.AbilityKit';
import { AdminUserItem, AiDraftQuestion, AiInterview, AiJobExplain, AiPlan, AiSummary, Answer, ApplicationItem, AssignmentItem, AssignmentSubmissionList, AuditLogItem, CareerEventItem, CareerEventSignupResult, ChatMsg, CheckinResult, CompanyItem, ConfigItem, ContactApplyResult, ContactItem, ContactRequestItem, ContactUser, Course, CourseDetail, Dashboard, DiscussionDetail, DiscussionPage, DiscussionPost, DiscussionReplyItem, FeedbackItem, FeedbackStats, FeedbackSubmitResult, AdminFeedbackPage, ManagedChapter, Exam, ExamResult, ExamSession, ExamSummary, ImportReport, Job, LearningStats, LikeResult, LoginRequest, LoginResponse, MonitorRecord, NotificationItem, PendingReviews, Profile, Progress, QuestionItem, QuestionPage, RecordAnswer, RegisterRequest, ResourcePage, Resume, ResumeContent, ResumeOptimizeResult, SearchUserResult, SensitiveWordItem, SignAttendanceResult, SignLatest, SignRecordItem, SignTask, SkillTagItem, StatFunnel, StatTrend, UnreadCount, UserImportItem, UserProfile, WrongAnalysis, WrongQuestion } from './Models';

interface ApiEnvelope<T> {
  code: number;
  message: string;
  data: T;
}

export class ApiClient {
  private static readonly baseUrl: string = 'http://10.0.2.2:8000';
  private static readonly maxAttempts: number = 3;
  private token: string = '';

  public setToken(token: string): void { this.token = token; }
  public hasToken(): boolean { return this.token.length > 0; }
  /** 上传等场景需要拼接完整地址。 */
  public get baseUrl(): string { return ApiClient.baseUrl; }
  /** multipart 上传所需的认证头。 */
  public authHeaders(): Record<string, string> {
    const h: Record<string, string> = {};
    if (this.token.length > 0) { h.Authorization = `Bearer ${this.token}`; }
    return h;
  }

  private parseEnvelope<T>(raw: string): ApiEnvelope<T> {
    try {
      return JSON.parse(raw) as ApiEnvelope<T>;
    } catch (error) {
      throw new Error('响应解析失败');
    }
  }

  private async request<T>(method: http.RequestMethod, path: string, body?: string): Promise<T> {
    let lastError: Error = new Error('网络请求失败');
    for (let attempt: number = 1; attempt <= ApiClient.maxAttempts; attempt += 1) {
      const client: http.HttpRequest = http.createHttp();
      try {
        const headers: Record<string, string> = { 'Content-Type': 'application/json' };
        if (this.token.length > 0) headers.Authorization = `Bearer ${this.token}`;
        const response: http.HttpResponse = await client.request(`${ApiClient.baseUrl}${path}`, {
          method, header: headers, extraData: body, connectTimeout: 10000, readTimeout: 15000
        });
        const envelope: ApiEnvelope<T> = this.parseEnvelope<T>(response.result as string);
        if (response.responseCode < 200 || response.responseCode >= 300 || envelope.code !== 0) {
          // 令牌失效：静默登出并回登录页（登录接口自身的 401 = 密码错误，不触发登出）
          if (response.responseCode === 401 && path !== '/api/v1/auth/login') {
            await this.forceLogout();
            throw new Error('登录已过期，请重新登录');
          }
          throw new Error(envelope.message || `请求失败 (${response.responseCode})`);
        }
        return envelope.data;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error('网络请求失败');
        if (attempt < ApiClient.maxAttempts && this.isRetryable(method, lastError)) {
          await this.delay(attempt * 500);
        } else {
          throw lastError;
        }
      } finally { client.destroy(); }
    }
    throw lastError;
  }
  private async forceLogout(): Promise<void> {
    this.token = '';
    const keys: string[] = ['token', 'refresh_token', 'role', 'username', 'userId', 'avatar'];
    for (const key of keys) { AppStorage.delete(key); }
    const context: Context | undefined = AppStorage.get<Object>('context') as Context | undefined;
    if (context !== undefined) {
      try {
        const p: preferences.Preferences = await preferences.getPreferences(context, { name: 'smartlearn_session' });
        for (const key of keys) { await p.delete(key); }
        await p.flush();
      } catch (_e) { /* 清盘失败不影响跳转 */ }
    }
    await router.replaceUrl({ url: 'pages/Login' });
  }

  private isRetryable(method: http.RequestMethod, error: Error): boolean {
    if (method === http.RequestMethod.POST) return false;
    const codeMatch: RegExpMatchArray | null = error.message.match(/\((\d+)\)/);
    if (codeMatch !== null) {
      const code: number = Number(codeMatch[1]);
      return code >= 500 || code === 408 || code === 429;
    }
    return true;
  }
  private delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => { setTimeout(resolve, milliseconds); });
  }

  public login(request: LoginRequest): Promise<LoginResponse> { return this.request<LoginResponse>(http.RequestMethod.POST, '/api/v1/auth/login', JSON.stringify(request)); }
  public register(request: RegisterRequest): Promise<LoginResponse> { return this.request<LoginResponse>(http.RequestMethod.POST, '/api/v1/auth/register', JSON.stringify(request)); }
  public changePassword(oldPassword: string, newPassword: string): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.PUT, '/api/v1/auth/password', JSON.stringify({ old_password: oldPassword, new_password: newPassword }));
  }
  public logout(): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, '/api/v1/auth/logout', JSON.stringify({}));
  }
  public getCourses(): Promise<Course[]> { return this.request<Course[]>(http.RequestMethod.GET, '/api/v1/courses'); }
  public getCourse(id: number): Promise<CourseDetail> { return this.request<CourseDetail>(http.RequestMethod.GET, `/api/v1/courses/${id}`); }
  public getProgress(): Promise<Progress[]> { return this.request<Progress[]>(http.RequestMethod.GET, '/api/v1/progress'); }
  public updateProgress(courseId: number, percent: number, chapterId?: number): Promise<Progress> {
    return this.request<Progress>(http.RequestMethod.PUT, `/api/v1/progress/${courseId}`, JSON.stringify({ percent, chapter_id: chapterId }));
  }
  public getExams(): Promise<ExamSummary[]> { return this.request<ExamSummary[]>(http.RequestMethod.GET, '/api/v1/exams'); }
  public createExam(courseId: number, title: string, durationMin: number, passScore: number, questionIds: number[]): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, '/api/v1/exams', JSON.stringify({ course_id: courseId, title, duration_min: durationMin, pass_score: passScore, question_ids: questionIds }));
  }
  public getExamMonitor(examId: number): Promise<MonitorRecord[]> { return this.request<MonitorRecord[]>(http.RequestMethod.GET, `/api/v1/exams/${examId}/monitor`); }
  public getRecordAnswers(recordId: number): Promise<RecordAnswer[]> { return this.request<RecordAnswer[]>(http.RequestMethod.GET, `/api/v1/records/${recordId}/answers`); }
  public gradeAnswer(answerId: number, score: number, comment: string): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, `/api/v1/answers/${answerId}/grade`, JSON.stringify({ score, comment }));
  }
  public getExam(id: number): Promise<Exam> { return this.request<Exam>(http.RequestMethod.GET, `/api/v1/exams/${id}`); }
  public startExam(id: number): Promise<ExamSession> {
    return this.request<ExamSession>(http.RequestMethod.POST, `/api/v1/exams/${id}/start`, JSON.stringify({}));
  }
  public getExamState(id: number): Promise<ExamSession> {
    return this.request<ExamSession>(http.RequestMethod.GET, `/api/v1/exams/${id}/state`);
  }
  public saveExamAnswers(id: number, answers: Answer[]): Promise<ExamSession> {
    return this.request<ExamSession>(http.RequestMethod.PUT, `/api/v1/exams/${id}/answers`, JSON.stringify({ answers }));
  }
  public submitExam(id: number, answers: Answer[]): Promise<ExamResult> {
    return this.request<ExamResult>(http.RequestMethod.POST, `/api/v1/exams/${id}/submit`, JSON.stringify({ answers }));
  }
  public createCourse(title: string, description: string): Promise<Course> {
    return this.request<Course>(http.RequestMethod.POST, '/api/v1/courses', JSON.stringify({ title, description }));
  }
  public updateCourse(id: number, title: string, description: string): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.PUT, `/api/v1/courses/${id}`, JSON.stringify({ title, description }));
  }
  public createAssignment(courseId: number, title: string, description: string, maxScore: number, deadline: string): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, '/api/v1/assignments', JSON.stringify({ course_id: courseId, title, description, max_score: maxScore, deadline }));
  }
  public getJobs(): Promise<Job[]> { return this.request<Job[]>(http.RequestMethod.GET, '/api/v1/jobs/recommendations'); }
  public getJobDetail(id: number): Promise<Job> { return this.request<Job>(http.RequestMethod.GET, `/api/v1/jobs/${id}`); }
  public applyJob(jobId: number): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, `/api/v1/jobs/${jobId}/applications`, JSON.stringify({}));
  }
  public favoriteJob(jobId: number): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.PUT, `/api/v1/jobs/${jobId}/favorite`, JSON.stringify({}));
  }
  public getCareerEvents(): Promise<CareerEventItem[]> { return this.request<CareerEventItem[]>(http.RequestMethod.GET, '/api/v1/career-events'); }
  public createCareerEvent(payload: Record<string, object>): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, '/api/v1/career-events', JSON.stringify(payload));
  }
  public signupCareerEvent(eventId: number): Promise<CareerEventSignupResult> {
    return this.request<CareerEventSignupResult>(http.RequestMethod.POST, `/api/v1/career-events/${eventId}/signup`, JSON.stringify({}));
  }
  public getNotifications(): Promise<NotificationItem[]> { return this.request<NotificationItem[]>(http.RequestMethod.GET, '/api/v1/notifications'); }
  public getUnreadCount(): Promise<UnreadCount> { return this.request<UnreadCount>(http.RequestMethod.GET, '/api/v1/notifications/unread-count'); }
  public markNotificationRead(id: number): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.PUT, `/api/v1/notifications/${id}/read`, JSON.stringify({}));
  }
  public markAllNotificationsRead(): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.PUT, '/api/v1/notifications/read-all', JSON.stringify({}));
  }
  public getApplications(): Promise<ApplicationItem[]> { return this.request<ApplicationItem[]>(http.RequestMethod.GET, '/api/v1/jobs/applications'); }
  public getAuditLogs(): Promise<AuditLogItem[]> { return this.request<AuditLogItem[]>(http.RequestMethod.GET, '/api/v1/admin/audit-logs'); }
  public getCompanies(): Promise<CompanyItem[]> { return this.request<CompanyItem[]>(http.RequestMethod.GET, '/api/v1/companies'); }
  public publishNotification(title: string, content: string, targetRole: string): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, '/api/v1/notifications', JSON.stringify({ type: 'SYSTEM', title, content, target_role: targetRole }));
  }
  public aiWrongAnalysis(question: string, answer: string, correctAnswer: string): Promise<WrongAnalysis> {
    return this.request<WrongAnalysis>(http.RequestMethod.POST, '/api/v1/ai/wrong-answer/analyze', JSON.stringify({ question, answer, correct_answer: correctAnswer }));
  }
  public optimizeResume(resume: string, targetRole: string): Promise<ResumeOptimizeResult> {
    return this.request<ResumeOptimizeResult>(http.RequestMethod.POST, '/api/v1/ai/resume/optimize', JSON.stringify({ resume, target_role: targetRole }));
  }
  public aiFeedback(logId: number, feedback: number): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, '/api/v1/ai/feedback', JSON.stringify({ log_id: logId, feedback }));
  }

  // ═══ 反馈中心（需求 18）═══
  public getMyFeedback(): Promise<FeedbackItem[]> { return this.request<FeedbackItem[]>(http.RequestMethod.GET, '/api/v1/feedback/my'); }
  public submitFeedback(category: string, title: string, content: string, contact: string): Promise<FeedbackSubmitResult> {
    return this.request<FeedbackSubmitResult>(http.RequestMethod.POST, '/api/v1/feedback',
      JSON.stringify({ category, title, content, contact: contact || null }));
  }
  public getAdminFeedback(status: string, page: number): Promise<AdminFeedbackPage> {
    const suffix: string = status === 'ALL' ? '' : `?status=${status}&page=${page}`;
    return this.request<AdminFeedbackPage>(http.RequestMethod.GET, `/api/v1/admin/feedback${suffix || `?page=${page}`}`);
  }
  public getAdminFeedbackStats(): Promise<FeedbackStats> { return this.request<FeedbackStats>(http.RequestMethod.GET, '/api/v1/admin/feedback/stats'); }
  public handleAdminFeedback(id: number, status: string, reply: string): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.PUT, `/api/v1/admin/feedback/${id}`,
      JSON.stringify({ status, reply: reply || null }));
  }
  public getStatTrend(): Promise<StatTrend> { return this.request<StatTrend>(http.RequestMethod.GET, '/api/v1/admin/stats/trend'); }
  public getStatFunnel(): Promise<StatFunnel> { return this.request<StatFunnel>(http.RequestMethod.GET, '/api/v1/admin/stats/funnel'); }
  public getProfile(): Promise<Profile> { return this.request<Profile>(http.RequestMethod.GET, '/api/v1/profile/me'); }
  public refreshProfile(): Promise<Profile> { return this.request<Profile>(http.RequestMethod.POST, '/api/v1/profile/refresh', JSON.stringify({})); }
  public getUserProfile(): Promise<UserProfile> { return this.request<UserProfile>(http.RequestMethod.GET, '/api/v1/user/profile'); }
  public updateUserProfile(data: Record<string, string>): Promise<UserProfile> {
    return this.request<UserProfile>(http.RequestMethod.PUT, '/api/v1/user/profile', JSON.stringify(data));
  }
  public uploadAvatar(ossKey: string): Promise<UserProfile> {
    return this.request<UserProfile>(http.RequestMethod.POST, '/api/v1/user/avatar', JSON.stringify({ oss_key: ossKey }));
  }
  public getResumes(): Promise<Resume[]> { return this.request<Resume[]>(http.RequestMethod.GET, '/api/v1/resumes'); }
  public createResume(title: string, content: ResumeContent): Promise<Resume> {
    return this.request<Resume>(http.RequestMethod.POST, '/api/v1/resumes', JSON.stringify({ title, content }));
  }
  public getWrongQuestions(): Promise<WrongQuestion[]> { return this.request<WrongQuestion[]>(http.RequestMethod.GET, '/api/v1/wrong-questions'); }
  public markWrongMastered(id: number): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.PUT, `/api/v1/wrong-questions/${id}/mastered`, JSON.stringify({}));
  }
  public getQuestions(): Promise<QuestionItem[]> { return this.request<QuestionItem[]>(http.RequestMethod.GET, '/api/v1/questions'); }
  /** 兼容旧调用：拉取前 N 条已发布题（教师端预览）。 */
  public async getQuestionsPreview(limit: number): Promise<QuestionItem[]> {
    const r = await this.request<QuestionPage>(http.RequestMethod.GET, `/api/v1/questions?page=1&page_size=${limit}`);
    return r.items;
  }
  public getQuestionsPaged(page: number, pageSize: number, keyword: string): Promise<QuestionPage> {
    const kw: string = keyword.length > 0 ? `&q=${encodeURIComponent(keyword)}` : '';
    return this.request<QuestionPage>(http.RequestMethod.GET, `/api/v1/questions?page=${page}&page_size=${pageSize}${kw}`);
  }
  /** 组卷筛选查询（需求 8：课程/题型/难度/关键词）。 */
  public getQuestionsFiltered(page: number, pageSize: number, courseId: number, type: string, difficulty: number, keyword: string): Promise<QuestionPage> {
    const parts: string[] = [`page=${page}`, `page_size=${pageSize}`];
    if (courseId > 0) { parts.push(`course_id=${courseId}`); }
    if (type.length > 0) { parts.push(`type=${type}`); }
    if (difficulty > 0) { parts.push(`difficulty=${difficulty}`); }
    if (keyword.length > 0) { parts.push(`q=${encodeURIComponent(keyword)}`); }
    return this.request<QuestionPage>(http.RequestMethod.GET, `/api/v1/questions?${parts.join('&')}`);
  }
  /** 随机组卷（需求 8）：返回试卷 id + 题目列表。 */
  public randomPaper(courseId: number, title: string, count: number, type: string, difficulty: number): Promise<Record<string, object>> {
    const parts: string[] = [`"course_id":${courseId}`, `"title":"${title}"`, `"count":${count}`];
    if (type.length > 0) { parts.push(`"type":"${type}"`); }
    if (difficulty > 0) { parts.push(`"difficulty":${difficulty}`); }
    return this.request<Record<string, object>>(http.RequestMethod.POST, '/api/v1/papers/random', `{${parts.join(',')}}`);
  }
  public getResources(fileType: string): Promise<ResourcePage> {
    const t: string = fileType.length > 0 ? `?file_type=${fileType}` : '';
    return this.request<ResourcePage>(http.RequestMethod.GET, `/api/v1/resources/list${t}`);
  }
  public downloadResource(path: string): void {
    // 简化：通过 http 拉取到本地缓存目录（生产可换 downloadManager）
    const client: http.HttpRequest = http.createHttp();
    client.request(`${ApiClient.baseUrl}${path}`, {
      method: http.RequestMethod.GET,
      header: this.authHeaders(),
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      connectTimeout: 30000, readTimeout: 60000,
    }).then((): void => { client.destroy(); }).catch((): void => { client.destroy(); });
  }
  public getQuestion(id: number): Promise<QuestionItem> { return this.request<QuestionItem>(http.RequestMethod.GET, `/api/v1/questions/${id}`); }
  public updateQuestion(id: number, qtype: string, content: string, answer: string, options: string[], difficulty: number, score: number): Promise<QuestionItem> {
    return this.request<QuestionItem>(http.RequestMethod.PUT, `/api/v1/questions/${id}`, JSON.stringify({ type: qtype, content, answer, options, difficulty, score }));
  }
  public createQuestion(qtype: string, content: string, answer: string, options: string[], difficulty: number, score: number): Promise<QuestionItem> {
    return this.request<QuestionItem>(http.RequestMethod.POST, '/api/v1/questions', JSON.stringify({ type: qtype, content, answer, options, difficulty, score }));
  }
  public getLearningStats(): Promise<LearningStats> { return this.request<LearningStats>(http.RequestMethod.GET, '/api/v1/stats/learning'); }
  public getDashboard(): Promise<Dashboard> { return this.request<Dashboard>(http.RequestMethod.GET, '/api/v1/admin/stats/dashboard'); }
  public getPendingReviews(): Promise<PendingReviews> { return this.request<PendingReviews>(http.RequestMethod.GET, '/api/v1/admin/reviews/pending'); }
  public createJob(title: string, company: string, description: string, requiredSkills: string[]): Promise<Job> {
    return this.request<Job>(http.RequestMethod.POST, '/api/v1/jobs', JSON.stringify({ title, company, description, required_skills: requiredSkills }));
  }
  public decideReview(targetType: string, targetId: number, action: string, reason: string): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, '/api/v1/admin/reviews', JSON.stringify({ target_type: targetType, target_id: targetId, action, reason }));
  }
  /** 兼容旧调用：返回首屏（前 20 条）。 */
  public getDiscussions(courseId?: number): Promise<DiscussionPost[]> {
    const suffix: string = courseId !== undefined && courseId > 0 ? `&course_id=${courseId}` : '';
    return this.request<DiscussionPage>(http.RequestMethod.GET, `/api/v1/discussions?page=1&page_size=20${suffix}`)
      .then((p: DiscussionPage): DiscussionPost[] => p.items);
  }
  /** 讨论广场分页（需求 16：10/50/100 条每页）。 */
  public getDiscussionPage(page: number, pageSize: number, courseId?: number): Promise<DiscussionPage> {
    const suffix: string = courseId !== undefined && courseId > 0 ? `&course_id=${courseId}` : '';
    return this.request<DiscussionPage>(http.RequestMethod.GET, `/api/v1/discussions?page=${page}&page_size=${pageSize}${suffix}`);
  }
  /** 帖子详情（回复树 + 作者 + 点赞状态）。 */
  public getDiscussionDetail(postId: number): Promise<DiscussionDetail> {
    return this.request<DiscussionDetail>(http.RequestMethod.GET, `/api/v1/discussions/${postId}`);
  }
  /** 回复帖子。 */
  public replyDiscussion(postId: number, content: string, replyToId?: number): Promise<Record<string, object>> {
    const body: string = replyToId !== undefined && replyToId > 0
      ? `{"content":"${content}","reply_to_id":${replyToId}}`
      : `{"content":"${content}"}`;
    return this.request<Record<string, object>>(http.RequestMethod.POST, `/api/v1/discussions/${postId}/replies`, body);
  }
  /** 回复点赞（需求 6）。 */
  public likeReply(replyId: number): Promise<LikeResult> {
    return this.request<LikeResult>(http.RequestMethod.POST, `/api/v1/discussions/replies/${replyId}/like`, JSON.stringify({}));
  }
  /** 教师教学讨论区（需求 9：TEACHER/ADMIN 专属）。 */
  public getTeacherRoom(): Promise<DiscussionPost[]> {
    return this.request<DiscussionPost[]>(http.RequestMethod.GET, '/api/v1/discussions/teacher-room');
  }
  public postTeacherRoom(title: string, content: string): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, '/api/v1/discussions/teacher-room', JSON.stringify({ course_id: 0, title: title, content: content }));
  }
  public createDiscussion(courseId: number, content: string): Promise<DiscussionPost> {
    return this.request<DiscussionPost>(http.RequestMethod.POST, '/api/v1/discussions', JSON.stringify({ course_id: courseId, content }));
  }
  // ═══ 需求 6：教师课程内容管理 ═══
  public getManagedChapters(courseId: number): Promise<ManagedChapter[]> {
    return this.request<ManagedChapter[]>(http.RequestMethod.GET, `/api/v1/courses/manage/${courseId}/chapters`);
  }
  public createChapter(courseId: number, title: string, description: string): Promise<ManagedChapter> {
    return this.request<ManagedChapter>(http.RequestMethod.POST, `/api/v1/courses/manage/${courseId}/chapters`, JSON.stringify({ title: title, description: description }));
  }
  public updateChapter(chapterId: number, title: string, description: string): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.PUT, `/api/v1/courses/manage/chapters/${chapterId}`, JSON.stringify({ title: title, description: description }));
  }
  public deleteChapter(chapterId: number): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.DELETE, `/api/v1/courses/manage/chapters/${chapterId}`);
  }
  public createSection(chapterId: number, title: string, type: string, content: string, videoUrl: string, durationMin: number, durationSec: number): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, `/api/v1/courses/manage/${chapterId}/sections`, JSON.stringify({
      title: title, type: type, content: content, video_url: videoUrl.length > 0 ? videoUrl : null,
      duration_minutes: durationMin, duration_sec: durationSec,
    }));
  }
  public updateSection(sectionId: number, title: string, type: string, content: string, videoUrl: string, durationMin: number, durationSec: number): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.PUT, `/api/v1/courses/manage/sections/${sectionId}`, JSON.stringify({
      title: title, type: type, content: content, video_url: videoUrl.length > 0 ? videoUrl : null,
      duration_minutes: durationMin, duration_sec: durationSec,
    }));
  }
  public deleteSection(sectionId: number): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.DELETE, `/api/v1/courses/manage/sections/${sectionId}`);
  }
  public likeDiscussion(postId: number): Promise<LikeResult> {
    return this.request<LikeResult>(http.RequestMethod.POST, `/api/v1/discussions/${postId}/like`, JSON.stringify({}));
  }
  public reportContent(targetType: string, targetId: number): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, '/api/v1/reports', JSON.stringify({ target_type: targetType, target_id: targetId }));
  }
  public deleteDiscussion(postId: number): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.DELETE, `/api/v1/discussions/${postId}`);
  }
  public createSignTask(courseId: number): Promise<SignTask> {
    return this.request<SignTask>(http.RequestMethod.POST, '/api/v1/sign/tasks', JSON.stringify({ course_id: courseId }));
  }
  public scanSign(taskId: number, token: string): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, '/api/v1/sign/scan', JSON.stringify({ task_id: taskId, token }));
  }
  public getSignRecords(taskId: number): Promise<SignRecordItem[]> {
    return this.request<SignRecordItem[]>(http.RequestMethod.GET, `/api/v1/sign/tasks/${taskId}/records`);
  }
  public getSignAttendance(taskId: number): Promise<SignAttendanceResult> {
    return this.request<SignAttendanceResult>(http.RequestMethod.GET, `/api/v1/sign/tasks/${taskId}/attendance`);
  }
  public manualSign(taskId: number, userId: number, signed: boolean): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, `/api/v1/sign/tasks/${taskId}/manual`, JSON.stringify({ user_id: userId, signed }));
  }
  public getLatestSignTask(courseId: number): Promise<SignLatest> {
    return this.request<SignLatest>(http.RequestMethod.GET, `/api/v1/sign/tasks/latest?course_id=${courseId}`);
  }
  public studentCheckin(taskId: number, code: string): Promise<CheckinResult> {
    return this.request<CheckinResult>(http.RequestMethod.POST, '/api/v1/sign/checkin', JSON.stringify({ task_id: taskId, code }));
  }
  // ═══════════════ 联系人域（好友/我的老师/私聊）═══════════════
  public searchUserByCode(code: string): Promise<SearchUserResult> {
    return this.request<SearchUserResult>(http.RequestMethod.GET, `/api/v1/contacts/search?code=${encodeURIComponent(code)}`);
  }
  public applyContact(userCode: string, relType: string): Promise<ContactApplyResult> {
    return this.request<ContactApplyResult>(http.RequestMethod.POST, '/api/v1/contacts/apply', JSON.stringify({ user_code: userCode, rel_type: relType }));
  }
  public handleContact(requesterId: number, relType: string, accept: boolean): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, '/api/v1/contacts/handle', JSON.stringify({ requester_id: requesterId, rel_type: relType, accept }));
  }
  public getMyFriends(): Promise<ContactItem[]> { return this.request<ContactItem[]>(http.RequestMethod.GET, '/api/v1/contacts/friends'); }
  public getMyTeachers(): Promise<ContactItem[]> { return this.request<ContactItem[]>(http.RequestMethod.GET, '/api/v1/contacts/teachers'); }
  public getIncomingRequests(): Promise<ContactRequestItem[]> {
    return this.request<ContactRequestItem[]>(http.RequestMethod.GET, '/api/v1/contacts/requests/incoming');
  }
  public updateContactRemark(targetId: number, relType: string, remark: string): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.PUT, '/api/v1/contacts/remark', JSON.stringify({ target_id: targetId, rel_type: relType, remark }));
  }
  public sendChatMessage(receiverId: number, content: string): Promise<ChatMsg> {
    return this.request<ChatMsg>(http.RequestMethod.POST, '/api/v1/chat/send', JSON.stringify({ receiver_id: receiverId, content }));
  }
  public getChatHistory(otherId: number): Promise<ChatMsg[]> {
    return this.request<ChatMsg[]>(http.RequestMethod.GET, `/api/v1/chat/history/${otherId}`);
  }
  public getChatUnread(): Promise<UnreadCount> { return this.request<UnreadCount>(http.RequestMethod.GET, '/api/v1/chat/unread-count'); }
  // ═══════════════ 我的课程（课表）═══════════════
  public getMyCourses(): Promise<Course[]> { return this.request<Course[]>(http.RequestMethod.GET, '/api/v1/my/courses'); }
  public updateCourseSchedule(courseId: number, payload: Record<string, string>): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.PUT, `/api/v1/courses/${courseId}/schedule`, JSON.stringify(payload));
  }
  public aiJobExplain(jobTitle: string, requiredSkills: string[], matchScore: number, matchedTags: string[], gapTags: string[]): Promise<AiJobExplain> {
    return this.request<AiJobExplain>(http.RequestMethod.POST, '/api/v1/ai/job-explain', JSON.stringify({ job_title: jobTitle, required_skills: requiredSkills, match_score: matchScore, matched_tags: matchedTags, gap_tags: gapTags }));
  }
  /** 传岗位 id：后端取真实 JD/技能权重/学生画像喂给真实 AI 生成匹配解析。 */
  public aiJobExplainById(jobId: number, jobTitle: string, matchScore: number, matchedTags: string[], gapTags: string[]): Promise<AiJobExplain> {
    return this.request<AiJobExplain>(http.RequestMethod.POST, '/api/v1/ai/job-explain', JSON.stringify({
      job_id: jobId, job_title: jobTitle, match_score: matchScore,
      matched_tags: matchedTags, gap_tags: gapTags, required_skills: []
    }));
  }
  public aiSummary(text: string): Promise<AiSummary> {
    return this.request<AiSummary>(http.RequestMethod.POST, '/api/v1/ai/summary', JSON.stringify({ text }));
  }
  public aiPlan(goal: string, dailyMinutes: number, weakKps: string[], days: number): Promise<AiPlan> {
    return this.request<AiPlan>(http.RequestMethod.POST, '/api/v1/ai/plan', JSON.stringify({ goal, daily_minutes: dailyMinutes, weak_kps: weakKps, days }));
  }
  public aiInterviewStart(jobTitle: string): Promise<AiInterview> {
    return this.request<AiInterview>(http.RequestMethod.POST, '/api/v1/ai/interview/start', JSON.stringify({ job_title: jobTitle, required_skills: [] }));
  }
  public aiInterviewTurn(jobTitle: string, question: string, answer: string, turn: number): Promise<AiInterview> {
    return this.request<AiInterview>(http.RequestMethod.POST, '/api/v1/ai/interview/turn', JSON.stringify({ job_title: jobTitle, question, answer, turn }));
  }
  public aiGenerateQuestions(kpNames: string[], qtype: string, count: number): Promise<Record<string, AiDraftQuestion[]>> {
    return this.request<Record<string, AiDraftQuestion[]>>(http.RequestMethod.POST, '/api/v1/ai/questions/draft', JSON.stringify({ kp_names: kpNames, type: qtype, count }));
  }
  public approveDraft(questionId: number): Promise<QuestionItem> {
    return this.request<QuestionItem>(http.RequestMethod.POST, '/api/v1/questions/drafts/approve', JSON.stringify({ question_id: questionId }));
  }
  public discardDraft(questionId: number): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.DELETE, `/api/v1/questions/drafts/${questionId}`);
  }
  public getAssignments(courseId?: number): Promise<AssignmentItem[]> {
    const suffix: string = courseId !== undefined ? `?course_id=${courseId}` : '';
    return this.request<AssignmentItem[]>(http.RequestMethod.GET, `/api/v1/assignments${suffix}`);
  }
  public submitAssignment(assignmentId: number, content: string): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, `/api/v1/assignments/${assignmentId}/submit`, JSON.stringify({ content }));
  }
  public getAssignmentSubmissions(assignmentId: number): Promise<AssignmentSubmissionList[]> {
    return this.request<AssignmentSubmissionList[]>(http.RequestMethod.GET, `/api/v1/assignments/${assignmentId}/submissions`);
  }
  public gradeSubmission(submissionId: number, score: number, feedback: string): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, `/api/v1/submissions/${submissionId}/grade`, JSON.stringify({ score, feedback }));
  }
  public getSensitiveWords(): Promise<SensitiveWordItem[]> { return this.request<SensitiveWordItem[]>(http.RequestMethod.GET, '/api/v1/admin/sensitive-words'); }
  public addSensitiveWord(word: string, level: number): Promise<SensitiveWordItem> {
    return this.request<SensitiveWordItem>(http.RequestMethod.POST, '/api/v1/admin/sensitive-words', JSON.stringify({ word, level }));
  }
  public deleteSensitiveWord(id: number): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.DELETE, `/api/v1/admin/sensitive-words/${id}`);
  }
  public getConfigs(): Promise<ConfigItem[]> { return this.request<ConfigItem[]>(http.RequestMethod.GET, '/api/v1/admin/configs'); }
  public upsertConfig(cfgKey: string, cfgValue: string, remark: string): Promise<ConfigItem> {
    return this.request<ConfigItem>(http.RequestMethod.PUT, '/api/v1/admin/configs', JSON.stringify({ cfg_key: cfgKey, cfg_value: cfgValue, remark }));
  }
  public getSkillTags(): Promise<SkillTagItem[]> { return this.request<SkillTagItem[]>(http.RequestMethod.GET, '/api/v1/admin/skill-tags'); }
  public addSkillTag(name: string, category: string): Promise<SkillTagItem> {
    return this.request<SkillTagItem>(http.RequestMethod.POST, '/api/v1/admin/skill-tags', JSON.stringify({ name, category }));
  }
  public deleteSkillTag(id: number): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.DELETE, `/api/v1/admin/skill-tags/${id}`);
  }
  public getUsers(): Promise<AdminUserItem[]> { return this.request<AdminUserItem[]>(http.RequestMethod.GET, '/api/v1/admin/users'); }
  public setUserStatus(userId: number, status: number): Promise<AdminUserItem> {
    return this.request<AdminUserItem>(http.RequestMethod.PUT, `/api/v1/admin/users/${userId}/status`, JSON.stringify({ status }));
  }
  public resetUserPassword(userId: number, newPassword: string): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, `/api/v1/admin/users/${userId}/reset-password`, JSON.stringify({ new_password: newPassword }));
  }
  public importUsers(users: UserImportItem[]): Promise<ImportReport> {
    return this.request<ImportReport>(http.RequestMethod.POST, '/api/v1/admin/users/import', JSON.stringify({ users }));
  }
  public reportExamMonitor(examId: number, switchCount: number): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, `/api/v1/exams/${examId}/monitor`, JSON.stringify({ switch_count: switchCount }));
  }
  public getUploadToken(fileName: string, fileSize: string): Promise<Record<string, string>> {
    return this.request<Record<string, string>>(http.RequestMethod.POST, '/api/v1/resources/upload-token', JSON.stringify({ file_name: fileName, file_size: fileSize }));
  }
  public confirmResourceUpload(fileName: string, ossKey: string, courseId: number, chapterId: number): Promise<Record<string, object>> {
    const ext: string = fileName.split('.').pop() ?? '';
    const videoExts: string[] = ['mp4', 'avi', 'mov', 'mkv'];
    return this.request<Record<string, object>>(http.RequestMethod.POST, '/api/v1/resources', JSON.stringify({
      file_name: fileName,
      file_type: videoExts.indexOf(ext.toLowerCase()) >= 0 ? 'video' : 'doc',
      file_size: null,
      oss_key: ossKey,
      duration: null,
      course_id: courseId,
      chapter_id: chapterId
    }));
  }
  public batchUpdateProgress(items: Progress[]): Promise<Record<string, object>> {
    return this.request<Record<string, object>>(http.RequestMethod.POST, '/api/v1/progress/batch', JSON.stringify({ items }));
  }
  /**
   * 下载简历 PDF：拉取二进制并写入用户下载目录，返回文件名。
   * （http request 返回 ArrayBuffer；fs 写入 Download 目录）
   */
  public async downloadResumePdf(resumeId: number, fileName: string): Promise<string> {
    const client: http.HttpRequest = http.createHttp();
    try {
      const headers: Record<string, string> = {};
      if (this.token.length > 0) headers.Authorization = `Bearer ${this.token}`;
      const response: http.HttpResponse = await client.request(
        `${ApiClient.baseUrl}/api/v1/resumes/${resumeId}/pdf`, {
        method: http.RequestMethod.GET, header: headers,
        connectTimeout: 10000, readTimeout: 30000, expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`下载失败 (${response.responseCode})`);
      }
      const buffer: ArrayBuffer = response.result as ArrayBuffer;
      if (buffer.byteLength < 100 || response.header['content-type'] === undefined) {
        throw new Error('PDF 内容为空');
      }
      // 写入应用下载目录（用户可通过文件管理器访问）
      return await this.saveToFile(buffer, fileName);
    } finally { client.destroy(); }
  }
  private async saveToFile(buffer: ArrayBuffer, fileName: string): Promise<string> {
    const context: Context | undefined = AppStorage.get<Object>('context') as Context | undefined;
    if (context === undefined) { throw new Error('应用上下文不可用'); }
    const dir: string = context.filesDir;
    const path: string = `${dir}/${fileName}`;
    const file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, buffer);
    } finally { fs.closeSync(file); }
    return path;
  }
}

export const api: ApiClient = new ApiClient();
