import { Theme } from '../common/Theme';

/**
 * 现代成绩环：渐变色弧线（按分数高低自动换色）、圆头端点、自适应尺寸（防溢出重叠）。
 */
@Component
export struct ScoreRingChart {
  @Prop score: number = 0;
  @Prop total: number = 100;
  @Prop label: string = '得分';
  @Prop chartSize: number = 0; // 0 = 自适应容器（推荐），>0 固定尺寸
  @State fitSize: number = 160;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  build() {
    Canvas(this.context)
      .width(this.effSize())
      .height(this.effSize())
      .onAreaChange((_old: Area, newArea: Area): void => {
        const w: number = Number(newArea.width);
        const h: number = Number(newArea.height);
        if (w > 0 && h > 0) {
          const fit: number = Math.floor(Math.min(w, Math.max(h, w), 220));
          if (Math.abs(fit - this.fitSize) > 4) { this.fitSize = fit; }
        }
      })
      .onReady((): void => { this.drawRing(); })
  }

  private effSize(): number {
    return this.chartSize > 0 ? this.chartSize : this.fitSize;
  }

  private arcColor(): string {
    const pct: number = this.total > 0 ? this.score / this.total : 0;
    if (pct >= 0.8) return Theme.SUCCESS;
    if (pct >= 0.6) return Theme.PRIMARY;
    if (pct >= 0.4) return Theme.WARNING;
    return Theme.DANGER;
  }

  private drawRing(): void {
    const ctx: CanvasRenderingContext2D = this.context;
    const size: number = this.effSize();
    const cx: number = size / 2;
    const cy: number = size / 2;
    const radius: number = size * 0.375;
    const lineW: number = Math.max(8, Math.round(size * 0.0625));
    const pct: number = this.total > 0 ? this.score / this.total : 0;
    const arc: string = this.arcColor();

    ctx.clearRect(0, 0, size, size);

    // 底轨
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.strokeStyle = Theme.PRIMARY_LIGHT;
    ctx.lineWidth = lineW;
    ctx.stroke();

    // 进度弧（超过阈值色），圆头端点
    if (pct > 0) {
      const startAngle: number = -Math.PI / 2;
      const endAngle: number = startAngle + Math.PI * 2 * pct;
      ctx.beginPath();
      ctx.arc(cx, cy, radius, startAngle, endAngle);
      ctx.strokeStyle = arc;
      ctx.lineWidth = lineW;
      ctx.lineCap = 'round';
      ctx.stroke();
      // 弧线端点高光
      ctx.beginPath();
      ctx.arc(cx + radius * Math.cos(endAngle), cy + radius * Math.sin(endAngle), lineW * 0.22, 0, Math.PI * 2);
      ctx.fillStyle = '#FFFFFF';
      ctx.fill();
    }

    // 分数（显示实际分值而非百分比换算：total=100 时二者一致，total≠100 时分数更直观）
    ctx.fillStyle = Theme.TEXT;
    ctx.font = `bold ${Math.round(size * 0.175)}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(`${Math.round(this.score)}`, cx, cy - size * 0.05);

    ctx.fillStyle = arc;
    ctx.font = `600 ${Math.round(size * 0.075)}px sans-serif`;
    ctx.fillText(this.label, cx, cy + size * 0.11);
  }
}
