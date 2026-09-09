import { Theme } from '../common/Theme';

/**
 * 现代折线/面积趋势图：渐变填充、圆点标注、悬停竖线网格。
 */
@Component
export struct TrendChart {
  @Prop labels: string[] = [];
  @Prop values: number[] = [];
  @Prop chartHeight: number = 180;
  @Prop lineColor: string = '#3D5AFE';

  build() {
    Column({ space: 8 }) {
      Canvas(this.context)
        .width('100%').height(this.chartHeight)
        .onReady((): void => { this.draw(); })
      // X 轴标签
      Row() {
        ForEach(this.labels, (label: string, idx: number) => {
          Text(label).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
            .layoutWeight(1).textAlign(TextAlign.Center)
        }, (label: string, idx: number) => `${idx}-${label}`)
      }.width('100%')
    }
    .width('100%')
  }

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private maxVal(): number {
    let m: number = 0;
    for (let i: number = 0; i < this.values.length; i += 1) {
      if (this.values[i] > m) { m = this.values[i]; }
    }
    return m <= 0 ? 1 : m;
  }

  private draw(): void {
    const ctx: CanvasRenderingContext2D = this.context;
    const w: number = 320;
    const h: number = this.chartHeight;
    const padX: number = 18;
    const padTop: number = 16;
    const padBottom: number = 10;
    const n: number = this.values.length;
    if (n < 2) return;
    ctx.clearRect(0, 0, w, h);
    const step: number = (w - padX * 2) / (n - 1);
    const maxV: number = this.maxVal() * 1.15;
    const yOf = (v: number): number => {
      return h - padBottom - (v / maxV) * (h - padTop - padBottom);
    };
    // 网格线
    ctx.strokeStyle = '#EEF1F6';
    ctx.lineWidth = 1;
    for (let g: number = 0; g <= 4; g += 1) {
      const y: number = padTop + (h - padTop - padBottom) * g / 4;
      ctx.beginPath();
      ctx.moveTo(padX, y);
      ctx.lineTo(w - padX, y);
      ctx.stroke();
    }
    // 面积渐变
    const grad: CanvasGradient = ctx.createLinearGradient(0, padTop, 0, h);
    grad.addColorStop(0, this.alpha(this.lineColor, 0.28));
    grad.addColorStop(1, this.alpha(this.lineColor, 0.02));
    ctx.beginPath();
    ctx.moveTo(padX, yOf(this.values[0]));
    for (let i: number = 1; i < n; i += 1) {
      ctx.lineTo(padX + step * i, yOf(this.values[i]));
    }
    ctx.lineTo(padX + step * (n - 1), h - padBottom);
    ctx.lineTo(padX, h - padBottom);
    ctx.closePath();
    ctx.fillStyle = grad;
    ctx.fill();
    // 折线
    ctx.strokeStyle = this.lineColor;
    ctx.lineWidth = 2.4;
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(padX, yOf(this.values[0]));
    for (let i: number = 1; i < n; i += 1) {
      ctx.lineTo(padX + step * i, yOf(this.values[i]));
    }
    ctx.stroke();
    // 数据点
    ctx.fillStyle = '#FFFFFF';
    ctx.strokeStyle = this.lineColor;
    ctx.lineWidth = 2.2;
    for (let i: number = 0; i < n; i += 1) {
      ctx.beginPath();
      ctx.arc(padX + step * i, yOf(this.values[i]), 4, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
    }
    // 末端数值气泡
    const lastY: number = yOf(this.values[n - 1]);
    ctx.fillStyle = this.lineColor;
    ctx.beginPath();
    ctx.arc(padX + step * (n - 1), lastY, 4, 0, Math.PI * 2);
    ctx.fill();
  }

  private alpha(hex: string, a: number): string {
    // '#3D5AFE' -> 'rgba(61,90,254,a)'
    const r: number = parseInt(hex.substring(1, 3), 16);
    const g: number = parseInt(hex.substring(3, 5), 16);
    const b: number = parseInt(hex.substring(5, 7), 16);
    return `rgba(${r},${g},${b},${a})`;
  }
}
