export class BreakpointHelper {
  public static readonly SM_MAX: number = 600;
  public static readonly MD_MAX: number = 840;

  public static current(): string {
    const bp: string | undefined = AppStorage.get<string>('breakpoint');
    if (bp !== undefined && bp.length > 0) return bp;
    return 'sm';
  }

  public static getColumns(): number {
    const bp: string = BreakpointHelper.current();
    if (bp === 'lg') return 2;
    if (bp === 'md') return 2;
    return 1;
  }

  public static isTablet(): boolean {
    const bp: string = BreakpointHelper.current();
    return bp === 'md' || bp === 'lg';
  }

  public static isPhone(): boolean {
    return BreakpointHelper.current() === 'sm';
  }

  public static cardWidth(): string {
    return BreakpointHelper.isTablet() ? '48%' : '100%';
  }

  public static listColumns(): string {
    if (BreakpointHelper.current() === 'lg') return '1fr 1fr';
    if (BreakpointHelper.current() === 'md') return '1fr 1fr';
    return '1fr';
  }

  /** 卡片在自适应网格中的占宽：手机单列，平板起双列。 */
  public static gridCardWidth(bp: string): string {
    return bp === 'sm' ? '100%' : '48.6%';
  }

  /** 数据统计瓦片列模板：手机 2 列，md 3 列，lg 4 列。 */
  public static statColumns(bp: string): string {
    if (bp === 'lg') return '1fr 1fr 1fr 1fr';
    if (bp === 'md') return '1fr 1fr 1fr';
    return '1fr 1fr';
  }

  /** 表单区最大内容宽度（vp）：宽屏下限宽居中，长字段不至拉伸过宽。 */
  public static formMaxWidth(): number {
    return 720;
  }
}
