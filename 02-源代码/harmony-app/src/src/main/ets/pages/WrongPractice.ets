import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { WrongQuestion } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, TagChip } from '../components/UiKit';
@Entry
@Component
struct WrongPractice {
  @State rows: WrongQuestion[] = [];
  @State answer: string = '';
  @State feedback: string = '';
  @State loading: boolean = true;
  @State message: string = '';
  @State correctCount: number = 0;
  @State totalCount: number = 0;
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    this.loading = true;
    this.message = '';
    try { this.rows = await api.getWrongQuestions(); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }
  private check(row: WrongQuestion): void {
    const mine: string = this.answer.trim().toLowerCase();
    const correct: string = row.correct_answer.trim().toLowerCase();
    if (mine.length === 0) { this.feedback = '请输入答案'; return; }
    this.totalCount += 1;
    if (mine === correct) {
      this.correctCount += 1;
      this.feedback = '✓ 回答正确，真棒！';
    } else {
      this.feedback = `✗ 错误，正确答案：${row.correct_answer}`;
    }
    this.answer = '';
  }
  private accuracy(): number {
    if (this.totalCount === 0) return 0;
    return Math.round(this.correctCount / this.totalCount * 100);
  }
  build() {
    Column() {
      PageHeader({ title: '错题重练', onBack: (): void => { router.back(); } })
      if (this.totalCount > 0) {
        Row({ space: 12 }) {
          Column({ space: 2 }) {
            Text('已练').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
            Text(`${this.totalCount}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
          }.layoutWeight(1)
          Column({ space: 2 }) {
            Text('答对').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
            Text(`${this.correctCount}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.SUCCESS)
          }.layoutWeight(1)
          Column({ space: 2 }) {
            Text('正确率').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
            Text(`${this.accuracy()}%`).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
          }.layoutWeight(1)
        }
        .width('100%').padding(14)
        .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
        .shadow(Theme.SHADOW_CARD)
        .margin({ left: 20, right: 20, bottom: 4 })
      }
      if (this.loading) {
        Column({ space: 12 }) { SkeletonCard(); SkeletonCard() }.padding(20)
      } else if (this.rows.length === 0) {
        EmptyState({ icon: '🎉', text: '没有需要重练的错题' })
      } else {
        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.rows, (row: WrongQuestion, index: number) => {
              Column({ space: 10 }) {
                Row({ space: 8 }) {
                  Text(`第 ${index + 1} 题`).fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                    .fontWeight(FontWeight.Bold)
                  TagChip({ text: row.question_type ?? '题目', tone: 'primary' })
                  Blank()
                  Text(`错 ${row.wrong_count} 次`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                }.width('100%')
                Text(row.question_text).fontSize(Theme.F_BODY)
                  .fontWeight(FontWeight.Medium).fontColor(Theme.TEXT).width('100%')
                TextInput({ placeholder: '输入你的答案', text: this.answer })
                  .onChange((v: string): void => { this.answer = v; })
                  .width('100%').height(44).fontSize(14)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                  .caretColor(Theme.PRIMARY)
                Button('判分')
                  .width('100%').height(40).fontSize(14)
                  .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                  .fontColor(Color.White).borderRadius(Theme.R_MD)
                  .onClick((): void => { this.check(row); })
              }
              .width('100%').padding(Theme.CARD_PAD)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            })
            if (this.feedback.length > 0) {
              Text(this.feedback)
                .fontSize(Theme.F_BODY).fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .width('100%').textAlign(TextAlign.Center)
                .padding(14)
                .linearGradient({
                  angle: 135,
                  colors: this.feedback.indexOf('✓') >= 0
                    ? [[Theme.SUCCESS, 0], ['#3ECF8E', 1]]
                    : [[Theme.DANGER, 0], ['#FF7A7E', 1]]
                })
                .borderRadius(Theme.R_LG)
                .shadow(Theme.SHADOW_FLOAT)
            }
          }.padding(20)
          .constraintSize({ maxWidth: 640 })
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
      if (this.message.length > 0) {
        Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER).padding(8)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
