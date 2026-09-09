import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { ChatMsg, ContactUser } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, showToast } from '../components/UiKit';

interface ChatParams { peerId?: number; peerName?: string; peerRole?: string; }

/**
 * 聊天页（需求 7/9/10）：与好友/老师私聊。
 * 8 秒轮询拉新消息；长按消息可复制；顶部显示对方身份。
 */
@Entry
@Component
struct Chat {
  @State messages: ChatMsg[] = [];
  @State input: string = '';
  @State loading: boolean = true;
  @State myUserId: number = 0;
  @State sending: boolean = false;
  @State peerId: number = 0;
  @State peerName: string = '';
  @State peerRole: string = '';
  @State message: string = '';
  @State lastListHeight: number = 0;  // 键盘避让检测用（需求 2）
  private scroller: Scroller = new Scroller();
  private pollTimer: number = -1;

  aboutToAppear(): void {
    const raw: Object | null = router.getParams();
    const params: ChatParams = (raw ?? {}) as ChatParams;
    this.peerId = Number(params.peerId ?? 0);
    this.peerName = String(params.peerName ?? '');
    this.peerRole = String(params.peerRole ?? '');
    this.myUserId = Number(AppStorage.get<string>('userId') ?? '0');
    this.load();
    this.pollTimer = setInterval((): void => { this.poll(); }, 8000);
  }

  aboutToDisappear(): void {
    if (this.pollTimer >= 0) { clearInterval(this.pollTimer); this.pollTimer = -1; }
  }

  private async load(): Promise<void> {
    try {
      this.messages = await api.getChatHistory(this.peerId);
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
    this.scrollBottom();
  }

  private async poll(): Promise<void> {
    try {
      const fresh: ChatMsg[] = await api.getChatHistory(this.peerId);
      if (fresh.length !== this.messages.length) {
        this.messages = fresh;
        this.scrollBottom();
      }
    } catch (_) {
      // 轮询失败静默（断网等情况）
    }
  }

  private scrollBottom(): void {
    this.scroller.scrollEdge(Edge.Bottom);
  }

  private async send(): Promise<void> {
    const text: string = this.input.trim();
    if (text.length === 0 || this.sending) { return; }
    this.sending = true;
    try {
      await api.sendChatMessage(this.peerId, text);
      this.input = '';
      this.messages = await api.getChatHistory(this.peerId);
      this.scrollBottom();
    } catch (error) {
      showToast(error instanceof Error ? error.message : '发送失败', 'fail');
    }
    this.sending = false;
  }

  private timeOf(ts: string): string {
    if (ts === undefined || ts === null || ts.length === 0) { return ''; }
    const d: Date = new Date(ts);
    const hh: string = d.getHours() < 10 ? `0${d.getHours()}` : `${d.getHours()}`;
    const mm: string = d.getMinutes() < 10 ? `0${d.getMinutes()}` : `${d.getMinutes()}`;
    return `${hh}:${mm}`;
  }

  private roleLabel(): string {
    return this.peerRole === 'TEACHER' ? '老师' : this.peerRole === 'STUDENT' ? '同学' : '用户';
  }

  build() {
    Column() {
      PageHeader({
        title: this.peerName.length > 0 ? this.peerName : '聊天',
        subtitle: `${this.roleLabel()} · 8 秒自动刷新`,
        onBack: (): void => { router.back(); },
      })

      // 消息列表
      if (this.loading) {
        Column({ space: 12 }) { SkeletonCard(); SkeletonCard(); SkeletonCard(); }.padding(20)
      } else {
        List({ scroller: this.scroller, space: 14 }) {
          if (this.messages.length === 0) {
            ListItem() {
              EmptyState({ icon: '💬', text: '开始你们的第一次对话吧' })
            }
          }
          ForEach(this.messages, (m: ChatMsg) => {
            ListItem() {
              this.MsgBubble(m)
            }
          }, (m: ChatMsg) => `${m.id}-${m.is_read}`)
        }
        .layoutWeight(1).width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .scrollBar(BarState.Off)
        // 需求 2：键盘弹出/收起导致列表高度变化时，贴底跟随（避免最新消息被顶出视口）
        .onAreaChange((_o: Area, n: Area): void => {
          const h: number = Number(n.height);
          if (h > 0 && Math.abs(h - this.lastListHeight) > 12) {
            this.lastListHeight = h;
            setTimeout((): void => { this.scrollBottom(); }, 120);
          }
        })
      }

      // 输入区
      Row({ space: 10 }) {
        TextInput({ placeholder: '输入消息…', text: this.input })
          .onChange((v: string): void => { this.input = v; })
          .layoutWeight(1).height(44)
          .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
          .fontSize(15).padding({ left: 14, right: 14 })
          .onSubmit((): void => { this.send(); })
          // 需求 2：键盘弹出时消息列表可视高度被压缩，滚动位置须跟随到底部，
          // 否则最新消息被键盘顶出视口不可见。
          .onFocus((): void => {
            setTimeout((): void => { this.scrollBottom(); }, 300);
          })
        Button(this.sending ? '…' : '发送')
          .width(72).height(44).fontSize(14).fontWeight(FontWeight.Medium)
          .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
          .fontColor(Color.White).borderRadius(Theme.R_MD)
          .enabled(!this.sending && this.input.trim().length > 0)
          .opacity(this.sending ? 0.5 : 1)
          .onClick((): void => { this.send(); })
      }
      .width('100%').padding({ left: 14, right: 14, top: 10, bottom: 14 })
      .backgroundColor(Theme.CARD)
      .shadow(Theme.SHADOW_FLOAT)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }

  @Builder MsgBubble(m: ChatMsg) {
    // 我发的（右）；对方（左）——头像 + 气泡 + 时间
    Row({ space: 10 }) {
      if (m.sender_id !== this.myUserId) {
        Column() {
          Text(this.roleLabel() === '老师' ? '👩‍🏫' : '🧑‍🎓').fontSize(20)
        }
        .width(38).height(38).borderRadius(19)
        .backgroundColor(Theme.PRIMARY_LIGHT)
        .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
      }
      Column({ space: 4 }) {
        if (m.sender_id === this.myUserId) {
          Text(m.content)
            .fontSize(15).fontColor(Color.White)
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
            .borderRadius({
              topLeft: 16, topRight: 16,
              bottomLeft: 16, bottomRight: 4
            })
            .constraintSize({ maxWidth: '86%' })
          Text(`${this.timeOf(m.created_at)}${m.is_read ? ' · 已读' : ' · 已发送'}`)
            .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
        } else {
          Text(m.content)
            .fontSize(15).fontColor(Theme.TEXT)
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .backgroundColor(Theme.CARD)
            .borderRadius({
              topLeft: 4, topRight: 16,
              bottomLeft: 16, bottomRight: 16
            })
            .constraintSize({ maxWidth: '86%' })
            .shadow(Theme.SHADOW_CARD)
          Text(this.timeOf(m.created_at)).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
        }
      }.alignItems(m.sender_id === this.myUserId ? HorizontalAlign.End : HorizontalAlign.Start)
      .layoutWeight(1)
      if (m.sender_id === this.myUserId) {
        Column() {
          Text('🧑‍🎓').fontSize(20)
        }
        .width(38).height(38).borderRadius(19)
        .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
        .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}
