import { promptAction, router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { FeedbackItem, FeedbackStats, AdminFeedbackPage } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, TagChip, EmptyState, SkeletonCard, BottomSpace } from '../components/UiKit';

@Entry
@Component
struct FeedbackManage {
  @State stats: FeedbackStats | null = null;
  @State rows: FeedbackItem[] = [];
  @State loading: boolean = true;
  @State message: string = '';
  @State filter: string = 'ALL';
  @State page: number = 1;
  @State total: number = 0;
  // 处理对话框
  @State handling: FeedbackItem | null = null;
  @State replyText: string = '';
  @State nextStatus: string = 'RESOLVED';
  @State submitting: boolean = false;
  @State adminName: string = AppStorage.get<string>('username') ?? 'admin';

  private readonly pageSize: number = 20;

  aboutToAppear(): void { this.load(); }

  private async load(reset: boolean = true): Promise<void> {
    if (reset) { this.page = 1; }
    this.loading = true;
    this.message = '';
    try {
      const stats: FeedbackStats = await api.getAdminFeedbackStats();
      const page: AdminFeedbackPage = await api.getAdminFeedback(this.filter, this.page);
      this.stats = stats;
      this.rows = page.items;
      this.total = page.total;
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }

  private async loadMore(): Promise<void> {
    if (this.loading || this.rows.length >= this.total) { return; }
    this.loading = true;
    try {
      this.page += 1;
      const page = await api.getAdminFeedback(this.filter, this.page);
      this.rows = this.rows.concat(page.items);
    } catch (_) {
      this.page -= 1;
    }
    this.loading = false;
  }

  private statusTone(status: string): string {
    if (status === 'RESOLVED') return 'success';
    if (status === 'PROCESSING') return 'primary';
    if (status === 'REJECTED') return 'danger';
    return 'warning';
  }
  private catTone(cat: string): string {
    if (cat === 'BUG') return 'danger';
    if (cat === 'FEATURE') return 'primary';
    if (cat === 'EXPERIENCE') return 'warning';
    if (cat === 'CONTENT') return 'success';
    return 'primary';
  }

  private openHandle(f: FeedbackItem, status: string): void {
    this.handling = f;
    this.nextStatus = status;
    this.replyText = f.reply ?? '';
  }

  private async confirmHandle(): Promise<void> {
    if (this.handling === null) { return; }
    if (this.nextStatus === 'REJECTED' && this.replyText.trim().length === 0) {
      promptAction.showToast({ message: '驳回时必须填写理由', duration: 1800 });
      return;
    }
    this.submitting = true;
    try {
      await api.handleAdminFeedback(this.handling.id, this.nextStatus, this.replyText.trim());
      promptAction.showToast({ message: '处理结果已保存', duration: 1800 });
      this.handling = null;
      this.replyText = '';
      this.load();
    } catch (error) {
      promptAction.showToast({ message: error instanceof Error ? error.message : '操作失败', duration: 2000 });
    }
    this.submitting = false;
  }

  private statusLabel(key: string): string {
    if (key === 'ALL') return `全部 ${this.stats?.total ?? 0}`;
    if (key === 'PENDING') return `待处理 ${this.stats?.pending ?? 0}`;
    if (key === 'PROCESSING') return `处理中 ${this.stats?.processing ?? 0}`;
    if (key === 'RESOLVED') return `已解决 ${this.stats?.resolved ?? 0}`;
    return `已驳回 ${this.stats?.rejected ?? 0}`;
  }

  build() {
    Column() {
      PageHeader({
        title: '反馈中心',
        subtitle: `共 ${this.total} 条 · 待处理 ${this.stats?.pending ?? 0}`,
        onBack: (): void => { router.back(); },
      })
      // 状态筛选 Tab（Scroll 包裹支持横向滚动）
      Scroll() {
        Row({ space: 8 }) {
          ForEach(['ALL', 'PENDING', 'PROCESSING', 'RESOLVED', 'REJECTED'], (k: string) => {
            Text(this.statusLabel(k))
              .fontSize(Theme.F_CAP)
              .fontColor(this.filter === k ? Color.White : Theme.TEXT_SECOND)
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .backgroundColor(this.filter === k ? Theme.PRIMARY : Theme.INPUT_BG)
              .borderRadius(16)
              .onClick((): void => {
                if (this.filter !== k) { this.filter = k; this.load(); }
              })
          }, (k: string) => `${k}-${this.stats ? this.stats.pending : 0}`)
        }
      }
      .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      .width('100%').padding({ left: 20, right: 20, top: 10, bottom: 4 })


      if (this.loading && this.rows.length === 0) {
        Column({ space: 12 }) {
          SkeletonCard(); SkeletonCard(); SkeletonCard()
        }.padding(20)
      } else if (this.rows.length === 0) {
        Column() { EmptyState({ icon: '📮', text: '暂无该状态的反馈' }) }.layoutWeight(1)
      } else {
        List({ space: 12 }) {
          ForEach(this.rows, (f: FeedbackItem) => {
            ListItem() {
              Column({ space: 10 }) {
                Row({ space: 8 }) {
                  Text(f.real_name || f.username).fontSize(Theme.F_CAP)
                    .fontColor(Theme.PRIMARY).fontWeight(FontWeight.Medium)
                  TagChip({ text: f.role === 'TEACHER' ? '教师' : '学生', tone: 'primary' })
                  Text(f.created_at).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).layoutWeight(1)
                }.width('100%')
                Row({ space: 8 }) {
                  TagChip({ text: f.category_label, tone: this.catTone(f.category) })
                  Text(f.title).fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium)
                    .fontColor(Theme.TEXT).layoutWeight(1).maxLines(1)
                  TagChip({ text: f.status_label, tone: this.statusTone(f.status) })
                }.width('100%')
                Text(f.content).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
                  .width('100%').maxLines(3)
                if (f.reply !== null && f.reply !== undefined && f.reply.length > 0) {
                  Text(`${f.handler_name ?? '管理员'}：${f.reply}`).fontSize(Theme.F_SUB)
                    .fontColor(Theme.PRIMARY).width('100%').maxLines(2)
                    .padding(10).backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_MD)
                }
                // 操作：待处理 → 开始处理/直接解决/驳回；处理中 → 解决/驳回
                Row({ space: 8 }) {
                  if (f.status !== 'RESOLVED' && f.status !== 'REJECTED') {
                    Button('解决').height(32).fontSize(Theme.F_CAP)
                      .backgroundColor(Theme.SUCCESS).fontColor(Color.White)
                      .borderRadius(16).padding({ left: 14, right: 14 })
                      .onClick((): void => { this.openHandle(f, 'RESOLVED'); })
                    if (f.status === 'PENDING') {
                      Button('处理中').height(32).fontSize(Theme.F_CAP)
                        .backgroundColor(Theme.PRIMARY).fontColor(Color.White)
                        .borderRadius(16).padding({ left: 14, right: 14 })
                        .onClick((): void => { this.openHandle(f, 'PROCESSING'); })
                    }
                    Button('驳回').height(32).fontSize(Theme.F_CAP)
                      .backgroundColor(Theme.DANGER_LIGHT).fontColor(Theme.DANGER)
                      .borderRadius(16).padding({ left: 14, right: 14 })
                      .onClick((): void => { this.openHandle(f, 'REJECTED'); })
                  } else {
                    Text(f.handled_at !== null ? `处理于 ${f.handled_at} · ${f.handler_name ?? ''}` : '')
                      .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  }
                }.width('100%').justifyContent(FlexAlign.End)
              }
              .width('100%').padding(14)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }
          }, (f: FeedbackItem) => `${f.id}-${f.status}`)
          ListItem() {
            if (this.rows.length < this.total) {
              Button('加载更多').width('100%').height(40).fontSize(Theme.F_CAP)
                .backgroundColor(Theme.INPUT_BG).fontColor(Theme.TEXT_SECOND)
                .borderRadius(Theme.R_MD)
                .onClick((): void => { this.loadMore(); })
            } else {
              BottomSpace()
            }
          }
        }
        .lanes({ minLength: 360, maxLength: 540 }, 12)
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 8, bottom: 12 })
        .scrollBar(BarState.Off)
      }
      // 处理对话框
      if (this.handling !== null) {
        Column() {
          Column({ space: 14 }) {
            Row({ space: 8 }) {
              Text(this.handling.title).fontSize(Theme.F_BODY).fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT).layoutWeight(1).maxLines(1)
              Text('✕').fontSize(18).fontColor(Theme.TEXT_HINT)
                .onClick((): void => { this.handling = null; })
            }.width('100%')
            Text(this.handling.content).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
              .width('100%').maxLines(4)
            TextArea({ placeholder: this.nextStatus === 'REJECTED' ? '驳回理由（必填）' : '处理回复（将展示给反馈人）', text: this.replyText })
              .onChange((v: string) => { this.replyText = v; })
              .height(110).fontSize(Theme.F_BODY)
            Row({ space: 10 }) {
              Button('取消').height(42).fontSize(14).layoutWeight(1)
                .backgroundColor(Theme.INPUT_BG).fontColor(Theme.TEXT_SECOND)
                .borderRadius(Theme.R_MD)
                .onClick((): void => { this.handling = null; })
              Button(this.submitting ? '保存中…' : (this.nextStatus === 'REJECTED' ? '确认驳回' : (this.nextStatus === 'PROCESSING' ? '标记处理中' : '确认解决')))
                .height(42).fontSize(14).layoutWeight(1)
                .backgroundColor(this.nextStatus === 'REJECTED' ? Theme.DANGER : Theme.SUCCESS)
                .fontColor(Color.White).borderRadius(Theme.R_MD)
                .enabled(!this.submitting)
                .onClick((): void => { this.confirmHandle(); })
            }.width('100%')
          }
          .width('92%').padding(18)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)
        }
        .width('100%').height('100%')
        .backgroundColor('rgba(0,0,0,0.45)')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .position({ x: 0, y: 0 })
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
