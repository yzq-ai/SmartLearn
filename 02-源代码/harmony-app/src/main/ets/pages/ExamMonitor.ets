import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { ExamSummary, MonitorRecord } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, TagChip } from '../components/UiKit';
@Entry
@Component
struct ExamMonitor {
  @State exams: ExamSummary[] = [];
  @State records: MonitorRecord[] = [];
  @State selectedExamId: number = 0;
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
    try { this.records = await api.getExamMonitor(examId); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载监控失败'; }
  }
  private switchTone(count: number): string {
    if (count >= 3) return 'danger';
    if (count >= 1) return 'warning';
    return 'success';
  }
  build() {
    Column() {
      PageHeader({ title: '考试监控', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 10 }) {
            Text('选择考试').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
            if (this.loading) {
              SkeletonCard()
            } else if (this.exams.length === 0) {
              Text('暂无考试').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).padding(8)
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
          if (this.records.length === 0) {
            EmptyState({ icon: '👁', text: '选择上方考试查看监控数据' })
          } else {
            Row({ space: 8 }) {
              Text('作答情况').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
              Blank()
              Text(`共 ${this.records.length} 人`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
            }.width('100%')
            GridRow({ gutter: { x: 12, y: 12 } }) {
              ForEach(this.records, (r: MonitorRecord) => {
                GridCol({ span: { sm: 12, md: 6, lg: 4 } }) {
                  Row({ space: 12 }) {
                    Column() {
                      Text((r.real_name.length > 0 ? r.real_name : r.username).length > 0
                        ? (r.real_name.length > 0 ? r.real_name : r.username).substring(0, 1) : '?')
                        .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
                    }
                    .width(42).height(42).borderRadius(21)
                    .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                    Column({ space: 3 }) {
                      Text(r.real_name.length > 0 ? r.real_name : r.username)
                        .fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
                        .maxLines(1)
                      Text(`#${r.record_id} · 学生${r.student_id}`)
                        .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    Column({ space: 4 }) {
                      TagChip({ text: `切屏 ${r.switch_count} 次`, tone: this.switchTone(r.switch_count) })
                      if (r.status === 'GRADING') {
                        TagChip({ text: '待批改', tone: 'warning' })
                      } else if (r.score !== null) {
                        Text(`${r.score}/${r.total ?? 100}`).fontSize(Theme.F_SUB)
                          .fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
                      } else {
                        TagChip({ text: '进行中', tone: 'primary' })
                      }
                    }.alignItems(HorizontalAlign.End)
                  }
                  .width('100%').padding(14)
                  .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
                  .shadow(Theme.SHADOW_CARD)
                }
              }, (r: MonitorRecord) => String(r.record_id))
            }
          }
          if (this.message.length > 0) {
            Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER).width('100%')
              .textAlign(TextAlign.Center)
          }
        }.padding(20)
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
