import { router } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
@Entry
@Component
struct Splash {
  @State logoScale: number = 0.6;
  @State contentOpacity: number = 0;
  @State btnOpacity: number = 0;
  @State ringPulse: number = 1;
  aboutToAppear(): void {
    animateTo({ duration: 800, curve: Curve.Friction, delay: 100 }, () => {
      this.logoScale = 1.0;
      this.contentOpacity = 1;
    });
    animateTo({ duration: 600, curve: Curve.EaseOut, delay: 1200 }, () => {
      this.btnOpacity = 1;
    });
    // 背景装饰圈缓慢呼吸
    animateTo({ duration: 3200, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.ringPulse = 1.15;
    });
    // 渐进检查持久化 token（PersistentStorage 恢复为异步，最多重试 4 次）
    // 首查 2.2s：让入场动画（logo 800ms + 标语 1.2s）完整呈现后再路由
    setTimeout((): void => { this.autoRoute(0); }, 2200);
  }
  private autoRoute(retry: number): void {
    const token: string = AppStorage.get<string>('token') ?? '';
    if (token.length > 0) {
      router.replaceUrl({ url: 'pages/Home' });
      return;
    }
    if (retry < 4) {
      setTimeout((): void => { this.autoRoute(retry + 1); }, 1000);
    } else {
      // 重试耗尽仍无 token → 动画已完整播放，进入登录页
      router.replaceUrl({ url: 'pages/Login' });
    }
  }
  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width(360).height(360).borderRadius(180)
        .backgroundColor('rgba(255,255,255,0.06)')
        .margin({ top: -200, left: -140 })
        .scale({ x: this.ringPulse, y: this.ringPulse })
      Column().width(260).height(260).borderRadius(130)
        .backgroundColor('rgba(255,255,255,0.04)')
        .margin({ bottom: -180, right: -120 })
        .scale({ x: 2 - this.ringPulse, y: 2 - this.ringPulse })
      Column().width(180).height(180).borderRadius(90)
        .backgroundColor('rgba(255,255,255,0.05)')
        .margin({ top: 60, right: -80 })
        .scale({ x: this.ringPulse, y: this.ringPulse })
      Column({ space: 16 }) {
        Column() {
          Image($r('app.media.app_icon')).width(100).height(100).borderRadius(26)
        }
        .padding(22)
        .backgroundColor('rgba(255,255,255,0.18)')
        .borderRadius(Theme.R_XL)
        .scale({ x: this.logoScale, y: this.logoScale })
        .shadow({ radius: 40, color: 'rgba(0,0,0,0.3)', offsetY: 14 })
        Column({ space: 6 }) {
          Text('鸿蒙智学业').fontSize(36).fontWeight(FontWeight.Bold)
            .fontColor(Color.White).letterSpacing(4)
          Text('智启学业 · 航向未来').fontSize(15)
            .fontColor('rgba(255,255,255,0.7)').letterSpacing(6)
        }.opacity(this.contentOpacity)
        Column({ space: 14 }) {
          Button('登 录')
            .width(260).height(52).fontSize(17).fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor('rgba(255,255,255,0.22)')
            .borderRadius(Theme.R_MD)
            .shadow({ radius: 12, color: 'rgba(255,255,255,0.15)', offsetY: 4 })
            .onClick((): void => { router.replaceUrl({ url: 'pages/Login' }); })
          Button('注 册')
            .width(260).height(52).fontSize(17).fontWeight(FontWeight.Medium)
            .fontColor(Theme.PRIMARY_DEEP)
            .backgroundColor(Color.White)
            .borderRadius(Theme.R_MD)
            .shadow({ radius: 16, color: 'rgba(0,0,0,0.1)', offsetY: 6 })
            .onClick((): void => { router.replaceUrl({ url: 'pages/Register' }); })
        }
        .margin({ top: 36 })
        .opacity(this.btnOpacity)
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%').height('100%')
    .linearGradient({
      angle: 150,
      colors: [[Theme.PRIMARY_DEEP, 0], [Theme.PRIMARY, 0.45], [Theme.PRIMARY_GRADIENT, 1]]
    })
  }
}
