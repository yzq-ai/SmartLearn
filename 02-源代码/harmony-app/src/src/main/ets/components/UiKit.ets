import { Theme } from '../common/Theme';
import { BreakpointHelper } from '../utils/BreakpointHelper';
import { curves } from '@kit.ArkUI';
import { IBestToast, IBestDialogUtil } from '@ibestservices/ibest-ui-v2';

// ═════════ IBest-UI 命令式 API（Toast / Dialog：不经组件插槽，V1/V2 页面均安全）═════════
export { IBestToast, IBestDialogUtil };

/** 轻提示（IBestToast，深浅色自适应）。 */
export function showToast(message: string, type?: 'success' | 'fail' | 'warning' | 'loading'): void {
  if (type !== undefined) {
    const opt: ToastOption = { message, duration: 1800, position: 'center', type: type };
    IBestToast.show(opt as ESObject);
  } else {
    const opt: ToastOption = { message, duration: 1800, position: 'center' };
    IBestToast.show(opt as ESObject);
  }
}

class ToastOption {
  message: string = '';
  duration: number = 1800;
  position: string = 'center';
  type?: 'success' | 'fail' | 'warning' | 'loading';
}

class DialogOption {
  title: string = '';
  message: string = '';
  showCancelButton: boolean = true;
  confirmButtonText: string = '确定';
  cancelButtonText: string = '取消';
  onConfirm: () => void = (): void => {};
}

/** 确认弹窗（IBestDialogUtil）。 */
export function confirmDialog(title: string, message: string, onOk: () => void, okText: string = '确定', cancelText: string = '取消'): void {
  const opt: DialogOption = {
    title, message,
    showCancelButton: true,
    confirmButtonText: okText,
    cancelButtonText: cancelText,
    onConfirm: onOk,
  };
  IBestDialogUtil.open(opt as ESObject);
}

// ═════════ 卡片容器（自动阴影+大圆角+按压回弹）═════════
@Component
export struct Card {
  @Builder
  defaultContent() {}
  @BuilderParam content: () => void = this.defaultContent;
  @Prop pad: number = Theme.CARD_PAD;
  @State pressed: boolean = false;
  build() {
    Column() { this.content() }
      .width('100%')
      .padding(this.pad)
      .backgroundColor(Theme.CARD)
      .borderRadius(Theme.R_LG)
      .shadow(Theme.SHADOW_CARD)
      .scale({ x: this.pressed ? 0.97 : 1, y: this.pressed ? 0.97 : 1 })
      .animation({ duration: 160, curve: Curve.Friction })
      .onTouch((e: TouchEvent): void => {
        if (e.type === TouchType.Down) { this.pressed = true; }
        else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = false; }
      })
  }
}

/** 响应式内容容器：手机全宽；平板/大屏限宽居中，避免内容拉伸过宽。 */
@Component
export struct ResponsiveBody {
  @Builder
  defaultContent() {}
  @BuilderParam content: () => void = this.defaultContent;
  @Prop maxWidth: number = 720;
  @Prop pad: number = 20;
  build() {
    Column() { this.content() }
      .width('100%')
      .constraintSize({ maxWidth: this.maxWidth })
      .padding({ left: this.pad, right: this.pad })
  }
}

/** 自适应双列卡片网格：手机单列，md/lg 双列（九宫瓦片、列表卡片通用）。 */
@Component
export struct CardGrid {
  @Builder
  defaultContent() {}
  @BuilderParam content: () => void = this.defaultContent;
  @State bp: string = 'sm';
  aboutToAppear(): void {
    this.bp = BreakpointHelper.current();
  }
  build() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Start }) {
      this.content()
    }
    .width('100%')
    .onAreaChange((_old: Area, newArea: Area): void => {
      const w: number = Number(newArea.width);
      this.bp = w >= BreakpointHelper.MD_MAX ? 'md' : 'sm';
    })
  }
}

/** 响应式列表网格列数：手机 1 列，平板起 2 列，宽屏 3 列。 */
export function gridLanes(): number {
  const bp: string = BreakpointHelper.current();
  if (bp === 'lg') return 3;
  if (bp === 'md') return 2;
  return 1;
}

// ═════════ 页面顶栏（原生实现：稳定优先；深浅色由 Theme 动态色板驱动）═════════
@Component
export struct PageHeader {
  @Prop title: string = '';
  @Prop subtitle: string = '';   // 可选副标题（页面上下文说明）
  onBack: () => void = () => {};
  @Builder
  defaultRight() {}
  @BuilderParam right: () => void = this.defaultRight;
  build() {
    Row({ space: 12 }) {
      Button('‹')
        .width(40).height(40).fontSize(20)
        .backgroundColor(Theme.CARD).fontColor(Theme.TEXT)
        .shadow(Theme.SHADOW_CARD)
        .onClick(() => this.onBack())
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(20).fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.subtitle.length > 0) {
          Text(this.subtitle).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      this.right()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 10 })
  }
}

/** 区块标题（统一小节标题：图标 + 文字 + 可选右侧动作，替换各页手写的 Row+Text 组合）。 */
@Component
export struct SectionTitle {
  @Prop icon: string = '';
  @Prop text: string = '';
  @Prop hint: string = '';        // 右侧浅色说明（如 "共 7 帖"）
  @State appeared: boolean = false;
  @Builder
  defaultAction() {}
  @BuilderParam action: () => void = this.defaultAction;
  build() {
    Row({ space: 8 }) {
      if (this.icon.length > 0) {
        Text(this.icon).fontSize(16)
      }
      Text(this.text).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
        .layoutWeight(this.hint.length > 0 ? 0 : 1)
      if (this.hint.length > 0) {
        Blank()
        Text(this.hint).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
      }
      this.action()
    }
    .width('100%')
    .translate({ y: this.appeared ? 0 : 10 })
    .opacity(this.appeared ? 1 : 0.6)
    .animation({ duration: 320, curve: Curve.EaseOut })
    .onAppear((): void => { this.appeared = true; })
  }
}

/** 底部留白（列表/表单页收尾，避免最后一张卡贴住屏幕底）。 */
@Component
export struct BottomSpace {
  @Prop h: number = 32;
  build() { Column().width('100%').height(this.h) }
}

// ═════════ 主按钮（原生 Button + 品牌渐变 + 按压回弹；V1 页面事件 100% 稳定）═════════
@Component
export struct PrimaryButton {
  @Prop label: string = '';
  @Prop loading: boolean = false;
  @Prop isDisabled: boolean = false;
  onTap: () => void = () => {};
  @State pressed: boolean = false;
  build() {
    Button(this.loading ? '请稍候…' : this.label)
      .width('100%').height(50)
      .fontSize(16).fontWeight(FontWeight.Medium)
      .fontColor(Color.White)
      .linearGradient({
        angle: 135,
        colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]]
      })
      .borderRadius(Theme.R_MD)
      .shadow(!this.isDisabled && !this.loading ? Theme.SHADOW_FLOAT : { radius: 0, color: 'transparent', offsetX: 0, offsetY: 0 })
      .opacity(!this.isDisabled && !this.loading ? 1 : 0.5)
      .scale({ x: this.pressed ? 0.96 : 1, y: this.pressed ? 0.96 : 1 })
      .animation({ duration: 150, curve: Curve.Friction })
      .onTouch((e: TouchEvent): void => {
        if (!this.isDisabled && !this.loading) {
          if (e.type === TouchType.Down) { this.pressed = true; }
          else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = false; }
        }
      })
      .onClick(() => { if (!this.isDisabled && !this.loading) this.onTap(); })
  }
}

// ═════════ 输入框（品牌圆角 + 深浅自适应）═════════
@Component
export struct FieldInput {
  @Prop placeholder: string = '';
  @Prop value: string = '';
  @Prop isPassword: boolean = false;
  onChange: (v: string) => void = (_v: string) => {};
  build() {
    TextInput({ placeholder: this.placeholder, text: this.value })
      .type(this.isPassword ? InputType.Password : InputType.Normal)
      .width('100%').height(52)
      .fontSize(15)
      .fontColor(Theme.TEXT)
      .placeholderColor(Theme.TEXT_HINT)
      .backgroundColor(Theme.INPUT_BG)
      .borderRadius(Theme.R_MD)
      .caretColor(Theme.PRIMARY)
      .onChange((v: string) => this.onChange(v))
  }
}

// ═════════ 标签徽章（品牌四色调 + 出现轻弹；V1 页面 100% 稳定）═════════
@Component
export struct TagChip {
  @Prop text: string = '';
  @Prop tone: string = 'primary';
  @State popScale: number = 0.6;
  build() {
    Text(this.text)
      .fontSize(Theme.F_CAP).fontWeight(FontWeight.Medium)
      .fontColor(
        this.tone === 'success' ? Theme.SUCCESS :
        this.tone === 'danger' ? Theme.DANGER :
        this.tone === 'warning' ? Theme.WARNING : Theme.PRIMARY)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor(
        this.tone === 'success' ? Theme.SUCCESS_LIGHT :
        this.tone === 'danger' ? Theme.DANGER_LIGHT :
        this.tone === 'warning' ? Theme.WARNING_LIGHT : Theme.PRIMARY_LIGHT)
      .borderRadius(8)
      .scale({ x: this.popScale, y: this.popScale })
      .onAppear((): void => {
        animateTo({ duration: 300, curve: curves.springMotion(0.4, 0.8) }, (): void => { this.popScale = 1; });
      })
  }
}

// ═════════ 空状态（浮动动画；V1 页面 100% 稳定）═════════
@Component
export struct EmptyState {
  @Prop icon: string = '📭';
  @Prop text: string = '暂无数据';
  @Prop hint: string = '';        // 次级说明（如操作引导）
  @State floatY: number = 0;
  build() {
    Column({ space: 12 }) {
      Text(this.icon).fontSize(52)
        .translate({ y: this.floatY })
        .animation({ duration: 1600, curve: Curve.EaseInOut })
      Text(this.text).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT)
        .opacity(0.85)
      if (this.hint.length > 0) {
        Text(this.hint).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).opacity(0.6)
      }
    }
    .width('100%').padding({ top: 60, bottom: 40 })
    .alignItems(HorizontalAlign.Center)
    .onAppear((): void => {
      // 轻微上下浮动循环
      animateTo({ duration: 1600, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, (): void => {
        this.floatY = -8;
      });
    })
  }
}

// ═════════ 骨架屏 ═════════
@Component
export struct SkeletonCard {
  @State shimmerX: number = -140;
  build() {
    Stack() {
      Column({ space: 10 }) {
        Row({ space: 12 }) {
          Column().width(44).height(44).borderRadius(22)
            .backgroundColor(Theme.INPUT_BG)
          Column({ space: 8 }) {
            Column().width('55%').height(14).borderRadius(7).backgroundColor(Theme.INPUT_BG)
            Column().width('80%').height(10).borderRadius(5).backgroundColor(Theme.INPUT_BG)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%')
        Column().width('100%').height(10).borderRadius(5).backgroundColor(Theme.INPUT_BG)
      }
      .width('100%').padding(Theme.CARD_PAD)
      .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)

      // 流光条（Stack 顶层，clip 圆角内扫过）
      Column()
        .width(120).height('110%')
        .linearGradient({
          angle: 105,
          colors: [['rgba(120,140,200,0)', 0], ['rgba(150,170,230,0.10)', 0.4],
            ['rgba(180,200,250,0.22)', 0.5], ['rgba(150,170,230,0.10)', 0.6],
            ['rgba(120,140,200,0)', 1]],
        })
        .translate({ x: this.shimmerX })
    }
    .width('100%')
    .borderRadius(Theme.R_LG)
    .clip(true)
    .onAppear((): void => {
      animateTo({ duration: 1500, curve: Curve.EaseInOut, iterations: -1 }, (): void => {
        this.shimmerX = 420;
      });
    })
  }
}

// ═════════ 通用渐变图标徽章（列表头像位，入场缩放浮现）═════════
@Component
export struct IconBadge {
  @Prop icon: string = '📚';
  @Prop badgeSize: number = 46;
  @Prop gradient: boolean = true;
  @State appeared: boolean = false;
  build() {
    Column() {
      Text(this.icon).fontSize(this.badgeSize * 0.42)
    }
    .width(this.badgeSize).height(this.badgeSize).borderRadius(this.badgeSize * 0.22)
    .backgroundColor(this.gradient ? Theme.PRIMARY_LIGHT : Theme.INPUT_BG)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .scale({ x: this.appeared ? 1 : 0.4, y: this.appeared ? 1 : 0.4 })
    .opacity(this.appeared ? 1 : 0)
    .animation({ duration: 420, curve: Curve.EaseOut })
    .onAppear((): void => {
      animateTo({ duration: 420, curve: Curve.EaseOut }, (): void => { this.appeared = true; });
    })
  }
}

// ═════════ 统计瓦片（响应式 2/3/4 列自适应，数字滚动）═════════
@Component
export struct StatTile {
  @Prop icon: string = '📊';
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop tone: string = 'primary';
  @State displayValue: string = '';
  @State appeared: boolean = false;
  private targetNum: number = 0;
  private isPureNumber: boolean = false;

  aboutToAppear(): void {
    const t: string = this.value.replace(/[^\d.]/g, '');
    this.isPureNumber = t.length > 0 && t === this.value;
    if (this.isPureNumber) {
      this.targetNum = Number(this.value);
      this.displayValue = '0';
    } else {
      this.displayValue = this.value;
    }
  }

  onAppearAnim(): void {
    if (!this.isPureNumber) { this.appeared = true; return; }
    // 数字滚动：1200ms SpringEaseOut
    const steps: number = 24;
    const per: number = Math.max(1, Math.round(this.targetNum / steps));
    let cur: number = 0;
    const timerId: number = setInterval((): void => {
      cur += per;
      if (cur >= this.targetNum) {
        cur = this.targetNum;
        clearInterval(timerId);
      }
      this.displayValue = String(cur);
    }, 42);
    this.appeared = true;
  }

  build() {
    Column({ space: 4 }) {
      Text(this.icon).fontSize(22)
      Text(this.displayValue).fontSize(24).fontWeight(FontWeight.Bold)
        .fontColor(this.tone === 'success' ? Theme.SUCCESS :
          this.tone === 'warning' ? Theme.WARNING :
          this.tone === 'danger' ? Theme.DANGER : Theme.PRIMARY)
      Text(this.label).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
    }
    .width('100%').padding(16)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
    .alignItems(HorizontalAlign.Start)
    .translate({ y: this.appeared ? 0 : 14 })
    .opacity(this.appeared ? 1 : 0)
    .animation({ duration: 380, curve: Curve.EaseOut })
    .onAppear((): void => { this.onAppearAnim(); })
  }
}
