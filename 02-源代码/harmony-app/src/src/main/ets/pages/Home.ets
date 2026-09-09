import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { api } from '../common/ApiClient';
import { tokenStore } from '../common/TokenStore';
import {
  AdminUserItem, AssignmentItem, AssignmentSubmissionList, ConfigItem,
  ContactItem, ContactRequestItem, Course, CourseStat, Dashboard, DiscussionPost, ExamSummary, Job,
  LearningStats, NotificationItem, PendingCompany, PendingJob, PendingPost,
  PendingReply, PendingReviews, Profile, QuestionItem, SensitiveWordItem,
  SignAttendanceResult, SignAttendanceStudent, SignRecordItem, SignTask, SkillTagItem, StatFunnel, StatTrend, WrongStat
} from '../common/Models';
import { Theme } from '../common/Theme';
import { TagChip, EmptyState, SkeletonCard, PrimaryButton, Card } from '../components/UiKit';
import { IBestNoticeBar, IBestDialogUtil } from '@ibestservices/ibest-ui-v2';
import { DonutChart } from '../components/DonutChart';
import { BarChart } from '../components/BarChart';
import { TrendChart } from '../components/TrendChart';
import { BreakpointHelper } from '../utils/BreakpointHelper';
interface SkillEntry { name: string; value: number; }
@Entry
@Component
struct Home {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State role: string = 'STUDENT';
  @State username: string = '';
  @State courses: Course[] = [];
  @State exams: ExamSummary[] = [];
  @State jobs: Job[] = [];
  @State notifications: NotificationItem[] = [];
  // 通知类型中文映射（消息 Tab 卡片标签）
  private typeName(type: string): string {
    if (type === 'SYSTEM') return '系统';
    if (type === 'EXAM') return '考试';
    if (type === 'JOB') return '就业';
    if (type === 'COURSE') return '课程';
    if (type === 'EVENT') return '活动';
    if (type === 'FRIEND_ACCEPT' || type === 'FRIEND_REQUEST') return '好友';
    if (type === 'SIGN') return '签到';
    if (type === 'ASSIGNMENT') return '作业';
    return '通知';
  }
  @State profile: Profile | null = null;
  @State questions: QuestionItem[] = [];
  @State stats: LearningStats | null = null;
  @State dashboard: Dashboard | null = null;
  @State pending: PendingReviews | null = null;
  @State statTrend: StatTrend | null = null;
  @State statFunnel: StatFunnel | null = null;
  @State loading: boolean = true;
  @State message: string = '';
  @State newCourseTitle: string = '';
  @State newCourseDesc: string = '';
  @State creatingCourse: boolean = false;
  @State discussions: DiscussionPost[] = [];
  @State newPost: string = '';
  @State signTask: SignTask | null = null;
  @State signRecords: SignRecordItem[] = [];
  @State signMessage: string = '';
  @State signRemaining: number = 0;
  @State signTimerId: number = -1;
  @State signAttendance: SignAttendanceResult | null = null;
  @State signListExpanded: boolean = false;  // 签到名单展开/收起（需求 12）
  @State studentSignCode: string = '';
  @State studentSignCourseId: number = 0;
  @State studentSignTaskId: number = 0;
  @State studentSignRemaining: number = 0;
  @State studentSignMsg: string = '';
  @State studentSignTimerId: number = -1;
  @State aiExplain: string = '';
  @State aiGenerating: boolean = false;
  @State assignments: AssignmentItem[] = [];
  @State submissions: AssignmentSubmissionList[] = [];
  @State assignmentContent: string = '';
  @State assignmentMessage: string = '';
  @State sensitiveWords: SensitiveWordItem[] = [];
  @State configs: ConfigItem[] = [];
  @State skillTags: SkillTagItem[] = [];
  @State adminUsers: AdminUserItem[] = [];
  @State newSensitiveWord: string = '';
  @State avatarUrl: string = '';
  @State userId: string = '';
  // ═══ 联系人域（好友/老师/私聊未读）═══
  @State contactList: ContactItem[] = [];
  @State incomingRequests: ContactRequestItem[] = [];
  // ═══ 入场动效（loadData 后 stagger 展开）═══
  @State enterPhase: number = 0;   // 0=未入场 1=进行中
  @StorageProp('darkMode') darkMode: boolean = false;  // 深色模式即时换肤
  @State expandWrongTop: boolean = false;  // 学情看板高频错题题干展开
  @State quickOpacity: number = 0; // 快捷条
  @State listOpacity: number = 0;  // 主体列表
  @State dashOpacity: number = 0;  // 数据区
  @State mineAnim: number = 0;     // 能力画像条 0→1
  @State livePulse: number = 1;    // 进行中考试呼吸
  private playEnter(): void {
    this.enterPhase = 1;
    animateTo({ duration: 450, curve: Curve.EaseOut, delay: 60 }, () => { this.quickOpacity = 1; });
    animateTo({ duration: 500, curve: Curve.FastOutSlowIn, delay: 180 }, () => { this.listOpacity = 1; });
    animateTo({ duration: 500, curve: Curve.FastOutSlowIn, delay: 300 }, () => { this.dashOpacity = 1; });
    animateTo({ duration: 1100, curve: Curve.Friction, delay: 250 }, () => { this.mineAnim = 1; });
    // 进行中考试的🔴持续呼吸（无限往返）
    animateTo({ duration: 1200, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.livePulse = 1.25;
    });
  }
  aboutToAppear(): void {
    // Home 是免登录入口直连页，ApiClient 内存 token 可能为空，必须从 AppStorage 恢复，
    // 否则所有数据请求都会 401。
    const savedToken: string = AppStorage.get<string>('token') ?? '';
    if (savedToken.length > 0) { api.setToken(savedToken); }
    this.role = AppStorage.get<string>('role') ?? 'STUDENT';
    this.username = AppStorage.get<string>('username') ?? '同学';
    this.avatarUrl = AppStorage.get<string>('avatar') ?? '';
    this.userId = AppStorage.get<string>('userId') ?? '';
    this.loadData();
  }
  /** 页面回前台/从子页返回时同步用户展示信息（需求 1：改名后顶部立即刷新）。 */
  onPageShow(): void {
    const name: string = AppStorage.get<string>('username') ?? this.username;
    if (name !== this.username) { this.username = name; }
    const avatar: string = AppStorage.get<string>('avatar') ?? this.avatarUrl;
    if (avatar !== this.avatarUrl) { this.avatarUrl = avatar; }
    // 联系人/申请也随返回刷新（聊天中已读等状态）
    if (!this.loading) { this.refreshContacts(); }
  }
  /** 轻量刷新联系人域（不重置整页 loading）。 */
  private async refreshContacts(): Promise<void> {
    try {
      const friends: ContactItem[] = await api.getMyFriends();
      const teachers: ContactItem[] = await api.getMyTeachers();
      this.contactList = friends.concat(teachers);
      this.incomingRequests = await api.getIncomingRequests();
    } catch (_) { /* 忽略 */ }
  }
  private async loadData(): Promise<void> {
    this.loading = true;
    this.message = '';
    try {
      if (this.role === 'STUDENT') {
        this.courses = await api.getCourses();
        this.exams = await api.getExams();
        this.jobs = await api.getJobs();
        this.notifications = await api.getNotifications();
        this.profile = await api.getProfile();
        this.discussions = await api.getDiscussions();
        this.assignments = await api.getAssignments();
      } else if (this.role === 'TEACHER') {
        this.courses = await api.getCourses();
        this.exams = await api.getExams();
        this.notifications = await api.getNotifications();
        try { this.stats = await api.getLearningStats(); } catch (_) { this.stats = null; } // 学情失败不阻塞首页（需求 13）
        this.questions = await api.getQuestionsPreview(12);
        this.assignments = await api.getAssignments();
      } else {
        this.courses = await api.getCourses();
        this.exams = await api.getExams();
        this.dashboard = await api.getDashboard();
        this.pending = await api.getPendingReviews();
        this.statTrend = await api.getStatTrend();
        this.statFunnel = await api.getStatFunnel();
        this.sensitiveWords = await api.getSensitiveWords();
        this.configs = await api.getConfigs();
        this.skillTags = await api.getSkillTags();
        this.adminUsers = await api.getUsers();
      }
      // 好友+老师列表（两角色均加载：未读徽标 + 我的页入口）
      try {
        const friends: ContactItem[] = await api.getMyFriends();
        const teachers: ContactItem[] = await api.getMyTeachers();
        this.contactList = friends.concat(teachers);
      } catch (_) {
        this.contactList = []; // 联系人加载失败不阻塞首页
      }
      // 待处理申请（消息页展示）
      try {
        this.incomingRequests = await api.getIncomingRequests();
      } catch (_) {
        this.incomingRequests = [];
      }
    } catch (error) {
      this.message = error instanceof Error ? error.message : '数据加载失败';
    }
    this.loading = false;
    this.avatarUrl = AppStorage.get<string>('avatar') ?? '';
    this.userId = AppStorage.get<string>('userId') ?? '';
    // 首次加载完成后播放入场动效
    if (this.enterPhase === 0) { this.playEnter(); }
  }
  private skillEntries(): SkillEntry[] {
    const entries: SkillEntry[] = [];
    const profile: Profile | null = this.profile;
    if (profile !== null && profile.skill_scores !== undefined) {
      const keys: string[] = Object.keys(profile.skill_scores);
      keys.forEach((key: string): void => {
        entries.push({ name: key, value: profile.skill_scores[key] });
      });
    }
    return entries;
  }
  /** 综合能力均值（我的页摘要展示用）。 */
  private abilityAvg(): number {
    const list: SkillEntry[] = this.skillEntries();
    if (list.length === 0) { return 0; }
    let sum: number = 0;
    list.forEach((e: SkillEntry): void => { sum += e.value; });
    return Math.round(sum / list.length);
  }
  /** 联系人未读总数（好友+老师私聊）。 */
  private chatUnreadTotal(): number {
    let n: number = 0;
    this.contactList.forEach((c: ContactItem): void => { n += c.unread; });
    return n;
  }
  /** 消息页直接处理好友/师生申请（需求 7/9）。 */
  private async handleIncomingRequest(req: ContactRequestItem, accept: boolean): Promise<void> {
    try {
      await api.handleContact(req.requester.id, req.rel_type, accept);
      this.incomingRequests = this.incomingRequests.filter(
        (r: ContactRequestItem): boolean => r.requester.id !== req.requester.id);
      try {
        const friends: ContactItem[] = await api.getMyFriends();
        const teachers: ContactItem[] = await api.getMyTeachers();
        this.contactList = friends.concat(teachers);
      } catch (_) { /* 忽略 */ }
    } catch (error) {
      this.message = error instanceof Error ? error.message : '操作失败';
    }
  }
  private async createCourse(): Promise<void> {
    if (this.newCourseTitle.length === 0 || this.creatingCourse) return;
    this.creatingCourse = true;
    this.message = '';
    try {
      await api.createCourse(this.newCourseTitle, this.newCourseDesc);
      this.newCourseTitle = '';
      this.newCourseDesc = '';
      this.courses = await api.getCourses();
      this.message = '✓ 课程已创建';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '创建失败';
    }
    this.creatingCourse = false;
  }
  private async decideReview(targetType: string, targetId: number, action: string): Promise<void> {
    this.message = '';
    // 后端 REJECT 必须携带非空 reason，否则 422
    const reason: string = action === 'REJECT' ? '不符合平台发布规范' : '';
    try {
      await api.decideReview(targetType, targetId, action, reason);
      this.pending = await api.getPendingReviews();
      this.message = '✓ 审核已处理';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '审核失败';
    }
  }
  private async postDiscussion(): Promise<void> {
    if (this.newPost.length === 0) return;
    const courseId: number = this.courses.length > 0 ? this.courses[0].id : 1;
    try {
      await api.createDiscussion(courseId, this.newPost);
      this.newPost = '';
      this.discussions = await api.getDiscussions();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '发帖失败';
    }
  }
  private async likeDiscussion(postId: number): Promise<void> {
    try {
      const result = await api.likeDiscussion(postId);
      if (result.first_time === false) {
        this.message = '已点过赞啦';
      }
      this.discussions = await api.getDiscussions();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '点赞失败';
    }
  }
  private async startSignTask(): Promise<void> {
    this.signMessage = '';
    const courseId: number = this.courses.length > 0 ? this.courses[0].id : 1;
    try {
      const r = await api.createSignTask(courseId);
      this.signTask = r;
      this.signRecords = [];
      this.signAttendance = null;
      this.signListExpanded = false;  // 新一轮签到重置名单展开态（需求 12）
      this.signRemaining = r.remaining_seconds ?? 30;
      if (this.signTimerId >= 0) { clearInterval(this.signTimerId); }
      this.signTimerId = setInterval(() => {
        if (this.signRemaining > 0) { this.signRemaining -= 1; }
        if (this.signRemaining <= 0 && this.signTimerId >= 0) { clearInterval(this.signTimerId); this.signTimerId = -1; }
      }, 1000);
      this.signMessage = '✓ 签到已发起：请学生输入 4 位数字码（30 秒内有效）';
    } catch (error) {
      this.signMessage = error instanceof Error ? error.message : '发起签到失败';
    }
  }
  private async loadSignRecords(): Promise<void> {
    if (this.signTask === null) return;
    try {
      this.signRecords = await api.getSignRecords(this.signTask.id);
    } catch (error) {
      this.signMessage = error instanceof Error ? error.message : '获取名单失败';
    }
  }
  private async loadAttendance(): Promise<void> {
    if (this.signTask === null) return;
    try {
      this.signAttendance = await api.getSignAttendance(this.signTask.id);
      if (this.signAttendance !== null && this.signAttendance.remaining_seconds > 0) {
        this.signRemaining = this.signAttendance.remaining_seconds;
      }
    } catch (error) {
      this.signMessage = error instanceof Error ? error.message : '获取考勤失败';
    }
  }
  private async manualSign(userId: number, signed: boolean): Promise<void> {
    if (this.signTask === null) return;
    try {
      await api.manualSign(this.signTask.id, userId, signed);
      this.signMessage = signed ? '✓ 已为该学生补签' : '✓ 已作废该学生签到';
      await this.loadAttendance();
    } catch (error) {
      this.signMessage = error instanceof Error ? error.message : '操作失败';
    }
  }
  private async studentStartSign(courseId: number): Promise<void> {
    this.studentSignMsg = '';
    this.studentSignCourseId = courseId;
    try {
      const r = await api.getLatestSignTask(courseId);
      this.studentSignTaskId = r.id;
      this.studentSignRemaining = r.remaining_seconds;
      this.studentSignCode = '';
      if (this.studentSignTimerId >= 0) { clearInterval(this.studentSignTimerId); }
      this.studentSignTimerId = setInterval(() => {
        if (this.studentSignRemaining > 0) { this.studentSignRemaining -= 1; }
        if (this.studentSignRemaining <= 0 && this.studentSignTimerId >= 0) {
          clearInterval(this.studentSignTimerId); this.studentSignTimerId = -1;
        }
      }, 1000);
    } catch (error) {
      this.studentSignMsg = error instanceof Error ? error.message : '暂无进行中的签到';
    }
  }
  private async studentCheckin(): Promise<void> {
    if (this.studentSignTaskId <= 0) return;
    if (this.studentSignCode.length !== 4) {
      this.studentSignMsg = '请输入 4 位数字签到码';
      return;
    }
    try {
      await api.studentCheckin(this.studentSignTaskId, this.studentSignCode);
      this.studentSignMsg = '✓ 签到成功';
      if (this.studentSignTimerId >= 0) { clearInterval(this.studentSignTimerId); this.studentSignTimerId = -1; }
    } catch (error) {
      this.studentSignMsg = error instanceof Error ? error.message : '签到失败';
    }
  }
  private async explainJob(job: Job): Promise<void> {
    this.aiExplain = '';
    try {
      const result = await api.aiJobExplain(job.title, job.required_skills, job.match_score,
        job.matched_tags, job.gap_tags);
      this.aiExplain = `${result.explanation}\n建议：${result.suggestions.join('；')}`;
    } catch (error) {
      this.aiExplain = error instanceof Error ? error.message : 'AI 解释失败';
    }
    // 就地弹出 AI 解释（IBestDialogUtil 美观弹窗）
    IBestDialogUtil.open({
      title: `🤖 「${job.title}」匹配解读`,
      message: this.aiExplain,
      showCancelButton: false,
      confirmButtonText: '知道了',
      onConfirm: (): void => { this.aiExplain = ''; },
    } as ESObject);
  }
  private async generateAiQuestions(): Promise<void> {
    if (this.aiGenerating) return;
    this.aiGenerating = true;
    this.message = '';
    try {
      await api.aiGenerateQuestions(['Python 基础'], 'SINGLE', 2);
      this.questions = await api.getQuestionsPreview(12);
      this.message = '✓ AI 草稿题已生成，请审阅后采纳或丢弃';
    } catch (error) {
      this.message = error instanceof Error ? error.message : 'AI 出题失败';
    }
    this.aiGenerating = false;
  }
  private async approveDraft(questionId: number): Promise<void> {
    try {
      await api.approveDraft(questionId);
      this.questions = await api.getQuestionsPreview(12);
    } catch (error) {
      this.message = error instanceof Error ? error.message : '采纳失败';
    }
  }
  private async discardDraft(questionId: number): Promise<void> {
    try {
      await api.discardDraft(questionId);
      this.questions = await api.getQuestionsPreview(12);
    } catch (error) {
      this.message = error instanceof Error ? error.message : '丢弃失败';
    }
  }
  private async submitAssignment(assignmentId: number): Promise<void> {
    if (this.assignmentContent.length === 0) {
      this.assignmentMessage = '请先填写作业内容';
      return;
    }
    this.assignmentMessage = '';
    try {
      await api.submitAssignment(assignmentId, this.assignmentContent);
      this.assignmentContent = '';
      this.assignments = await api.getAssignments();
      this.assignmentMessage = '✓ 作业已提交';
    } catch (error) {
      this.assignmentMessage = error instanceof Error ? error.message : '提交失败';
    }
  }
  private async viewSubmissions(assignmentId: number): Promise<void> {
    try {
      this.submissions = await api.getAssignmentSubmissions(assignmentId);
    } catch (error) {
      this.assignmentMessage = error instanceof Error ? error.message : '获取提交失败';
    }
  }
  private async gradeSubmission(submissionId: number, score: number): Promise<void> {
    try {
      await api.gradeSubmission(submissionId, score, '已批改');
      this.assignmentMessage = '✓ 已批改';
    } catch (error) {
      this.assignmentMessage = error instanceof Error ? error.message : '批改失败';
    }
  }
  private async addSensitiveWordAdmin(): Promise<void> {
    if (this.newSensitiveWord.length === 0) {
      this.message = '请输入敏感词';
      return;
    }
    try {
      await api.addSensitiveWord(this.newSensitiveWord, 1);
      this.newSensitiveWord = '';
      this.sensitiveWords = await api.getSensitiveWords();
      this.message = '✓ 敏感词已添加';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '添加失败';
    }
  }
  private async deleteSensitiveWordAdmin(id: number): Promise<void> {
    try {
      await api.deleteSensitiveWord(id);
      this.sensitiveWords = await api.getSensitiveWords();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '删除失败';
    }
  }
  private logout(): void {
    api.setToken('');
    AppStorage.delete('token');
    AppStorage.delete('refresh_token');
    AppStorage.delete('role');
    AppStorage.delete('username');
    AppStorage.delete('avatar');
    AppStorage.delete('userId');
    // 清磁盘登录态，重启后回到登录页
    const ctx: object | undefined = this.getUIContext().getHostContext();
    if (ctx !== undefined) {
      tokenStore.clear(ctx as common.UIAbilityContext);
    }
    router.replaceUrl({ url: 'pages/Login' });
  }
  private roleLabel(): string {
    if (this.role === 'STUDENT') return '学生端';
    if (this.role === 'TEACHER') return '教师端';
    return '管理端';
  }
  /** 首条未读通知标题（NoticeBar 播报用）。 */
  private firstUnreadTitle(): string {
    for (const n of this.notifications) {
      if (!(n.is_read ?? 0)) { return n.title; }
    }
    return '暂无新通知';
  }
  @Builder Toast() {
    if (this.message.length > 0) {
      Row({ space: 6 }) {
        Text('💡').fontSize(13)
        Text(this.message).fontSize(Theme.F_SUB)
          .fontColor(this.message.indexOf('失败') >= 0 || this.message.indexOf('错误') >= 0
            ? Theme.DANGER : Theme.SUCCESS)
      }
      .width('100%').padding(10)
      .backgroundColor(this.message.indexOf('失败') >= 0
        ? Theme.DANGER_LIGHT : Theme.SUCCESS_LIGHT)
      .borderRadius(Theme.R_SM)
    }
  }
  @Builder TopBar() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Stack() {
          if (this.avatarUrl.startsWith('http://') || this.avatarUrl.startsWith('https://')) {
            Image(this.avatarUrl).width(42).height(42).borderRadius(21)
              .objectFit(ImageFit.Cover)
          } else {
            Column() {
              Text(this.username.length > 0 ? this.username.substring(0, 1).toUpperCase() : '?')
                .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
            }
            .width(42).height(42).borderRadius(21)
            .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
          }
        }
        .shadow(Theme.SHADOW_FLOAT)
        Column({ space: 2 }) {
          Text(`Hi，${this.username}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
          Text(`鸿蒙智学业 · ${this.roleLabel()}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Button('退出').fontSize(12).height(32)
          .backgroundColor(Theme.CARD).fontColor(Theme.TEXT_HINT)
          .shadow(Theme.SHADOW_CARD)
          .onClick((): void => { this.logout(); })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 14, bottom: 10 })
      // 平板/大屏：顶部增加快捷入口，减少页面跳转层级
      if (this.bp === 'md' || this.bp === 'lg') {
        Scroll() {
          Row({ space: 8 }) {
            if (this.role === 'STUDENT') {
              this.TopChip('🔍', '搜索', 'pages/SearchPage')
              this.TopChip('📂', '资料', 'pages/ResourceList')
              this.TopChip('📕', '错题本', 'pages/WrongBook')
              this.TopChip('📋', '作业', 'pages/AssignmentList')
              this.TopChip('📝', '笔记', 'pages/Notes')
              this.TopChip('📅', '计划', 'pages/StudyPlan')
            } else if (this.role === 'TEACHER') {
              this.TopChip('📝', '组卷', 'pages/ExamEdit')
              this.TopChip('✅', '批改', 'pages/AssignmentGrading')
              this.TopChip('👁', '监考', 'pages/ExamMonitor')
              this.TopChip('📤', '上传', 'pages/ResourceUpload')
              this.TopChip('💬', '教研', 'pages/TeacherRoom')
            } else {
              this.TopChip('👥', '用户', 'pages/UserManage')
              this.TopChip('🏢', '企业', 'pages/CompanyManage')
              this.TopChip('📊', '大屏', 'pages/DataDashboard')
              this.TopChip('📜', '日志', 'pages/AuditLogs')
            }
          }.padding({ left: 20, right: 20, bottom: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .opacity(this.quickOpacity)
        .translate({ y: (1 - this.quickOpacity) * 16 })
      }
      // 未读通知公告条（IBestNoticeBar 滚动播报，纯展示组件 V1 页面安全）
      if (this.unreadCount() > 0) {
        IBestNoticeBar({
          text: `📢 新通知：${this.firstUnreadTitle()}（未读 ${this.unreadCount()} 条，到消息页查看）`,
          scrollable: true,
          radius: 8,
          barHeight: 40,
        } as ESObject)
          .margin({ left: 20, right: 20, top: 2, bottom: 4 })
      }
    }.width('100%')
  }
  @Builder TopChip(icon: string, label: string, page: string) {
    Row({ space: 4 }) {
      Text(icon).fontSize(13)
      Text(label).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
    }
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .backgroundColor(Theme.CARD).borderRadius(14)
    .shadow(Theme.SHADOW_CARD)
    .onClick((): void => { router.pushUrl({ url: page }); })
  }
  @Builder CourseListTab() {
    Column({ space: 14 }) {
      Row() {
        Text(this.role === 'TEACHER' ? '我的授课' : '推荐课程').fontSize(22)
          .fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).layoutWeight(1)
        if (this.role === 'STUDENT') {
          Button('🔍 搜索').height(34).fontSize(13)
            .backgroundColor(Theme.CARD).fontColor(Theme.TEXT)
            .shadow(Theme.SHADOW_CARD)
            .onClick((): void => { router.pushUrl({ url: 'pages/SearchPage' }); })
        }
      }.width('100%')
      if (this.loading) {
        SkeletonCard(); SkeletonCard(); SkeletonCard()
      } else if (this.courses.length === 0) {
        EmptyState({ icon: '📚', text: '暂无课程' })
      } else {
        GridRow({ gutter: { x: 12, y: 14 } }) {
          ForEach(this.courses, (course: Course) => {
            GridCol({ span: { sm: 12, md: 6, lg: 4 } }) {
              Column({ space: 10 }) {
                Row({ space: 12 }) {
                  Column() {
                    Text(course.title.length > 0 ? course.title.substring(0, 1) : '?')
                      .fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
                  }
                  .width(48).height(48).borderRadius(Theme.R_MD)
                  .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                  Column({ space: 3 }) {
                    Text(course.title).fontSize(16).fontWeight(FontWeight.Bold)
                      .fontColor(Theme.TEXT).maxLines(1)
                    Text(`${course.chapters.length} 个章节 · ${course.teacher}`)
                      .fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).maxLines(1)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                }.width('100%')
                Row({ space: 10 }) {
                  Button('进入课程').height(36).fontSize(13).layoutWeight(1)
                    .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                    .fontColor(Color.White)
                    .onClick((): void => { router.pushUrl({ url: 'pages/CourseDetail', params: { courseId: course.id } }); })
                  if (this.role === 'STUDENT') {
                    Button('AI 摘要').height(36).fontSize(13).layoutWeight(1)
                      .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
                      .onClick((): void => { router.pushUrl({ url: 'pages/AISummary' }); })
                  } else if (this.role === 'TEACHER') {
                    // 需求 6：授课管理 —— 章节 / 小节 / 视频编辑
                    Button('管理内容').height(36).fontSize(13).layoutWeight(1)
                      .backgroundColor(Theme.WARNING_LIGHT).fontColor(Theme.WARNING)
                      .onClick((): void => {
                        router.pushUrl({
                          url: 'pages/CourseContentManage',
                          params: { course_id: course.id, course_title: course.title }
                        });
                      })
                  } else {
                    Button('编辑课程').height(36).fontSize(13).layoutWeight(1)
                      .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
                      .onClick((): void => { router.pushUrl({ url: 'pages/CourseEdit', params: { courseId: course.id } }); })
                  }
                }.width('100%')
              }
              .width('100%').padding(Theme.CARD_PAD)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }
          }, (course: Course) => String(course.id))
        }
        .width('100%')
        .opacity(this.listOpacity)
        .translate({ y: (1 - this.listOpacity) * 24 })
      }
      if (this.role === 'TEACHER') {
        this.SignSection()
        this.TeacherAssignmentSection()
        this.TeacherToolSection()
      } else if (this.role === 'STUDENT') {
        this.StudentSignSection()
        this.DiscussionSection()
        this.StudentAssignmentSection()
      }
      this.Toast()
    }.width('100%').padding(20)
  }
  @Builder TeacherToolSection() {
    Column({ space: 12 }) {
      Text('教学工具箱').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        this.ToolItem('📝', '作业编辑', 'pages/AssignmentEdit')
        this.ToolItem('✅', '作业批改', 'pages/AssignmentGrading')
        this.ToolItem('💬', '讨论管理', 'pages/DiscussionManage')
        this.ToolItem('👁', '考试监控', 'pages/ExamMonitor')
        this.ToolItem('🖊', '主观题批改', 'pages/SubjectiveGrading')
        this.ToolItem('📋', '组卷建考', 'pages/ExamEdit')
        this.ToolItem('📤', '资源上传', 'pages/ResourceUpload')
        this.ToolItem('💼', '岗位发布', 'pages/JobPublish')
        this.ToolItem('🎪', '活动发布', 'pages/CareerEventPublish')
      }.width('100%')
    }
    .width('100%').padding(Theme.CARD_PAD)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
  }
  @Builder ToolItem(icon: string, label: string, page: string) {
    Column({ space: 6 }) {
      Text(icon).fontSize(24)
      Text(label).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
    }
    .width(this.bp === 'sm' ? '23%' : '31%')
    .padding({ top: 14, bottom: 14 })
    .backgroundColor(Theme.BG).borderRadius(Theme.R_MD)
    .onClick((): void => { router.pushUrl({ url: page }); })
  }
  @Builder SignSection() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('📍').fontSize(16)
        Text('课堂签到').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
        Blank()
        if (this.signTask !== null) {
          TagChip({
            text: this.signRemaining > 0 ? `进行中 ${this.signRemaining}s` : '已结束',
            tone: this.signRemaining > 0 ? 'success' : 'danger'
          })
        }
      }.width('100%')
      if (this.signTask === null) {
        PrimaryButton({
          label: '发起签到（4 位数字码 · 30 秒）',
          onTap: (): void => { this.startSignTask(); }
        })
      } else {
        Column({ space: 10 }) {
          // 大号 4 位数字码
          Row({ space: 6 }) {
            ForEach([0, 1, 2, 3], (i: number) => {
              Text((this.signTask!.code ?? this.signTask!.qrcode_token).length > i
                ? (this.signTask!.code ?? this.signTask!.qrcode_token)[i] : '-')
                .fontSize(34).fontWeight(FontWeight.Bold)
                .fontColor(this.signRemaining > 0 ? Theme.PRIMARY : Theme.TEXT_HINT)
                .width(52).height(64).textAlign(TextAlign.Center)
                .backgroundColor(this.signRemaining > 0 ? Theme.PRIMARY_LIGHT : Theme.INPUT_BG)
                .borderRadius(Theme.R_MD)
            }, (i: number) => `d${i}`)
          }
          if (this.signRemaining > 0) {
            Progress({ value: this.signRemaining, total: 30, type: ProgressType.Linear })
              .width('100%').color(Theme.PRIMARY).style({ strokeWidth: 4 })
            Text(`有效期剩余 ${this.signRemaining} 秒，请学生尽快输入`).fontSize(Theme.F_CAP)
              .fontColor(Theme.TEXT_HINT).width('100%').textAlign(TextAlign.Center)
          } else {
            Text('本轮签到已结束，可重新发起或手动补签').fontSize(Theme.F_CAP)
              .fontColor(Theme.TEXT_HINT).width('100%').textAlign(TextAlign.Center)
          }
          Row({ space: 8 }) {
            Button('🔄 重新发起').height(40).fontSize(13).layoutWeight(1)
              .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
              .borderRadius(Theme.R_MD)
              .onClick((): void => { this.startSignTask(); })
            Button(this.signListExpanded ? '📋 收起名单 ▴' : '📋 签到名单 ▾').height(40).fontSize(13).layoutWeight(1)
              .backgroundColor(Theme.BG).fontColor(Theme.TEXT)
              .borderRadius(Theme.R_MD)
              .onClick((): void => {
                // 需求 12：点击展开名单（懒加载），再次点击收起
                if (this.signListExpanded) {
                  this.signListExpanded = false;
                } else {
                  this.loadAttendance();
                  this.signListExpanded = true;
                }
              })
          }.width('100%')
          // 考勤名单（未签红色可补签，已签绿色可作废）—— 需求 12：可展开收起
          if (this.signAttendance !== null && this.signListExpanded) {
            Row({ space: 8 }) {
              Text(`应到 ${this.signAttendance.total}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
              Text(`已签 ${this.signAttendance.signed}`).fontSize(Theme.F_CAP).fontColor(Theme.SUCCESS)
              Text(`未签 ${this.signAttendance.unsigned}`).fontSize(Theme.F_CAP).fontColor(Theme.DANGER)
              Blank()
              Text('再次点击上方按钮收起').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
            }.width('100%').justifyContent(FlexAlign.Center)
            ForEach(this.signAttendance.students, (stu: SignAttendanceStudent) => {
              Row({ space: 8 }) {
                Text(stu.real_name.length > 0 ? stu.real_name : stu.username)
                  .fontSize(Theme.F_SUB).fontColor(Theme.TEXT).layoutWeight(1)
                if (stu.signed) {
                  TagChip({ text: '已签', tone: 'success' })
                  Button('作废').height(26).fontSize(11)
                    .backgroundColor(Theme.DANGER_LIGHT).fontColor(Theme.DANGER)
                    .onClick((): void => { this.manualSign(stu.user_id, false); })
                } else {
                  TagChip({ text: '未签', tone: 'danger' })
                  Button('补签').height(26).fontSize(11)
                    .backgroundColor(Theme.SUCCESS_LIGHT).fontColor(Theme.SUCCESS)
                    .onClick((): void => { this.manualSign(stu.user_id, true); })
                }
              }
              .width('100%').padding(8)
              .backgroundColor(Theme.BG).borderRadius(Theme.R_SM)
            }, (stu: SignAttendanceStudent) => `${stu.user_id}-${stu.signed ? 1 : 0}`)
          }
        }
      }
      if (this.signMessage.length > 0) {
        Text(this.signMessage).fontSize(Theme.F_SUB)
          .fontColor(this.signMessage.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
          .width('100%')
      }
    }
    .width('100%').padding(Theme.CARD_PAD)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
  }
  @Builder StudentSignSection() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('📍').fontSize(16)
        Text('课堂签到').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
        Blank()
        if (this.studentSignTaskId > 0) {
          TagChip({
            text: this.studentSignRemaining > 0 ? `剩余 ${this.studentSignRemaining}s` : '已过期',
            tone: this.studentSignRemaining > 0 ? 'success' : 'danger'
          })
        }
      }.width('100%')
      if (this.studentSignTaskId <= 0) {
        Row({ space: 8 }) {
          Text('老师发起签到后，输入 4 位数字码完成打卡').fontSize(Theme.F_CAP)
            .fontColor(Theme.TEXT_HINT).layoutWeight(1)
          Button('刷新').height(34).fontSize(12)
            .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
            .onClick((): void => {
              const cid: number = this.courses.length > 0 ? this.courses[0].id : 1;
              this.studentStartSign(cid);
            })
        }.width('100%')
      } else {
        Column({ space: 10 }) {
          TextInput({ placeholder: '输入 4 位数字签到码', text: this.studentSignCode })
            .type(InputType.Number)
            .maxLength(4)
            .onChange((v: string): void => { this.studentSignCode = v; })
            .width(220).height(56).fontSize(26).textAlign(TextAlign.Center)
            .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_LG)
            .caretColor(Theme.PRIMARY)
          if (this.studentSignRemaining > 0) {
            Progress({ value: this.studentSignRemaining, total: 30, type: ProgressType.Linear })
              .width('100%').color(Theme.PRIMARY).style({ strokeWidth: 4 })
          }
          PrimaryButton({
            label: '✓ 立即签到',
            onTap: (): void => { this.studentCheckin(); }
          })
        }.width('100%').alignItems(HorizontalAlign.Center)
      }
      if (this.studentSignMsg.length > 0) {
        Text(this.studentSignMsg).fontSize(Theme.F_SUB)
          .fontColor(this.studentSignMsg.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
          .width('100%').textAlign(TextAlign.Center)
      }
    }
    .width('100%').padding(Theme.CARD_PAD)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
  }
  @Builder DiscussionSection() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('💬').fontSize(16)
        Text('课程讨论').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
        Blank()
        // 需求 16：更多按钮 → 讨论广场（全量讨论 + 10/50/100 分页）
        Row({ space: 4 }) {
          Text('讨论广场').fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
          Text('›').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
        }
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(14)
        .onClick((): void => { router.pushUrl({ url: 'pages/DiscussionSquare' }); })
      }.width('100%')
      Row({ space: 8 }) {
        TextInput({ placeholder: '说点什么…', text: this.newPost })
          .onChange((v: string): void => { this.newPost = v; })
          .layoutWeight(1).height(42).fontSize(13)
          .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
        Button('发帖').height(42).fontSize(13)
          .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
          .fontColor(Color.White).borderRadius(Theme.R_MD)
          .onClick((): void => { this.postDiscussion(); })
      }.width('100%')
      ForEach(this.discussions, (post: DiscussionPost) => {
        Row({ space: 10 }) {
          Column({ space: 4 }) {
            Text(post.content).fontSize(Theme.F_BODY).fontColor(Theme.TEXT).width('100%')
            Row({ space: 6 }) {
              Text(`👍 ${post.like_count}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
              Blank()
              Button(post.liked_by_me ? '已赞' : '点赞').height(26).fontSize(11)
                .backgroundColor(post.liked_by_me ? Theme.INPUT_BG : Theme.PRIMARY_LIGHT)
                .fontColor(post.liked_by_me ? Theme.TEXT_HINT : Theme.PRIMARY)
                .enabled(!post.liked_by_me)
                .onClick((): void => { this.likeDiscussion(post.id); })
            }.width('100%')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }
        .width('100%').padding(12)
        .backgroundColor(Theme.BG).borderRadius(Theme.R_MD)
      }, (post: DiscussionPost) => `${post.id}-${post.like_count}-${post.liked_by_me ? 1 : 0}`)
    }
    .width('100%').padding(Theme.CARD_PAD)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
  }
  @Builder StudentAssignmentSection() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('📋').fontSize(16)
        Text('我的作业').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
      }.width('100%')
      if (this.assignments.length === 0) {
        Text('暂无作业').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).width('100%').padding(8)
      } else {
        ForEach(this.assignments.slice(0, 3), (assignment: AssignmentItem) => {
          Column({ space: 8 }) {
            Row() {
              Text(assignment.title).fontSize(Theme.F_BODY)
                .fontWeight(FontWeight.Medium).fontColor(Theme.TEXT).layoutWeight(1)
              if (assignment.my_submission !== null) {
                TagChip({
                  text: assignment.my_submission.status === 'GRADED'
                    ? `${assignment.my_submission.score} 分` : '已提交', tone: 'success'
                })
              } else {
                TagChip({ text: '未提交', tone: 'danger' })
              }
            }.width('100%')
            Text(`截止：${this.fmtDateTime(assignment.deadline)}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
            if (assignment.my_submission === null) {
              Row({ space: 8 }) {
                TextInput({ placeholder: '作业内容', text: this.assignmentContent })
                  .onChange((v: string): void => { this.assignmentContent = v; })
                  .layoutWeight(1).height(40).fontSize(13)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                Button('提交').height(40).fontSize(13)
                  .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                  .fontColor(Color.White).borderRadius(Theme.R_SM)
                  .onClick((): void => { this.submitAssignment(assignment.id); })
              }.width('100%')
            } else if (assignment.my_submission.feedback !== null && assignment.my_submission.feedback !== undefined) {
              Text(`评语：${assignment.my_submission.feedback}`)
                .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND).width('100%')
            }
          }
          .width('100%').padding(12)
          .backgroundColor(Theme.BG).borderRadius(Theme.R_MD)
        }, (assignment: AssignmentItem) => String(assignment.id))
      }
      if (this.assignmentMessage.length > 0) {
        Text(this.assignmentMessage).fontSize(Theme.F_SUB)
          .fontColor(this.assignmentMessage.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
          .width('100%')
      }
      if (this.assignments.length > 3) {
        Row({ space: 4 }) {
          Text(`查看全部 ${this.assignments.length} 项作业`).fontSize(Theme.F_SUB).fontColor(Theme.PRIMARY)
          Text('›').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
        }
        .width('100%').justifyContent(FlexAlign.Center)
        .padding({ top: 8, bottom: 4 })
        .onClick((): void => { router.pushUrl({ url: 'pages/AssignmentList' }); })
      }
    }
    .width('100%').padding(Theme.CARD_PAD)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
  }
  @Builder TeacherAssignmentSection() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('📋').fontSize(16)
        Text('作业管理').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
      }.width('100%')
      if (this.assignments.length === 0) {
        Text('暂无作业').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).width('100%').padding(8)
      } else {
        ForEach(this.assignments.slice(0, 3), (assignment: AssignmentItem) => {
          Column({ space: 8 }) {
            Row() {
              Text(assignment.title).fontSize(Theme.F_BODY)
                .fontWeight(FontWeight.Medium).fontColor(Theme.TEXT).layoutWeight(1)
              Button('查看提交').height(30).fontSize(12)
                .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
                .onClick((): void => { this.viewSubmissions(assignment.id); })
            }.width('100%')
            ForEach(this.submissions, (sub: AssignmentSubmissionList) => {
              Row() {
                Text(sub.real_name.length > 0 ? sub.real_name : sub.username)
                  .fontSize(Theme.F_SUB).fontColor(Theme.TEXT).layoutWeight(1)
                Text(sub.status).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                Blank()
                if (sub.status === 'SUBMITTED') {
                  Button('给 90 分').height(26).fontSize(11)
                    .linearGradient({ angle: 135, colors: [[Theme.SUCCESS, 0], ['#3ECF8E', 1]] })
                    .fontColor(Color.White)
                    .onClick((): void => { this.gradeSubmission(sub.id, 90); })
                }
              }
              .width('100%').padding(8)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_SM)
            }, (sub: AssignmentSubmissionList) => String(sub.id))
          }
          .width('100%').padding(12)
          .backgroundColor(Theme.BG).borderRadius(Theme.R_MD)
        }, (assignment: AssignmentItem) => String(assignment.id))
      }
      if (this.assignmentMessage.length > 0) {
        Text(this.assignmentMessage).fontSize(Theme.F_SUB)
          .fontColor(this.assignmentMessage.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
          .width('100%')
      }
      if (this.assignments.length > 3) {
        Row({ space: 4 }) {
          Text(`查看全部 ${this.assignments.length} 项作业`).fontSize(Theme.F_SUB).fontColor(Theme.PRIMARY)
          Text('›').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
        }
        .width('100%').justifyContent(FlexAlign.Center)
        .padding({ top: 8, bottom: 4 })
        .onClick((): void => { router.pushUrl({ url: 'pages/AssignmentList' }); })
      }
    }
    .width('100%').padding(Theme.CARD_PAD)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
  }
  private examPhase(e: ExamSummary): string {
    if (e.phase !== undefined && e.phase !== null && e.phase.length > 0) { return e.phase; }
    if (e.status === 2) { return 'ended'; }
    return 'open';
  }
  private examPhaseLabel(phase: string): string {
    if (phase === 'ongoing') return '进行中';
    if (phase === 'upcoming') return '未开始';
    if (phase === 'ended') return '已结束';
    return '开放中';
  }
  private examCountdown(e: ExamSummary): string {
    // 进行中：距 end 剩余；未开始：距 start 剩余
    const nowMs: number = Date.now();
    if (e.end_time !== null && e.end_time !== undefined) {
      const endMs: number = Date.parse(e.end_time.endsWith('Z') ? e.end_time : `${e.end_time}Z`);
      if (!Number.isNaN(endMs)) {
        const diff: number = endMs - nowMs;
        if (diff > 0) {
          const h: number = Math.floor(diff / 3600000);
          const m: number = Math.floor((diff % 3600000) / 60000);
          return h > 0 ? `剩 ${h}h${m}m` : `剩 ${m} 分钟`;
        }
      }
    }
    if (e.start_time !== null && e.start_time !== undefined) {
      const startMs: number = Date.parse(e.start_time.endsWith('Z') ? e.start_time : `${e.start_time}Z`);
      if (!Number.isNaN(startMs)) {
        const diff: number = startMs - nowMs;
        if (diff > 0) {
          const d: number = Math.floor(diff / 86400000);
          const h: number = Math.floor((diff % 86400000) / 3600000);
          return d > 0 ? `${d} 天后开考` : `${h} 小时后开考`;
        }
      }
    }
    return '';
  }
  @Builder ExamListTab() {
    Column({ space: 14 }) {
      Text('考试中心').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
      if (this.loading) {
        SkeletonCard(); SkeletonCard()
      } else if (this.exams.length === 0) {
        EmptyState({ icon: '📝', text: '暂无考试安排' })
      } else {
        GridRow({ gutter: { x: 12, y: 14 } }) {
          ForEach(this.exams, (exam: ExamSummary) => {
            GridCol({ span: { sm: 12, md: 6, lg: 4 } }) {
              Column({ space: 8 }) {
                Row({ space: 12 }) {
                  Column() {
                    Text(this.examPhase(exam) === 'ongoing' ? '🔴' : this.examPhase(exam) === 'ended' ? '✅' : '📝').fontSize(20)
                  }
                  .width(46).height(46).borderRadius(Theme.R_MD)
                  .backgroundColor(
                    this.examPhase(exam) === 'ongoing' ? Theme.DANGER_LIGHT
                      : this.examPhase(exam) === 'ended' ? Theme.SUCCESS_LIGHT
                        : Theme.PRIMARY_LIGHT)
                  .alignItems(HorizontalAlign.Center)
                  .scale({
                    x: this.examPhase(exam) === 'ongoing' ? this.livePulse : 1,
                    y: this.examPhase(exam) === 'ongoing' ? this.livePulse : 1
                  })
                  .animation({ curve: Curve.EaseInOut })
                  Column({ space: 3 }) {
                    Text(exam.title).fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).maxLines(1)
                    Text(`时长 ${exam.duration_min} 分钟`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  // 状态角标
                  Text(this.examPhaseLabel(this.examPhase(exam)))
                    .fontSize(Theme.F_CAP).fontWeight(FontWeight.Bold)
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 }).borderRadius(10)
                    .fontColor(
                      this.examPhase(exam) === 'ongoing' ? Theme.DANGER
                        : this.examPhase(exam) === 'ended' ? Theme.SUCCESS : Theme.PRIMARY)
                    .backgroundColor(
                      this.examPhase(exam) === 'ongoing' ? Theme.DANGER_LIGHT
                        : this.examPhase(exam) === 'ended' ? Theme.SUCCESS_LIGHT
                          : Theme.PRIMARY_LIGHT)
                }.width('100%')
                // 倒计时条（进行中红色高亮）
                if (this.examCountdown(exam).length > 0) {
                  Row({ space: 6 }) {
                    Text('⏱').fontSize(11)
                    Text(this.examCountdown(exam)).fontSize(Theme.F_CAP)
                      .fontColor(this.examPhase(exam) === 'ongoing' ? Theme.DANGER : Theme.WARNING)
                      .fontWeight(FontWeight.Bold)
                  }.width('100%')
                }
                Button(this.examPhase(exam) === 'ended' ? '查看成绩' : this.examPhase(exam) === 'upcoming' ? '考试须知' : '进入考试')
                  .height(34).fontSize(13).width('100%')
                  .linearGradient({ angle: 135, colors: this.examPhase(exam) === 'ongoing'
                    ? [[Theme.DANGER, 0], ['#FF6B9D', 1]]
                    : [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                  .fontColor(Color.White)
                  .onClick((): void => {
                    if (this.examPhase(exam) === 'ended') {
                      router.pushUrl({ url: 'pages/ExamResult', params: { examId: exam.id } });
                    } else {
                      router.pushUrl({ url: 'pages/ExamNotice', params: { examId: exam.id } });
                    }
                  })
              }
              .width('100%').padding(14)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
              .border({
                width: this.examPhase(exam) === 'ongoing' ? 1.5 : 0,
                color: this.examPhase(exam) === 'ongoing' ? Theme.DANGER : Color.Transparent
              })
            }
          }, (exam: ExamSummary) => `${exam.id}-${this.examPhase(exam)}`)
        }
        .width('100%')
        .opacity(this.listOpacity)
        .translate({ y: (1 - this.listOpacity) * 24 })
      }
    }.width('100%').padding(20)
  }
  @Builder JobTab() {
    Column({ space: 14 }) {
      Row() {
        Text('就业推荐').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).layoutWeight(1)
        Text('🎪 招聘活动 →').fontSize(Theme.F_SUB).fontColor(Theme.PRIMARY)
          .onClick((): void => { router.pushUrl({ url: 'pages/CareerEvent' }); })
      }.width('100%')
      if (this.loading) {
        SkeletonCard(); SkeletonCard()
      } else if (this.jobs.length === 0) {
        EmptyState({ icon: '💼', text: '暂无匹配岗位' })
      } else {
        GridRow({ gutter: { x: 12, y: 14 } }) {
          ForEach(this.jobs, (job: Job) => {
            GridCol({ span: { sm: 12, md: 6, lg: 4 } }) {
              Column({ space: 8 }) {
                Row({ space: 10 }) {
                  Column() {
                    Text('💼').fontSize(20)
                  }
                  .width(46).height(46).borderRadius(Theme.R_MD)
                  .backgroundColor(Theme.PRIMARY_LIGHT)
                  .alignItems(HorizontalAlign.Center)
                  Column({ space: 2 }) {
                    Text(job.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).maxLines(1)
                    Text(job.company).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Stack() {
                    Progress({ value: job.match_score, total: 100, type: ProgressType.Ring })
                      .width(44).height(44).color(this.scoreColor(job.match_score)).style({ strokeWidth: 5 })
                    Text(this.fmtScore(job.match_score)).fontSize(11).fontWeight(FontWeight.Bold)
                      .fontColor(this.scoreColor(job.match_score))
                  }
                }.width('100%')
                Text(`技能：${job.required_skills.join('、')}`)
                  .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND).width('100%').maxLines(2)
                if (job.gap_tags.length > 0) {
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(job.gap_tags, (tag: string) => {
                      Text(`↑ ${tag}`).fontSize(Theme.F_CAP).fontColor(Theme.WARNING)
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .backgroundColor(Theme.WARNING_LIGHT).borderRadius(8).margin({ right: 6, bottom: 4 })
                    })
                  }.width('100%')
                }
                Row({ space: 10 }) {
                  Button('🤖 AI 解释匹配').height(34).fontSize(12).layoutWeight(1)
                    .backgroundColor(Theme.BG).fontColor(Theme.PRIMARY)
                    .onClick((): void => { this.explainJob(job); })
                  Button('查看详情').height(34).fontSize(12).layoutWeight(1)
                    .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
                    .onClick((): void => { router.pushUrl({ url: 'pages/JobDetail', params: { jobId: job.id } }); })
                }.width('100%')
              }
              .width('100%').padding(Theme.CARD_PAD)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }
          }, (job: Job) => String(job.id))
        }
        .width('100%')
        .opacity(this.listOpacity)
        .translate({ y: (1 - this.listOpacity) * 24 })
      }
    }.width('100%').padding(20)
  }
  @Builder QuestionBankTab() {
    Column({ space: 14 }) {
      Row() {
        Text('题库管理').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).layoutWeight(1)
        Button('题库页').height(34).fontSize(13)
          .backgroundColor(Theme.CARD).fontColor(Theme.PRIMARY)
          .shadow(Theme.SHADOW_CARD)
          .onClick((): void => { router.pushUrl({ url: 'pages/QuestionBank' }); })
      }.width('100%')
      PrimaryButton({
        label: '🤖 AI 出题（单选×2）',
        loading: this.aiGenerating,
        onTap: (): void => { this.generateAiQuestions(); }
      })
      if (this.loading) {
        SkeletonCard(); SkeletonCard()
      } else if (this.questions.length === 0) {
        EmptyState({ icon: '❓', text: '题库为空' })
      } else {
        GridRow({ gutter: { x: 12, y: 12 } }) {
          ForEach(this.questions, (question: QuestionItem) => {
            GridCol({ span: { sm: 12, md: 6, lg: 4 } }) {
              Column({ space: 6 }) {
                Row() {
                  TagChip({
                    text: `${question.type} · 难度${question.difficulty}`,
                    tone: question.status === 'DRAFT' ? 'warning' : 'primary'
                  })
                  Blank()
                  Text(`${question.score} 分`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                }.width('100%')
                Text(question.content).fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium)
                  .fontColor(Theme.TEXT).width('100%').maxLines(2)
                Text(`答案：${question.answer}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  .width('100%').maxLines(1)
                if (question.status === 'DRAFT') {
                  Row({ space: 8 }) {
                    Button('✓ 采纳').height(30).fontSize(12).layoutWeight(1)
                      .linearGradient({ angle: 135, colors: [[Theme.SUCCESS, 0], ['#3ECF8E', 1]] })
                      .fontColor(Color.White)
                      .onClick((): void => { this.approveDraft(question.id); })
                    Button('✕ 丢弃').height(30).fontSize(12).layoutWeight(1)
                      .backgroundColor(Theme.DANGER_LIGHT).fontColor(Theme.DANGER)
                      .onClick((): void => { this.discardDraft(question.id); })
                  }.width('100%')
                }
              }
              .width('100%').padding(Theme.CARD_PAD)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
              // 点击题目卡片查看详情并可编辑
              .onClick((): void => {
                router.pushUrl({ url: 'pages/QuestionEdit', params: { questionId: question.id } });
              })
            }
          }, (question: QuestionItem) => String(question.id))
        }
      }
      this.Toast()
    }.width('100%').padding(20)
  }
  @Builder AnalyticsTab() {
    Column({ space: 14 }) {
      Row() {
        Text('学情看板').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).layoutWeight(1)
        Button('完整统计 ›').height(32).fontSize(12)
          .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
          .borderRadius(16)
          .onClick((): void => { router.pushUrl({ url: 'pages/LearningStats' }); })
      }.width('100%')
      if (this.loading || this.stats === null) {
        SkeletonCard(); SkeletonCard()
      } else {
        // ═══ 图表：真实平均分 + 题型正确率（需求 13 修复）═══
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text('全库平均分').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
            Text(this.stats.overall_avg_score !== undefined && this.stats.overall_avg_score !== null
              ? `${this.stats.overall_avg_score}` : '—')
              .fontSize(26).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
            Text('已交卷归一化（百分制）').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Column({ space: 4 }) {
            Text('题型正确率').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
            if (this.typeRateEntries().length > 0) {
              ForEach(this.typeRateEntries().slice(0, 2), (entry: SkillEntry) => {
                Row({ space: 6 }) {
                  Text(entry.name).fontSize(11).fontColor(Theme.TEXT)
                  Text(`${entry.value}%`).fontSize(11).fontWeight(FontWeight.Bold)
                    .fontColor(entry.value >= 60 ? Theme.SUCCESS : Theme.DANGER)
                }
              }, (e: SkillEntry) => e.name)
            } else {
              Text('暂无判分数据').fontSize(11).fontColor(Theme.TEXT_HINT)
            }
          }.alignItems(HorizontalAlign.End)
        }
        .width('100%').padding(16)
        .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
        .shadow(Theme.SHADOW_CARD)
        // ═══ 图表：各课程选课人数（柱状图）═══
        Card() {
          Column({ space: 14 }) {
            Row({ space: 8 }) {
              Text('👥').fontSize(15)
              Text('各课程选课人数').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
            }.width('100%')
            BarChart({
              labels: this.statsCourseLabels(),
              values: this.statsCourseStudents(),
              unit: ' 人'
            })
          }.width('100%')
        }
        Text('课程概览').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
        GridRow({ gutter: { x: 12, y: 10 } }) {
          ForEach(this.stats.courses, (course: CourseStat) => {
            GridCol({ span: { sm: 12, md: 6 } }) {
              Row() {
                Text(course.title).fontSize(Theme.F_BODY).fontColor(Theme.TEXT).layoutWeight(1).maxLines(1)
                Text(`${course.student_count} 人 · ${course.exam_count} 考`)
                  .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
              }
              .width('100%').padding(12)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_MD)
              .shadow(Theme.SHADOW_CARD)
            }
          }, (course: CourseStat) => course.title)
        }
        // ═══ 图表：高频错题 TOP（柱状图 + 图例说明，合并原重复列表）═══
        if (this.stats.top_wrong.length === 0) {
          Text('暂无错题数据').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).padding(12)
        } else {
          Card() {
            Column({ space: 14 }) {
              Row({ space: 8 }) {
                Text('🔥').fontSize(15)
                Text('高频错题 TOP').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                Blank()
                Text(`${this.stats.top_wrong.length} 题`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
              }.width('100%')
              BarChart({
                labels: this.statsWrongLabels(),
                values: this.statsWrongCounts(),
                unit: ' 次',
                colors: ['', '', '', Theme.WARNING, Theme.DANGER],
                chartHeight: 2000  // 需求 7：TOP10 条目多时不再被 maxHeight 裁切挤压造成重叠
              })
              if (this.expandWrongTop) {
                Divider().color(Theme.DIVIDER).margin({ top: 4, bottom: 4 })
                ForEach(this.stats.top_wrong, (item: WrongStat) => {
                  Row({ space: 10 }) {
                    Text('🔥').fontSize(13)
                    Text(item.text).fontSize(Theme.F_SUB).fontColor(Theme.TEXT).layoutWeight(1).maxLines(2)
                    TagChip({ text: `${item.count} 次`, tone: 'danger' })
                  }.width('100%').padding({ top: 6, bottom: 6 })
                }, (item: WrongStat) => item.text)
              }
              Button(this.expandWrongTop ? '收起题干 ▴' : '查看题干 ▾')
                .height(30).fontSize(Theme.F_CAP)
                .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
                .onClick((): void => { this.expandWrongTop = !this.expandWrongTop; })
            }.width('100%')
          }
        }
      }
      this.Toast()  // 学情 Tab 错误出口（需求 13：不再静默失败）
    }.width('100%').padding(20)
  }
  // ═══ 学情图表数据辅助 ═══
  /** 题型正确率条目（需求 13：真实判分数据）。 */
  private typeRateEntries(): SkillEntry[] {
    const out: SkillEntry[] = [];
    const st: LearningStats | null = this.stats;
    if (st !== null && st.type_rates !== undefined && st.type_rates !== null) {
      const rates: Record<string, number> = st.type_rates;
      const names: Record<string, string> = {
        'SINGLE': '单选', 'MULTI': '多选', 'JUDGE': '判断', 'BLANK': '填空', 'SHORT': '简答'
      };
      Object.keys(rates).forEach((key: string): void => {
        const label: string = names[key] ?? key;
        const val: number = rates[key];
        out.push({ name: label, value: Math.round(val) });
      });
    }
    return out;
  }
  private statsCourseLabels(): string[] {
    const list: string[] = [];
    if (this.stats !== null) {
      for (const c of this.stats.courses) { list.push(c.title); }
    }
    return list;
  }
  private statsCourseStudents(): number[] {
    const list: number[] = [];
    if (this.stats !== null) {
      for (const c of this.stats.courses) { list.push(c.student_count); }
    }
    return list;
  }
  private statsWrongLabels(): string[] {
    const list: string[] = [];
    if (this.stats !== null) {
      for (const w of this.stats.top_wrong) {
        const short: string = w.text.length > 10 ? `${w.text.substring(0, 10)}…` : w.text;
        list.push(`TOP${list.length + 1} ${short}`);
      }
    }
    return list;
  }
  private statsWrongCounts(): number[] {
    const list: number[] = [];
    if (this.stats !== null) {
      for (const w of this.stats.top_wrong) { list.push(w.count); }
    }
    return list;
  }
  private unreadCount(): number {
    let n = 0;
    for (const it of this.notifications) { if (!(it.is_read ?? 0)) { n++; } }
    return n;
  }
  private fmtDateTime(iso: string | null | undefined): string {
    if (iso === null || iso === undefined || iso.length < 16) { return iso ?? '—'; }
    const ms: number = Date.parse(iso.endsWith('Z') ? iso : `${iso}Z`);
    if (Number.isNaN(ms)) { return `${iso.substring(0, 10)} ${iso.substring(11, 16)}`; }
    const d: Date = new Date(ms);
    const p2 = (n: number): string => n < 10 ? `0${n}` : `${n}`;
    return `${p2(d.getMonth() + 1)}-${p2(d.getDate())} ${p2(d.getHours())}:${p2(d.getMinutes())}`;
  }
  private fmtScore(v: number): string {
    const rounded: number = Math.round(v * 10) / 10;
    return Number.isInteger(rounded) ? `${rounded}` : `${rounded.toFixed(1)}`;
  }
  private scoreColor(v: number): string {
    // 分数色阶：高匹配绿 / 中蓝 / 待提升橙
    if (v >= 75) { return Theme.SUCCESS; }
    if (v >= 60) { return Theme.PRIMARY; }
    return Theme.WARNING;
  }
  @Builder ReviewTab() {
    Column({ space: 14 }) {
      Text('审核工作台').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
      if (this.loading || this.pending === null) {
        SkeletonCard(); SkeletonCard()
      } else {
        Text('待审岗位').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
        if (this.pending.jobs.length === 0) {
          Text('暂无待审岗位').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).padding(12)
        } else {
          GridRow({ gutter: { x: 12, y: 12 } }) {
            ForEach(this.pending.jobs, (job: PendingJob) => {
              GridCol({ span: { sm: 12, md: 6, lg: 4 } }) {
                Column({ space: 8 }) {
                  Text(job.title).fontSize(Theme.F_BODY).fontWeight(FontWeight.Bold)
                    .fontColor(Theme.TEXT).width('100%').maxLines(1)
                  Text(job.company).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).width('100%').maxLines(1)
                  Row({ space: 8 }) {
                    Button('✓ 通过').height(34).fontSize(13).layoutWeight(1)
                      .linearGradient({ angle: 135, colors: [[Theme.SUCCESS, 0], ['#3ECF8E', 1]] })
                      .fontColor(Color.White)
                      .onClick((): void => { this.decideReview('JOB', job.id, 'APPROVE'); })
                    Button('✕ 驳回').height(34).fontSize(13).layoutWeight(1)
                      .backgroundColor(Theme.DANGER_LIGHT).fontColor(Theme.DANGER)
                      .onClick((): void => { this.decideReview('JOB', job.id, 'REJECT'); })
                  }.width('100%')
                }
                .width('100%').padding(14)
                .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
                .shadow(Theme.SHADOW_CARD)
              }
            }, (job: PendingJob) => String(job.id))
          }
        }
        Text('待审企业').fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT).width('100%').margin({ top: 8 })
        if (this.pending.companies.length === 0) {
          Text('暂无待审企业').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).padding(12)
        } else {
          GridRow({ gutter: { x: 12, y: 12 } }) {
            ForEach(this.pending.companies, (company: PendingCompany) => {
              GridCol({ span: { sm: 12, md: 6, lg: 4 } }) {
                Column({ space: 8 }) {
                  Text(company.name).fontSize(Theme.F_BODY).fontWeight(FontWeight.Bold)
                    .fontColor(Theme.TEXT).width('100%').maxLines(1)
                  Row({ space: 8 }) {
                    Button('✓ 通过').height(34).fontSize(13).layoutWeight(1)
                      .linearGradient({ angle: 135, colors: [[Theme.SUCCESS, 0], ['#3ECF8E', 1]] })
                      .fontColor(Color.White)
                      .onClick((): void => { this.decideReview('COMPANY', company.id, 'APPROVE'); })
                    Button('✕ 驳回').height(34).fontSize(13).layoutWeight(1)
                      .backgroundColor(Theme.DANGER_LIGHT).fontColor(Theme.DANGER)
                      .onClick((): void => { this.decideReview('COMPANY', company.id, 'REJECT'); })
                  }.width('100%')
                }
                .width('100%').padding(14)
                .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
                .shadow(Theme.SHADOW_CARD)
              }
            }, (company: PendingCompany) => String(company.id))
          }
        }
        // ═══ 举报讨论审核（被举报帖/回复重新入队）═══
        Text('举报讨论审核').fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT).width('100%').margin({ top: 8 })
        if (this.pending.posts.length === 0 && this.pending.replies.length === 0) {
          Text('暂无被举报内容').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).padding(12)
        } else {
          GridRow({ gutter: { x: 12, y: 12 } }) {
            ForEach(this.pending.posts, (post: PendingPost) => {
              GridCol({ span: { sm: 12, md: 6, lg: 4 } }) {
                Column({ space: 8 }) {
                  Row({ space: 6 }) {
                    Text('🚩').fontSize(14)
                      .scale({ x: this.livePulse, y: this.livePulse })
                      .animation({ curve: Curve.EaseInOut })
                    Text('帖子').fontSize(Theme.F_CAP).fontColor(Theme.DANGER)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .backgroundColor(Theme.DANGER_LIGHT).borderRadius(8)
                    Blank()
                    Text(`ID ${post.id}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  }.width('100%')
                  Text(post.title ?? '（无标题）').fontSize(Theme.F_BODY).fontWeight(FontWeight.Bold)
                    .fontColor(Theme.TEXT).width('100%').maxLines(1)
                  Text(post.content).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
                    .width('100%').maxLines(2)
                  Row({ space: 8 }) {
                    Button('✓ 恢复展示').height(34).fontSize(13).layoutWeight(1)
                      .linearGradient({ angle: 135, colors: [[Theme.SUCCESS, 0], ['#3ECF8E', 1]] })
                      .fontColor(Color.White)
                      .onClick((): void => { this.decideReview('POST', post.id, 'APPROVE'); })
                    Button('✕ 驳回下架').height(34).fontSize(13).layoutWeight(1)
                      .backgroundColor(Theme.DANGER_LIGHT).fontColor(Theme.DANGER)
                      .onClick((): void => { this.decideReview('POST', post.id, 'REJECT'); })
                  }.width('100%')
                }
                .width('100%').padding(14)
                .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
                .shadow(Theme.SHADOW_CARD)
              }
            }, (post: PendingPost) => `post-${post.id}`)
            ForEach(this.pending.replies, (reply: PendingReply) => {
              GridCol({ span: { sm: 12, md: 6, lg: 4 } }) {
                Column({ space: 8 }) {
                  Row({ space: 6 }) {
                    Text('🚩').fontSize(14)
                      .scale({ x: this.livePulse, y: this.livePulse })
                      .animation({ curve: Curve.EaseInOut })
                    Text('回复').fontSize(Theme.F_CAP).fontColor(Theme.WARNING)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .backgroundColor(Theme.WARNING_LIGHT).borderRadius(8)
                    Blank()
                    Text(`ID ${reply.id}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  }.width('100%')
                  Text(reply.content).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
                    .width('100%').maxLines(2)
                  Row({ space: 8 }) {
                    Button('✓ 恢复展示').height(34).fontSize(13).layoutWeight(1)
                      .linearGradient({ angle: 135, colors: [[Theme.SUCCESS, 0], ['#3ECF8E', 1]] })
                      .fontColor(Color.White)
                      .onClick((): void => { this.decideReview('REPLY', reply.id, 'APPROVE'); })
                    Button('✕ 驳回下架').height(34).fontSize(13).layoutWeight(1)
                      .backgroundColor(Theme.DANGER_LIGHT).fontColor(Theme.DANGER)
                      .onClick((): void => { this.decideReview('REPLY', reply.id, 'REJECT'); })
                  }.width('100%')
                }
                .width('100%').padding(14)
                .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
                .shadow(Theme.SHADOW_CARD)
              }
            }, (reply: PendingReply) => `reply-${reply.id}`)
          }
        }
        this.Toast()
      }
    }.width('100%').padding(20)
  }
  @Builder DashboardTab() {
    Column({ space: 14 }) {
      // ═══ 需求 12：管理员欢迎横幅（渐变美化）═══
      Column({ space: 8 }) {
        Row({ space: 10 }) {
          Text('🛡').fontSize(26)
          Column({ space: 2 }) {
            Text('管理员控制台').fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White)
            Text('平台运营与治理总览').fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.85)')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }.width('100%')
        if (this.dashboard !== null) {
          Row({ space: 14 }) {
            Text(`👤 用户 ${this.dashboard!.users}`).fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.9)')
            Text(`📚 课程 ${this.dashboard!.courses}`).fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.9)')
            Text(`⏳ 待审 ${this.dashboard!.pending_jobs}`).fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.9)')
          }.width('100%')
        }
      }
      .width('100%').padding(20)
      .linearGradient({ angle: 145, colors: [[Theme.PRIMARY_DEEP, 0], [Theme.PRIMARY_GRADIENT, 1]] })
      .borderRadius(Theme.R_XL)
      .shadow(Theme.SHADOW_FLOAT)

      // ═══ 需求 10：快捷管理入口 ═══
      Column({ space: 10 }) {
        Text('⚙️ 快捷管理').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
        GridRow({ gutter: { x: 10, y: 10 } }) {
          GridCol({ span: 6 }) { this.AdminEntry('👥', '用户管理', 'pages/UserManage') }
          GridCol({ span: 6 }) { this.AdminEntry('🏢', '企业管理', 'pages/CompanyManage') }
          GridCol({ span: 6 }) { this.AdminEntry('📢', '发布通知', 'pages/NotificationPublish') }
          GridCol({ span: 6 }) { this.AdminEntry('📜', '审计日志', 'pages/AuditLogs') }
          GridCol({ span: 6 }) { this.AdminEntry('🔧', '系统配置', 'pages/ConfigManage') }
          GridCol({ span: 6 }) { this.AdminEntry('🔤', '敏感词库', 'pages/ConfigManage') }
          GridCol({ span: 6 }) { this.AdminEntry('📮', '反馈中心', 'pages/FeedbackManage') }
        }.width('100%')
      }.width('100%')

      Text('平台指标').fontSize(17).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
      if (this.loading || this.dashboard === null) {
        SkeletonCard(); SkeletonCard()
      } else {
        GridRow({ gutter: { x: 12, y: 12 } }) {
          GridCol({ span: 6 }) { this.MetricCard('👥', '用户', `${this.dashboard!.users}`) }
          GridCol({ span: 6 }) { this.MetricCard('📚', '课程', `${this.dashboard!.courses}`) }
          GridCol({ span: 6 }) { this.MetricCard('📝', '考试', `${this.dashboard!.exams}`) }
          GridCol({ span: 6 }) { this.MetricCard('💼', '岗位', `${this.dashboard!.jobs}`) }
          GridCol({ span: 6 }) { this.MetricCard('⏳', '待审岗位', `${this.dashboard!.pending_jobs}`) }
          GridCol({ span: 6 }) { this.MetricCard('📨', '投递', `${this.dashboard!.applications}`) }
        }
        .width('100%')
        .opacity(this.dashOpacity)
        .translate({ y: (1 - this.dashOpacity) * 30 })
        // ═══ 图表：平台内容分布（环形图）═══
        Card() {
          Column({ space: 14 }) {
            Row({ space: 8 }) {
              Text('🍩').fontSize(15)
              Text('平台内容分布').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
            }.width('100%')
            DonutChart({
              labels: ['课程', '考试', '岗位', '投递'],
              values: [
                this.dashboard!.courses,
                this.dashboard!.exams,
                this.dashboard!.jobs,
                this.dashboard!.applications
              ],
              colors: [Theme.PRIMARY, Theme.PRIMARY_GRADIENT, Theme.SUCCESS, Theme.WARNING],
              centerLabel: '内容总量'
            })
          }.width('100%')
        }
        // ═══ 图表：各项数量对比（柱状图）═══
        Card() {
          Column({ space: 14 }) {
            Row({ space: 8 }) {
              Text('📊').fontSize(15)
              Text('平台资源对比').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
            }.width('100%')
            BarChart({
              labels: ['用户', '课程', '考试', '岗位', '投递'],
              values: [
                this.dashboard!.users,
                this.dashboard!.courses,
                this.dashboard!.exams,
                this.dashboard!.jobs,
                this.dashboard!.applications
              ],
              unit: ''
            })
          }.width('100%')
        }
        // ═══ 图表：近 7 日活跃趋势（折线）═══
        if (this.statTrend !== null && this.statTrend!.labels.length > 0) {
          Card() {
            Column({ space: 14 }) {
              Row({ space: 8 }) {
                Text('📈').fontSize(15)
                Text('近 7 日活跃用户趋势').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                Blank()
                Text('DAU').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(8)
              }.width('100%')
              TrendChart({
                labels: this.statTrend!.labels,
                values: this.statTrend!.values,
                chartHeight: 170,
                lineColor: Theme.PRIMARY
              })
            }.width('100%')
          }
        }
        // ═══ 图表：投递漏斗 ═══
        if (this.statFunnel !== null && this.statFunnel!.labels.length > 0) {
          Card() {
            Column({ space: 14 }) {
              Row({ space: 8 }) {
                Text('🔻').fontSize(15)
                Text('投递转化漏斗').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
              }.width('100%')
              BarChart({
                labels: this.statFunnel!.labels,
                values: this.statFunnel!.values,
                unit: ''
              })
            }.width('100%')
          }
        }
        PrimaryButton({ label: '🔄 刷新数据', onTap: (): void => { this.loadData(); } })
      }
    }.width('100%').padding(20)
  }
  @Builder MetricCard(icon: string, label: string, value: string) {
    Column({ space: 4 }) {
      Text(icon).fontSize(22)
      Text(value).fontSize(26).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
      Text(label).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
    }
    .width('100%').padding(16)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
    .alignItems(HorizontalAlign.Start)
  }
  @Builder MessageView() {
    Column({ space: 12 }) {
      Row() {
        Row({ space: 8 }) {
          Text('消息中心').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
          if (this.unreadCount() > 0) {
            Text(`${this.unreadCount()}`).fontSize(11).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .padding({ left: 7, right: 7, top: 2, bottom: 2 }).borderRadius(10)
              .linearGradient({ angle: 135, colors: [[Theme.DANGER, 0], ['#FF6B9D', 1]] })
          }
        }.layoutWeight(1)
        if (this.role === 'TEACHER' || this.role === 'ADMIN') {
          Button('📢 发布通知').height(34).fontSize(13)
            .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
            .fontColor(Color.White)
            .onClick((): void => { router.pushUrl({ url: 'pages/NotificationPublish' }); })
        }
      }.width('100%')
      // ═══ 好友/师生申请（需求 7/9：申请信息展示在消息中）═══
      if (!this.loading && this.incomingRequests.length > 0) {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Text('🤝').fontSize(16)
            Text(`联系人申请（${this.incomingRequests.length}）`)
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).layoutWeight(1)
            Text('去处理 ›').fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
              .onClick((): void => { router.pushUrl({ url: 'pages/Contacts' }); })
          }.width('100%')
          ForEach(this.incomingRequests, (req: ContactRequestItem) => {
            Row({ space: 10 }) {
              Column() {
                Text((req.requester.real_name.length > 0 ? req.requester.real_name : req.requester.username)
                  .substring(0, 1).toUpperCase())
                  .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
              }.width(38).height(38).borderRadius(19)
              .backgroundColor(Theme.PRIMARY_LIGHT)
              Column({ space: 2 }) {
                Text(req.requester.real_name.length > 0 ? req.requester.real_name : req.requester.username)
                  .fontSize(Theme.F_SUB).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
                Text(`请求添加你为${req.rel_type === 'TEACHER' ? '学生' : '好友'} · ${req.requester.user_code}`)
                  .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Button('同意').height(30).fontSize(12)
                .backgroundColor(Theme.SUCCESS_LIGHT).fontColor(Theme.SUCCESS)
                .borderRadius(Theme.R_SM)
                .onClick((): void => { this.handleIncomingRequest(req, true); })
              Button('拒绝').height(30).fontSize(12)
                .backgroundColor(Theme.INPUT_BG).fontColor(Theme.TEXT_SECOND)
                .borderRadius(Theme.R_SM)
                .onClick((): void => { this.handleIncomingRequest(req, false); })
            }
            .width('100%').padding(12)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
            .shadow(Theme.SHADOW_CARD)
          }, (req: ContactRequestItem) => `${req.requester.id}-${req.rel_type}`)
        }.width('100%')
      }
      if (this.loading) {
        SkeletonCard(); SkeletonCard()
      } else if (this.notifications.length === 0) {
        EmptyState({ icon: '🔔', text: '暂无消息通知' })
      } else {
        GridRow({ gutter: { x: 12, y: 12 } }) {
          ForEach(this.notifications, (item: NotificationItem) => {
            GridCol({ span: { sm: 12, md: 6 } }) {
              Column({ space: 8 }) {
                Row({ space: 12 }) {
                  Column() {
                    Text('📢').fontSize(18)
                    if (!(item.is_read ?? 0)) {
                      Circle().width(8).height(8).fill(Theme.DANGER)
                        .position({ x: 27, y: 2 })
                        .scale({ x: this.mineAnim, y: this.mineAnim })
                        .opacity(this.mineAnim)
                    }
                  }
                  .width(40).height(40).borderRadius(20)
                  .backgroundColor(Theme.PRIMARY_LIGHT)
                  .alignItems(HorizontalAlign.Center)
                  Column({ space: 3 }) {
                    Row({ space: 6 }) {
                      Text(item.title).fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
                        .maxLines(1).layoutWeight(1)
                      if (!(item.is_read ?? 0)) {
                        Text('NEW').fontSize(Theme.F_CAP).fontWeight(FontWeight.Bold).fontColor(Color.White)
                          .padding({ left: 5, right: 5, top: 1, bottom: 1 }).borderRadius(4)
                          .linearGradient({ angle: 135, colors: [[Theme.DANGER, 0], ['#FF6B9D', 1]] })
                      }
                    }.width('100%')
                    if (item.content !== null && item.content !== undefined) {
                      Text(item.content).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).maxLines(2)
                    }
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  TagChip({ text: this.typeName(item.type) })
                }.width('100%')
                Row({ space: 4 }) {
                  Text('查看详情').fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                  Text('›').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
                }.width('100%').justifyContent(FlexAlign.End)
              }
              .width('100%').padding(14)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
              // 点击消息卡片查看完整内容
              .onClick((): void => {
                if (!(item.is_read ?? 0)) {
                  // 数组整体替换触发 UI 更新（对象属性直改不会刷新）
                  const updated: NotificationItem[] = this.notifications.map((n: NotificationItem): NotificationItem => {
                    return n.id === item.id ? { id: n.id, type: n.type, title: n.title, content: n.content, created_at: n.created_at, is_read: 1 } : n;
                  });
                  this.notifications = updated;
                  api.markNotificationRead(item.id).catch((): void => {});
                }
                router.pushUrl({
                  url: 'pages/NotificationDetail',
                  params: {
                    type: item.type,
                    title: item.title,
                    content: item.content ?? '',
                    created_at: item.created_at
                  }
                });
              })
            }
          }, (item: NotificationItem) => `${item.id}-${item.is_read ?? 0}`)
        }
      }
    }.width('100%').padding(20)
  }
  @Builder MineView() {
    Column({ space: 14 }) {
      Column({ space: 12 }) {
        Row({ space: 14 }) {
          Stack() {
            if (this.avatarUrl.startsWith('http://') || this.avatarUrl.startsWith('https://')) {
              Image(this.avatarUrl).width(64).height(64).borderRadius(32)
                .objectFit(ImageFit.Cover)
            } else {
              Column() {
                Text(this.username.length > 0 ? this.username.substring(0, 1).toUpperCase() : '?')
                  .fontSize(26).fontWeight(FontWeight.Bold).fontColor(Color.White)
              }
              .width(64).height(64).borderRadius(32)
              .backgroundColor('rgba(255,255,255,0.25)')
            }
          }
          .width(64).height(64)
          Column({ space: 4 }) {
            Text(this.username).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
            if (this.userId.length > 0) {
              Text(`ID: ${this.userId}`).fontSize(Theme.F_CAP)
                .fontColor('rgba(255,255,255,0.7)').letterSpacing(1)
            }
            Text(`${this.roleLabel()}`).fontSize(Theme.F_SUB)
              .fontColor('rgba(255,255,255,0.8)')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button('编辑').height(32).fontSize(12)
            .backgroundColor('rgba(255,255,255,0.2)').fontColor(Color.White)
            .borderRadius(Theme.R_SM)
            .onClick((): void => { router.pushUrl({ url: 'pages/ProfileEdit' }); })
        }.width('100%')
        if (this.role === 'STUDENT' && this.profile !== null) {
          // 能力画像改为独立页跳转（需求 1）：卡片摘要 + 查看完整画像
          Row({ space: 12 }) {
            Column({ space: 2 }) {
              Text('能力画像').fontSize(Theme.F_SUB).fontColor('rgba(255,255,255,0.85)')
              Text(`综合 ${this.abilityAvg()}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Row({ space: 4 }) {
              ForEach(this.skillEntries().slice(0, 3), (entry: SkillEntry) => {
                Text(entry.name.length > 4 ? `${entry.name.substring(0, 4)}…` : entry.name)
                  .fontSize(Theme.F_CAP).fontColor(Color.White)
                  .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                  .backgroundColor('rgba(255,255,255,0.18)').borderRadius(8)
                  .margin({ right: 4 })
              }, (e: SkillEntry) => e.name)
            }
            Text('查看完整画像 ›').fontSize(Theme.F_CAP).fontColor(Color.White)
          }
          .width('100%').padding({ top: 10, bottom: 10, left: 14, right: 14 })
          .backgroundColor('rgba(255,255,255,0.15)').borderRadius(Theme.R_MD)
          .onClick((): void => { router.pushUrl({ url: 'pages/AbilityProfile' }); })
        }
      }
      .width('100%').padding(22)
      .linearGradient({ angle: 150, colors: [[Theme.PRIMARY_DEEP, 0], [Theme.PRIMARY_GRADIENT, 1]] })
      .borderRadius(Theme.R_XL)
      .shadow(Theme.SHADOW_FLOAT)
      GridRow({ gutter: { x: 12, y: 12 } }) {
        GridCol({ span: { sm: 12, md: 6 } }) { this.MineEntry('📅', '我的课程', 'pages/MyCourses') }
        GridCol({ span: { sm: 12, md: 6 } }) {
          Row({ space: 0 }) {
            this.MineEntry('👥', '我的好友', 'pages/Contacts')
            if (this.chatUnreadTotal() > 0) {
              Text(this.chatUnreadTotal() > 99 ? '99+' : String(this.chatUnreadTotal()))
                .fontSize(Theme.F_CAP).fontColor(Color.White).fontWeight(FontWeight.Bold)
                .padding({ left: 5, right: 5 }).constraintSize({ minWidth: 16 }).height(16)
                .textAlign(TextAlign.Center).borderRadius(8).backgroundColor(Theme.DANGER)
                .position({ x: 6, y: -6 })
            }
          }.width('100%').alignItems(VerticalAlign.Top)
        }
        GridCol({ span: { sm: 12, md: 6 } }) {
          Row({ space: 14 }) {
            Text(this.role === 'TEACHER' ? '🧑‍🎓' : '👩‍🏫').fontSize(18).width(40).height(40)
              .textAlign(TextAlign.Center)
              .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_SM)
            // 需求 4：教师端显示「我的学生」（师生关系双向），学生端仍为「我的老师」
            Text(this.role === 'TEACHER' ? '我的学生' : '我的老师')
              .fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium)
              .fontColor(Theme.TEXT).layoutWeight(1)
            Text('›').fontSize(18).fontColor(Theme.TEXT_HINT)
          }
          .width('100%').padding({ top: 14, bottom: 14, left: 16, right: 16 })
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)
          .onClick((): void => { router.pushUrl({ url: 'pages/Contacts', params: { mode: 'teacher' } }); })
        }
        if (this.role === 'STUDENT') {
          GridCol({ span: { sm: 12, md: 6 } }) { this.MineEntry('✅', '我要签到', 'pages/StudentCheckin') }
          GridCol({ span: { sm: 12, md: 6 } }) { this.MineEntry('📂', '学习资料', 'pages/ResourceList') }
          GridCol({ span: { sm: 12, md: 6 } }) { this.MineEntry('📕', '错题本', 'pages/WrongBook') }
          GridCol({ span: { sm: 12, md: 6 } }) { this.MineEntry('📄', '简历编辑', 'pages/ResumeEdit') }
          GridCol({ span: { sm: 12, md: 6 } }) { this.MineEntry('📨', '投递记录', 'pages/Applications') }
          GridCol({ span: { sm: 12, md: 6 } }) { this.MineEntry('🎪', '招聘活动', 'pages/CareerEvent') }
          GridCol({ span: { sm: 12, md: 6 } }) { this.MineEntry('📋', '作业列表', 'pages/AssignmentList') }
          GridCol({ span: { sm: 12, md: 6 } }) { this.MineEntry('📝', '笔记', 'pages/Notes') }
          GridCol({ span: { sm: 12, md: 6 } }) { this.MineEntry('📅', '学习计划', 'pages/StudyPlan') }
        }
        GridCol({ span: { sm: 12, md: 6 } }) { this.MineEntry('⚙️', '设置', 'pages/Settings') }
      }
      Button('退出登录')
        .width('100%').height(48).fontSize(15)
        .fontColor(Theme.DANGER).backgroundColor(Theme.DANGER_LIGHT)
        .borderRadius(Theme.R_MD).margin({ bottom: 24 })
        .onClick((): void => { this.logout(); })
    }.width('100%').padding(20)
  }
  @Builder MineEntry(icon: string, label: string, page: string) {
    Row({ space: 14 }) {
      Text(icon).fontSize(18).width(40).height(40)
        .textAlign(TextAlign.Center)
        .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_SM)
      Text(label).fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT).layoutWeight(1)
      Text('›').fontSize(18).fontColor(Theme.TEXT_HINT)
    }
    .width('100%').padding({ top: 14, bottom: 14, left: 16, right: 16 })
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
    .onClick((): void => { router.pushUrl({ url: page }); })
  }
  @Builder TabBadge(label: string) {
    Stack({ alignContent: Alignment.Center }) {
      // 与普通 tabBar 纯文本完全一致的结构（需求 3/5：保证与其他 Tab 文字同行同基线）
      Text(label).fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium)
      if (this.unreadCount() > 0) {
        Text(this.unreadCount() > 99 ? '99+' : String(this.unreadCount()))
          .fontSize(Theme.F_CAP).fontColor(Color.White).fontWeight(FontWeight.Bold)
          .padding({ left: 5, right: 5 })
          .constraintSize({ minWidth: 16 })
          .textAlign(TextAlign.Center)
          .height(16)
          .borderRadius(8)
          .backgroundColor(Theme.DANGER)
          .shadow({ radius: 4, color: 'rgba(255,77,79,0.4)', offsetX: 0, offsetY: 1 })
          // 徽标悬浮在文字右上角（不占布局空间，不影响行高对齐）
          .markAnchor({ x: '50%', y: '50%' })
          .position({ x: '78%', y: '6%' })
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
  @Builder StudentTabs() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() { Scroll() { this.CourseListTab() }.scrollBar(BarState.Off).layoutWeight(1) }.tabBar('📚 学习')
      TabContent() { Scroll() { this.ExamListTab() }.scrollBar(BarState.Off).layoutWeight(1) }.tabBar('📝 考试')
      TabContent() { Scroll() { this.JobTab() }.scrollBar(BarState.Off).layoutWeight(1) }.tabBar('💼 就业')
      TabContent() { Scroll() { this.MessageView() }.scrollBar(BarState.Off).layoutWeight(1) }
        .tabBar(this.TabBadge('🔔 消息'))
      TabContent() { Scroll() { this.MineView() }.scrollBar(BarState.Off).layoutWeight(1) }.tabBar('👤 我的')
    }
    .barHeight(58)
    .barMode(BarMode.Fixed)
    .vertical(false)
    .scrollable(true)
    .animationDuration(260)
    .onChange((index: number): void => {
      // 切到消息 Tab 时自动清除已读计数之外的缓存态（通知列表保持，仅视觉反馈）
      if (index === 3) { this.message = ''; }
    })
    .width('100%').layoutWeight(1)
  }
  @Builder TeacherTabs() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() { Scroll() { this.CourseListTab() }.scrollBar(BarState.Off).layoutWeight(1) }.tabBar('📚 授课')
      TabContent() { Scroll() { this.QuestionBankTab() }.scrollBar(BarState.Off).layoutWeight(1) }.tabBar('❓ 题库')
      TabContent() { Scroll() { this.AnalyticsTab() }.scrollBar(BarState.Off).layoutWeight(1) }.tabBar('📊 学情')
      TabContent() { Scroll() { this.MessageView() }.scrollBar(BarState.Off).layoutWeight(1) }
        .tabBar(this.TabBadge('📢 通知'))
      TabContent() { Scroll() { this.MineView() }.scrollBar(BarState.Off).layoutWeight(1) }.tabBar('👤 我的')
    }
    .barHeight(58)
    .barMode(BarMode.Fixed)
    .vertical(false)
    .scrollable(true)
    .animationDuration(260)
    .width('100%').layoutWeight(1)
  }
  @Builder AdminSettingsTab() {
    Column({ space: 12 }) {
      Text('系统管理').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
      Text('敏感词库').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
      Row({ space: 8 }) {
        TextInput({ placeholder: '新敏感词', text: this.newSensitiveWord })
          .onChange((v: string): void => { this.newSensitiveWord = v; })
          .layoutWeight(1).height(42).fontSize(13)
          .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
        Button('添加').height(42).fontSize(13)
          .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
          .fontColor(Color.White).borderRadius(Theme.R_MD)
          .onClick((): void => { this.addSensitiveWordAdmin(); })
      }.width('100%')
      if (this.sensitiveWords.length === 0) {
        Text('暂无敏感词').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.sensitiveWords, (word: SensitiveWordItem) => {
            Row({ space: 6 }) {
              Text(word.word).fontSize(Theme.F_SUB).fontColor(Theme.TEXT)
              Text('×').fontSize(12).fontColor(Theme.DANGER)
                .onClick((): void => { this.deleteSensitiveWordAdmin(word.id); })
            }
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(Theme.BG).borderRadius(16)
            .margin({ right: 8, bottom: 8 })
          })
        }.width('100%')
      }
      Text('系统入口').fontSize(15).fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT).width('100%').margin({ top: 8 })
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        this.AdminEntry('👥', '用户管理', 'pages/UserManage')
        this.AdminEntry('🏢', '企业管理', 'pages/CompanyManage')
        this.AdminEntry('📚', '课程管理', 'pages/CourseManage')
        this.AdminEntry('📝', '考试管理', 'pages/ExamManage')
        this.AdminEntry('🏷', '技能标签', 'pages/SkillTagManage')
        this.AdminEntry('🔧', '系统配置', 'pages/ConfigManage')
        this.AdminEntry('📊', '数据大屏', 'pages/DataDashboard')
        this.AdminEntry('📜', '操作日志', 'pages/AuditLogs')
        this.AdminEntry('📮', '反馈中心', 'pages/FeedbackManage')
      }.width('100%')
      this.Toast()
    }.width('100%').padding(20)
  }
  @Builder AdminEntry(icon: string, label: string, page: string) {
    Column({ space: 6 }) {
      Text(icon).fontSize(22)
      Text(label).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
    }
    .width(this.bp === 'sm' ? '23%' : '31%')
    .padding({ top: 14, bottom: 14 })
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_MD)
    .shadow(Theme.SHADOW_CARD)
    .onClick((): void => { router.pushUrl({ url: page }); })
  }
  @Builder AdminTabs() {
    Tabs({ barPosition: BarPosition.End }) {
      // 需求 11：原「工作台」与「数据」内容完全一致，删除重复项
      TabContent() { Scroll() { this.DashboardTab() }.scrollBar(BarState.Off).layoutWeight(1) }.tabBar('📊 数据看板')
      TabContent() { Scroll() { this.ReviewTab() }.scrollBar(BarState.Off).layoutWeight(1) }.tabBar('✅ 审核')
      TabContent() { Scroll() { this.AdminSettingsTab() }.scrollBar(BarState.Off).layoutWeight(1) }.tabBar('⚙️ 设置')
    }
    .barHeight(56)
    .width('100%').layoutWeight(1)
  }
  build() {
    Column() {
      this.TopBar()
      if (this.role === 'STUDENT') {
        this.StudentTabs()
      } else if (this.role === 'TEACHER') {
        this.TeacherTabs()
      } else {
        this.AdminTabs()
      }
    }
    .width('100%').height('100%')
    .backgroundColor(Theme.BG)
  }
}