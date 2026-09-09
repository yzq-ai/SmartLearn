import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Theme } from '../common/Theme';
import { PageHeader, Card, PrimaryButton } from '../components/UiKit';
@Entry
@Component
struct AssignmentEdit {
  @State courseId: number = 1;
  @State title: string = '';
  @State description: string = '';
  @State maxScore: number = 100;
  @State deadline: string = '2026-12-31T23:59:59';
  @State message: string = '';
  @State sending: boolean = false;
  private formValid(): boolean {
    return this.title.length > 0 && this.description.length > 0;
  }
  private async submit(): Promise<void> {
    if (this.title.length === 0) { this.message = '请填写作业标题'; return; }
    this.sending = true;
    this.message = '';
    try {
      await api.createAssignment(this.courseId, this.title, this.description,
        this.maxScore, this.deadline);
      this.title = '';
      this.description = '';
      this.message = '✓ 作业已发布';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '发布失败';
    }
    this.sending = false;
  }
  build() {
    Column() {
      PageHeader({ title: '发布作业', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          Row({ space: 12 }) {
            Text('📝').fontSize(26)
            Column({ space: 3 }) {
              Text('创建新作业').fontSize(16).fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
              Text('填写作业信息，发布后学生端立即可见')
                .fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.8)')
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }
          .width('100%').padding(20)
          .linearGradient({ angle: 140, colors: [[Theme.PRIMARY_DEEP, 0], [Theme.PRIMARY_GRADIENT, 1]] })
          .borderRadius(Theme.R_XL)
          .shadow(Theme.SHADOW_FLOAT)
          Card() {
            Column({ space: 14 }) {
              Text('基本信息').fontSize(16).fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT).width('100%')
              this.FormField('课程 ID', '如：1', `${this.courseId}`,
                (v: string): void => { this.courseId = Number(v); })
              this.FormField('作业标题', '请输入作业标题', this.title,
                (v: string): void => { this.title = v; })
              Column({ space: 6 }) {
                Text('作业描述').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                TextArea({ placeholder: '描述作业要求、提交格式等…', text: this.description })
                  .onChange((v: string): void => { this.description = v; })
                  .width('100%').height(110).fontSize(14)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                  .caretColor(Theme.PRIMARY)
              }.width('100%')
            }.width('100%')
          }
          Card() {
            Column({ space: 14 }) {
              Text('评分设置').fontSize(16).fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT).width('100%')
              Row({ space: 10 }) {
                Column({ space: 6 }) {
                  Text('满分分值').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  TextInput({ text: `${this.maxScore}` })
                    .type(InputType.Number)
                    .onChange((v: string): void => { this.maxScore = Number(v); })
                    .width('100%').height(44).fontSize(14)
                    .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                    .caretColor(Theme.PRIMARY)
                }.layoutWeight(1)
                Column({ space: 6 }) {
                  Text('截止时间').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  TextInput({ text: this.deadline })
                    .onChange((v: string): void => { this.deadline = v; })
                    .width('100%').height(44).fontSize(13)
                    .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                    .caretColor(Theme.PRIMARY)
                }.layoutWeight(2)
              }.width('100%')
              Row({ space: 8 }) {
                Text('快捷设置：').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                this.QuickChip('3 天', 72)
                this.QuickChip('7 天', 168)
                this.QuickChip('14 天', 336)
              }.width('100%')
            }.width('100%')
          }
          PrimaryButton({
            label: '🚀 发布作业', loading: this.sending,
            isDisabled: !this.formValid(),
            onTap: (): void => { this.submit(); }
          })
          if (!this.formValid()) {
            Text('请填写作业标题与描述后发布').fontSize(Theme.F_CAP)
              .fontColor(Theme.TEXT_HINT).width('100%').textAlign(TextAlign.Center)
          }
          if (this.message.length > 0) {
            Text(this.message).fontSize(Theme.F_SUB)
              .fontColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
              .width('100%').textAlign(TextAlign.Center)
              .margin({ bottom: 24 })
          }
        }.padding(20)
        .constraintSize({ maxWidth: 640 })
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
  @Builder FormField(label: string, placeholder: string, value: string, onChange: (v: string) => void) {
    Column({ space: 6 }) {
      Text(label).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
      TextInput({ placeholder: placeholder, text: value })
        .onChange((v: string): void => { onChange(v); })
        .width('100%').height(46).fontSize(14)
        .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
        .caretColor(Theme.PRIMARY)
    }.width('100%')
  }
  @Builder QuickChip(label: string, hours: number) {
    Text(label)
      .fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(12)
      .onClick((): void => {
        const d: Date = new Date(Date.now() + hours * 3600 * 1000);
        const pad = (n: number): string => `${n < 10 ? '0' : ''}${n}`;
        this.deadline = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T23:59:59`;
      })
  }
}
