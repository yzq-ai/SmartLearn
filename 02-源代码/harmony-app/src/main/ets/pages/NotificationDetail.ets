import { router } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState } from '../components/UiKit';

interface NotificationDetailParams {
  type?: string;
  title?: string;
  content?: string;
  created_at?: string;
}

/**
 * 消息详情页：从消息中心的卡片整卡点击进入，
 * 展示完整标题、正文与发布时间，渐变头卡 + 正文卡片。
 */
@Entry
@Component
struct NotificationDetail {
  @State type: string = 'SYSTEM';
  @State title: string = '';
  @State content: string = '';
  @State createdAt: string = '';
  @State ready: boolean = false;

  aboutToAppear(): void {
    const raw: Object | null = router.getParams();
    if (raw !== null && raw !== undefined) {
      const p: NotificationDetailParams = raw as NotificationDetailParams;
      this.type = p.type ?? 'SYSTEM';
      this.title = p.title ?? '消息详情';
      this.content = p.content ?? '（无正文内容）';
      this.createdAt = p.created_at ?? '';
    }
    this.ready = true;
  }

  private typeLabel(): string {
    if (this.type === 'SYSTEM' || this.type === '系统') return '系统通知';
    if (this.type === 'COURSE') return '课程通知';
    if (this.type === 'EXAM') return '考试通知';
    if (this.type === 'ASSIGNMENT') return '作业通知';
    if (this.type === 'JOB') return '就业通知';
    if (this.type === 'EVENT') return '活动通知';
    if (this.type === 'FRIEND_ACCEPT' || this.type === 'FRIEND_REQUEST') return '好友通知';
    if (this.type === 'SIGN') return '签到通知';
    return '站内通知';
  }
  private typeIcon(): string {
    if (this.type === 'COURSE') return '📚';
    if (this.type === 'EXAM') return '📝';
    if (this.type === 'ASSIGNMENT') return '📋';
    if (this.type === 'JOB') return '💼';
    return '📢';
  }
  private fmtTime(iso: string): string {
    if (iso === null || iso === undefined || iso.length < 16) { return iso; }
    // 后端时间为 UTC：补 Z 解析后转本地时区展示
    const ms: number = Date.parse(iso.endsWith('Z') ? iso : `${iso}Z`);
    if (Number.isNaN(ms)) { return `${iso.substring(0, 10)} ${iso.substring(11, 16)}`; }
    const d: Date = new Date(ms);
    const p2 = (n: number): string => n < 10 ? `0${n}` : `${n}`;
    return `${d.getFullYear()}-${p2(d.getMonth() + 1)}-${p2(d.getDate())} ${p2(d.getHours())}:${p2(d.getMinutes())}`;
  }

  build() {
    Column() {
      PageHeader({
        title: '消息详情',
        onBack: (): void => { router.back(); }
      })
      if (!this.ready) {
        EmptyState({ icon: '📬', text: '加载中…' })
      } else {
        Scroll() {
          Column({ space: 14 }) {
            // ═══ 头部卡（渐变 + 类型徽章）═══
            Column({ space: 12 }) {
              Row({ space: 10 }) {
                Column() {
                  Text(this.typeIcon()).fontSize(24)
                }
                .width(52).height(52).borderRadius(26)
                .backgroundColor('rgba(255,255,255,0.22)')
                .alignItems(HorizontalAlign.Center)
                Column({ space: 3 }) {
                  Text(this.typeLabel()).fontSize(Theme.F_CAP)
                    .fontColor('rgba(255,255,255,0.85)')
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .backgroundColor('rgba(255,255,255,0.2)').borderRadius(8)
                  if (this.createdAt.length > 0) {
                    Text(this.fmtTime(this.createdAt)).fontSize(Theme.F_CAP)
                      .fontColor('rgba(255,255,255,0.7)')
                  }
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              }.width('100%')
              Text(this.title).fontSize(20).fontWeight(FontWeight.Bold)
                .fontColor(Color.White).width('100%').lineHeight(28)
            }
            .width('100%').padding(20)
            .alignItems(HorizontalAlign.Start)
            .linearGradient({ angle: 145, colors: [[Theme.PRIMARY_DEEP, 0], [Theme.PRIMARY, 0.55], [Theme.PRIMARY_GRADIENT, 1]] })
            .borderRadius(Theme.R_XL)
            .shadow(Theme.SHADOW_FLOAT)

            // ═══ 正文卡片 ═══
            Column() {
              Text('正文内容').fontSize(Theme.F_SUB).fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT_HINT).width('100%')
              Divider().color(Theme.DIVIDER).margin({ top: 8, bottom: 12 })
              Text(this.content).fontSize(16).fontColor(Theme.TEXT)
                .width('100%').lineHeight(28)
            }
            .width('100%').padding(18)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_XL)
            .shadow(Theme.SHADOW_CARD)
            .alignItems(HorizontalAlign.Start)

            // 操作
            Button('✓ 我知道了').height(48).fontSize(15).width('100%')
              .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
              .fontColor(Color.White).borderRadius(16)
              .shadow(Theme.SHADOW_FLOAT)
              .onClick((): void => { router.back(); })
          }
          .padding(20)
          .width('100%')
          .constraintSize({ maxWidth: 560 })
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
