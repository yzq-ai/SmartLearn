import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { api } from '../common/ApiClient';
import { Theme } from '../common/Theme';
import { FieldInput, PrimaryButton, PageHeader } from '../components/UiKit';
import { RegisterRequest } from '../common/Models';
import { tokenStore } from '../common/TokenStore';
@Entry
@Component
struct Register {
  @State username: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State realName: string = '';
  @State message: string = '';
  @State loading: boolean = false;
  @State headerOpacity: number = 0;
  @State cardOffset: number = 40;
  aboutToAppear(): void {
    animateTo({ duration: 600, curve: Curve.EaseOut, delay: 200 }, () => {
      this.headerOpacity = 1;
    });
    animateTo({ duration: 500, curve: Curve.FastOutSlowIn, delay: 400 }, () => {
      this.cardOffset = 0;
    });
  }
  private async signUp(): Promise<void> {
    if (this.username.length === 0 || this.password.length === 0 || this.realName.length === 0) {
      this.message = '请填写所有必填项';
      return;
    }
    if (this.password.length < 6) {
      this.message = '密码至少6位';
      return;
    }
    if (this.password !== this.confirmPassword) {
      this.message = '两次密码不一致';
      return;
    }
    this.loading = true;
    this.message = '';
    try {
      const req: RegisterRequest = {
        username: this.username,
        password: this.password,
        real_name: this.realName,
        role: 'student'
      };
      const result = await api.register(req);
      api.setToken(result.access_token);
      AppStorage.setOrCreate<string>('token', result.access_token);
      AppStorage.setOrCreate<string>('refresh_token', result.refresh_token);
      AppStorage.setOrCreate<string>('username', result.user.username);
      AppStorage.setOrCreate<string>('role', result.user.role);
      AppStorage.setOrCreate<string>('userId', String(result.user.id));
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await tokenStore.save(ctx);
      router.replaceUrl({
        url: result.pwd_changed === 0 ? 'pages/ChangePassword' : 'pages/Home'
      });
    } catch (error) {
      this.message = error instanceof Error ? error.message : '注册失败，请检查网络';
    }
    this.loading = false;
  }
  build() {
    Column() {
      PageHeader({ title: '创建账号', onBack: (): void => { router.replaceUrl({ url: 'pages/Login' }); } })
      Scroll() {
        Column({ space: 0 }) {
          Column({ space: 6 }) {
            Text('🎉 欢迎加入').fontSize(26).fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT).letterSpacing(1)
            Text('注册后即刻开启智慧学习之旅').fontSize(13)
              .fontColor(Theme.TEXT_HINT).letterSpacing(1)
          }
          .width('100%').alignItems(HorizontalAlign.Start)
          .padding({ left: 28, right: 28, top: 16, bottom: 20 })
          .opacity(this.headerOpacity)
          .translate({ y: this.headerOpacity === 1 ? 0 : 16 })
          Column({ space: 14 }) {
            FieldInput({
              placeholder: '用户名 / 学号',
              value: this.username,
              onChange: (v: string): void => { this.username = v; }
            })
            FieldInput({
              placeholder: '真实姓名',
              value: this.realName,
              onChange: (v: string): void => { this.realName = v; }
            })
            FieldInput({
              placeholder: '密码（至少6位）', value: this.password, isPassword: true,
              onChange: (v: string): void => { this.password = v; }
            })
            FieldInput({
              placeholder: '确认密码', value: this.confirmPassword, isPassword: true,
              onChange: (v: string): void => { this.confirmPassword = v; }
            })
            Column({ space: 6 }) {
              Row({ space: 8 }) {
                Text('🎓').fontSize(18)
                Text('学生账号').fontSize(Theme.F_SUB).fontColor(Theme.TEXT)
              }.width('100%')
              Text('注册将创建学生账号；教师与管理员账号请联系管理员开通')
                .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
            }
            .width('100%').padding(12)
            .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_MD)
            if (this.message.length > 0) {
              Row({ space: 6 }) {
                Text('⚠').fontSize(13)
                Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER)
              }
              .width('100%').padding(10)
              .backgroundColor(Theme.DANGER_LIGHT).borderRadius(Theme.R_SM)
            }
            PrimaryButton({
              label: '注 册', loading: this.loading,
              onTap: (): void => { this.signUp(); }
            })
            Row({ space: 4 }) {
              Text('已有账号？').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT)
              Text('去登录').fontSize(Theme.F_SUB).fontColor(Theme.PRIMARY)
                .onClick((): void => { router.replaceUrl({ url: 'pages/Login' }); })
            }.width('100%').justifyContent(FlexAlign.Center)
          }
          .width('100%').padding(24)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_XL)
          .shadow(Theme.SHADOW_CARD)
          .margin({ left: 20, right: 20 })
          .constraintSize({ maxWidth: 480 })
          .translate({ y: this.cardOffset })
          Text('注册即代表同意《用户协议》与《隐私政策》')
            .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
            .margin({ top: 16, bottom: 20 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
