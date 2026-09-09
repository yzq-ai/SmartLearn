import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { api } from '../common/ApiClient';
import { Theme } from '../common/Theme';
import { PrimaryButton, showToast } from '../components/UiKit';
import { tokenStore } from '../common/TokenStore';
import { IBestSwitch, IBestCheckbox } from '@ibestservices/ibest-ui-v2';

@Entry
@Component
struct Login {
  @State username: string = '';
  @State password: string = '';
  @State message: string = '';
  @State loading: boolean = false;
  @State showPwd: boolean = false;
  @State remember: boolean = true;
  // 动效
  @State logoScale: number = 0.5;
  @State logoSpin: number = 0;
  @State headerOpacity: number = 0;
  @State cardOffset: number = 60;
  @State cardOpacity: number = 0;
  @State footOpacity: number = 0;
  // 呼吸光晕
  @State glowPulse: number = 1;
  @State socialScale: number = 1;
  // 错误抖动
  @State shakeX: number = 0;

  private shakeCard(): void {
    animateTo({ duration: 60, curve: Curve.EaseIn }, () => { this.shakeX = -10; });
    setTimeout((): void => { animateTo({ duration: 60 }, () => { this.shakeX = 10; }); }, 70);
    setTimeout((): void => { animateTo({ duration: 60 }, () => { this.shakeX = -6; }); }, 140);
    setTimeout((): void => { animateTo({ duration: 60, curve: Curve.EaseOut }, () => { this.shakeX = 0; }); }, 210);
  }

  aboutToAppear(): void {
    animateTo({ duration: 900, curve: Curve.Friction }, () => {
      this.logoScale = 1;
      this.logoSpin = 360;
    });
    animateTo({ duration: 700, curve: Curve.EaseOut, delay: 250 }, () => {
      this.headerOpacity = 1;
    });
    animateTo({ duration: 600, curve: Curve.FastOutSlowIn, delay: 450 }, () => {
      this.cardOffset = 0;
      this.cardOpacity = 1;
    });
    animateTo({ duration: 600, curve: Curve.EaseOut, delay: 800 }, () => {
      this.footOpacity = 1;
    });
    // 光晕缓慢呼吸（无限往返）
    animateTo({ duration: 3600, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.glowPulse = 1.18;
    });
  }

  private async signIn(): Promise<void> {
    if (this.username.length === 0 || this.password.length === 0) {
      this.message = '请输入账号和密码';
      this.shakeCard();
      return;
    }
    this.loading = true;
    this.message = '';
    try {
      const result = await api.login({ username: this.username, password: this.password });
      api.setToken(result.access_token);
      AppStorage.setOrCreate<string>('token', result.access_token);
      AppStorage.setOrCreate<string>('refresh_token', result.refresh_token);
      AppStorage.setOrCreate<string>('username', result.user.username);
      AppStorage.setOrCreate<string>('role', result.user.role);
      AppStorage.setOrCreate<string>('userId', String(result.user.id));
      // 立即落盘：进程被杀/重启后免登录
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await tokenStore.save(ctx);
      showToast('欢迎回来，' + result.user.username, 'success');
      router.replaceUrl({
        url: result.pwd_changed === 0 ? 'pages/ChangePassword' : 'pages/Home'
      });
    } catch (error) {
      this.message = error instanceof Error ? error.message : '登录失败，请检查网络';
      showToast(this.message, 'fail');
      this.shakeCard();
    }
    this.loading = false;
  }

  @Builder
  FancyField(placeholder: string, icon: string, isPwd: boolean) {
    Column({ space: 6 }) {
      Row({ space: 12 }) {
        Text(icon).fontSize(18)
        if (isPwd) {
          TextInput({ placeholder: placeholder, text: this.password })
            .type(this.showPwd ? InputType.Normal : InputType.Password)
            .layoutWeight(1).height(48)
            .fontSize(15).placeholderFont({ size: 15, weight: FontWeight.Normal })
            .placeholderColor(Theme.TEXT_HINT)
            .fontColor(Theme.TEXT)
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .padding({ left: 0, right: 0 })
            .caretColor(Theme.PRIMARY)
            .onChange((v: string) => this.password = v)
          Text(this.showPwd ? '🙈' : '👁')
            .fontSize(18)
            .onClick((): void => {
              animateTo({ duration: 150 }, () => { this.showPwd = !this.showPwd; });
            })
        } else {
          TextInput({ placeholder: placeholder, text: this.username })
            .layoutWeight(1).height(48)
            .fontSize(15).placeholderFont({ size: 15, weight: FontWeight.Normal })
            .placeholderColor(Theme.TEXT_HINT)
            .fontColor(Theme.TEXT)
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .padding({ left: 0, right: 0 })
            .caretColor(Theme.PRIMARY)
            .onChange((v: string) => this.username = v)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 14 })
      .backgroundColor(Theme.INPUT_BG)
      .borderRadius(16)
    }
  }

  @Builder
  SocialBtn(icon: string, label: string) {
    Column({ space: 5 }) {
      Text(icon).fontSize(24)
      Text(label).fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.5)')
    }
    .padding(10).borderRadius(Theme.R_LG)
    .backgroundColor('rgba(255,255,255,0.10)')
    .animation({ curve: Curve.EaseOut })
    .scale({ x: this.socialScale, y: this.socialScale })
    .onClick((): void => {
      animateTo({ duration: 120 }, () => { this.socialScale = 0.92; });
      setTimeout((): void => { animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.socialScale = 1; }); }, 130);
    })
  }

  build() {
    Stack() {
      // ═══ 背景：深色渐变天空 + 双浮动光晕 ═══
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#1B2A6B', 0], [Theme.PRIMARY_DEEP, 0.42], ['#3D5AFE', 1]]
        })
      // 光晕 A（左上，紫）
      Column().width(420).height(420).borderRadius(210)
        .linearGradient({ angle: 135, colors: [['rgba(124,77,255,0.45)', 0], ['rgba(124,77,255,0)', 1]] })
        .margin({ top: -160, left: -150 })
        .scale({ x: this.glowPulse, y: this.glowPulse })
      // 光晕 B（右中，青）
      Column().width(360).height(360).borderRadius(180)
        .linearGradient({ angle: 135, colors: [['rgba(0,229,255,0.28)', 0], ['rgba(0,229,255,0)', 1]] })
        .margin({ top: 500, left: 900 })
        .scale({ x: 2 - this.glowPulse, y: 2 - this.glowPulse })
      // 光晕 C（底部中央，粉）
      Column().width(460).height(460).borderRadius(230)
        .linearGradient({ angle: 160, colors: [['rgba(255,94,120,0.20)', 0], ['rgba(255,94,120,0)', 1]] })
        .margin({ top: 2200, left: 420 })
        .scale({ x: this.glowPulse, y: this.glowPulse })

      Scroll() {
        Column({ space: 0 }) {
          // ═══ 品牌区（logo + 双行标语）═══
          Column({ space: 14 }) {
            Stack({ alignContent: Alignment.BottomEnd }) {
              Column()
                .width(96).height(96).borderRadius(30)
                .linearGradient({ angle: 140, colors: [['#7C4DFF', 0], ['#3D5AFE', 1]] })
                .shadow({ radius: 30, color: 'rgba(61,90,254,0.55)', offsetY: 12 })
                .rotate({ angle: this.logoSpin })
                .scale({ x: this.logoScale, y: this.logoScale })
                .animation({ curve: Curve.Friction })
              Image($r('app.media.app_icon')).width(96).height(96).borderRadius(30)
                .scale({ x: this.logoScale, y: this.logoScale })
              // 小徽标
              Column()
                .width(28).height(28).borderRadius(14)
                .backgroundColor('#2BE0A5')
                .border({ width: 3, color: '#FFFFFF' })
                .margin({ right: -2, bottom: -2 })
            }
            Column({ space: 6 }) {
              Text('鸿蒙智学业')
                .fontSize(34).fontWeight(FontWeight.Bold)
                .fontColor(Color.White).letterSpacing(3)
              Text('智启学业 · 航向未来')
                .fontSize(14).fontColor('rgba(255,255,255,0.72)').letterSpacing(2)
                .maxLines(1)
            }.alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 90, bottom: 36 })
          .opacity(this.headerOpacity)
          .translate({ y: this.headerOpacity === 1 ? 0 : 24 })

          // ═══ 主卡片（悬浮玻璃感）═══
          Column({ space: 18 }) {
            // 卡片头
            Row({ space: 8 }) {
              Text('欢迎回来').fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
              Blank()
              Column().width(6).height(6).borderRadius(3).backgroundColor('#3D5AFE')
              Column().width(6).height(6).borderRadius(3).backgroundColor('#7C4DFF')
              Column().width(6).height(6).borderRadius(3).backgroundColor('#2BE0A5')
            }.width('100%')

            this.FancyField('用户名 / 用户号（SL 开头）', '👤', false)
            this.FancyField('密码', '🔒', true)

            // 错误提示
            if (this.message.length > 0) {
              Row({ space: 6 }) {
                Text('⚠').fontSize(13)
                Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER).layoutWeight(1)
              }
              .width('100%').padding(12)
              .backgroundColor(Theme.DANGER_LIGHT).borderRadius(Theme.R_MD)
            }

            // 记住我 / 忘记密码（IBestCheckbox）
            Row() {
              Row({ space: 8 }) {
                IBestCheckbox({
                  value: this.remember,
                  onChange: (v: boolean | number): void => { this.remember = v === true; },
                } as ESObject)
                Text('记住我').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
              }
              Blank()
              Text('忘记密码？').fontSize(Theme.F_SUB).fontColor(Theme.PRIMARY)
                .onClick((): void => { router.pushUrl({ url: 'pages/ForgotPassword' }); })
            }.width('100%')

            PrimaryButton({
              label: '登 录', loading: this.loading,
              onTap: (): void => { this.signIn(); }
            })

            // ═══ 注册引导（醒目大按钮）═══
            Button('还没有账号？立即注册 →')
              .width('100%').height(48)
              .fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor(Theme.PRIMARY)
              .backgroundColor(Theme.PRIMARY_LIGHT)
              .borderRadius(16)
              .onClick((): void => { router.replaceUrl({ url: 'pages/Register' }); })
          }
          .width('100%').padding(24)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_XL)
          .shadow({ radius: 40, color: 'rgba(10,18,45,0.35)', offsetY: 18 })
          .margin({ left: 20, right: 20, bottom: 8 })
          .constraintSize({ maxWidth: 480 })
          .translate({ y: this.cardOffset, x: this.shakeX })
          .opacity(this.cardOpacity)

          // ═══ 底部第三方登录装饰 ═══
          Column({ space: 14 }) {
            Row({ space: 12 }) {
              Column().width(60).height(1).backgroundColor('rgba(255,255,255,0.3)')
              Text('其他登录方式').fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.55)')
              Column().width(60).height(1).backgroundColor('rgba(255,255,255,0.3)')
            }
            Row({ space: 18 }) {
              this.SocialBtn('💬', '华为账号')
              this.SocialBtn('📱', '本机号码')
              this.SocialBtn('📮', '邮箱验证')
            }
            Text('登录即代表同意《用户协议》与《隐私政策》')
              .fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.45)')
              .margin({ top: 10, bottom: 26 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 22 })
          .opacity(this.footOpacity)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%').height('100%')
      .scrollBar(BarState.Off).align(Alignment.Top)
    }
    .width('100%').height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
