import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { DiscussionAuthor, DiscussionDetail, DiscussionPost, DiscussionReplyItem } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, showToast } from '../components/UiKit';

/**
 * 讨论广场（需求 16）：全站讨论流 + 分页（10/50/100 条/页）。
 * 帖子可展开查看回复、点赞、回复、emoji 快捷表情。
 */
@Entry
@Component
struct DiscussionSquare {
  @State loading: boolean = true;
  @State posts: DiscussionPost[] = [];
  @State total: number = 0;
  @State page: number = 1;
  @State pageSize: number = 10;   // 10 / 50 / 100
  @State message: string = '';
  @State detail: DiscussionDetail | null = null;   // 展开的帖子详情
  @State detailLoading: boolean = false;
  @State replyInput: string = '';
  @State emojiBar: boolean = false;

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    try {
      const p = await api.getDiscussionPage(this.page, this.pageSize);
      this.posts = p.items;
      this.total = p.total;
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }

  private totalPages(): number {
    return Math.max(1, Math.ceil(this.total / this.pageSize));
  }

  private async openDetail(postId: number): Promise<void> {
    if (this.detail !== null && this.detail.id === postId) {
      this.detail = null;  // 再次点击收起
      return;
    }
    this.detailLoading = true;
    this.detail = null;
    try {
      this.detail = await api.getDiscussionDetail(postId);
    } catch (error) {
      showToast(error instanceof Error ? error.message : '加载详情失败', 'fail');
    }
    this.detailLoading = false;
  }

  private async likePost(postId: number): Promise<void> {
    try {
      const r = await api.likeDiscussion(postId);
      // 刷新列表与详情的计数（ArkTS 不允许 spread interface，逐项重建）
      const next: DiscussionPost[] = [];
      this.posts.forEach((p: DiscussionPost): void => {
        if (p.id === postId) {
          const q: DiscussionPost = {
            id: p.id, course_id: p.course_id, user_id: p.user_id, title: p.title,
            content: p.content, is_pinned: p.is_pinned, like_count: r.like_count,
            liked_by_me: true, created_at: p.created_at, author: p.author, reply_count: p.reply_count,
          };
          next.push(q);
        } else {
          next.push(p);
        }
      });
      this.posts = next;
      if (this.detail !== null && this.detail.id === postId) {
        const d: DiscussionDetail = this.detail;
        this.detail = {
          id: d.id, course_id: d.course_id, user_id: d.user_id, author: d.author,
          title: d.title, content: d.content, is_pinned: d.is_pinned,
          like_count: r.like_count, liked_by_me: true, created_at: d.created_at, replies: d.replies,
        };
      }
    } catch (error) {
      showToast(error instanceof Error ? error.message : '点赞失败', 'fail');
    }
  }

  private async likeReply(replyId: number): Promise<void> {
    try {
      const r = await api.likeReply(replyId);
      if (this.detail !== null) {
        const d: DiscussionDetail = this.detail;
        const replies: DiscussionReplyItem[] = [];
        d.replies.forEach((r2: DiscussionReplyItem): void => {
          if (r2.id === replyId) {
            replies.push({
              id: r2.id, post_id: r2.post_id, user_id: r2.user_id, author: r2.author,
              content: r2.content, reply_to_id: r2.reply_to_id,
              like_count: r.like_count, liked_by_me: true, created_at: r2.created_at,
            });
          } else {
            replies.push(r2);
          }
        });
        this.detail = {
          id: d.id, course_id: d.course_id, user_id: d.user_id, author: d.author,
          title: d.title, content: d.content, is_pinned: d.is_pinned,
          like_count: d.like_count, liked_by_me: d.liked_by_me, created_at: d.created_at, replies: replies,
        };
      }
    } catch (error) {
      showToast(error instanceof Error ? error.message : '点赞失败', 'fail');
    }
  }

  private async sendReply(): Promise<void> {
    const text: string = this.replyInput.trim();
    if (text.length === 0 || this.detail === null) { return; }
    try {
      await api.replyDiscussion(this.detail.id, text);
      this.replyInput = '';
      showToast('回复成功', 'success');
      await this.openDetail(this.detail.id);
      await this.load();
    } catch (error) {
      showToast(error instanceof Error ? error.message : '回复失败', 'fail');
    }
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
      PageHeader({ title: '讨论广场', onBack: (): void => { router.back(); } })
      // ── 分页大小选择 ──
      Row({ space: 8 }) {
        Text('每页').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
        ForEach([10, 50, 100], (size: number) => {
          Text(`${size} 条`)
            .fontSize(13)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .fontColor(this.pageSize === size ? Color.White : Theme.TEXT)
            .backgroundColor(this.pageSize === size ? Theme.PRIMARY : Theme.INPUT_BG)
            .borderRadius(14)
            .onClick((): void => {
              this.pageSize = size; this.page = 1; this.load();
            })
        }, (size: number) => String(size))
        Blank()
        Text(`共 ${this.total} 帖`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
      }
      .width('100%').padding({ left: 16, right: 16, top: 4, bottom: 8 })

      Scroll() {
        Column({ space: 12 }) {
          if (this.loading) {
            Column({ space: 12 }) { SkeletonCard(); SkeletonCard(); SkeletonCard(); }.width('100%')
          } else if (this.posts.length === 0) {
            EmptyState({ icon: '💬', text: this.message.length > 0 ? this.message : '暂无讨论，来发第一帖吧' })
          } else {
            ForEach(this.posts, (post: DiscussionPost) => {
              Column({ space: 10 }) {
                // 帖子头：作者 + 时间
                Row({ space: 10 }) {
                  Column() {
                    Text(this.authorName(post).substring(0, 1))
                      .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
                  }.width(38).height(38).borderRadius(19)
                  .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                  Column({ space: 2 }) {
                    Text(this.authorName(post)).fontSize(Theme.F_SUB).fontWeight(FontWeight.Medium)
                      .fontColor(Theme.TEXT)
                    Text(`${post.user_id} · ${this.fmt(post.created_at)}`)
                      .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  if ((post.reply_count ?? 0) > 0) {
                    Text(`💬 ${post.reply_count}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
                  }
                }.width('100%')
                if (post.title !== null && post.title.length > 0) {
                  Text(post.title).fontSize(15).fontWeight(FontWeight.Bold)
                    .fontColor(Theme.TEXT).width('100%')
                }
                Text(post.content).fontSize(Theme.F_BODY).fontColor(Theme.TEXT)
                  .width('100%').maxLines(4)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                // 操作行：点赞 + 展开
                Row({ space: 10 }) {
                  Button(post.liked_by_me === true ? `❤️ ${post.like_count}` : `🤍 ${post.like_count}`)
                    .height(30).fontSize(12)
                    .backgroundColor(post.liked_by_me === true ? '#FFF0F2' : Theme.INPUT_BG)
                    .fontColor(post.liked_by_me === true ? '#FF4D6D' : Theme.TEXT)
                    .borderRadius(15)
                    .enabled(post.liked_by_me !== true)
                    .onClick((): void => { this.likePost(post.id); })
                  Blank()
                  Text(this.detail !== null && this.detail.id === post.id ? '收起 ▴' : '回复与详情 ▾')
                    .fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                    .onClick((): void => { this.openDetail(post.id); })
                }.width('100%')

                // ── 展开的详情 + 回复区 ──
                if (this.detailLoading && this.detail === null) {
                  Text('加载中…').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                } else if (this.detail !== null && this.detail.id === post.id) {
                  Column({ space: 10 }) {
                    // 回复列表
                    if (this.detail.replies.length === 0) {
                      Text('暂无回复，沙发等你来').fontSize(Theme.F_CAP)
                        .fontColor(Theme.TEXT_HINT).width('100%')
                    } else {
                      ForEach(this.detail.replies, (r: DiscussionReplyItem) => {
                        Column({ space: 6 }) {
                          Row({ space: 8 }) {
                            Text((r.author !== null && r.author.real_name.length > 0)
                              ? r.author.real_name.substring(0, 1)
                              : '👤')
                              .fontSize(12)
                              .width(26).height(26).textAlign(TextAlign.Center)
                              .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(13)
                              .fontColor(Theme.PRIMARY)
                            Column({ space: 2 }) {
                              Text(r.author !== null
                                ? (r.author.real_name.length > 0 ? r.author.real_name : r.author.username)
                                : `用户 ${r.user_id}`)
                                .fontSize(Theme.F_CAP).fontColor(Theme.TEXT).fontWeight(FontWeight.Medium)
                              Text(`#${r.user_id}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                            }.alignItems(HorizontalAlign.Start)
                            Blank()
                            Button(r.liked_by_me ? `❤️ ${r.like_count}` : `🤍 ${r.like_count}`)
                              .height(24).fontSize(Theme.F_CAP)
                              .backgroundColor(r.liked_by_me ? '#FFF0F2' : Theme.INPUT_BG)
                              .fontColor(r.liked_by_me ? '#FF4D6D' : Theme.TEXT)
                              .borderRadius(12)
                              .enabled(!r.liked_by_me)
                              .onClick((): void => { this.likeReply(r.id); })
                          }.width('100%')
                          Text(r.content).fontSize(Theme.F_SUB).fontColor(Theme.TEXT).width('100%')
                        }
                        .width('100%').padding(10)
                        .backgroundColor(Theme.BG).borderRadius(Theme.R_MD)
                      }, (r: DiscussionReplyItem) => `${r.id}-${r.like_count}-${r.liked_by_me ? 1 : 0}`)
                    }
                    // 回复输入 + emoji
                    Column({ space: 8 }) {
                      if (this.emojiBar) {
                        Row({ space: 6 }) {
                          ForEach(['👍', '❤️', '😂', '😮', '😢', '🎉', '🔥', '✨', '🙏', '💯'], (e: string) => {
                            Text(e).fontSize(22)
                              .onClick((): void => { this.replyInput = `${this.replyInput}${e}`; })
                          }, (e: string) => e)
                        }.width('100%').padding(8)
                        .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
                      }
                      Row({ space: 8 }) {
                        Text('😀').fontSize(22)
                          .onClick((): void => { this.emojiBar = !this.emojiBar; })
                        TextInput({ placeholder: '回复…', text: this.replyInput })
                          .onChange((v: string): void => { this.replyInput = v; })
                          .layoutWeight(1).height(40).fontSize(13)
                          .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
                        Button('回复').height(40).fontSize(13)
                          .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                          .fontColor(Color.White).borderRadius(Theme.R_MD)
                          .enabled(this.replyInput.trim().length > 0)
                          .onClick((): void => { this.sendReply(); })
                      }.width('100%')
                    }.width('100%')
                  }
                  .width('100%').padding(10)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
                }
              }
              .width('100%').padding(14)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }, (post: DiscussionPost) => `${post.id}-${post.like_count}-${this.detail !== null && this.detail.id === post.id ? 'open' : 'closed'}`)
          }

          // ── 翻页器 ──
          if (!this.loading && this.total > this.pageSize) {
            Row({ space: 10 }) {
              Button('‹ 上一页').height(36).fontSize(13)
                .backgroundColor(Theme.INPUT_BG).fontColor(Theme.TEXT)
                .borderRadius(18)
                .enabled(this.page > 1)
                .opacity(this.page > 1 ? 1 : 0.4)
                .onClick((): void => {
                  if (this.page > 1) { this.page -= 1; this.detail = null; this.load(); }
                })
              Text(`${this.page} / ${this.totalPages()}`)
                .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                .padding({ left: 16, right: 16 })
              Button('下一页 ›').height(36).fontSize(13)
                .backgroundColor(Theme.INPUT_BG).fontColor(Theme.TEXT)
                .borderRadius(18)
                .enabled(this.page < this.totalPages())
                .opacity(this.page < this.totalPages() ? 1 : 0.4)
                .onClick((): void => {
                  if (this.page < this.totalPages()) { this.page += 1; this.detail = null; this.load(); }
                })
            }.width('100%').justifyContent(FlexAlign.Center).padding(8)
          }
        }.width('100%').padding({ left: 16, right: 16, bottom: 24 })
      }
      .scrollBar(BarState.Off).layoutWeight(1)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
