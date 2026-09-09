import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { DiscussionPost } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, TagChip } from '../components/UiKit';

@Entry
@Component
struct DiscussionManage {
  @State rows: DiscussionPost[] = [];
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    try { this.rows = await api.getDiscussions(1); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }

  private async remove(id: number): Promise<void> {
    try {
      await api.deleteDiscussion(id);
      this.rows = await api.getDiscussions(1);
      this.message = '✓ 已删除';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '删除失败';
    }
  }

  build() {
    Column() {
      PageHeader({ title: '讨论管理', onBack: (): void => { router.back(); } })
      if (this.loading) {
        Column({ space: 12 }) { SkeletonCard(); SkeletonCard() }.padding(20)
      } else if (this.rows.length === 0) {
        EmptyState({ icon: '💬', text: '暂无讨论帖' })
      } else {
        List({ space: 10 }) {
          ForEach(this.rows, (post: DiscussionPost) => {
            ListItem() {
              Row({ space: 12 }) {
                Column() {
                  Text('💬').fontSize(18)
                }
                .width(42).height(42).borderRadius(Theme.R_MD)
                .backgroundColor(Theme.PRIMARY_LIGHT)
                .alignItems(HorizontalAlign.Center)
                Column({ space: 4 }) {
                  Text(post.content).fontSize(Theme.F_SUB).fontColor(Theme.TEXT)
                    .maxLines(2).width('100%')
                  Row({ space: 8 }) {
                    Text(`用户 #${post.user_id}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    Text(`👍 ${post.like_count}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    if (post.is_pinned === 1) {
                      TagChip({ text: '置顶', tone: 'warning' })
                    }
                  }
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text('🗑')
                  .fontSize(16).padding(8)
                  .onClick((): void => { this.remove(post.id); })
              }
              .width('100%').padding(14)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }
          }, (post: DiscussionPost) => String(post.id))
        }
        .lanes({ minLength: 360, maxLength: 540 }, 12)
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 4, bottom: 20 })
        .scrollBar(BarState.Off)
      }
      if (this.message.length > 0) {
        Text(this.message).fontSize(Theme.F_SUB)
          .fontColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
          .padding(8).width('100%').textAlign(TextAlign.Center)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
