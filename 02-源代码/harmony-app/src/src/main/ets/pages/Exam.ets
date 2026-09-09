import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Answer, Exam as ExamModel, ExamQuestion, ExamResult, ExamSession, ExamSessionAnswer } from '../common/Models';
import { Theme } from '../common/Theme';
import { PrimaryButton } from '../components/UiKit';
import { IBestDialogUtil } from '@ibestservices/ibest-ui-v2';
interface ExamRouteParams { examId?: number | string; }
@Entry
@Component
struct Exam {
  @State exam: ExamModel | undefined = undefined;
  @State answers: Record<string, string> = {};
  @State remaining: number = 1800;
  @State examId: number = 0;
  @State status: string = '正在加载考试…';
  @State result: ExamResult | undefined = undefined;
  @State saving: boolean = false;
  @State submitting: boolean = false;
  @State switchCount: number = 0;
  @State showSwitchWarning: boolean = false;
  @State currentIndex: number = 0;
  private timerId: number = -1;
  private syncTimerId: number = -1;
  private backgroundTime: number = 0;
  private maxSwitchCount: number = 3;
  aboutToAppear(): void { this.load(); }
  aboutToDisappear(): void { this.stopTimers(); }
  private stopTimers(): void {
    if (this.timerId >= 0) { clearInterval(this.timerId); this.timerId = -1; }
    if (this.syncTimerId >= 0) { clearInterval(this.syncTimerId); this.syncTimerId = -1; }
  }
  private async load(): Promise<void> {
    const raw: Object | null = router.getParams();
    if (raw === null || raw === undefined) { this.status = '缺少参数'; return; }
    const params: ExamRouteParams = raw as ExamRouteParams;
    const value: number | string | undefined = params.examId;
    const parsed: number = typeof value === 'number' ? value : (typeof value === 'string' ? Number(value) : 0);
    if (!Number.isFinite(parsed) || parsed <= 0) { this.status = '缺少有效的考试编号'; return; }
    this.examId = parsed;
    try {
      const loaded: ExamModel = await api.getExam(this.examId);
      this.exam = loaded;
      this.examId = loaded.id;
      await api.startExam(this.examId);
      const session: ExamSession = await api.getExamState(this.examId);
      const restored: Record<string, string> = {};
      session.answers.forEach((item: ExamSessionAnswer): void => {
        restored[String(item.question_id)] = Array.isArray(item.answer) ? item.answer.join(',') : item.answer;
      });
      this.answers = restored;
      const deadlineMs: number = new Date(session.deadline_at).getTime();
      this.remaining = Math.max(0, Math.floor((deadlineMs - Date.now()) / 1000));
      this.status = '答题进行中';
      this.timerId = setInterval(() => {
        if (this.remaining > 0) this.remaining -= 1;
        else if (!this.submitting && this.result === undefined) { this.submit(false); }
      }, 1000);
      this.syncTimerId = setInterval(() => { this.save(); }, 30000);
    } catch (error) {
      this.status = error instanceof Error ? error.message : '考试加载失败';
    }
  }
  private async reportSwitch(): Promise<void> {
    this.switchCount += 1;
    this.showSwitchWarning = true;
    setTimeout(() => { this.showSwitchWarning = false; }, 3000);
    try { await api.reportExamMonitor(this.examId, this.switchCount); } catch (error) { }
    if (this.switchCount >= this.maxSwitchCount) { this.submit(false); }
  }
  onPageHide(): void { this.backgroundTime = Date.now(); }
  onPageShow(): void {
    if (this.backgroundTime > 0 && this.exam !== undefined && this.result === undefined) {
      const elapsed: number = Date.now() - this.backgroundTime;
      if (elapsed > 3000) { this.reportSwitch(); }
    }
    this.backgroundTime = 0;
  }
  private typeOf(question: ExamQuestion): string { return question.type.toUpperCase(); }
  private optionsFor(question: ExamQuestion): string[] {
    if (question.options !== undefined && question.options.length > 0) return question.options;
    const type: string = this.typeOf(question);
    if (type === 'JUDGE' || type === 'TRUE_FALSE') return ['true', 'false'];
    return [];
  }
  private choose(question: ExamQuestion, answer: string): void {
    const next: Record<string, string> = {};
    Object.keys(this.answers).forEach((key: string): void => { next[key] = this.answers[key]; });
    next[String(question.id)] = answer;
    this.answers = next;
  }
  private isSelected(question: ExamQuestion, option: string): boolean {
    return this.answers[String(question.id)] === option;
  }
  private toggleMulti(question: ExamQuestion, option: string): void {
    const current: string = this.answers[String(question.id)] ?? '';
    const selected: string[] = current.length > 0 ? current.split(',') : [];
    const index: number = selected.indexOf(option);
    if (index >= 0) { selected.splice(index, 1); } else { selected.push(option); }
    this.choose(question, selected.join(','));
  }
  private isMultiSelected(question: ExamQuestion, option: string): boolean {
    const current: string = this.answers[String(question.id)] ?? '';
    return current.length > 0 && current.split(',').indexOf(option) >= 0;
  }
  private onTextAnswer(question: ExamQuestion, value: string): void { this.choose(question, value); }
  private answeredCount(): number {
    if (this.exam === undefined) return 0;
    return this.exam.questions.filter(
      (q: ExamQuestion): boolean => (this.answers[String(q.id)] ?? '').length > 0).length;
  }
  private async save(): Promise<void> {
    if (this.exam === undefined || this.saving || this.submitting) return;
    const list: Answer[] = this.exam.questions
      .filter((question: ExamQuestion): boolean => (this.answers[String(question.id)] ?? '').length > 0)
      .map((question: ExamQuestion): Answer => ({
        question_id: question.id, answer: this.answers[String(question.id)] ?? ''
      }));
    this.saving = true;
    try {
      const session: ExamSession = await api.saveExamAnswers(this.examId, list);
      this.status = `✓ 已同步 ${session.answers.length} 题`;
    } catch (error) {
      this.status = '同步失败，将在下次自动重试';
    }
    this.saving = false;
  }
  @Builder SingleOptions(question: ExamQuestion) {
    Column({ space: 10 }) {
      ForEach(this.optionsFor(question), (option: string) => {
        Row({ space: 12 }) {
          Text(option)
            .fontSize(Theme.F_BODY).fontWeight(FontWeight.Bold)
            .fontColor(this.isSelected(question, option) ? Color.White : Theme.TEXT_SECOND)
            .width(36).height(36).textAlign(TextAlign.Center)
            .borderRadius(18)
            .backgroundColor(this.isSelected(question, option) ? 'rgba(255,255,255,0.25)' : Theme.BG)
          Text(option)
            .fontSize(Theme.F_BODY)
            .fontColor(this.isSelected(question, option) ? Color.White : Theme.TEXT)
            .layoutWeight(1)
        }
        .width('100%').padding(12)
        .backgroundColor(this.isSelected(question, option)
          ? Theme.PRIMARY : Theme.BG)
        .borderRadius(Theme.R_MD)
        .animation({ duration: 180, curve: Curve.EaseOut })
        .onClick(() => { this.choose(question, option); })
      })
    }.width('100%')
  }
  @Builder MultiOptions(question: ExamQuestion) {
    Column({ space: 10 }) {
      ForEach(this.optionsFor(question), (option: string) => {
        Row({ space: 12 }) {
          Text(this.isMultiSelected(question, option) ? '✓' : '')
            .fontSize(14).fontWeight(FontWeight.Bold)
            .fontColor(this.isMultiSelected(question, option) ? Color.White : Theme.TEXT_HINT)
            .width(36).height(36).textAlign(TextAlign.Center)
            .borderRadius(10)
            .backgroundColor(this.isMultiSelected(question, option)
              ? 'rgba(255,255,255,0.25)' : Theme.CARD)
          Text(option).fontSize(Theme.F_BODY)
            .fontColor(this.isMultiSelected(question, option) ? Color.White : Theme.TEXT)
            .layoutWeight(1)
        }
        .width('100%').padding(12)
        .backgroundColor(this.isMultiSelected(question, option) ? Theme.PRIMARY : Theme.BG)
        .borderRadius(Theme.R_MD)
        .animation({ duration: 180, curve: Curve.EaseOut })
        .onClick(() => { this.toggleMulti(question, option); })
      })
      Text('💡 多选题：可选中多个选项').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
    }.width('100%')
  }
  @Builder QuestionBody(question: ExamQuestion) {
    if (this.typeOf(question) === 'SINGLE') { this.SingleOptions(question) }
    else if (this.typeOf(question) === 'MULTI') { this.MultiOptions(question) }
    else if (this.typeOf(question) === 'JUDGE' || this.typeOf(question) === 'TRUE_FALSE') {
      this.SingleOptions(question)
    }
    else if (this.typeOf(question) === 'BLANK') {
      TextInput({ placeholder: '请输入答案', text: this.answers[String(question.id)] ?? '' })
        .onChange((value: string): void => { this.onTextAnswer(question, value); })
        .width('100%').height(48).fontSize(15)
        .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD).caretColor(Theme.PRIMARY)
    }
    else if (this.typeOf(question) === 'SHORT') {
      TextArea({ placeholder: '请输入简答内容…', text: this.answers[String(question.id)] ?? '' })
        .onChange((value: string): void => { this.onTextAnswer(question, value); })
        .width('100%').height(120).fontSize(15)
        .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD).caretColor(Theme.PRIMARY)
    }
    else { Text('该题暂无可用选项').fontColor(Theme.DANGER).fontSize(Theme.F_SUB) }
  }
  private confirmSubmit(): void {
    if (this.submitting || this.result !== undefined) return;
    const unanswered: number = this.exam?.questions.filter(
      (q: ExamQuestion): boolean => (this.answers[String(q.id)] ?? '').length === 0).length ?? 0;
    const msg: string = unanswered > 0
      ? `还有 ${unanswered} 题未作答，确认交卷？`
      : '确认交卷？交卷后不能修改。';
    // 原生 AlertDialog（IBestDialogUtil.onConfirm 在 V1 页面存在回调不触发的静默失败，需求 17）
    this.getUIContext().showAlertDialog({
      title: '交卷确认',
      message: msg,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '继续答题',
        action: (): void => {},
      },
      secondaryButton: {
        value: '确认交卷',
        fontColor: '#E5484D',
        action: (): void => { this.submit(true); },
      },
      cancel: (): void => {},
    });
  }
  private async submit(manual: boolean): Promise<void> {
    if (this.exam === undefined || this.submitting || this.result !== undefined) return;
    this.submitting = true;
    this.stopTimers();
    this.status = '正在交卷…';
    const list: Answer[] = this.exam.questions.map((question: ExamQuestion): Answer => ({
      question_id: question.id, answer: this.answers[String(question.id)] ?? ''
    }));
    try {
      this.result = await api.submitExam(this.examId, list);
      this.status = '✓ 已交卷';
    } catch (error) {
      this.status = error instanceof Error ? error.message : '交卷失败，请重试';
      this.submitting = false;
    }
  }
  private formatTimer(sec: number): string {
    const h: number = Math.floor(sec / 3600);
    const m: number = Math.floor((sec % 3600) / 60);
    const s: number = sec % 60;
    if (h > 0) return `${h}:${m < 10 ? '0' : ''}${m}:${s < 10 ? '0' : ''}${s}`;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  }
  @Builder ResultView() {
    Column({ space: 20 }) {
      Text('🎉').fontSize(64)
      Text('考试完成').fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
      Text(`${this.result!.score} / ${this.result!.total}`)
        .fontSize(48).fontColor(Theme.PRIMARY).fontWeight(FontWeight.Bold)
      Text(this.result!.passed ? '恭喜，考试通过' : '继续加油')
        .fontSize(16).fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .padding({ left: 20, right: 20, top: 8, bottom: 8 })
        .linearGradient({
          angle: 135,
          colors: this.result!.passed
            ? [[Theme.SUCCESS, 0], ['#3ECF8E', 1]]
            : [[Theme.DANGER, 0], ['#FF7A7E', 1]]
        })
        .borderRadius(20)
      PrimaryButton({
        label: '查看成绩单',
        onTap: (): void => {
          router.pushUrl({ url: 'pages/ExamResult', params: { examId: this.examId } });
        }
      })
      Button('返回')
        .width('100%').height(48).fontSize(15)
        .backgroundColor(Theme.CARD).fontColor(Theme.TEXT)
        .borderRadius(Theme.R_MD)
        .shadow(Theme.SHADOW_CARD)
        .onClick(() => { router.back(); })
    }
    .justifyContent(FlexAlign.Center).layoutWeight(1).width('100%').padding(24)
  }
  build() {
    Column() {
      Row({ space: 12 }) {
        Button('‹')
          .width(38).height(38).fontSize(18)
          .backgroundColor('rgba(255,255,255,0.2)').fontColor(Color.White)
          .onClick(() => {
            if (this.result === undefined) { this.save(); }
            router.back();
          })
        Text(this.exam?.title ?? '考试')
          .fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor(Color.White).maxLines(1).layoutWeight(1)
        Row({ space: 6 }) {
          Text('⏱').fontSize(13)
          Text(this.formatTimer(this.remaining))
            .fontSize(16).fontWeight(FontWeight.Bold)
            .fontColor(this.remaining < 300 ? '#FFD54F' : Color.White)
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor(this.remaining < 300 ? 'rgba(229,72,77,0.55)' : 'rgba(255,255,255,0.15)')
        .borderRadius(20)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .linearGradient({ angle: 135, colors: [[Theme.PRIMARY_DEEP, 0], [Theme.PRIMARY_GRADIENT, 1]] })
      if (this.showSwitchWarning) {
        Row({ space: 8 }) {
          Text('⚠').fontSize(14)
          Text(`切屏警告 第${this.switchCount}/${this.maxSwitchCount}次，超限将自动交卷`)
            .fontSize(Theme.F_SUB).fontColor(Theme.DANGER).fontWeight(FontWeight.Bold)
        }
        .width('100%').padding(10)
        .backgroundColor(Theme.DANGER_LIGHT)
        .animation({ duration: 200 })
      }
      if (this.result !== undefined) {
        this.ResultView()
      } else if (this.exam !== undefined) {
        Column({ space: 6 }) {
          Row() {
            Text(`第 ${this.currentIndex + 1} / ${this.exam.questions.length} 题`)
              .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
            Blank()
            Text(`已答 ${this.answeredCount()} 题 · ${this.status}`)
              .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
          }.width('100%')
          Progress({
            value: this.answeredCount(),
            total: this.exam.questions.length,
            type: ProgressType.Linear
          })
            .width('100%').color(Theme.PRIMARY).style({ strokeWidth: 5 })
        }
        .width('100%').padding({ left: 20, right: 20, top: 10, bottom: 6 })
        Scroll() {
          Column({ space: 16 }) {
            ForEach(this.exam.questions, (question: ExamQuestion, index: number) => {
              Column({ space: 14 }) {
                Row({ space: 10 }) {
                  Text(`${index + 1}`)
                    .fontColor(Color.White).width(28).height(28)
                    .textAlign(TextAlign.Center)
                    .backgroundColor(Theme.PRIMARY).borderRadius(8).fontSize(13)
                    .fontWeight(FontWeight.Bold)
                  Text(question.text)
                    .fontSize(16).fontWeight(FontWeight.Medium)
                    .fontColor(Theme.TEXT).layoutWeight(1)
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
                Text(`${question.type} · ${question.score} 分`)
                  .fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(8)
                this.QuestionBody(question)
              }
              .width('100%').padding(Theme.CARD_PAD)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }, (question: ExamQuestion, index: number) => `${question.id}_${index}`)
            Row({ space: 12 }) {
              Button(this.saving ? '同步中…' : '💾 手动保存')
                .layoutWeight(1).height(48).fontSize(14)
                .backgroundColor(Theme.CARD).fontColor(Theme.TEXT)
                .borderRadius(Theme.R_MD)
                .shadow(Theme.SHADOW_CARD)
                .enabled(!this.saving && !this.submitting)
                .onClick(() => { this.save(); })
              Button('📤 交卷')
                .layoutWeight(1).height(48).fontSize(14).fontWeight(FontWeight.Bold)
                .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                .fontColor(Color.White)
                .borderRadius(Theme.R_MD)
                .enabled(!this.submitting)
                .onClick(() => { this.confirmSubmit(); })
            }.width('100%').margin({ bottom: 24 })
          }.padding({ left: 20, right: 20, top: 8 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      } else {
        Column({ space: 14 }) {
          LoadingProgress().width(48).height(48).color(Theme.PRIMARY)
          Text(this.status).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT)
        }.layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
