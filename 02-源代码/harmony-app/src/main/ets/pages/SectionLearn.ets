import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { DiscussionAuthor, DiscussionPost, SectionDetail } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, Card, EmptyState, SkeletonCard, TagChip, showToast } from '../components/UiKit';

/**
 * 小节学习页（需求 6 学生端）：
 * - 视频 / 图文正文一体化展示（Video 组件在线播放）
 * - 小节下方讨论区：显示学生用户号 + 用户名，可回复、点赞、emoji 表情
 */
@Entry
@Component
struct SectionLearn {
  @State section: SectionDetail | null = null;
  @State chapterTitle: string = '';
  @State courseId: number = 1;
  @State loading: boolean = true;
  @State message: string = '';
  // 讨论区
  @State posts: DiscussionPost[] = [];
  @State postInput: string = '';
  @State replyInput: string = '';
  @State openPost: number = 0;
  @State emojiBar: boolean = false;
  @State sending: boolean = false;
  private videoController: VideoController = new VideoController();

  aboutToAppear(): void {
    const raw: Record<string, object> | null = router.getParams() as Record<string, object>;
    if (raw !== null && raw !== undefined) {
      const s: SectionDetail = raw.section as SectionDetail;
      this.section = s;
      this.chapterTitle = String(raw.chapterTitle ?? '');
      const cid: number = Number(raw.course_id);
      if (cid > 0) { this.courseId = cid; }
    }
    this.loadDiscussions();
    this.loading = false;
  }

  private async loadDiscussions(): Promise<void> {
    try {
      this.posts = await api.getDiscussions(this.courseId);
    } catch (error) {
      this.message = error instanceof Error ? error.message : '讨论加载失败';
    }
  }

  private async sendPost(): Promise<void> {
    const c: string = this.postInput.trim();
    if (c.length === 0) { return; }
    this.sending = true;
    try {
      await api.createDiscussion(this.courseId, c);
      this.postInput = '';
      showToast('✓ 已发布', 'success');
      await this.loadDiscussions();
    } catch (error) {
      showToast(error instanceof Error ? error.message : '发布失败', 'fail');
    }
    this.sending = false;
  }

  private async likePost(postId: number): Promise<void> {
    try {
      const r = await api.likeDiscussion(postId);
      const next: DiscussionPost[] = [];
      this.posts.forEach((p: DiscussionPost): void => {
        if (p.id === postId) {
          next.push({
            id: p.id, course_id: p.course_id, user_id: p.user_id, title: p.title,
            content: p.content, is_pinned: p.is_pinned, like_count: r.like_count,
            liked_by_me: true, created_at: p.created_at, author: p.author, reply_count: p.reply_count,
          });
        } else {
          next.push(p);
        }
      });
      this.posts = next;
    } catch (error) {
      showToast(error instanceof Error ? error.message : '点赞失败', 'fail');
    }
  }

  private async sendReply(): Promise<void> {
    const c: string = this.replyInput.trim();
    if (c.length === 0 || this.openPost === 0) { return; }
    this.sending = true;
    try {
      await api.replyDiscussion(this.openPost, c);
      this.replyInput = '';
      showToast('✓ 回复成功', 'success');
      await this.loadDiscussions();
    } catch (error) {
      showToast(error instanceof Error ? error.message : '回复失败', 'fail');
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

  build() {
    Column() {
      PageHeader({
        title: this.section !== null ? this.section.title : '小节学习',
        onBack: (): void => { router.back(); }
      })
      Scroll() {
        Column({ space: 14 }) {
          if (this.loading) {
            SkeletonCard(); SkeletonCard()
          } else if (this.section !== null) {
            // ═══ 视频区 ═══
            if (this.section.type === 'VIDEO') {
              Column() {
                Video({
                  src: this.section.video_url !== null && this.section.video_url !== undefined
                    ? this.section.video_url : '',
                  controller: this.videoController
                })
                  .width('100%').height(200)
                  .borderRadius(Theme.R_LG)
                  .autoPlay(false)
              }.width('100%')
              if (this.section.duration_minutes > 0) {
                Text(`时长约 ${this.section.duration_minutes} 分钟`)
                  .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
              }
            }

            // ═══ 正文区 ═══
            Card() {
              Column({ space: 10 }) {
                Row({ space: 8 }) {
                  TagChip({ text: this.section.type === 'VIDEO' ? '视频' : '图文' })
                  Text(this.chapterTitle).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                }.width('100%')
                Text(this.section.content.length > 0
                  ? this.section.content
                  : '本小节暂无文字内容，请观看视频或联系老师补充。')
                  .fontSize(Theme.F_BODY).fontColor(Theme.TEXT).width('100%')
                  .lineHeight(24)
              }.width('100%')
            }

            // ═══ 讨论区（需求 6）═══
            Card() {
              Column({ space: 12 }) {
                Row({ space: 8 }) {
                  Text('💬').fontSize(16)
                  Text('讨论区').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                  Blank()
                  Text(`${this.posts.length} 条`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                }.width('100%')
                // 发帖
                Row({ space: 8 }) {
                  TextInput({ placeholder: '说说你的想法…', text: this.postInput })
                    .onChange((v: string): void => { this.postInput = v; })
                    .layoutWeight(1).height(42).fontSize(13)
                    .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
                  Button('发布').height(42).fontSize(13)
                    .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                    .fontColor(Color.White).borderRadius(Theme.R_MD)
                    .enabled(this.postInput.trim().length > 0 && !this.sending)
                    .onClick((): void => { this.sendPost(); })
                }.width('100%')
                if (this.posts.length === 0) {
                  Text(this.message.length > 0 ? this.message : '暂无讨论，来抢沙发')
                    .fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).width('100%')
                } else {
                  ForEach(this.posts, (post: DiscussionPost) => {
                    Column({ space: 8 }) {
                      // 帖子
                      Row({ space: 10 }) {
                        Column() {
                          Text(this.authorName(post).substring(0, 1))
                            .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Color.White)
                        }.width(34).height(34).borderRadius(17)
                        .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                        Column({ space: 2 }) {
                          Text(this.authorName(post)).fontSize(Theme.F_SUB)
                            .fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
                            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                          Text(`${post.author?.user_code ?? post.user_id} · ${post.user_id}`)
                            .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                        Button(post.liked_by_me === true ? `❤️ ${post.like_count}` : `🤍 ${post.like_count}`)
                          .height(28).fontSize(Theme.F_CAP)
                          .backgroundColor(post.liked_by_me === true ? Theme.DANGER_LIGHT : Theme.INPUT_BG)
                          .fontColor(post.liked_by_me === true ? Theme.DANGER : Theme.TEXT)
                          .borderRadius(14)
                          .enabled(post.liked_by_me !== true)
                          .onClick((): void => { this.likePost(post.id); })
                      }.width('100%')
                      Text(post.content).fontSize(Theme.F_SUB).fontColor(Theme.TEXT).width('100%')
                        .maxLines(this.openPost === post.id ? 30 : 6)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(this.openPost === post.id ? '收起回复 ▴' : '回复 ▾')
                        .fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                        .onClick((): void => {
                          this.openPost = this.openPost === post.id ? 0 : post.id;
                        })
                      // 回复输入
                      if (this.openPost === post.id) {
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
                              .layoutWeight(1).height(38).fontSize(13)
                              .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
                            Button('发送').height(38).fontSize(12)
                              .backgroundColor(Theme.PRIMARY).fontColor(Color.White).borderRadius(19)
                              .enabled(this.replyInput.trim().length > 0 && !this.sending)
                              .onClick((): void => { this.sendReply(); })
                          }.width('100%')
                        }.width('100%')
                      }
                    }
                    .width('100%').padding(10)
                    .backgroundColor(Theme.BG).borderRadius(Theme.R_MD)
                  }, (post: DiscussionPost) => `${post.id}-${post.like_count}-${this.openPost === post.id ? 1 : 0}`)
                }
              }.width('100%')
            }
          } else {
            EmptyState({ icon: '📖', text: '小节内容加载失败' })
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
