export interface User {
  id: number;
  username: string;
  role: string;
}

export interface LoginResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  pwd_changed: number;
  user: User;
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface RegisterRequest {
  username: string;
  password: string;
  real_name: string;
  role: string;
}

export interface Course {
  id: number;
  title: string;
  description: string;
  teacher: string;
  teacher_id?: number;
  semester?: string;
  student_count?: number;
  skill_tags?: string[];
  start_date?: string;
  end_date?: string;
  class_time?: string;
  location?: string;
  exam_time?: string;
  chapters: string[];
}

export interface SectionDetail {
  id: number;
  title: string;
  content: string;
  video_url: string | null;
  duration_minutes: number;
  position: number;
  type: string;
}

export interface ChapterDetail {
  id: number;
  title: string;
  description: string;
  position: number;
  sections: SectionDetail[];
}

export interface CourseDetail {
  id: number;
  title: string;
  description: string;
  teacher: string;
  chapters: ChapterDetail[];
}

export interface UserImportItem {
  username: string;
  real_name: string;
  role: string;
  password?: string;
}

export interface ImportReport {
  success: number;
  failed: number;
  success_list: string[];
  failed_list: ImportFailedItem[];
}

export interface ImportFailedItem {
  username: string;
  reason: string;
}

export interface Resume {
  id: number;
  title: string;
  content: Record<string, string>;
  version: number;
  is_default: number;
}

export interface ResumeContent {
  name: string;
  education: string;
  skills: string;
  projects: string;
  self_eval: string;
}

export interface ResumeSuggestion {
  original: string;
  suggestion: string;
  reason: string;
  type: string;
}

export interface ResumeOptimizeResult {
  items: ResumeSuggestion[];
  source: string;
}

export interface ApplicationItem {
  id: number;
  job_id: number;
  status: string;
  applied_at: string;
}

export interface AuditLogItem {
  id: number;
  user_id: number | null;
  action: string;
  target_type: string | null;
  target_id: number | null;
  created_at: string;
}

export interface WrongAnalysis {
  cause_category: string;
  analysis: string;
  suggestions: string[];
  knowledge_points: string[];
  source: string;
  log_id?: number;
}

export interface CompanyItem {
  id: number;
  name: string;
  industry: string | null;
  scale: string | null;
  intro: string | null;
  verify_status: number;
}

export interface MonitorRecord {
  record_id: number;
  student_id: number;
  username: string;
  real_name: string;
  status: string;
  switch_count: number;
  score: number | null;
  total: number | null;
}

export interface RecordAnswer {
  answer_id: number;
  question_id: number;
  type: string;
  text: string;
  answer: string | string[];
  is_correct: number | null;
  score: number | null;
  teacher_comment: string | null;
}

export interface Progress {
  id?: number;
  user_id?: number;
  course_id: number;
  percent: number;
  chapter_id?: number;
}

export interface ExamQuestion {
  id: number;
  type: string;
  text: string;
  score: number;
  options?: string[];
}

export interface Exam {
  id: number;
  title: string;
  questions: ExamQuestion[];
}

export interface Answer {
  question_id: number;
  answer: string | string[];
}

export interface ExamSessionAnswer {
  question_id: number;
  answer: string | string[];
}

export interface ExamReviewItem {
  question_id: number;
  type: string;
  text: string;
  options: string[];
  my_answer: string;
  correct_answer: string;
  earned: number | null;
  score: number;
  analysis: string;
}

export interface ExamSession {
  record_id: number;
  exam_id: number;
  status: string;
  deadline_at: string;
  answers: ExamSessionAnswer[];
  score?: number;
  total?: number;
  passed?: boolean;
  review?: ExamReviewItem[];
}

export interface ExamResult {
  exam_id: number;
  score: number;
  total: number;
  passed: boolean;
}

export interface ExamSummary {
  id: number;
  title: string;
  status: number;
  duration_min: number;
  course_id?: number | null;
  start_time?: string | null;
  end_time?: string | null;
  phase?: string;
}

export interface Job {
  id: number;
  title: string;
  company: string;
  description: string;
  required_skills: string[];
  match_score: number;
  matched_tags: string[];
  gap_tags: string[];
  skill_scores?: Record<string, number>;
  gap_courses?: string[];
  is_favorite: boolean;
  application_status: string | null;
}

export interface CareerEventItem {
  id: number;
  title: string;
  event_type: string;         // TALK 宣讲会 / FAIR 双选会 / INTERNSHIP 实习实践
  company: string;
  description: string | null;
  location: string | null;
  start_time: string;
  end_time: string;
  signup_count: number;
  signed_up: boolean;
  is_ended: boolean;
}

export interface CareerEventSignupResult {
  event_id: number;
  signed_up: boolean;
  first_time: boolean;
}

export interface NotificationItem {
  id: number;
  type: string;
  title: string;
  content: string | null;
  created_at: string;
  is_read?: number;
}

export interface UnreadCount {
  unread: number;
}

// ═══ 反馈中心（需求 18）═══
export interface FeedbackItem {
  id: number;
  user_id: number;
  username: string;
  real_name: string;
  role: string;
  category: string;
  category_label: string;
  title: string;
  content: string;
  contact: string | null;
  status: string;
  status_label: string;
  reply: string | null;
  handled_by: number | null;
  handler_name: string | null;
  handled_at: string | null;
  created_at: string;
}

export interface FeedbackSubmitResult {
  id: number;
  message: string;
}

export interface FeedbackStats {
  total: number;
  pending: number;
  processing: number;
  resolved: number;
  rejected: number;
}

export interface AdminFeedbackPage {
  total: number;
  page: number;
  page_size: number;
  items: FeedbackItem[];
}

export interface Profile {
  user_id: number;
  skill_scores: Record<string, number>;
  radar_data: Record<string, number>;
  self_tags: string[];
  match_version: number;
}

export interface UserProfile {
  id: number;
  username: string;
  user_code: string;
  real_name: string;
  role: string;
  avatar: string;
  signature: string;
  email: string;
  phone: string;
  major?: string;
  class_name?: string;
  grade?: string;
  department?: string;
  title?: string;
}

export interface WrongQuestion {
  id: number;
  question_id: number;
  question_type: string | null;
  question_text: string;
  correct_answer: string;
  analysis: string | null;
  my_answer: string | string[] | null;
  source_type: string | null;
  wrong_count: number;
  is_mastered: number;
}

export interface QuestionItem {
  id: number;
  type: string;
  content: string;
  options: string[];
  answer: string;
  analysis: string;
  difficulty: number;
  score: number;
  kp_ids: number[];
  course_id: number | null;
  source: string;
  status: string;
}

export interface QuestionPage {
  items: QuestionItem[];
  total: number;
  page: number;
  page_size: number;
  pages: number;
}

export interface ResourceItem {
  id: number;
  file_name: string;
  file_type: string;
  file_size: number | null;
  oss_key: string | null;
  duration: number | null;
  download_url: string;
  is_local: boolean;
  course_id?: number | null;
}

export interface ResourcePage {
  items: ResourceItem[];
  total: number;
  page: number;
  page_size: number;
}

export interface LearningStats {
  courses: CourseStat[];
  top_wrong: WrongStat[];
  exams: ExamStat[];
  overall_avg_score?: number | null;
  type_rates?: Record<string, number>;
}

export interface CourseStat {
  id: number;
  title: string;
  teacher: string;
  student_count: number;
  exam_count: number;
}

export interface WrongStat {
  question_id: number;
  text: string;
  count: number;
}

export interface ExamStat {
  id: number;
  title: string;
  records: number;
  avg_score?: number | null;
  avg_raw?: number | null;
  graded?: number;
}

export interface Dashboard {
  users: number;
  courses: number;
  exams: number;
  jobs: number;
  pending_jobs: number;
  applications: number;
}

export interface StatTrend {
  labels: string[];
  values: number[];
  metric: string;
}

export interface StatFunnel {
  labels: string[];
  values: number[];
}

export interface PendingJob {
  id: number;
  title: string;
  company: string;
  description: string;
}

export interface PendingCompany {
  id: number;
  name: string;
  industry: string | null;
  intro: string | null;
}

export interface PendingReviews {
  jobs: PendingJob[];
  companies: PendingCompany[];
  posts: PendingPost[];
  replies: PendingReply[];
}

export interface PendingPost {
  id: number;
  course_id: number;
  title: string | null;
  content: string;
  user_id: number;
}

export interface PendingReply {
  id: number;
  post_id: number;
  content: string;
  user_id: number;
}

export interface DiscussionPost {
  id: number;
  course_id: number;
  user_id: number;
  title: string | null;
  content: string;
  is_pinned: number;
  like_count: number;
  liked_by_me?: boolean;
  created_at: string;
  author?: DiscussionAuthor | null;   // 需求 6：讨论区显示用户 id/用户名
  reply_count?: number;
}

export interface LikeResult {
  id: number;
  like_count: number;
  liked_by_me: boolean;
  first_time: boolean;
}

export interface SignTask {
  id: number;
  course_id: number;
  qrcode_token: string;
  expire_at: string;
  code?: string;
  remaining_seconds?: number;
  window_seconds?: number;
}

export interface SignAttendanceStudent {
  user_id: number;
  username: string;
  real_name: string;
  signed: boolean;
  sign_at: string | null;
}

export interface SignAttendanceResult {
  task_id: number;
  course_id: number;
  code: string;
  remaining_seconds: number;
  expired: boolean;
  total: number;
  signed: number;
  unsigned: number;
  students: SignAttendanceStudent[];
}

export interface SignLatest {
  id: number;
  course_id: number;
  expire_at: string;
  remaining_seconds: number;
  expired: boolean;
}

export interface SignRecordItem {
  id: number;
  user_id: number;
  username: string;
  real_name: string;
  sign_at: string;
  is_valid: number;
}

export interface AiJobExplain {
  explanation: string;
  suggestions: string[];
  match_score: number;
  source?: string;
}

export interface AiSummary {
  summary: string;
  key_points: string[];
}

export interface AiPlan {
  plan: AiPlanDay[];
}

export interface AiPlanDay {
  date: string;
  tasks: AiPlanTask[];
}

export interface AiPlanTask {
  kp: string;
  minutes: number;
}

export interface AiInterview {
  question: string;
  feedback?: string;
  next_question?: string | null;
  done?: boolean;
}

export interface AiDraftQuestion {
  id: number;
  type: string;
  content: string;
  answer: string;
  difficulty: number;
  status: string;
  kp_ids: number[];
}

export interface AssignmentItem {
  id: number;
  course_id: number;
  title: string;
  description: string | null;
  max_score: number;
  deadline: string;
  is_expired: boolean;
  my_submission: AssignmentSubmissionItem | null;
}

export interface AssignmentSubmissionItem {
  id: number;
  status: string;
  score: number | null;
  feedback: string | null;
  is_late: number;
  submitted_at: string;
  content?: string | null;
}

export interface AssignmentSubmissionList {
  id: number;
  student_id: number;
  username: string;
  real_name: string;
  content: string | null;
  is_late: number;
  score: number | null;
  feedback: string | null;
  status: string;
  submitted_at: string;
}

export interface SensitiveWordItem {
  id: number;
  word: string;
  level: number;
}

export interface ConfigItem {
  cfg_key: string;
  cfg_value: string;
  remark: string | null;
}

export interface SkillTagItem {
  id: number;
  name: string;
  category: string | null;
}

export interface AdminUserItem {
  id: number;
  username: string;
  real_name: string;
  role: string;
  status: number;
}

// ═══════════════ 联系人域（好友/我的老师/私聊）═══════════════

export interface ContactUser {
  id: number;
  username: string;
  real_name: string;
  role: string;
  user_code: string;
  avatar: string;
}

export interface ContactItem {
  user: ContactUser;
  remark: string | null;
  display_name: string;
  last_message: string;
  last_at: string | null;
  unread: number;
}

export interface ContactRequestItem {
  requester: ContactUser;
  rel_type: string;      // FRIEND / TEACHER
  created_at: string;
}

export interface ChatMsg {
  id: number;
  sender_id: number;
  receiver_id: number;
  content: string;
  is_read: number;
  created_at: string;
}

export interface ManagedSection {
  id: number;
  chapter_id: number;
  title: string;
  type: string;          // TEXT | VIDEO | QUIZ
  content: string;
  video_url: string;
  duration_minutes: number;
  duration_sec: number;
  position: number;
  status: number;
}

export interface ManagedChapter {
  id: number;
  course_id: number;
  title: string;
  description: string;
  position: number;
  sections: ManagedSection[];
}

export interface DiscussionAuthor {
  id: number;
  username: string;
  real_name: string;
  user_code: string;
  role: string;
}

export interface DiscussionReplyItem {
  id: number;
  post_id: number;
  user_id: number;
  author: DiscussionAuthor | null;
  content: string;
  reply_to_id: number | null;
  like_count: number;
  liked_by_me: boolean;
  created_at: string;
}

export interface DiscussionDetail {
  id: number;
  course_id: number;
  user_id: number;
  author: DiscussionAuthor | null;
  title: string;
  content: string;
  is_pinned: number;
  like_count: number;
  liked_by_me: boolean;
  created_at: string;
  replies: DiscussionReplyItem[];
}

export interface DiscussionPage {
  page: number;
  page_size: number;
  total: number;
  items: DiscussionPost[];
}

export interface ContactExisting {
  rel_type: string;
  status: string;
  direction: string;
}

export interface ContactApplyResult {
  already: boolean;
  status: string;
  message: string;
}

export interface CheckinResult {
  already: boolean;
  task_id?: number;
  is_valid?: number;
}

export interface SearchUserResult {
  user: ContactUser;
  existing: ContactExisting | null;
}
