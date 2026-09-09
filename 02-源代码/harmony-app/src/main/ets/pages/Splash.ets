import { router, curves } from '@kit.ArkUI';
import { Theme } from '../common/Theme';

// ═══ 星尘粒子（伪随机固定布局，避免每帧重算）═══
class Star {
  x: number = 0;      // 0~1000 百分比坐标
  y: number = 0;
  size: number = 2;
  delay: number = 0;
  dur: number = 2000;
  drift: number = 0;  // 水平漂移
}

@Entry
@Component
struct Splash {
  // Logo 弹性入场（弹簧曲线三段）
  @State logoScale: number = 0.3;
  @State logoRotate: number = -30;
  // 逐字标题（5 字依次浮现）
  @State titleChars: number[] = [0, 0, 0, 0, 0];
  // 副标语 & 徽标 & 按钮 & 进度
  @State subOpacity: number = 0;
  @State btnOpacity: number = 0;
  @State btnOffset: number = 30;
  @State shineX: number = -220;         // 流光扫描位置
  @State ringPulse: number = 1;
  @State starOpacity: number = 0;
  @State ringRotate: number = 0;        // 装饰环旋转
  @State leaveScale: number = 1;        // 离场缩放
  @State leaveOpacity: number = 1;
  @State isLeaving: boolean = false;
  // 粒子
  private stars: Star[] = [];

  aboutToAppear(): void {
    // 固定种子伪随机（每次启动星空一致）
    let seed: number = 42;
    const rand = (): number => {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280;
    };
    for (let i = 0; i < 26; i++) {
      const s = new Star();
      s.x = Math.round(rand() * 960);
      s.y = Math.round(rand() * 2100);
      s.size = rand() > 0.75 ? 4 : (rand() > 0.5 ? 3 : 2);
      s.delay = Math.round(rand() * 900);
      s.dur = 1600 + Math.round(rand() * 1600);
      s.drift = Math.round(rand() * 30 - 15);
      this.stars.push(s);
    }

    // ① 星空淡入
    animateTo({ duration: 1400, curve: Curve.EaseOut }, () => { this.starOpacity = 1; });

    // ② Logo 弹簧入场：缩放 + 旋转 + 微回弹（springMotion 手感）
    this.getUIContext().animateTo({ duration: 950, curve: curves.springMotion(0.42, 0.9) }, () => {
      this.logoScale = 1;
      this.logoRotate = 0;
    });

    // ③ 标题逐字浮现（每字间隔 110ms，从第 500ms 起）
    for (let i = 0; i < 5; i++) {
      const idx = i;
      setTimeout((): void => {
        animateTo({ duration: 420, curve: Curve.FastOutSlowIn }, () => { this.titleChars[idx] = 1; });
      }, 500 + i * 110);
    }

    // ④ 副标语 + 进度流光
    animateTo({ duration: 600, curve: Curve.EaseOut, delay: 1150 }, () => { this.subOpacity = 1; });
    animateTo({ duration: 1700, curve: Curve.EaseInOut, delay: 1150, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.shineX = 220;
    });

    // ⑤ 按钮上浮淡入
    animateTo({ duration: 550, curve: Curve.FastOutSlowIn, delay: 1500 }, () => {
      this.btnOpacity = 1;
      this.btnOffset = 0;
    });

    // ⑥ 呼吸光环（无限往返）+ 装饰环恒速旋转
    animateTo({ duration: 3000, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.ringPulse = 1.14;
    });
    animateTo({ duration: 22000, curve: Curve.Linear, iterations: -1 }, () => { this.ringRotate = 360; });

    // ⑦ 自动路由：token 存在 → Home；重试后无 token → 登录页
    setTimeout((): void => { this.autoRoute(0); }, 2600);
  }

  private go(url: string): void {
    if (this.isLeaving) { return; }
    this.isLeaving = true;
    // 离场转场：整页缩放淡出
    this.getUIContext().animateTo({ duration: 420, curve: Curve.Friction }, () => {
      this.leaveScale = 1.12;
      this.leaveOpacity = 0;
    });
    setTimeout((): void => { router.replaceUrl({ url }); }, 380);
  }

  private autoRoute(retry: number): void {
    const token: string = AppStorage.get<string>('token') ?? '';
    if (token.length > 0) {
      this.go('pages/Home');
      return;
    }
    if (retry < 3) {
      setTimeout((): void => { this.autoRoute(retry + 1); }, 1000);
    } else {
      this.go('pages/Login');
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // ═══ 背景层：深夜渐变天空 ═══
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 170,
          colors: [['#10173F', 0], ['#1B2A6B', 0.38], [Theme.PRIMARY_DEEP, 0.7], ['#3D5AFE', 1]]
        })

      // ═══ 星尘层：伪随机 26 粒（独立闪烁）═══
      ForEach(this.stars, (s: Star, idx: number) => {
        Column()
          .width(s.size).height(s.size).borderRadius(s.size / 2)
          .backgroundColor(idx % 5 === 0 ? '#9FB4FF' : '#FFFFFF')
          .opacity(this.starOpacity * 0.85)
          .position({ x: `${s.x / 10}%`, y: `${s.y / 21.2}%` })
          .translate({ x: s.drift })
          .animation({ duration: s.dur, curve: Curve.EaseInOut, delay: s.delay, iterations: -1, playMode: PlayMode.Alternate })
          .scale({ x: idx % 3 === 0 ? 0.6 : 1, y: idx % 3 === 0 ? 0.6 : 1 })
      }, (s: Star, idx: number) => `star-${idx}`)

      // ═══ 大光晕：三团呼吸雾 ═══
      Column().width(460).height(460).borderRadius(230)
        .linearGradient({ angle: 135, colors: [['rgba(124,77,255,0.42)', 0], ['rgba(124,77,255,0)', 1]] })
        .margin({ top: -260, left: -180 })
        .scale({ x: this.ringPulse, y: this.ringPulse })
      Column().width(380).height(380).borderRadius(190)
        .linearGradient({ angle: 135, colors: [['rgba(0,229,255,0.22)', 0], ['rgba(0,229,255,0)', 1]] })
        .margin({ top: 560, left: 780 })
        .scale({ x: 2 - this.ringPulse, y: 2 - this.ringPulse })
      Column().width(420).height(420).borderRadius(210)
        .linearGradient({ angle: 160, colors: [['rgba(255,94,120,0.16)', 0], ['rgba(255,94,120,0)', 1]] })
        .margin({ top: 1900, left: 480 })
        .scale({ x: this.ringPulse, y: this.ringPulse })

      // ═══ 主体内容 ═══
      Column({ space: 20 }) {
        // ── Logo 组合：旋转装饰环 + 玻璃底座 + 图标 ──
        Stack({ alignContent: Alignment.Center }) {
          // 外环（虚线旋转）
          Column().width(148).height(148).borderRadius(74)
            .border({ width: 1.2, color: 'rgba(255,255,255,0.35)', style: BorderStyle.Dashed })
            .rotate({ angle: this.ringRotate })
          // 呼吸光环
          Column().width(136).height(136).borderRadius(68)
            .backgroundColor('rgba(255,255,255,0.08)')
            .scale({ x: this.ringPulse, y: this.ringPulse })
          // 玻璃底座 + 品牌渐变
          Column().width(108).height(108).borderRadius(34)
            .linearGradient({ angle: 140, colors: [['#7C4DFF', 0], ['#3D5AFE', 1]] })
            .shadow({ radius: 44, color: 'rgba(61,90,254,0.65)', offsetY: 16 })
            .scale({ x: this.logoScale, y: this.logoScale })
            .rotate({ angle: this.logoRotate })
          Image($r('app.media.app_icon'))
            .width(108).height(108).borderRadius(34)
            .scale({ x: this.logoScale, y: this.logoScale })
            .rotate({ angle: this.logoRotate })
        }
        .width(160).height(160)

        // ── 逐字标题 ──
        Row({ space: 2 }) {
          ForEach(['鸿', '蒙', '智', '学', '业'], (ch: string, i: number) => {
            Text(ch)
              .fontSize(38).fontWeight(FontWeight.Bold)
              .fontColor(Color.White).letterSpacing(2)
              .opacity(this.titleChars[i])
              .translate({ y: this.titleChars[i] === 1 ? 0 : 22 })
              .animation({ duration: 420, curve: Curve.FastOutSlowIn })
          }, (ch: string, i: number) => `t-${i}`)
        }

        // ── 副标语 + 流光 ──
        Stack() {
          Text('智启学业 · 航向未来')
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.62)').letterSpacing(7)
          // 流光层
          Text('智启学业 · 航向未来')
            .fontSize(14).letterSpacing(7)
            .fontColor('rgba(255,255,255,0.95)')
            .linearGradient({
              angle: 0,
              colors: [['rgba(255,255,255,0)', 0], ['rgba(255,255,255,0.95)', 0.5], ['rgba(255,255,255,0)', 1]]
            })
            .clip(true)
            .translate({ x: this.shineX })
        }
        .width(300)
        .clip(true)
        .opacity(this.subOpacity)

        // ── 行动按钮（延迟浮现）──
        Row({ space: 14 }) {
          Button('登 录')
            .width(150).height(50).fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor('#3D5AFE')
            .backgroundColor(Color.White)
            .borderRadius(Theme.R_XL)
            .shadow({ radius: 20, color: 'rgba(255,255,255,0.25)', offsetY: 6 })
            .onClick((): void => { this.go('pages/Login'); })
          Button('注 册')
            .width(150).height(50).fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor('rgba(255,255,255,0.16)')
            .borderRadius(Theme.R_XL)
            .border({ width: 1, color: 'rgba(255,255,255,0.35)' })
            .shadow({ radius: 12, color: 'rgba(0,0,0,0.18)', offsetY: 5 })
            .onClick((): void => { this.go('pages/Register'); })
        }
        .margin({ top: 30 })
        .opacity(this.btnOpacity)
        .translate({ y: this.btnOffset })
      }
      .alignItems(HorizontalAlign.Center)
      .scale({ x: this.leaveScale, y: this.leaveScale })
      .opacity(this.leaveOpacity)
    }
    .width('100%').height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
