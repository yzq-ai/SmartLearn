import { Theme } from '../common/Theme';

/**
 * 现代横向柱状图：渐变柱体、圆角端、数值标签、自适应宽度、入场生长动画。
 */
@Component
export struct BarChart {
  @Prop labels: string[] = [];
  @Prop values: number[] = [];
  @Prop colors: string[] = [];
  // 显示为百分比的柱（全部按最大值归一化）
  @Prop unit: string = '';
  @Prop chartHeight: number = 220;
  @State progress: number = 0;

  aboutToAppear(): void {
    this.progress = 0;
    animateTo({ duration: 900, curve: Curve.EaseOut, delay: 120 }, (): void => {
      this.progress = 1;
    });
  }

  build() {
    Column({ space: 10 }) {
      ForEach(this.labels, (label: string, idx: number) => {
        Column({ space: 5 }) {
          Row() {
            Text(label).fontSize(Theme.F_SUB).fontColor(Theme.TEXT)
              .maxLines(1).layoutWeight(1)
            Text(this.valueText(idx)).fontSize(Theme.F_SUB)
              .fontWeight(FontWeight.Bold).fontColor(this.barColor(idx))
          }.width('100%')
          // 轨道
          Stack({ alignContent: Alignment.Start }) {
            Column().width('100%').height(12).borderRadius(6)
              .backgroundColor(Theme.INPUT_BG)
            // 柱体（生长动画：宽度 × progress，逐条错峰）
            Column()
              .width(`${this.pct(idx) * this.progress}%`)
              .height(12)
              .borderRadius(6)
              .linearGradient({
                angle: 90,
                colors: [[this.barColor(idx), 0], [this.lighten(this.barColor(idx)), 1]]
              })
              .animation({ duration: 700, curve: Curve.EaseOut, delay: idx * 90 })
          }.width('100%')
        }.width('100%')
      }, (label: string, idx: number) => `${idx}-${label}`)
    }
    .width('100%')
    .constraintSize({ maxHeight: this.chartHeight })
  }

  private maxVal(): number {
    let m: number = 0;
    for (let i: number = 0; i < this.values.length; i += 1) {
      if (this.values[i] > m) { m = this.values[i]; }
    }
    return m <= 0 ? 1 : m;
  }
  private pct(idx: number): number {
    const v: number = idx < this.values.length ? this.values[idx] : 0;
    const p: number = Math.round(v / this.maxVal() * 100);
    return Math.max(4, Math.min(100, p));
  }
  private valueText(idx: number): string {
    const v: number = idx < this.values.length ? this.values[idx] : 0;
    return `${v}${this.unit}`;
  }
  private barColor(idx: number): string {
    const preset: string[] = [Theme.PRIMARY, '#7C4DFF', '#00C9A7', Theme.WARNING, '#FF6B9D', '#4DABF7'];
    if (idx < this.colors.length && this.colors[idx].length > 0) { return this.colors[idx]; }
    return preset[idx % preset.length];
  }
  private lighten(color: string): string {
    const map: Record<string, string> = {
      '#3D5AFE': '#7C4DFF', '#7C4DFF': '#9B6DFF', '#00C9A7': '#3EDBB9',
      '#F5A623': '#FFC55C', '#E5484D': '#F37F82', '#22A06B': '#3ECF8E',
      '#FF6B9D': '#FF9BBF', '#4DABF7': '#7CC3F9'
    };
    return map[color] ?? color;
  }
}
