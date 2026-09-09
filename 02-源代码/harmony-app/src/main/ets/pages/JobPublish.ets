import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Theme } from '../common/Theme';
import { PageHeader, Card, PrimaryButton } from '../components/UiKit';
@Entry
@Component
struct JobPublish {
  @State title: string = '';
  @State company: string = '';
  @State description: string = '';
  @State skills: string = '';
  @State message: string = '';
  @State sending: boolean = false;
  private async submit(): Promise<void> {
    if (this.title.length === 0 || this.company.length === 0 || this.description.length === 0) {
      this.message = '请填写标题、企业与描述';
      return;
    }
    this.sending = true;
    this.message = '';
    const requiredSkills: string[] = this.skills.length > 0 ? this.skills.split(',') : [];
    try {
      await api.createJob(this.title, this.company, this.description, requiredSkills);
      this.title = '';
      this.company = '';
      this.description = '';
      this.skills = '';
      this.message = '✓ 岗位已提交，待管理员审核后发布';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '提交失败';
    }
    this.sending = false;
  }
  build() {
    Column() {
      PageHeader({ title: '发布岗位', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          Row({ space: 12 }) {
            Text('💼').fontSize(26)
            Column({ space: 3 }) {
              Text('发布新岗位').fontSize(16).fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
              Text('提交后需管理员审核（先审后发）')
                .fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.8)')
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }
          .width('100%').padding(20)
          .linearGradient({ angle: 140, colors: [[Theme.PRIMARY_DEEP, 0], [Theme.PRIMARY_GRADIENT, 1]] })
          .borderRadius(Theme.R_XL)
          .shadow(Theme.SHADOW_FLOAT)
          Card() {
            Column({ space: 14 }) {
              Text('岗位信息').fontSize(16).fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT).width('100%')
              this.FormField('岗位标题', '如：Python 后端开发工程师', this.title,
                (v: string): void => { this.title = v; })
              this.FormField('企业名称', '如：智云科技', this.company,
                (v: string): void => { this.company = v; })
              Column({ space: 6 }) {
                Text('技能要求（逗号分隔）').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                TextInput({ placeholder: '如：Python,FastAPI,MySQL', text: this.skills })
                  .onChange((v: string): void => { this.skills = v; })
                  .width('100%').height(46).fontSize(14)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                  .caretColor(Theme.PRIMARY)
                if (this.skills.length > 0) {
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.skills.split(','), (s: string) => {
                      if (s.trim().length > 0) {
                        Text(s.trim()).fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                          .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(10)
                          .margin({ right: 6, bottom: 4 })
                      }
                    })
                  }.width('100%')
                }
              }.width('100%')
              Column({ space: 6 }) {
                Text('岗位描述').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                TextArea({ placeholder: '岗位职责、任职要求、薪资范围…', text: this.description })
                  .onChange((v: string): void => { this.description = v; })
                  .width('100%').height(120).fontSize(14)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                  .caretColor(Theme.PRIMARY)
              }.width('100%')
            }.width('100%')
          }
          Row({ space: 10 }) {
            Text('ℹ️').fontSize(14)
            Text('岗位发布流程：提交 → 管理员审核 → 上架展示')
              .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND).layoutWeight(1)
          }
          .width('100%').padding(12)
          .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_SM)
          PrimaryButton({
            label: '📤 提交审核', loading: this.sending,
            onTap: (): void => { this.submit(); }
          })
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
}
