import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { AiSummary } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, PrimaryButton, TagChip } from '../components/UiKit';
@Entry
@Component
struct AISummary {
  @State text: string = '';
  @State result: AiSummary | null = null;
  @State loading: boolean = false;
  @State message: string = '';
  private async summarize(): Promise<void> {
    if (this.text.length === 0) { this.message = '请输入待摘要的文本'; return; }
    this.loading = true;
    this.message = '';
    try {
      this.result = await api.aiSummary(this.text);
    } catch (error) {
      this.message = error instanceof Error ? error.message : '生成失败';
    }
    this.loading = false;
  }
  build() {
    Column() {
      PageHeader({ title: 'AI 智能摘要', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 10 }) {
            Row({ space: 8 }) {
              Text('🤖').fontSize(18)
              Text('粘贴文档 / 字幕文本').fontSize(15).fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT)
              Blank()
              if (this.text.length > 0) {
                Text(`${this.text.length} 字`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
              }
            }.width('100%')
            TextArea({ placeholder: '在此粘贴需要总结的长文本…', text: this.text })
              .onChange((v: string): void => { this.text = v; })
              .width('100%').height(140).fontSize(14)
              .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
              .caretColor(Theme.PRIMARY)
            PrimaryButton({
              label: '✨ 生成摘要',
              loading: this.loading,
              onTap: (): void => { this.summarize(); }
            })
            if (this.message.length > 0) {
              Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER)
                .width('100%').textAlign(TextAlign.Center)
            }
          }
          .width('100%').padding(Theme.CARD_PAD)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)
          if (this.result !== null) {
            this.ResultCard()
          } else if (!this.loading && this.text.length === 0) {
            Column({ space: 10 }) {
              Text('✨ 你可以输入：').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT)
              this.HintRow('📄', '课件 / 讲义长文本，一键提炼核心内容')
              this.HintRow('🎬', '视频字幕，快速了解视频要点')
              this.HintRow('📚', '教材章节，生成复习提纲')
            }
            .width('100%').padding(20)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
            .shadow(Theme.SHADOW_CARD)
          }
        }.padding(20)
        .constraintSize({ maxWidth: 640 })
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
  @Builder ResultCard() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('📄').fontSize(16)
        Text('摘要').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
        Blank()
        TagChip({ text: 'AI 生成' })
      }.width('100%')
      Text(this.result!.summary).fontSize(Theme.F_BODY)
        .fontColor(Theme.TEXT).width('100%').lineHeight(24)
    }
    .width('100%').padding(Theme.CARD_PAD)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
    if (this.result!.key_points.length > 0) {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text('💡').fontSize(16)
          Text('核心要点').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
        }.width('100%')
        ForEach(this.result!.key_points, (p: string, index: number) => {
          Row({ space: 10 }) {
            Text(`${index + 1}`)
              .fontSize(Theme.F_CAP).fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .width(22).height(22).textAlign(TextAlign.Center)
              .borderRadius(11).backgroundColor(Theme.PRIMARY)
            Text(p).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND).layoutWeight(1)
          }
          .width('100%').padding(10)
          .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_SM)
        })
      }
      .width('100%').padding(Theme.CARD_PAD)
      .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
      .shadow(Theme.SHADOW_CARD)
    }
  }
  @Builder HintRow(icon: string, text: string) {
    Row({ space: 10 }) {
      Text(icon).fontSize(14)
      Text(text).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).layoutWeight(1)
    }.width('100%')
  }
}
