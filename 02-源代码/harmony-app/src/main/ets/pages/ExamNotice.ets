import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Exam, ExamQuestion } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, Card, PrimaryButton, TagChip } from '../components/UiKit';
interface ExamNoticeParams { examId?: number | string; }
@Entry
@Component
struct ExamNotice {
  @State exam: Exam | null = null;
  @State loading: boolean = true;
  @State message: string = '';
  @State agreed: boolean = false;
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    const raw: Object | null = router.getParams();
    if (raw === null || raw === undefined) { this.message = '缺少参数'; this.loading = false; return; }
    const params: ExamNoticeParams = raw as ExamNoticeParams;
    const value: number | string | undefined = params.examId;
    const id: number = typeof value === 'number' ? value : (typeof value === 'string' ? Number(value) : 0);
    if (!Number.isFinite(id) || id <= 0) { this.message = '缺少考试编号'; this.loading = false; return; }
    try {
      this.exam = await api.getExam(id);
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }
  private totalScore(): number {
    if (this.exam === null) return 0;
    let total: number = 0;
    this.exam.questions.forEach((q) => { total += q.score; });
    return total;
  }
  build() {
    Column() {
      PageHeader({ title: '考试须知', onBack: (): void => { router.back(); } })
      if (this.loading) {
        Column({ space: 14 }) {
          Column().width('100%').height(120).borderRadius(Theme.R_LG).backgroundColor(Theme.INPUT_BG)
          Column().width('100%').height(180).borderRadius(Theme.R_LG).backgroundColor(Theme.INPUT_BG)
        }.padding(20)
      } else if (this.exam === null) {
        Column() {
          Text('😕').fontSize(52)
          Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER).margin({ top: 12 })
        }.layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else {
        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 12 }) {
              Row({ space: 10 }) {
                Text('📝').fontSize(24)
                Text(this.exam.title).fontSize(22).fontWeight(FontWeight.Bold)
                  .fontColor(Color.White).layoutWeight(1)
              }.width('100%')
              Row({ space: 8 }) {
                Text(`共 ${this.exam.questions.length} 题`).fontSize(Theme.F_SUB)
                  .fontColor('rgba(255,255,255,0.85)')
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .backgroundColor('rgba(255,255,255,0.15)').borderRadius(8)
                Text(`总分 ${this.totalScore()} 分`).fontSize(Theme.F_SUB)
                  .fontColor('rgba(255,255,255,0.85)')
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .backgroundColor('rgba(255,255,255,0.15)').borderRadius(8)
              }.width('100%')
            }
            .width('100%').padding(24)
            .linearGradient({ angle: 145, colors: [[Theme.PRIMARY_DEEP, 0], [Theme.PRIMARY_GRADIENT, 1]] })
            .borderRadius(Theme.R_XL)
            .shadow(Theme.SHADOW_FLOAT)
            Card() {
              Column({ space: 14 }) {
                Text('考试规则').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
                this.RuleRow('⏱', '限时作答', '请在规定时间内完成作答，倒计时结束自动交卷')
                this.RuleRow('📵', '切屏监控', '切屏超过 3 次将自动交卷，请勿中途离开')
                this.RuleRow('🔒', '交卷不可逆', '交卷后不能修改答案，请确认后再提交')
                this.RuleRow('✍️', '判分方式', '客观题自动判分，简答题由教师批改后出分')
              }.width('100%')
            }
            Card() {
              Column({ space: 10 }) {
                Text('题型概览').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.exam!.questions, (q: ExamQuestion, index: number) => {
                    Row({ space: 6 }) {
                      Text(`${index + 1}`).fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                        .fontWeight(FontWeight.Bold)
                      Text(`${q.type} · ${q.score}分`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
                    }
                    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                    .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(8)
                    .margin({ right: 8, bottom: 8 })
                  })
                }.width('100%')
              }.width('100%')
            }
            Row({ space: 10 }) {
              Checkbox({ name: 'agree' })
                .select(this.agreed)
                .selectedColor(Theme.PRIMARY)
                .onChange((value: boolean) => { this.agreed = value; })
              Text('我已阅读并理解以上考试规则')
                .fontSize(Theme.F_BODY).fontColor(Theme.TEXT)
            }
            .width('100%').padding(14)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_MD)
            .shadow(Theme.SHADOW_CARD)
            Column({ space: 8 }) {
              PrimaryButton({
                label: '🚀 开始考试',
                isDisabled: !this.agreed,
                onTap: (): void => {
                  router.pushUrl({ url: 'pages/Exam', params: { examId: this.exam!.id } });
                }
              })
              if (!this.agreed) {
                Text('请先勾选同意考试规则').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
              }
            }.width('100%').margin({ bottom: 24 })
          }.padding(20)
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
  @Builder RuleRow(icon: string, title: string, desc: string) {
    Row({ space: 12 }) {
      Text(icon).fontSize(16)
        .width(36).height(36).textAlign(TextAlign.Center)
        .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_SM)
      Column({ space: 2 }) {
        Text(title).fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
        Text(desc).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%')
  }
}
