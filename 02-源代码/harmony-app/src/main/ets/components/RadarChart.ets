import { Theme } from '../common/Theme';

/**
 * 现代雷达图：品牌渐变填充、柔和网格、按容器自适应尺寸（防溢出重叠）。
 */
@Component
export struct RadarChart {
  @Prop labels: string[] = [];
  @Prop values: number[] = [];
  @Prop chartSize: number = 0; // 0 = 自适应容器宽（推荐）
  @State fitSize: number = 220;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  build() {
    Canvas(this.context)
      .width(this.effSize())
      .height(this.effSize())
      .onAreaChange((_old: Area, newArea: Area): void => {
        // 容器实际可用宽（取宽高中较小者，防止竖向溢出）
        const w: number = Number(newArea.width);
        const h: number = Number(newArea.height);
        if (w > 0 && h > 0) {
          const fit: number = Math.floor(Math.min(w, Math.max(h, w), 300));
          if (Math.abs(fit - this.fitSize) > 4) { this.fitSize = fit; }
        }
      })
      .onReady((): void => { this.drawRadar(); })
  }

  private effSize(): number {
    return this.chartSize > 0 ? this.chartSize : this.fitSize;
  }

  private drawRadar(): void {
    const ctx: CanvasRenderingContext2D = this.context;
    const w: number = this.effSize();
    const h: number = this.effSize();
    const cx: number = w / 2;
    const cy: number = h / 2;
    const maxR: number = w / 2 - 34;
    const n: number = this.labels.length;
    if (n < 3) return;

    ctx.clearRect(0, 0, w, h);

    // 网格层
    for (let level = 1; level <= 5; level += 1) {
      ctx.beginPath();
      for (let i = 0; i < n; i += 1) {
        const angle: number = -Math.PI / 2 + (2 * Math.PI * i) / n;
        const r: number = (maxR * level) / 5;
        const x: number = cx + r * Math.cos(angle);
        const y: number = cy + r * Math.sin(angle);
        if (i === 0) { ctx.moveTo(x, y); } else { ctx.lineTo(x, y); }
      }
      ctx.closePath();
      ctx.strokeStyle = 'rgba(61,90,254,0.12)';
      ctx.lineWidth = level === 5 ? 1.4 : 1;
      ctx.stroke();
    }
    // 轴线
    for (let i = 0; i < n; i += 1) {
      const angle: number = -Math.PI / 2 + (2 * Math.PI * i) / n;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(cx + maxR * Math.cos(angle), cy + maxR * Math.sin(angle));
      ctx.strokeStyle = 'rgba(61,90,254,0.12)';
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    // 数据多边形
    ctx.beginPath();
    for (let i = 0; i < n; i += 1) {
      const angle: number = -Math.PI / 2 + (2 * Math.PI * i) / n;
      const val: number = i < this.values.length ? Math.max(0, Math.min(100, this.values[i])) : 0;
      const r: number = (maxR * val) / 100;
      const x: number = cx + r * Math.cos(angle);
      const y: number = cy + r * Math.sin(angle);
      if (i === 0) { ctx.moveTo(x, y); } else { ctx.lineTo(x, y); }
    }
    ctx.closePath();
    const grad = ctx.createLinearGradient(0, 0, w, h);
    grad.addColorStop(0, 'rgba(61,90,254,0.35)');
    grad.addColorStop(1, 'rgba(124,77,255,0.18)');
    ctx.fillStyle = grad;
    ctx.fill();
    ctx.strokeStyle = '#3D5AFE';
    ctx.lineWidth = 2.2;
    ctx.stroke();

    // 顶点圆点
    for (let i = 0; i < n; i += 1) {
      const angle: number = -Math.PI / 2 + (2 * Math.PI * i) / n;
      const val: number = i < this.values.length ? Math.max(0, Math.min(100, this.values[i])) : 0;
      const r: number = (maxR * val) / 100;
      ctx.beginPath();
      ctx.arc(cx + r * Math.cos(angle), cy + r * Math.sin(angle), 3.2, 0, Math.PI * 2);
      ctx.fillStyle = '#3D5AFE';
      ctx.fill();
    }

    // 标签（防重叠：限制 5 字内并按宽度截断）
    ctx.font = '11px sans-serif';
    ctx.fillStyle = '#8A94A6';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (let i = 0; i < n; i += 1) {
      const angle: number = -Math.PI / 2 + (2 * Math.PI * i) / n;
      const lx: number = cx + (maxR + 18) * Math.cos(angle);
      const ly: number = cy + (maxR + 18) * Math.sin(angle);
      let text: string = this.labels[i] ?? '';
      if (text.length > 6) { text = `${text.substring(0, 5)}…`; }
      ctx.fillText(text, lx, ly);
    }
  }
}
