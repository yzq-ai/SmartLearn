import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { DiscussionAuthor, DiscussionPost } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, Card, EmptyState, SkeletonCard, PrimaryButton, TagChip, showToast } from '../components/UiKit';

/**
 * 教学讨论区（需求 9）：仅教师/管理员可见可发言。
 * 学生调用后端会收到 403；本页入口也只在教师端展示。
 */
@Entry
@Component
struct TeacherRoom {
  @State loading: boolean = true;
  @State posts: DiscussionPost[] = [];
  @State title: string = '';
  @State content: string = '';
  @State sending: boolean = false;
  @State message: string = '';
  @State expanded: number = -1;

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    try {
      this.posts = await api.getTeacherRoom();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }

  private async send(): Promise<void> {
    const c: string = this.content.trim();
    if (c.length === 0) { return; }
    this.sending = true;
    try {
      await api.postTeacherRoom(this.title.trim(), c);
      this.title = '';
      this.content = '';
      showToast('✓ 已发布到教学讨论区', 'success');
      await this.load();
    } catch (error) {
      showToast(error instanceof Error ? error.message : '发布失败', 'fail');
    }
    this.sending = false;
  }

  private authorName(post: DiscussionPost): string {
    const a: DiscussionAuthor | null | undefined = post.author;
    if (a !== null && a !== undefined) {
      return a.real_name.length > 0 ? a.real_name : a.username;
    }
    return `用户 ${post.user_id}`;
  }

  private fmt(ts: string): string {
    if (ts === undefined || ts.length === 0) { return ''; }
    const d: Date = new Date(ts);
    return `${d.getMonth() + 1}-${d.getDate()} ${d.getHours() < 10 ? '0' : ''}${d.getHours()}:${d.getMinutes() < 10 ? '0' : ''}${d.getMinutes()}`;
  }

  build() {
    Column() {
      PageHeader({ title: '教学讨论区', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          // 提示条
          Row({ space: 8 }) {
            Text('🔒').fontSize(14)
            Text('教师专属讨论空间，学生不可见').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
          }.width('100%').padding(10)
          .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_MD)

          // 发帖卡
          Card() {
            Column({ space: 10 }) {
              Text('✍️ 发起讨论').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
              TextInput({ placeholder: '标题（可选）', text: this.title })
                .onChange((v: string): void => { this.title = v; })
                .height(42).fontSize(13).width('100%')
                .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
              TextArea({ placeholder: '和同事们聊聊教学心得、课程设计、学生情况…', text: this.content })
                .onChange((v: string): void => { this.content = v; })
                .fontSize(13).width('100%')
                .constraintSize({ minHeight: 90 })
                .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
              if (this.sending) {
                LoadingProgress().width(20).height(20).color(Theme.PRIMARY)
              } else {
                PrimaryButton({
                  label: '发布',
                  onTap: (): void => { this.send(); }
                })
              }
            }.width('100%')
          }

          // 帖子列表
          if (this.loading) {
            SkeletonCard(); SkeletonCard(); SkeletonCard()
          } else if (this.posts.length === 0) {
            EmptyState({ icon: '💬', text: this.message.length > 0 ? this.message : '还没有讨论，来发第一帖' })
          } else {
            ForEach(this.posts, (post: DiscussionPost) => {
              Card() {
                Column({ space: 8 }) {
                  Row({ space: 10 }) {
                    Column() {
                      Text(this.authorName(post).substring(0, 1))
                        .fontSize(15).fontWeight(FontWeight.Bold).fontColor(Color.White)
                    }.width(36).height(36).borderRadius(18)
                    .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                    Column({ space: 2 }) {
                      Row({ space: 6 }) {
                        Text(this.authorName(post)).fontSize(Theme.F_SUB).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                        TagChip({ text: '教师' })
                      }
                      Text(`${post.user_id} · ${this.fmt(post.created_at)}`)
                        .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    Blank()
                    Text(`👍 ${post.like_count}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  }.width('100%')
                  if (post.title !== null && post.title.length > 0) {
                    Text(post.title).fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  Text(post.content)
                    .fontSize(Theme.F_BODY).fontColor(Theme.TEXT).width('100%')
                    .maxLines(this.expanded === post.id ? 30 : 4)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.expanded === post.id ? '收起 ▴' : '展开 ▾')
                    .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    .onClick((): void => { this.expanded = this.expanded === post.id ? -1 : post.id; })
                }.width('100%')
              }
            }, (post: DiscussionPost) => `${post.id}-${post.like_count}-${this.expanded === post.id ? 1 : 0}`)
          }
        }.padding(20)
        .constraintSize({ maxWidth: 640 })
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
