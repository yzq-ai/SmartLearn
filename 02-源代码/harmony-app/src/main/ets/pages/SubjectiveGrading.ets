import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { ExamSummary, MonitorRecord, RecordAnswer } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, TagChip } from '../components/UiKit';
@Entry
@Component
struct SubjectiveGrading {
  @State exams: ExamSummary[] = [];
  @State records: MonitorRecord[] = [];
  @State answers: RecordAnswer[] = [];
  @State selectedExamId: number = 0;
  @State selectedRecordId: number = 0;
  @State loading: boolean = true;
  @State message: string = '';
  aboutToAppear(): void { this.loadExams(); }
  private async loadExams(): Promise<void> {
    this.loading = true;
    this.message = '';
    try { this.exams = await api.getExams(); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }
  private async monitor(examId: number): Promise<void> {
    this.selectedExamId = examId;
    this.answers = [];
    this.selectedRecordId = 0;
    try {
      const rows: MonitorRecord[] = await api.getExamMonitor(examId);
      this.records = rows.filter((r: MonitorRecord): boolean => r.status === 'GRADING');
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
  }
  private async viewAnswers(recordId: number): Promise<void> {
    this.selectedRecordId = recordId;
    try {
      const rows: RecordAnswer[] = await api.getRecordAnswers(recordId);
      this.answers = rows.filter((a: RecordAnswer): boolean => a.type === 'SHORT');
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载答案失败';
    }
  }
  private async grade(answerId: number, score: number): Promise<void> {
    try {
      await api.gradeAnswer(answerId, score, '教师批改');
      this.message = `✓ 已评分 ${score} 分`;
    } catch (error) {
      this.message = error instanceof Error ? error.message : '批改失败';
    }
  }
  private maxScoreOf(text: string): number {
    return 20;
  }
  build() {
    Column() {
      PageHeader({ title: '主观题批改', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 10 }) {
            this.StepHeader(1, '选择考试')
            if (this.loading) {
              Text('加载中…').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT)
            } else {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.exams, (exam: ExamSummary) => {
                  Text(exam.title)
                    .fontSize(Theme.F_SUB)
                    .fontColor(this.selectedExamId === exam.id ? Color.White : Theme.TEXT)
                    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                    .backgroundColor(this.selectedExamId === exam.id ? Theme.PRIMARY : Theme.BG)
                    .borderRadius(18)
                    .margin({ right: 8, bottom: 8 })
                    .maxLines(1)
                    .onClick((): void => { this.monitor(exam.id); })
                })
              }.width('100%')
            }
          }
          .width('100%').padding(Theme.CARD_PAD)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)
          if (this.records.length > 0) {
            Column({ space: 10 }) {
              Row() {
                this.StepHeader(2, `待批记录（${this.records.length} 人）`)
              }.width('100%')
              GridRow({ gutter: { x: 10, y: 10 } }) {
                ForEach(this.records, (r: MonitorRecord) => {
                  GridCol({ span: { sm: 12, md: 6, lg: 4 } }) {
                    Row({ space: 10 }) {
                      Column() {
                        Text((r.real_name.length > 0 ? r.real_name : r.username).length > 0
                          ? (r.real_name.length > 0 ? r.real_name : r.username).substring(0, 1) : '?')
                          .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Color.White)
                      }
                      .width(36).height(36).borderRadius(18)
                      .linearGradient({ angle: 135, colors: [[Theme.WARNING, 0], ['#FFB74D', 1]] })
                      Text(r.real_name.length > 0 ? r.real_name : r.username)
                        .fontSize(Theme.F_BODY).fontColor(Theme.TEXT).layoutWeight(1)
                      if (this.selectedRecordId === r.record_id) {
                        TagChip({ text: '批改中', tone: 'warning' })
                      }
                      Button('查看简答').height(32).fontSize(12)
                        .backgroundColor(this.selectedRecordId === r.record_id
                          ? Theme.PRIMARY : Theme.PRIMARY_LIGHT)
                        .fontColor(this.selectedRecordId === r.record_id ? Color.White : Theme.PRIMARY)
                        .onClick((): void => { this.viewAnswers(r.record_id); })
                    }
                    .width('100%').padding(10)
                    .backgroundColor(this.selectedRecordId === r.record_id
                      ? Theme.PRIMARY_LIGHT : Theme.BG)
                    .borderRadius(Theme.R_SM)
                  }
                }, (r: MonitorRecord) => String(r.record_id))
              }
            }
            .width('100%').padding(Theme.CARD_PAD)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
            .shadow(Theme.SHADOW_CARD)
          }
          if (this.answers.length > 0) {
            Column({ space: 12 }) {
              this.StepHeader(3, `简答题（${this.answers.length} 题）`)
              ForEach(this.answers, (a: RecordAnswer, index: number) => {
                Column({ space: 10 }) {
                  Row({ space: 8 }) {
                    Text(`第 ${index + 1} 题`).fontSize(Theme.F_CAP)
                      .fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
                    TagChip({ text: '简答', tone: 'primary' })
                    Blank()
                    Text(`满分 ${this.maxScoreOf(a.text)}`).fontSize(Theme.F_CAP)
                      .fontColor(Theme.TEXT_HINT)
                  }.width('100%')
                  Text(a.text).fontSize(Theme.F_BODY)
                    .fontWeight(FontWeight.Medium).fontColor(Theme.TEXT).width('100%')
                  Column({ space: 6 }) {
                    Text('学生作答').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    Text(Array.isArray(a.answer) ? a.answer.join('、') : a.answer)
                      .fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
                      .width('100%').lineHeight(22)
                  }
                  .width('100%').padding(12)
                  .backgroundColor(Theme.BG).borderRadius(Theme.R_SM)
                  .alignItems(HorizontalAlign.Start)
                  Row({ space: 8 }) {
                    Button('低分').height(34).fontSize(12).layoutWeight(1)
                      .backgroundColor(Theme.DANGER_LIGHT).fontColor(Theme.DANGER)
                      .onClick((): void => { this.grade(a.answer_id, 5); })
                    Button('中等').height(34).fontSize(12).layoutWeight(1)
                      .backgroundColor(Theme.WARNING_LIGHT).fontColor(Theme.WARNING)
                      .onClick((): void => { this.grade(a.answer_id, 12); })
                    Button('高分').height(34).fontSize(12).layoutWeight(1)
                      .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
                      .onClick((): void => { this.grade(a.answer_id, 16); })
                    Button('满分').height(34).fontSize(12).layoutWeight(1)
                      .linearGradient({ angle: 135, colors: [[Theme.SUCCESS, 0], ['#3ECF8E', 1]] })
                      .fontColor(Color.White)
                      .onClick((): void => { this.grade(a.answer_id, 20); })
                  }.width('100%')
                  if (a.teacher_comment !== null) {
                    Text(`已批：${a.score ?? 0} 分 · ${a.teacher_comment}`)
                      .fontSize(Theme.F_CAP).fontColor(Theme.SUCCESS)
                      .width('100%').padding(8)
                      .backgroundColor(Theme.SUCCESS_LIGHT).borderRadius(Theme.R_SM)
                  }
                }
                .width('100%').padding(Theme.CARD_PAD)
                .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
                .shadow(Theme.SHADOW_CARD)
              })
            }.width('100%')
          } else if (this.selectedRecordId > 0) {
            EmptyState({ icon: '✅', text: '该记录没有简答题或已批改完成' })
          } else if (this.selectedExamId > 0) {
            EmptyState({ icon: '⏳', text: '暂无待批改的记录' })
          }
          if (this.message.length > 0) {
            Text(this.message).fontSize(Theme.F_SUB)
              .fontColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
              .width('100%').textAlign(TextAlign.Center)
              .margin({ bottom: 24 })
          }
        }.padding(20)
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
  @Builder StepHeader(step: number, title: string) {
    Row({ space: 10 }) {
      Text(`${step}`)
        .fontSize(13).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .width(24).height(24).textAlign(TextAlign.Center)
        .borderRadius(12).backgroundColor(Theme.PRIMARY)
      Text(title).fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
    }.width('100%')
  }
}
