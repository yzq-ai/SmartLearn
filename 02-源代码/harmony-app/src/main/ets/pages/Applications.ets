import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { ApplicationItem } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, TagChip } from '../components/UiKit';
interface StatusInfo { label: string; tone: string; icon: string }
@Entry
@Component
struct Applications {
  @State rows: ApplicationItem[] = [];
  @State loading: boolean = true;
  @State message: string = '';
  @State filter: string = 'ALL';
  // 动效：节点点亮 + 卡片入场
  @State tlAnim: number = 0;
  @State listReveal: number = 0;
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    this.loading = true;
    this.message = '';
    try { this.rows = await api.getApplications(); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
    // 时间线节点依序点亮，列表淡入
    animateTo({ duration: 1400, curve: Curve.Friction, delay: 150 }, () => { this.tlAnim = 1; });
    animateTo({ duration: 480, curve: Curve.EaseOut, delay: 80 }, () => { this.listReveal = 1; });
  }
  private statusInfo(status: string): StatusInfo {
    if (status === 'APPLIED') return { label: '已投递', tone: 'primary', icon: '📤' };
    if (status === 'VIEWED') return { label: '被查看', tone: 'primary', icon: '👀' };
    if (status === 'INTERVIEW') return { label: '面试中', tone: 'warning', icon: '🗣' };
    if (status === 'OFFER') return { label: 'Offer', tone: 'success', icon: '🎉' };
    if (status === 'REJECTED') return { label: '不合适', tone: 'danger', icon: '💔' };
    return { label: status, tone: 'primary', icon: '📄' };
  }
  private filtered(): ApplicationItem[] {
    if (this.filter === 'ACTIVE') {
      return this.rows.filter((r: ApplicationItem): boolean => r.status !== 'REJECTED');
    }
    if (this.filter === 'OFFER') {
      return this.rows.filter((r: ApplicationItem): boolean => r.status === 'OFFER');
    }
    return this.rows;
  }
  private stageIndex(status: string): number {
    // 里程碑：0 已投递 → 1 被查看 → 2 面试 → 3 Offer
    if (status === 'APPLIED') return 0;
    if (status === 'VIEWED') return 1;
    if (status === 'INTERVIEW') return 2;
    if (status === 'OFFER') return 3;
    return -1;  // REJECTED：展示中断标记
  }
  private stageReached(status: string, stage: number): boolean {
    const idx: number = this.stageIndex(status);
    return idx >= stage;
  }
  @Builder TimelineStages(status: string) {
    Row({ space: 0 }) {
      ForEach(['已投递', '被查看', '面试', 'Offer'], (stage: string, i: number) => {
        Row({ space: 0 }) {
          // 节点（点亮动画：已达节点随 tlAnim 放大显现）
          Column({ space: 2 }) {
            Text(this.stageReached(status, i) ? (i === 3 ? '🎉' : '●') : '○')
              .fontSize(i === 3 ? 13 : 10)
              .fontColor(this.stageReached(status, i)
                ? (status === 'REJECTED' && this.stageIndex(status) === i ? Theme.DANGER
                  : i === 3 ? Theme.SUCCESS : Theme.PRIMARY)
                : '#C5CAD6')
              .scale({
                x: this.stageReached(status, i) ? 0.6 + 0.4 * Math.min(1, this.tlAnim * (4 - i)) : 1,
                y: this.stageReached(status, i) ? 0.6 + 0.4 * Math.min(1, this.tlAnim * (4 - i)) : 1
              })
            Text(stage).fontSize(Theme.F_CAP)
              .fontColor(this.stageReached(status, i) ? Theme.TEXT : Theme.TEXT_HINT)
          }
          .alignItems(HorizontalAlign.Center)
          .layoutWeight(i === 3 ? 0 : 1)
          // 连线（从左向右生长）
          if (i < 3) {
            Row() {
              Line()
                .width(this.stageReached(status, i + 1)
                  ? `${Math.round(100 * Math.max(0, Math.min(1, this.tlAnim * (3.2 - i))))}%` : '100%')
                .height(2)
                .backgroundColor(this.stageReached(status, i + 1) ? Theme.PRIMARY : '#E8EBF2')
                .borderRadius(1)
            }
            .layoutWeight(1).padding({ left: 3, right: 3, bottom: 14 })
            .alignItems(VerticalAlign.Top)
          }
        }
        .layoutWeight(i === 3 ? 0 : 1)
      }, (stage: string, i: number) => `${stage}-${i}-${this.stageReached(status, i)}`)
    }
    .width('100%')
    .padding({ top: 4 })
  }
  build() {
    Column() {
      PageHeader({ title: '投递记录', onBack: (): void => { router.back(); } })
      Row({ space: 8 }) {
        this.FilterChip('全部', 'ALL')
        this.FilterChip('进行中', 'ACTIVE')
        this.FilterChip('Offer', 'OFFER')
        Blank()
        Text(`共 ${this.rows.length} 条`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 4, bottom: 8 })
      if (this.loading) {
        Column({ space: 12 }) { SkeletonCard(); SkeletonCard(); SkeletonCard() }.padding(20)
      } else if (this.rows.length === 0) {
        EmptyState({ icon: '📨', text: '还没有投递记录，去就业页看看岗位吧' })
      } else {
        List({ space: 12 }) {
          ForEach(this.filtered(), (row: ApplicationItem) => {
            ListItem() {
              Column({ space: 10 }) {
                Row({ space: 12 }) {
                  Column() {
                    Text(this.statusInfo(row.status).icon).fontSize(18)
                  }
                  .width(44).height(44).borderRadius(Theme.R_MD)
                  .backgroundColor(
                    this.statusInfo(row.status).tone === 'success' ? Theme.SUCCESS_LIGHT
                      : this.statusInfo(row.status).tone === 'danger' ? Theme.DANGER_LIGHT
                        : this.statusInfo(row.status).tone === 'warning' ? Theme.WARNING_LIGHT
                          : Theme.PRIMARY_LIGHT)
                  .alignItems(HorizontalAlign.Center)
                  Column({ space: 3 }) {
                    Text(`岗位 #${row.job_id}`).fontSize(Theme.F_BODY)
                      .fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                    Text(row.applied_at).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  TagChip({
                    text: this.statusInfo(row.status).label,
                    tone: this.statusInfo(row.status).tone
                  })
                }.width('100%')
                // ═══ 四阶段时间线 ═══
                this.TimelineStages(row.status)
                if (row.status === 'INTERVIEW') {
                  // 面试提醒
                  Row({ space: 6 }) {
                    Text('🗣').fontSize(12)
                    Text('面试进行中 · 请留意通知中心的面试邀约消息')
                      .fontSize(Theme.F_CAP).fontColor(Theme.WARNING)
                  }
                  .width('100%').padding({ left: 8, right: 8, top: 6, bottom: 6 })
                  .backgroundColor(Theme.WARNING_LIGHT).borderRadius(Theme.R_SM)
                }
                if (row.status === 'REJECTED') {
                  Row({ space: 6 }) {
                    Text('💔').fontSize(12)
                    Text('流程已结束 · 30 天后可再次投递该岗位')
                      .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  }
                  .width('100%').padding({ left: 8, right: 8, top: 6, bottom: 6 })
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                }
              }
              .width('100%').padding(Theme.CARD_PAD)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
              .opacity(this.listReveal)
              .translate({ y: (1 - this.listReveal) * 22 })
            }
          }, (row: ApplicationItem) => `${row.job_id}-${row.applied_at}`)
        }
        .lanes({ minLength: 340, maxLength: 520 }, 12)
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 4, bottom: 20 })
        .scrollBar(BarState.Off)
      }
      if (this.message.length > 0) {
        Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER).padding(8)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
  @Builder FilterChip(label: string, value: string) {
    Text(label)
      .fontSize(Theme.F_SUB)
      .fontColor(this.filter === value ? Color.White : Theme.TEXT_SECOND)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .backgroundColor(this.filter === value ? Theme.PRIMARY : Theme.CARD)
      .borderRadius(16)
      .onClick((): void => { this.filter = value; })
  }
}
