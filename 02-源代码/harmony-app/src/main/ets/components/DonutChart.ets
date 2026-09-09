import { Theme } from '../common/Theme';

/**
 * 现代环形分布图（甜甜圈）：中心总数、右侧图例、分段渐变色。
 * 用于角色分布 / 企业状态 / 投递状态等占比展示。
 */
@Component
export struct DonutChart {
  @Prop labels: string[] = [];
  @Prop values: number[] = [];
  @Prop colors: string[] = [];
  @Prop centerLabel: string = '总计';
  @Prop chartSize: number = 0; // 0 = 自适应（推荐）
  @Prop legendVertical: boolean = false;
  @State fitSize: number = 180;

  build() {
    Row({ space: 20 }) {
      Canvas(this.context).width(this.effSize()).height(this.effSize())
        .onAreaChange((_old: Area, newArea: Area): void => {
          const w: number = Number(newArea.width);
          if (w > 0) {
            const fit: number = Math.floor(Math.min(w, 200));
            if (Math.abs(fit - this.fitSize) > 4) { this.fitSize = fit; }
          }
        })
        .onReady((): void => { this.drawDonut(); })
      // 图例
      Column({ space: 10 }) {
        ForEach(this.labels, (label: string, idx: number) => {
          Row({ space: 8 }) {
            Column().width(10).height(10).borderRadius(5)
              .backgroundColor(this.sliceColor(idx))
            Text(label).fontSize(Theme.F_SUB).fontColor(Theme.TEXT)
              .maxLines(1).layoutWeight(1)
            Text(`${this.values.length > idx ? this.values[idx] : 0}`)
              .fontSize(Theme.F_SUB).fontWeight(FontWeight.Bold)
              .fontColor(this.sliceColor(idx))
          }.constraintSize({ maxWidth: 160 })
        }, (label: string, idx: number) => `${idx}-${label}`)
      }
      .alignItems(this.legendVertical ? HorizontalAlign.Start : HorizontalAlign.Center)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private total(): number {
    let t: number = 0;
    for (let i: number = 0; i < this.values.length; i += 1) { t += this.values[i]; }
    return t;
  }
  private effSize(): number {
    return this.chartSize > 0 ? this.chartSize : this.fitSize;
  }
  private sliceColor(idx: number): string {
    const preset: string[] = [Theme.PRIMARY, '#7C4DFF', '#00C9A7', Theme.WARNING, '#FF6B9D', '#4DABF7'];
    if (idx < this.colors.length && this.colors[idx].length > 0) { return this.colors[idx]; }
    return preset[idx % preset.length];
  }

  private drawDonut(): void {
    const ctx: CanvasRenderingContext2D = this.context;
    const w: number = this.effSize();
    const cx: number = w / 2;
    const cy: number = w / 2;
    const rOut: number = w / 2 - 6;
    const rIn: number = rOut - 26;
    const t: number = this.total();
    ctx.clearRect(0, 0, w, w);
    if (t <= 0) {
      // 无数据：灰环
      ctx.beginPath();
      ctx.arc(cx, cy, (rOut + rIn) / 2, 0, Math.PI * 2);
      ctx.strokeStyle = '#EEF1F6';
      ctx.lineWidth = rOut - rIn;
      ctx.stroke();
      return;
    }
    let startAngle: number = -Math.PI / 2;
    for (let i: number = 0; i < this.values.length; i += 1) {
      const val: number = this.values[i];
      if (val <= 0) continue;
      const sweep: number = Math.PI * 2 * val / t;
      ctx.beginPath();
      ctx.arc(cx, cy, rOut, startAngle, startAngle + sweep);
      ctx.arc(cx, cy, rIn, startAngle + sweep, startAngle, true);
      ctx.closePath();
      ctx.fillStyle = this.sliceColor(i);
      ctx.fill();
      // 分隔缝隙
      ctx.strokeStyle = '#FFFFFF';
      ctx.lineWidth = 2;
      ctx.stroke();
      startAngle += sweep;
    }
    // 中心文本
    const grad: CanvasGradient = ctx.createLinearGradient(0, 0, 0, w);
    grad.addColorStop(0, Theme.PRIMARY);
    grad.addColorStop(1, '#7C4DFF');
    ctx.fillStyle = grad;
    ctx.font = '800 30px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(String(t), cx, cy - 10);
    ctx.fillStyle = Theme.TEXT_HINT;
    ctx.font = '500 12px sans-serif';
    ctx.fillText(this.centerLabel, cx, cy + 16);
  }
}
