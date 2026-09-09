import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { AuditLogItem } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard } from '../components/UiKit';

@Entry
@Component
struct AuditLogs {
  @State rows: AuditLogItem[] = [];
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    try { this.rows = await api.getAuditLogs(); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }

  private actionIcon(action: string): string {
    if (action.indexOf('CREATE') >= 0 || action.indexOf('PUBLISH') >= 0) return '➕';
    if (action.indexOf('DELETE') >= 0 || action.indexOf('REJECT') >= 0) return '🗑';
    if (action.indexOf('UPDATE') >= 0 || action.indexOf('GRADE') >= 0) return '✏️';
    if (action.indexOf('LOGIN') >= 0) return '🔑';
    return '📜';
  }

  build() {
    Column() {
      PageHeader({ title: '操作日志', onBack: (): void => { router.back(); } })
      if (this.loading) {
        Column({ space: 12 }) { SkeletonCard(); SkeletonCard(); SkeletonCard() }.padding(20)
      } else if (this.rows.length === 0) {
        EmptyState({ icon: '📜', text: '暂无操作日志' })
      } else {
        List({ space: 0 }) {
          ForEach(this.rows, (row: AuditLogItem, index: number) => {
            ListItem() {
              Row({ space: 12 }) {
                Column({ space: 2 }) {
                  Text(this.actionIcon(row.action))
                    .fontSize(14)
                    .width(36).height(36).textAlign(TextAlign.Center)
                    .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(18)
                  if (index < this.rows.length - 1) {
                    Column().width(2).layoutWeight(1)
                      .backgroundColor(Theme.DIVIDER)
                      .margin({ top: 4 })
                  }
                }.width(36)
                Column({ space: 4 }) {
                  Text(row.action).fontSize(Theme.F_BODY)
                    .fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
                  Text(`操作人 #${row.user_id ?? '-'} · 目标 ${row.target_type ?? '-'} #${row.target_id ?? '-'}`)
                    .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  Text(row.created_at).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .padding({ bottom: 16 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
              .padding({ left: 20, right: 20 })
            }
          }, (row: AuditLogItem) => `${row.id}-${row.created_at}`)
        }
        .lanes({ minLength: 400, maxLength: 620 }, 16)
        .layoutWeight(1)
        .padding({ top: 8, bottom: 20 })
        .scrollBar(BarState.Off)
      }
      if (this.message.length > 0) {
        Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER).padding(8)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
