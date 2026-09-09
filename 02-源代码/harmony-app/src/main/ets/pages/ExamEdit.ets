import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Course, QuestionItem } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, Card, PrimaryButton, EmptyState, SkeletonCard, TagChip, showToast } from '../components/UiKit';

const TYPE_OPTIONS: string[] = ['全部', 'SINGLE', 'MULTI', 'JUDGE', 'BLANK', 'SHORT'];
const TYPE_LABELS: Record<string, string> = {
  '全部': '全部题型', 'SINGLE': '单选题', 'MULTI': '多选题', 'JUDGE': '判断题', 'BLANK': '填空题', 'SHORT': '简答题'
};
const DIFF_OPTIONS: number[] = [0, 1, 2, 3];
const DIFF_LABELS: Record<number, string> = { 0: '全部难度', 1: '简单', 2: '中等', 3: '困难' };

/**
 * 组卷建考（需求 8 全面重做）：
 * - 课程下拉（真实课程列表，不再手输数字 ID）
 * - 题型 / 难度 / 关键词筛选题库
 * - 手动选题 + 智能随机抽题两种模式
 * - 实时统计：题数 / 总分 / 题型分布 / 难度分布
 * - 一键创建考试
 */
@Entry
@Component
struct ExamEdit {
  @State courses: Course[] = [];
  @State courseId: number = 0;
  @State title: string = '';
  @State durationMin: number = 60;
  @State passScore: number = 60;
  @State loading: boolean = true;
  @State bankLoading: boolean = false;
  @State sending: boolean = false;
  @State message: string = '';
  @State allQuestions: QuestionItem[] = [];     // 当前筛选下的题库
  @State selected: QuestionItem[] = [];        // 已选题（保序）
  // 筛选
  @State fType: string = '全部';
  @State fDiff: number = 0;
  @State fKeyword: string = '';
  // 随机抽题面板
  @State randomCount: number = 10;
  @State randomType: string = '全部';
  @State randomDiff: number = 0;
  @State randomLoading: boolean = false;
  // 展开预览
  @State expanded: number = -1;

  aboutToAppear(): void { this.init(); }

  private async init(): Promise<void> {
    this.loading = true;
    try {
      this.courses = await api.getCourses();
      if (this.courses.length > 0) { this.courseId = this.courses[0].id; }
      await this.loadBank();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '初始化失败';
    }
    this.loading = false;
  }

  private async loadBank(): Promise<void> {
    this.bankLoading = true;
    try {
      const r = await api.getQuestionsFiltered(1, 100, this.courseId, this.fType === '全部' ? '' : this.fType, this.fDiff, this.fKeyword);
      this.allQuestions = r.items.filter((q: QuestionItem): boolean => q.status === 'PUBLISHED');
    } catch (error) {
      showToast(error instanceof Error ? error.message : '题库加载失败', 'fail');
    }
    this.bankLoading = false;
  }

  private isSelected(qid: number): boolean {
    return this.selected.some((q: QuestionItem): boolean => q.id === qid);
  }

  private toggle(q: QuestionItem): void {
    if (this.isSelected(q.id)) {
      this.selected = this.selected.filter((x: QuestionItem): boolean => x.id !== q.id);
    } else {
      this.selected = [...this.selected, q];
    }
  }

  private totalScore(): number {
    return this.selected.reduce((s: number, q: QuestionItem): number => s + q.score, 0);
  }

  private countByType(t: string): number {
    return this.selected.filter((q: QuestionItem): boolean => q.type === t).length;
  }

  private countByDiff(d: number): number {
    return this.selected.filter((q: QuestionItem): boolean => q.difficulty === d).length;
  }

  private typeName(t: string): string {
    const label: string | undefined = TYPE_LABELS[t];
    return label !== undefined ? label : t;
  }

  /** 智能随机：本地从当前筛选题库抽取（数量不足时取全部）。 */
  private localRandom(): void {
    if (this.allQuestions.length === 0) {
      showToast('当前筛选条件下没有题目', 'fail');
      return;
    }
    const pool: QuestionItem[] = [...this.allQuestions];
    const n: number = Math.min(this.randomCount, pool.length);
    // 简单洗牌取前 n
    for (let i: number = pool.length - 1; i > 0; i -= 1) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const tmp: QuestionItem = pool[i];
      pool[i] = pool[j];
      pool[j] = tmp;
    }
    this.selected = pool.slice(0, n);
    showToast(`已抽取 ${n} 题`, 'success');
  }

  private async submit(): Promise<void> {
    if (this.title.trim().length === 0) {
      this.message = '请填写考试标题';
      return;
    }
    if (this.selected.length === 0) {
      this.message = '请先选题（手动点选或智能抽题）';
      return;
    }
    if (this.totalScore() < this.passScore) {
      this.message = `当前总分 ${this.totalScore()} 分低于及格线 ${this.passScore} 分，请调整`;
      return;
    }
    this.sending = true;
    this.message = '';
    try {
      await api.createExam(this.courseId, this.title.trim(), this.durationMin, this.passScore,
        this.selected.map((q: QuestionItem): number => q.id));
      showToast(`✓ 考试「${this.title.trim()}」已创建（${this.selected.length} 题 / ${this.totalScore()} 分）`, 'success');
      this.selected = [];
      this.title = '';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '创建失败';
    }
    this.sending = false;
  }

  build() {
    Column() {
      PageHeader({ title: '组卷建考', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          if (this.loading) {
            SkeletonCard(); SkeletonCard(); SkeletonCard()
          } else {
            // ═══ ① 考试信息卡 ═══
            Card() {
              Column({ space: 12 }) {
                Text('考试信息').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
                // 课程下拉（真实课程）
                Column({ space: 6 }) {
                  Text('选择课程').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
                  Row({ space: 6 }) {
                    Text(this.courses.find((c: Course): boolean => c.id === this.courseId)?.title ?? '未选择')
                      .fontSize(Theme.F_SUB).fontColor(Theme.TEXT).layoutWeight(1).maxLines(1)
                    Text('‹›').fontSize(16).fontColor(Theme.PRIMARY)
                  }
                  .width('100%').height(44).padding({ left: 14, right: 14 })
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                  .onClick((): void => {
                    // 循环切换课程并重载题库
                    const idx: number = this.courses.findIndex((c: Course): boolean => c.id === this.courseId);
                    const next: Course | undefined = this.courses[(idx + 1) % this.courses.length];
                    if (next !== undefined) {
                      this.courseId = next.id;
                      this.selected = [];
                      this.loadBank();
                    }
                  })
                }.width('100%')
                this.LabeledInput('考试标题', this.title, (v: string): void => { this.title = v; })
                Row({ space: 8 }) {
                  this.LabeledInput('时长(分钟)', `${this.durationMin}`, (v: string): void => { this.durationMin = Number(v) || 0; })
                  this.LabeledInput('及格线(分)', `${this.passScore}`, (v: string): void => { this.passScore = Number(v) || 0; })
                }.width('100%')
                if (this.message.length > 0) {
                  Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER).width('100%')
                }
              }.width('100%')
            }

            // ═══ ② 智能抽题卡 ═══
            Card() {
              Column({ space: 12 }) {
                Row({ space: 8 }) {
                  Text('🎲').fontSize(16)
                  Text('智能随机抽题').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                  Blank()
                  Text(`题库 ${this.allQuestions.length} 题`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                }.width('100%')
                Row({ space: 8 }) {
                  Column({ space: 4 }) {
                    Text('抽题数量').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
                    TextInput({ text: `${this.randomCount}` })
                      .type(InputType.Number)
                      .onChange((v: string): void => { this.randomCount = Number(v) || 0; })
                      .height(40).fontSize(13).width(84)
                      .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                  }
                  Column({ space: 4 }).layoutWeight(1) {
                    Text('题型偏好').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
                    Text(this.typeName(this.randomType)).fontSize(13).fontColor(Theme.TEXT)
                      .width('100%').height(40).textAlign(TextAlign.Center)
                      .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                      .onClick((): void => {
                        const idx: number = TYPE_OPTIONS.indexOf(this.randomType);
                        this.randomType = TYPE_OPTIONS[(idx + 1) % TYPE_OPTIONS.length];
                        this.applyRandomFilterToBank();
                      })
                  }
                  Column({ space: 4 }) {
                    Text('难度').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
                    Text(DIFF_LABELS[this.randomDiff] ?? '全部').fontSize(13).fontColor(Theme.TEXT)
                      .height(40).textAlign(TextAlign.Center).padding({ left: 12, right: 12 })
                      .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                      .onClick((): void => {
                        this.randomDiff = DIFF_OPTIONS[(DIFF_OPTIONS.indexOf(this.randomDiff) + 1) % DIFF_OPTIONS.length];
                        this.applyRandomFilterToBank();
                      })
                  }
                }.width('100%').alignItems(VerticalAlign.Bottom)
                Row({ space: 10 }) {
                  Button(`抽取 ${this.randomCount} 题`).height(42).fontSize(13)
                    .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                    .fontColor(Color.White).borderRadius(Theme.R_MD).layoutWeight(1)
                    .enabled(!this.bankLoading && this.randomCount > 0)
                    .onClick((): void => {
                      this.fType = this.randomType;
                      this.fDiff = this.randomDiff;
                      this.loadBank().then((): void => { this.localRandom(); });
                    })
                  Button('清空已选').height(42).fontSize(13)
                    .backgroundColor(Theme.INPUT_BG).fontColor(Theme.TEXT_SECOND)
                    .borderRadius(Theme.R_MD)
                    .enabled(this.selected.length > 0)
                    .onClick((): void => { this.selected = []; })
                }.width('100%')
              }.width('100%')
            }

            // ═══ ③ 已选统计卡 ═══
            if (this.selected.length > 0) {
              Card() {
                Column({ space: 10 }) {
                  Row({ space: 8 }) {
                    Text('📋 已选题目').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                    Blank()
                    Text(`${this.selected.length} 题`).fontSize(Theme.F_SUB).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
                  }.width('100%')
                  Row({ space: 8 }) {
                    Text(`总分 ${this.totalScore()}`).fontSize(Theme.F_SUB).fontWeight(FontWeight.Bold)
                      .fontColor(this.totalScore() >= this.passScore ? Theme.SUCCESS : Theme.DANGER)
                    Blank()
                    Text(this.totalScore() >= this.passScore ? '✓ 达到及格线' : '⚠ 低于及格线')
                      .fontSize(Theme.F_CAP).fontColor(this.totalScore() >= this.passScore ? Theme.SUCCESS : Theme.DANGER)
                  }.width('100%')
                  Row({ space: 6 }) {
                    ForEach(['SINGLE', 'MULTI', 'JUDGE', 'BLANK', 'SHORT'], (t: string) => {
                      if (this.countByType(t) > 0) {
                        TagChip({ text: `${this.typeName(t)} ${this.countByType(t)}` })
                      }
                    }, (t: string) => t)
                  }.width('100%')
                  Row({ space: 6 }) {
                    ForEach([1, 2, 3], (d: number) => {
                      if (this.countByDiff(d) > 0) {
                        TagChip({ text: `${DIFF_LABELS[d]} ${this.countByDiff(d)}`, tone: d === 3 ? 'danger' : (d === 2 ? 'warning' : 'success') })
                      }
                    }, (d: number) => String(d))
                  }.width('100%')
                  PrimaryButton({
                    label: `✓ 创建考试（${this.selected.length} 题 · ${this.totalScore()} 分）`,
                    loading: this.sending,
                    onTap: (): void => { this.submit(); }
                  })
                }.width('100%')
              }
            }

            // ═══ ④ 题库筛选 ═══
            Card() {
              Column({ space: 10 }) {
                Row({ space: 8 }) {
                  Text('📚').fontSize(16)
                  Text('题库选题').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                  Blank()
                  Text(`点选加入（${this.allQuestions.length} 题可选）`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                }.width('100%')
                TextInput({ placeholder: '🔍 搜索题干关键词…', text: this.fKeyword })
                  .onChange((v: string): void => { this.fKeyword = v; })
                  .height(42).fontSize(13).width('100%')
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
                  .onSubmit((): void => { this.loadBank(); })
                Row({ space: 6 }) {
                  ForEach(TYPE_OPTIONS, (t: string) => {
                    Text(TYPE_LABELS[t] ?? t)
                      .fontSize(12)
                      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                      .fontColor(this.fType === t ? Color.White : Theme.TEXT)
                      .backgroundColor(this.fType === t ? Theme.PRIMARY : Theme.INPUT_BG)
                      .borderRadius(14)
                      .onClick((): void => { this.fType = t; this.loadBank(); })
                  }, (t: string) => t)
                }.width('100%')
                Row({ space: 6 }) {
                  ForEach(DIFF_OPTIONS, (d: number) => {
                    Text(DIFF_LABELS[d] ?? '全部')
                      .fontSize(12)
                      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                      .fontColor(this.fDiff === d ? Color.White : Theme.TEXT)
                      .backgroundColor(this.fDiff === d ? Theme.PRIMARY : Theme.INPUT_BG)
                      .borderRadius(14)
                      .onClick((): void => { this.fDiff = d; this.loadBank(); })
                  }, (d: number) => String(d))
                }.width('100%')
              }.width('100%')
            }

            // ═══ ⑤ 题目列表 ═══
            if (this.bankLoading) {
              SkeletonCard(); SkeletonCard()
            } else if (this.allQuestions.length === 0) {
              EmptyState({ icon: '❓', text: '当前筛选下暂无已发布题目' })
            } else {
              ForEach(this.allQuestions, (q: QuestionItem) => {
                Column({ space: 6 }) {
                  Row({ space: 10 }) {
                    Column() {
                      Text(this.isSelected(q.id) ? '✓' : '+')
                        .fontSize(14).fontWeight(FontWeight.Bold)
                        .fontColor(this.isSelected(q.id) ? Color.White : Theme.PRIMARY)
                        .width(30).height(30).textAlign(TextAlign.Center)
                        .borderRadius(15)
                        .backgroundColor(this.isSelected(q.id) ? Theme.PRIMARY : Theme.PRIMARY_LIGHT)
                    }
                    Column({ space: 4 }) {
                      Text(q.content).fontSize(Theme.F_SUB).fontColor(Theme.TEXT)
                        .maxLines(this.expanded === q.id ? 20 : 2).width('100%')
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Row({ space: 8 }) {
                        TagChip({ text: this.typeName(q.type) })
                        TagChip({
                          text: DIFF_LABELS[q.difficulty] ?? `难度${q.difficulty}`,
                          tone: q.difficulty === 3 ? 'danger' : (q.difficulty === 2 ? 'warning' : 'success')
                        })
                        Blank()
                        Text(`${q.score} 分`).fontSize(Theme.F_CAP)
                          .fontColor(Theme.PRIMARY).fontWeight(FontWeight.Bold)
                      }.width('100%')
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  }.width('100%')
                  Text(this.expanded === q.id ? '收起 ▴' : '展开题干 ▾')
                    .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    .onClick((): void => { this.expanded = this.expanded === q.id ? -1 : q.id; })
                }
                .width('100%').padding(12)
                .backgroundColor(this.isSelected(q.id) ? Theme.PRIMARY_LIGHT : Theme.CARD)
                .borderRadius(Theme.R_MD)
                .border({ width: this.isSelected(q.id) ? 1.5 : 0, color: Theme.PRIMARY })
                .shadow(Theme.SHADOW_CARD)
                .animation({ duration: 150 })
                .onClick((): void => { this.toggle(q); })
              }, (q: QuestionItem) => `${q.id}-${this.isSelected(q.id) ? 1 : 0}-${this.expanded === q.id ? 1 : 0}`)
            }
          }
        }.padding(20)
        .constraintSize({ maxWidth: 640 })
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }

  /** 抽题面板的题型/难度偏好同步到题库筛选（抽完恢复）。 */
  private applyRandomFilterToBank(): void {
    this.fType = this.randomType;
    this.fDiff = this.randomDiff;
    this.loadBank();
  }

  @Builder LabeledInput(label: string, value: string, onChange: (v: string) => void) {
    Column({ space: 4 }) {
      Text(label).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
      TextInput({ placeholder: label, text: value })
        .onChange((v: string): void => { onChange(v); })
        .height(44).fontSize(13).width('100%')
        .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
        .caretColor(Theme.PRIMARY)
    }.width('100%')
  }
}
