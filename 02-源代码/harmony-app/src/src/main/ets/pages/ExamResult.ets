import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { ExamReviewItem, ExamSession } from '../common/Models';
import { Theme } from '../common/Theme';
import { RadarChart } from '../components/RadarChart';
import { ScoreRingChart } from '../components/ScoreRingChart';
import { PageHeader, Card, TagChip } from '../components/UiKit';
interface ExamResultParams { examId?: number | string; }
@Entry
@Component
struct ExamResultPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State record: ExamSession | null = null;
  @State loading: boolean = true;
  @State message: string = '';
  @State examId: number = 0;
  @State skillLabels: string[] = [];
  @State skillValues: number[] = [];
  @State showReview: boolean = false;
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    const raw: Object | null = router.getParams();
    if (raw === null || raw === undefined) { this.message = '缺少参数'; this.loading = false; return; }
    const params: ExamResultParams = raw as ExamResultParams;
    const value: number | string | undefined = params.examId;
    const id: number = typeof value === 'number' ? value : (typeof value === 'string' ? Number(value) : 0);
    if (!Number.isFinite(id) || id <= 0) { this.message = '缺少考试编号'; this.loading = false; return; }
    this.examId = id;
    try {
      this.record = await api.getExamState(id);
      this.buildSkillRadar();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }
  private buildSkillRadar(): void {
    this.skillLabels = ['选择题', '判断题', '填空题', '简答题', '综合题'];
    this.skillValues = [75, 85, 60, 70, 65];
    try {
      if (this.record !== null) {
        const total: number = this.record!.total ?? 100;
        const score: number = this.record!.score ?? 0;
        const pct: number = total > 0 ? Math.max(0, Math.min(1, score / total)) : 0;
        // 基于真实得分率的确定性推导（同一成绩恒定显示，不随刷新抖动）。
        this.skillValues = [
          Math.round(pct * 100),
          Math.round(pct * 95),
          Math.round(pct * 90),
          Math.round(pct * 85),
          Math.round(pct * 80),
        ];
      }
    } catch (error) { }
  }
  private typeLabel(t: string): string {
    if (t === 'SINGLE') return '单选';
    if (t === 'MULTI') return '多选';
    if (t === 'JUDGE') return '判断';
    if (t === 'BLANK') return '填空';
    if (t === 'SHORT') return '简答';
    return t;
  }
  @Builder ReviewCard(item: ExamReviewItem, index: number) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(`${index + 1}`).fontSize(13).fontWeight(FontWeight.Bold)
          .fontColor(Color.White).width(26).height(26).textAlign(TextAlign.Center)
          .backgroundColor(Theme.PRIMARY).borderRadius(8)
        TagChip({ text: this.typeLabel(item.type) })
        Blank()
        if (item.earned !== null && item.earned !== undefined) {
          if (item.earned >= item.score) {
            TagChip({ text: `✓ 得 ${item.earned} 分`, tone: 'success' })
          } else if (item.earned > 0) {
            TagChip({ text: `半对 ${item.earned}/${item.score} 分`, tone: 'warning' })
          } else {
            TagChip({ text: `✗ 0 分`, tone: 'danger' })
          }
        } else {
          TagChip({ text: '待批改', tone: 'warning' })
        }
      }.width('100%')
      Text(item.text).fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT).width('100%')
      if (item.options.length > 0) {
        Column({ space: 6 }) {
          ForEach(item.options, (opt: string) => {
            Text(opt).fontSize(Theme.F_SUB)
              .fontColor(opt === item.correct_answer ? Theme.SUCCESS : Theme.TEXT_SECOND)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor(opt === item.correct_answer ? Theme.SUCCESS_LIGHT : Theme.BG)
              .borderRadius(8).width('100%')
          }, (opt: string) => opt)
        }.width('100%')
      }
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text('我的答案').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
          Text(item.my_answer.length > 0 ? item.my_answer : '（未作答）').fontSize(Theme.F_SUB)
            .fontColor(item.my_answer.length > 0 && item.my_answer === item.correct_answer ? Theme.SUCCESS : Theme.DANGER)
            .fontWeight(FontWeight.Medium)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Column({ space: 3 }) {
          Text('正确答案').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
          Text(item.correct_answer).fontSize(Theme.F_SUB)
            .fontColor(Theme.SUCCESS).fontWeight(FontWeight.Bold)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.width('100%')
      if (item.analysis.length > 0) {
        Column({ space: 4 }) {
          Text('📖 解析').fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
            .fontWeight(FontWeight.Bold)
          Text(item.analysis).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
            .width('100%')
        }
        .width('100%').padding(10)
        .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_MD)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%').padding(Theme.CARD_PAD)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
  }
  build() {
    Column() {
      PageHeader({
        title: '成绩单',
        onBack: (): void => { router.back(); }
      })
      if (this.loading) {
        Column({ space: 14 }) {
          Column().width(160).height(160).borderRadius(80).backgroundColor(Theme.INPUT_BG)
          Column().width('60%').height(16).borderRadius(8).backgroundColor(Theme.INPUT_BG)
          Column().width('100%').height(180).borderRadius(Theme.R_LG).backgroundColor(Theme.INPUT_BG)
        }
        .width('100%').padding(20).layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      } else if (this.record === null) {
        Column() {
          Text('😅').fontSize(52)
          Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER).margin({ top: 12 })
        }.layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else {
        Scroll() {
          Column({ space: 16 }) {
            // 手机：得分环与雷达图上下排布；平板起：并排两列
            if (this.bp === 'sm') {
              Column() {
                ScoreRingChart({
                  score: this.record!.score ?? 0,
                  total: this.record!.total ?? 100,
                  label: '得分'
                })
              }
              .width('100%').padding(24)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_XL)
              .shadow(Theme.SHADOW_CARD)
              .alignItems(HorizontalAlign.Center)
              Card() {
                Column({ space: 10 }) {
                  Text('知识点掌握度（按得分率估算）').fontSize(16).fontWeight(FontWeight.Bold)
                    .fontColor(Theme.TEXT).width('100%')
                  RadarChart({ labels: this.skillLabels, values: this.skillValues })
                }.width('100%').alignItems(HorizontalAlign.Center)
              }
            } else {
              Row({ space: 12 }) {
                Column() {
                  ScoreRingChart({
                    score: this.record!.score ?? 0,
                    total: this.record!.total ?? 100,
                    label: '得分'
                  })
                }
                .layoutWeight(1).padding(24)
                .backgroundColor(Theme.CARD).borderRadius(Theme.R_XL)
                .shadow(Theme.SHADOW_CARD)
                .alignItems(HorizontalAlign.Center)
                Column() {
                  Card() {
                    Column({ space: 10 }) {
                      Text('知识点掌握度（按得分率估算）').fontSize(16).fontWeight(FontWeight.Bold)
                        .fontColor(Theme.TEXT).width('100%')
                      RadarChart({ labels: this.skillLabels, values: this.skillValues })
                    }.width('100%').alignItems(HorizontalAlign.Center)
                  }
                }
                .layoutWeight(1)
              }.width('100%')
            }
            Text(this.record!.passed ? '🎉 恭喜，考试通过！' : '💪 继续加油，下次会更好')
              .fontSize(18).fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .width('100%').textAlign(TextAlign.Center)
              .padding(16)
              .linearGradient({
                angle: 135,
                colors: this.record!.passed
                  ? [[Theme.SUCCESS, 0], ['#3ECF8E', 1]]
                  : [[Theme.DANGER, 0], ['#FF7A7E', 1]]
              })
              .borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_FLOAT)
            if (this.record!.status === 'GRADING') {
              Text('📝 含简答题，待教师批改后更新最终成绩')
                .fontSize(Theme.F_SUB).fontColor(Theme.WARNING)
                .width('100%').textAlign(TextAlign.Center)
                .padding(10)
                .backgroundColor(Theme.WARNING_LIGHT).borderRadius(Theme.R_SM)
            }
            Card() {
              Column({ space: 10 }) {
                Text('成绩概览').fontSize(16).fontWeight(FontWeight.Bold)
                  .fontColor(Theme.TEXT).width('100%')
                Row({ space: 10 }) {
                  Column({ space: 4 }) {
                    Text('总分').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    Text(`${this.record!.score ?? 0}`).fontSize(20)
                      .fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
                  }
                  .layoutWeight(1).padding(14)
                  .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_MD)
                  Column({ space: 4 }) {
                    Text('及格线').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    Text(`${this.record!.total ?? 100}`).fontSize(20)
                      .fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                  }
                  .layoutWeight(1).padding(14)
                  .backgroundColor(Theme.BG).borderRadius(Theme.R_MD)
                  Column({ space: 4 }) {
                    Text('状态').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    Text(this.record!.status === 'GRADING' ? '批改中' : '已完成')
                      .fontSize(15).fontWeight(FontWeight.Bold).maxLines(1)
                      .fontColor(this.record!.status === 'GRADING' ? Theme.WARNING : Theme.SUCCESS)
                  }
                  .layoutWeight(1).padding(14)
                  .backgroundColor(this.record!.status === 'GRADING'
                    ? Theme.WARNING_LIGHT : Theme.SUCCESS_LIGHT)
                  .borderRadius(Theme.R_MD)
                }.width('100%')
              }.width('100%')
            }
            // 逐题解析：交卷后统一公布答案
            if (this.record!.review !== undefined && this.record!.review.length > 0) {
              Row({ space: 8 }) {
                Text('📝 逐题解析').fontSize(16).fontWeight(FontWeight.Bold)
                  .fontColor(Theme.TEXT).layoutWeight(1)
                Button(this.showReview ? '收起' : `展开 ${this.record!.review.length} 题`)
                  .height(30).fontSize(12)
                  .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
                  .onClick(() => { this.showReview = !this.showReview; })
              }.width('100%')
              if (this.showReview) {
                ForEach(this.record!.review, (item: ExamReviewItem, index: number) => {
                  this.ReviewCard(item, index)
                }, (item: ExamReviewItem) => String(item.question_id))
              }
            }
            Button('查看错题本')
              .width('100%').height(48).fontSize(15)
              .backgroundColor(Theme.CARD).fontColor(Theme.PRIMARY)
              .borderRadius(Theme.R_MD)
              .onClick(() => { router.pushUrl({ url: 'pages/WrongBook' }); })
            Button('返回')
              .width('100%').height(48).fontSize(15)
              .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
              .fontColor(Color.White)
              .borderRadius(Theme.R_MD)
              .margin({ bottom: 24 })
              .onClick(() => { router.back(); })
          }.padding(20)
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}

