import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Theme } from '../common/Theme';
import { FieldInput, PrimaryButton, PageHeader } from '../components/UiKit';
@Entry
@Component
struct ChangePassword {
  @State oldPassword: string = '';
  @State newPassword: string = '';
  @State confirm: string = '';
  @State message: string = '';
  @State loading: boolean = false;
  private strength(): number {
    let s: number = 0;
    if (this.newPassword.length >= 8) s += 1;
    if (/[A-Z]/.test(this.newPassword) || /[a-z]/.test(this.newPassword)) s += 1;
    if (/\d/.test(this.newPassword)) s += 1;
    return s;
  }
  private async submit(): Promise<void> {
    if (this.newPassword.length < 8) { this.message = '新密码至少 8 位'; return; }
    if (this.newPassword !== this.confirm) { this.message = '两次输入的新密码不一致'; return; }
    this.loading = true;
    this.message = '';
    try {
      await api.changePassword(this.oldPassword, this.newPassword);
      await api.logout();
      api.setToken('');
      AppStorage.delete('token');
      AppStorage.delete('refresh_token');
      AppStorage.delete('role');
      AppStorage.delete('username');
      AppStorage.delete('avatar');
      AppStorage.delete('userId');
      router.replaceUrl({ url: 'pages/Login' });
    } catch (error) {
      this.message = error instanceof Error ? error.message : '改密失败';
    }
    this.loading = false;
  }
  build() {
    Column() {
      PageHeader({ title: '修改密码', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 10 }) {
            Text('🔐').fontSize(52)
            Text('设置新密码').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
            Text('密码需包含字母和数字，至少 8 位')
              .fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT)
          }.width('100%').alignItems(HorizontalAlign.Center).padding({ top: 16, bottom: 8 })
          Column({ space: 14 }) {
            FieldInput({
              placeholder: '原密码', value: this.oldPassword, isPassword: true,
              onChange: (v: string): void => { this.oldPassword = v; }
            })
            FieldInput({
              placeholder: '新密码（≥8 位，含字母数字）',
              value: this.newPassword, isPassword: true,
              onChange: (v: string): void => { this.newPassword = v; }
            })
            Row({ space: 6 }) {
              ForEach([1, 2, 3], (i: number) => {
                Column()
                  .layoutWeight(1).height(4).borderRadius(2)
                  .backgroundColor(i <= this.strength() ? Theme.SUCCESS : Theme.DIVIDER)
              })
              Text(this.strength() <= 1 ? '弱' : (this.strength() === 2 ? '中' : '强'))
                .fontSize(Theme.F_CAP)
                .fontColor(this.strength() <= 1 ? Theme.DANGER
                  : (this.strength() === 2 ? Theme.WARNING : Theme.SUCCESS))
            }.width('100%')
            FieldInput({
              placeholder: '确认新密码', value: this.confirm, isPassword: true,
              onChange: (v: string): void => { this.confirm = v; }
            })
          }
          .width('100%').padding(20)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)
          if (this.message.length > 0) {
            Row({ space: 6 }) {
              Text('⚠').fontSize(13)
              Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER)
            }
            .width('100%').padding(10)
            .backgroundColor(Theme.DANGER_LIGHT).borderRadius(Theme.R_SM)
          }
          PrimaryButton({
            label: '确认修改', loading: this.loading,
            onTap: (): void => { this.submit(); }
          })
        }
        .constraintSize({ maxWidth: 560 })
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 24 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
