import { router } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { PageHeader, FieldInput, PrimaryButton } from '../components/UiKit';
@Entry
@Component
struct ForgotPassword {
  @State step: number = 1;
  @State username: string = '';
  @State newPassword: string = '';
  @State confirm: string = '';
  @State message: string = '';
  private stepTitle(): string {
    if (this.step === 1) return '输入账号';
    if (this.step === 2) return '验证身份';
    return '设置新密码';
  }
  private next(): void {
    if (this.step === 1 && this.username.length === 0) {
      this.message = '请输入账号';
      return;
    }
    if (this.step === 3 && (this.newPassword.length < 8 || this.newPassword !== this.confirm)) {
      this.message = '密码至少 8 位且两次输入一致';
      return;
    }
    this.message = '';
    if (this.step < 3) {
      this.step += 1;
      animateTo({ duration: 250, curve: Curve.EaseOut }, () => {});
    } else {
      this.message = '✓ 密码已重置（演示环境）';
    }
  }
  private prev(): void {
    if (this.step > 1) { this.step -= 1; this.message = ''; }
  }
  build() {
    Column() {
      PageHeader({ title: '找回密码', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 20 }) {
          Column({ space: 16 }) {
            Text(this.step === 3 ? '🔐' : (this.step === 2 ? '🛡' : '👤'))
              .fontSize(40)
            Text(this.stepTitle())
              .fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White)
            Row({ space: 0 }) {
              this.StepDot(1)
              this.StepLine()
              this.StepDot(2)
              this.StepLine()
              this.StepDot(3)
            }.width('70%')
          }
          .width('100%').padding(28)
          .linearGradient({ angle: 145, colors: [[Theme.PRIMARY_DEEP, 0], [Theme.PRIMARY_GRADIENT, 1]] })
          .borderRadius(Theme.R_XL)
          .shadow(Theme.SHADOW_FLOAT)
          .alignItems(HorizontalAlign.Center)
          Column({ space: 16 }) {
            if (this.step === 1) {
              FieldInput({
                placeholder: '账号（学号 / 工号）',
                value: this.username,
                onChange: (v: string): void => { this.username = v; }
              })
              Text('输入注册时使用的账号，用于验证身份')
                .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
            } else if (this.step === 2) {
              Row({ space: 10 }) {
                Text('✅').fontSize(16)
                Column({ space: 2 }) {
                  Text('身份验证通过').fontSize(Theme.F_BODY)
                    .fontWeight(FontWeight.Medium).fontColor(Theme.SUCCESS)
                  Text(`账号：${this.username}（演示环境跳过验证码）`)
                    .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              }
              .width('100%').padding(14)
              .backgroundColor(Theme.SUCCESS_LIGHT).borderRadius(Theme.R_MD)
            } else {
              FieldInput({
                placeholder: '新密码（≥8 位）',
                value: this.newPassword, isPassword: true,
                onChange: (v: string): void => { this.newPassword = v; }
              })
              FieldInput({
                placeholder: '确认新密码',
                value: this.confirm, isPassword: true,
                onChange: (v: string): void => { this.confirm = v; }
              })
              if (this.confirm.length > 0) {
                Row({ space: 6 }) {
                  Text(this.newPassword === this.confirm ? '✓' : '✗')
                    .fontSize(Theme.F_CAP)
                    .fontColor(this.newPassword === this.confirm ? Theme.SUCCESS : Theme.DANGER)
                  Text(this.newPassword === this.confirm ? '两次输入一致' : '两次输入不一致')
                    .fontSize(Theme.F_CAP)
                    .fontColor(this.newPassword === this.confirm ? Theme.SUCCESS : Theme.DANGER)
                }.width('100%')
              }
            }
          }
          .width('100%').padding(Theme.CARD_PAD)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)
          if (this.message.length > 0 && this.message.indexOf('✓') < 0) {
            Row({ space: 6 }) {
              Text('⚠').fontSize(13)
              Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER)
            }
            .width('100%').padding(10)
            .backgroundColor(Theme.DANGER_LIGHT).borderRadius(Theme.R_SM)
          }
          if (this.message.indexOf('✓') >= 0) {
            Column({ space: 12 }) {
              Text('🎉').fontSize(48)
              Text('密码重置成功').fontSize(17).fontWeight(FontWeight.Bold)
                .fontColor(Theme.SUCCESS)
              Text('请使用新密码重新登录').fontSize(Theme.F_SUB)
                .fontColor(Theme.TEXT_HINT)
              Button('返回登录')
                .width('100%').height(48).fontSize(15)
                .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                .fontColor(Color.White)
                .borderRadius(Theme.R_MD)
                .onClick((): void => { router.back(); })
            }
            .width('100%').padding(24)
            .backgroundColor(Theme.SUCCESS_LIGHT).borderRadius(Theme.R_LG)
            .alignItems(HorizontalAlign.Center)
          }
          if (this.message.indexOf('✓') < 0) {
            Row({ space: 10 }) {
              if (this.step > 1) {
                Button('‹ 上一步')
                  .layoutWeight(1).height(48).fontSize(14)
                  .backgroundColor(Theme.CARD).fontColor(Theme.TEXT)
                  .borderRadius(Theme.R_MD)
                  .shadow(Theme.SHADOW_CARD)
                  .onClick((): void => { this.prev(); })
              }
              Button(this.step === 3 ? '完成重置' : '下一步 ›')
                .layoutWeight(this.step > 1 ? 2 : 1)
                .height(48).fontSize(15).fontWeight(FontWeight.Medium)
                .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                .fontColor(Color.White)
                .borderRadius(Theme.R_MD)
                .onClick((): void => { this.next(); })
            }.width('100%')
          }
        }.padding(20)
        .constraintSize({ maxWidth: 640 })
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
  @Builder StepDot(step: number) {
    Column() {
      Text(this.step >= step ? '✓' : `${step}`)
        .fontSize(12).fontWeight(FontWeight.Bold)
        .fontColor(this.step >= step ? Color.White : 'rgba(255,255,255,0.6)')
        .width(26).height(26).textAlign(TextAlign.Center)
        .borderRadius(13)
        .backgroundColor(this.step >= step
          ? 'rgba(255,255,255,0.35)' : 'rgba(255,255,255,0.12)')
    }
  }
  @Builder StepLine() {
    Column()
      .layoutWeight(1).height(2)
      .backgroundColor('rgba(255,255,255,0.25)')
      .margin({ left: 4, right: 4 })
  }
}
