import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { NotificationItem } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, TagChip, EmptyState, SkeletonCard } from '../components/UiKit';
@Entry
@Component
struct Notifications {
  @State rows: NotificationItem[] = [];
  @State loading: boolean = true;
  @State message: string = '';
  @State unread: number = 0;
  @State markingAll: boolean = false;
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    this.loading = true;
    this.message = '';
    try {
      this.rows = await api.getNotifications();
      this.unread = this.rows.filter((it: NotificationItem): boolean => !(it.is_read ?? 0)).length;
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }
  private async markRead(item: NotificationItem): Promise<void> {
    if (item.is_read) { return; }
    try {
      await api.markNotificationRead(item.id);
      item.is_read = 1;
      this.unread = Math.max(0, this.unread - 1);
    } catch (_) {
      // 已读标记失败不阻断浏览
    }
  }
  private async markAllRead(): Promise<void> {
    this.markingAll = true;
    try {
      await api.markAllNotificationsRead();
      for (const it of this.rows) { it.is_read = 1; }
      this.unread = 0;
    } catch (error) {
      this.message = error instanceof Error ? error.message : '操作失败';
    }
    this.markingAll = false;
  }
  private typeIcon(type: string): string {
    if (type === 'SYSTEM') return '📢';
    if (type === 'EXAM') return '📝';
    if (type === 'JOB') return '💼';
    return '🔔';
  }
  private typeName(type: string): string {
    if (type === 'SYSTEM') return '系统';
    if (type === 'EXAM') return '考试';
    if (type === 'JOB') return '就业';
    if (type === 'COURSE') return '课程';
    if (type === 'EVENT') return '活动';
    if (type === 'FRIEND_ACCEPT') return '好友';
    if (type === 'FRIEND_REQUEST') return '好友';
    if (type === 'SIGN') return '签到';
    if (type === 'ASSIGNMENT') return '作业';
    return '通知';
  }
  build() {
    Column() {
      PageHeader({ title: '消息中心', onBack: (): void => { router.back(); } })
      if (this.loading) {
        Column({ space: 12 }) {
          SkeletonCard(); SkeletonCard(); SkeletonCard()
        }.padding(20)
      } else if (this.rows.length === 0) {
        EmptyState({ icon: '🔔', text: '暂无消息通知' })
      } else {
        // 工具栏：未读统计 + 全部已读
        Row({ space: 10 }) {
          Row({ space: 6 }) {
            Text('🔔').fontSize(13)
            Text(`未读 ${this.unread} 条`).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
          }.layoutWeight(1)
          Button(this.markingAll ? '处理中…' : '✓ 全部已读')
            .height(34).fontSize(13)
            .backgroundColor(this.unread > 0 ? Theme.PRIMARY : Theme.INPUT_BG)
            .fontColor(this.unread > 0 ? Color.White : Theme.TEXT_HINT)
            .enabled(this.unread > 0 && !this.markingAll)
            .onClick((): void => { this.markAllRead(); })
        }
        .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 4 })
        List({ space: 12 }) {
          ForEach(this.rows, (item: NotificationItem) => {
            ListItem() {
              Column({ space: 8 }) {
                Row({ space: 12 }) {
                  Column() {
                    Text(this.typeIcon(item.type)).fontSize(18)
                    if (!(item.is_read ?? 0)) {
                      // 未读红点（图标右上角）
                      Circle().width(9).height(9).fill(Theme.DANGER)
                        .position({ x: 30, y: 2 })
                    }
                  }
                  .width(44).height(44).borderRadius(22)
                  .backgroundColor(Theme.PRIMARY_LIGHT)
                  .alignItems(HorizontalAlign.Center)
                  Column({ space: 4 }) {
                    Row({ space: 6 }) {
                      Text(item.title).fontSize(Theme.F_BODY)
                        .fontWeight(FontWeight.Medium).fontColor(Theme.TEXT).layoutWeight(1).maxLines(1)
                      if (!(item.is_read ?? 0)) {
                        Text('NEW').fontSize(Theme.F_CAP).fontWeight(FontWeight.Bold)
                          .fontColor(Color.White)
                          .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                          .borderRadius(4)
                          .linearGradient({ angle: 135, colors: [[Theme.DANGER, 0], ['#FF6B9D', 1]] })
                      }
                    }.width('100%')
                    if (item.content !== null && item.content !== undefined) {
                      Text(item.content).fontSize(Theme.F_SUB)
                        .fontColor(Theme.TEXT_HINT).width('100%').maxLines(2)
                        .opacity((item.is_read ?? 0) ? 0.75 : 1)
                    }
                    Text(item.created_at).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  TagChip({ text: this.typeName(item.type) })
                }.width('100%')
                // 点击查看完整消息内容
                Row({ space: 4 }) {
                  Text('查看详情').fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                  Text('›').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
                }.width('100%').justifyContent(FlexAlign.End)
              }
              .width('100%').padding(14)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
              .onClick((): void => {
                this.markRead(item);
                router.pushUrl({
                  url: 'pages/NotificationDetail',
                  params: {
                    type: item.type,
                    title: item.title,
                    content: item.content ?? '',
                    created_at: item.created_at
                  }
                });
              })
            }
          }, (item: NotificationItem) => `${item.id}-${item.is_read ?? 0}`)
        }
        .lanes({ minLength: 360, maxLength: 540 }, 12)
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 4, bottom: 20 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
