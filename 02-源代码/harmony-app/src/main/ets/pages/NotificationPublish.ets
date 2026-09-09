import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Theme } from '../common/Theme';
import { PageHeader, Card, PrimaryButton } from '../components/UiKit';

@Entry
@Component
struct NotificationPublish {
  @State title: string = '';
  @State content: string = '';
  @State targetRole: string = 'ALL';
  @State message: string = '';
  @State sending: boolean = false;

  private async send(): Promise<void> {
    if (this.title.length === 0 || this.content.length === 0) {
      this.message = '请填写标题与内容';
      return;
    }
    this.sending = true;
    this.message = '';
    try {
      await api.publishNotification(this.title, this.content, this.targetRole);
      this.title = '';
      this.content = '';
      this.message = '✓ 通知已发布';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '发布失败';
    }
    this.sending = false;
  }

  build() {
    Column() {
      PageHeader({ title: '发布通知', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          Row({ space: 12 }) {
            Text('📢').fontSize(26)
            Column({ space: 3 }) {
              Text('发布新通知').fontSize(16).fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
              Text('支持按角色定向推送')
                .fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.8)')
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }
          .width('100%').padding(20)
          .linearGradient({ angle: 140, colors: [[Theme.PRIMARY_DEEP, 0], [Theme.PRIMARY_GRADIENT, 1]] })
          .borderRadius(Theme.R_XL)
          .shadow(Theme.SHADOW_FLOAT)
          Card() {
            Column({ space: 14 }) {
              this.FormField('通知标题', '如：期末考试安排通知', this.title,
                (v: string): void => { this.title = v; })
              Column({ space: 6 }) {
                Text('通知内容').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                TextArea({ placeholder: '填写通知正文…', text: this.content })
                  .onChange((v: string): void => { this.content = v; })
                  .width('100%').height(120).fontSize(14)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                  .caretColor(Theme.PRIMARY)
              }.width('100%')
              Column({ space: 8 }) {
                Text('推送对象').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                Row({ space: 8 }) {
                  this.RoleChip('全体', 'ALL', '👥')
                  this.RoleChip('学生', 'STUDENT', '🎓')
                  this.RoleChip('教师', 'TEACHER', '👩‍🏫')
                }.width('100%')
              }.width('100%')
            }.width('100%')
          }
          if (this.title.length > 0 || this.content.length > 0) {
            Column({ space: 8 }) {
              Text('📋 预览').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
              Row({ space: 10 }) {
                Text('📢').fontSize(16)
                  .width(36).height(36).textAlign(TextAlign.Center)
                  .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(18)
                Column({ space: 3 }) {
                  Text(this.title.length > 0 ? this.title : '（标题）')
                    .fontSize(Theme.F_BODY).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                  Text(this.content.length > 0 ? this.content : '（内容）')
                    .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).maxLines(2)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              }
              .width('100%').padding(12)
              .backgroundColor(Theme.BG).borderRadius(Theme.R_MD)
            }
            .width('100%').padding(Theme.CARD_PAD)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
            .shadow(Theme.SHADOW_CARD)
          }
          PrimaryButton({
            label: '📢 发布通知', loading: this.sending,
            onTap: (): void => { this.send(); }
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

  @Builder RoleChip(label: string, value: string, icon: string) {
    Row({ space: 5 }) {
      Text(icon).fontSize(13)
        .fontColor(this.targetRole === value ? Color.White : Theme.TEXT_SECOND)
      Text(label).fontSize(Theme.F_SUB).fontWeight(FontWeight.Medium)
        .fontColor(this.targetRole === value ? Color.White : Theme.TEXT_SECOND)
    }
    .layoutWeight(1).height(40).justifyContent(FlexAlign.Center)
    .backgroundColor(this.targetRole === value ? Theme.PRIMARY : Theme.BG)
    .borderRadius(Theme.R_SM)
    .onClick((): void => { this.targetRole = value; })
  }
}
