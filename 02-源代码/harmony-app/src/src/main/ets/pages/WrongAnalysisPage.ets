import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { WrongAnalysis } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, TagChip } from '../components/UiKit';
interface WrongAnalysisParams {
  question?: string;
  answer?: string;
  correct?: string;
}
@Entry
@Component
struct WrongAnalysisPage {
  @State question: string = '';
  @State answer: string = '';
  @State correct: string = '';
  @State result: WrongAnalysis | null = null;
  @State loading: boolean = false;
  @State message: string = '';
  @State myFeedback: number = 0;
  aboutToAppear(): void {
    const raw: Object | null = router.getParams();
    if (raw !== null && raw !== undefined) {
      const params: WrongAnalysisParams = raw as WrongAnalysisParams;
      this.question = params.question ?? '';
      this.answer = params.answer ?? '';
      this.correct = params.correct ?? '';
    }
    if (this.question.length > 0) { this.analyze(); }
  }
  private async sendFeedback(v: number): Promise<void> {
    this.myFeedback = v;
    const logId: number = this.result?.log_id ?? 0;
    if (logId > 0) {
      api.aiFeedback(logId, v).catch((): void => { /* 反馈失败静默 */ });
    }
  }
  private async analyze(): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    this.message = '';
    try {
      this.result = await api.aiWrongAnalysis(this.question, this.answer, this.correct);
    } catch (error) {
      this.message = error instanceof Error ? error.message : '分析失败';
    }
    this.loading = false;
  }
  @Builder ResultContent() {
    Row({ space: 10 }) {
      Text('🎯').fontSize(20)
      Column({ space: 2 }) {
        Text('错因分类').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
        Text(this.result!.cause_category).fontSize(16)
          .fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      TagChip({ text: this.result!.source === 'AI' ? 'AI 生成' : '规则分析' })
    }
    .width('100%').padding(14)
    .linearGradient({ angle: 135, colors: [[Theme.PRIMARY_LIGHT, 0], ['#F0F1FF', 1]] })
    .borderRadius(Theme.R_LG)
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('📖').fontSize(16)
        Text('详细分析').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
      }.width('100%')
      Text(this.result!.analysis).fontSize(Theme.F_BODY)
        .fontColor(Theme.TEXT_SECOND).width('100%').lineHeight(22)
    }
    .width('100%').padding(Theme.CARD_PAD)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('💡').fontSize(16)
        Text('学习建议').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
      }.width('100%')
      ForEach(this.result!.suggestions, (s: string, index: number) => {
        Row({ space: 10 }) {
          Text(`${index + 1}`)
            .fontSize(Theme.F_CAP).fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .width(22).height(22).textAlign(TextAlign.Center)
            .borderRadius(11).backgroundColor(Theme.PRIMARY)
          Text(s).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND).layoutWeight(1)
        }
        .width('100%').padding(10)
        .backgroundColor(Theme.BG).borderRadius(Theme.R_SM)
      })
    }
    .width('100%').padding(Theme.CARD_PAD)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
    if (this.result!.knowledge_points.length > 0) {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text('🔗').fontSize(16)
          Text('相关知识点').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
        }.width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.result!.knowledge_points, (kp: string) => {
            Text(kp).fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(14)
              .margin({ right: 8, bottom: 8 })
          })
        }.width('100%')
      }
      .width('100%').padding(Theme.CARD_PAD)
      .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
      .shadow(Theme.SHADOW_CARD)
    }
    // ═══ AI 结果反馈 👍👎 ═══
    Row({ space: 10 }) {
      Text('本次分析有帮助吗？').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).layoutWeight(1)
      Button(this.myFeedback === 1 ? '👍 已赞' : '👍')
        .fontSize(15).height(36)
        .backgroundColor(this.myFeedback === 1 ? Theme.SUCCESS : Theme.INPUT_BG)
        .fontColor(this.myFeedback === 1 ? Color.White : Theme.TEXT_SECOND)
        .onClick((): void => { this.sendFeedback(1); })
      Button(this.myFeedback === -1 ? '👎 已踩' : '👎')
        .fontSize(15).height(36)
        .backgroundColor(this.myFeedback === -1 ? Theme.DANGER : Theme.INPUT_BG)
        .fontColor(this.myFeedback === -1 ? Color.White : Theme.TEXT_SECOND)
        .onClick((): void => { this.sendFeedback(-1); })
    }
    .width('100%').padding(12)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
  }
  build() {
    Column() {
      PageHeader({ title: '错题 AI 分析', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 10 }) {
            Text('题目回顾').fontSize(15).fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT).width('100%')
            Text(this.question).fontSize(Theme.F_BODY).fontColor(Theme.TEXT).width('100%')
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text('你的答案').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                Text(this.answer.length > 0 ? this.answer : '—').fontSize(Theme.F_SUB)
                  .fontColor(Theme.DANGER).fontWeight(FontWeight.Medium)
              }
              .layoutWeight(1).padding(10)
              .backgroundColor(Theme.DANGER_LIGHT).borderRadius(Theme.R_SM)
              Column({ space: 2 }) {
                Text('正确答案').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                Text(this.correct).fontSize(Theme.F_SUB)
                  .fontColor(Theme.SUCCESS).fontWeight(FontWeight.Medium)
              }
              .layoutWeight(1).padding(10)
              .backgroundColor(Theme.SUCCESS_LIGHT).borderRadius(Theme.R_SM)
            }.width('100%')
          }
          .width('100%').padding(Theme.CARD_PAD)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)
          if (this.loading) {
            Column({ space: 14 }) {
              Row({ space: 10 }) {
                LoadingProgress().width(28).height(28).color(Theme.PRIMARY)
                Text('🤖 AI 正在深度分析错因…')
                  .fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
              }
              Column({ space: 8 }) {
                Column().width('40%').height(14).borderRadius(7).backgroundColor(Theme.INPUT_BG)
                Column().width('100%').height(10).borderRadius(5).backgroundColor(Theme.INPUT_BG)
                Column().width('100%').height(10).borderRadius(5).backgroundColor(Theme.INPUT_BG)
                Column().width('85%').height(10).borderRadius(5).backgroundColor(Theme.INPUT_BG)
              }.width('100%')
            }
            .width('100%').padding(20)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
            .shadow(Theme.SHADOW_CARD)
          } else if (this.result !== null) {
            this.ResultContent()
          }
          if (!this.loading && this.question.length > 0) {
            Button('🔄 重新分析')
              .width('100%').height(44).fontSize(14)
              .backgroundColor(Theme.CARD).fontColor(Theme.PRIMARY)
              .borderRadius(Theme.R_MD)
              .shadow(Theme.SHADOW_CARD)
              .margin({ bottom: 24 })
              .onClick((): void => { this.analyze(); })
          }
          if (this.message.length > 0) {
            Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER)
              .width('100%').textAlign(TextAlign.Center)
          }
        }.padding(20)
        .constraintSize({ maxWidth: 640 })
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
