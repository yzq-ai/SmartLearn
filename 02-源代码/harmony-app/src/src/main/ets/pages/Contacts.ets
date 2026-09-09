import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { ContactApplyResult, ContactItem, ContactRequestItem, ContactUser, SearchUserResult } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, showToast } from '../components/UiKit';

interface ContactsParams { mode?: string; } // 'friend' | 'teacher'

/**
 * 联系人页（需求 6/7/9/10）：好友 & 我的老师 双 Tab。
 * - 列表（备注名/最后一条消息/未读）→ 点击进聊天
 * - 搜索用户号添加（申请-同意流）
 * - 收到的申请（同意/拒绝）
 * - 长按/编辑备注名
 */
@Entry
@Component
struct Contacts {
  @State mode: string = 'friend';       // friend | teacher
  @State loading: boolean = true;
  @State friends: ContactItem[] = [];
  @State teachers: ContactItem[] = [];
  @State requests: ContactRequestItem[] = [];
  @State message: string = '';
  @State showAdd: boolean = false;      // 添加面板展开
  @State searchCode: string = '';       // 用户号输入
  @State searchResult: SearchUserResult | null = null;
  @State searching: boolean = false;
  @State applying: boolean = false;
  @State remarkTarget: ContactItem | null = null;  // 备注编辑对象
  @State remarkInput: string = '';

  aboutToAppear(): void {
    const raw: Object | null = router.getParams();
    const params: ContactsParams = (raw ?? {}) as ContactsParams;
    this.mode = params.mode === 'teacher' ? 'teacher' : 'friend';
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    try {
      this.friends = await api.getMyFriends();
      this.teachers = await api.getMyTeachers();
      this.requests = await api.getIncomingRequests();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }

  private activeList(): ContactItem[] {
    return this.mode === 'teacher' ? this.teachers : this.friends;
  }

  private title(): string {
    const role: string = (AppStorage.get<string>('role') ?? 'STUDENT');
    if (this.mode === 'teacher') {
      // 需求 4：教师视角显示「我的学生」
      return role === 'TEACHER' ? '我的学生' : '我的老师';
    }
    return '我的好友';
  }

  private relType(): string {
    return this.mode === 'teacher' ? 'TEACHER' : 'FRIEND';
  }

  private async doSearch(): Promise<void> {
    const code: string = this.searchCode.trim();
    if (code.length === 0) { showToast('请输入用户号', 'warning'); return; }
    this.searching = true;
    this.searchResult = null;
    try {
      this.searchResult = await api.searchUserByCode(code);
    } catch (error) {
      showToast(error instanceof Error ? error.message : '搜索失败', 'fail');
    }
    this.searching = false;
  }

  private async doApply(): Promise<void> {
    if (this.searchResult === null || this.applying) { return; }
    this.applying = true;
    try {
      const r: ContactApplyResult = await api.applyContact(
        this.searchResult.user.user_code, this.relType());
      showToast(r.message, r.already ? 'warning' : 'success');
      if (!r.already) { this.searchResult = null; this.searchCode = ''; }
    } catch (error) {
      showToast(error instanceof Error ? error.message : '申请失败', 'fail');
    }
    this.applying = false;
  }

  private async handleRequest(req: ContactRequestItem, accept: boolean): Promise<void> {
    try {
      await api.handleContact(req.requester.id, req.rel_type, accept);
      showToast(accept ? '已同意' : '已拒绝', 'success');
      this.requests = this.requests.filter((r: ContactRequestItem): boolean => r.requester.id !== req.requester.id);
      await this.load();
    } catch (error) {
      showToast(error instanceof Error ? error.message : '操作失败', 'fail');
    }
  }

  private openRemark(item: ContactItem): void {
    this.remarkTarget = item;
    this.remarkInput = item.remark ?? '';
  }

  private async saveRemark(): Promise<void> {
    const target: ContactItem | null = this.remarkTarget;
    if (target === null) { return; }
    try {
      await api.updateContactRemark(target.user.id, this.relType(), this.remarkInput.trim());
      showToast('备注已更新', 'success');
      this.remarkTarget = null;
      await this.load();
    } catch (error) {
      showToast(error instanceof Error ? error.message : '保存失败', 'fail');
    }
  }

  private intoChat(item: ContactItem): void {
    router.pushUrl({
      url: 'pages/Chat',
      params: {
        peerId: item.user.id,
        peerName: item.display_name,
        peerRole: item.user.role,
      }
    });
  }

  private roleBadge(role: string): string {
    return role === 'TEACHER' ? '👩‍🏫 老师' : role === 'STUDENT' ? '🧑‍🎓 同学' : '👤';
  }

  build() {
    Column() {
      PageHeader({ title: this.title(), onBack: (): void => { router.back(); } })
      // ── Tab 切换 ──
      Row({ space: 0 }) {
        this.ModeTab('friend', '👥 我的好友', this.friends.length)
        // 需求 4：教师视角「我的学生」
        this.ModeTab('teacher', (AppStorage.get<string>('role') ?? 'STUDENT') === 'TEACHER'
          ? '🧑‍🎓 我的学生' : '👩‍🏫 我的老师', this.teachers.length)
      }
      .width('100%').margin({ top: 4, bottom: 8 })
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column({ space: 12 }) {
          // ── 添加入口 ──
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Text(this.mode === 'teacher'
                ? ((AppStorage.get<string>('role') ?? 'STUDENT') === 'TEACHER'
                  ? '➕ 按学生用户码添加' : '➕ 按教师用户码添加')
                : '➕ 按用户码添加好友')
                .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.PRIMARY)
                .layoutWeight(1)
              Text(this.showAdd ? '收起 ▲' : '展开 ▼').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
            }.width('100%')
            .onClick((): void => { this.showAdd = !this.showAdd; })

            if (this.showAdd) {
              Column({ space: 10 }) {
                Row({ space: 10 }) {
                  TextInput({ placeholder: this.mode === 'teacher' ? '输入教师用户号，如 SL000003' : '输入对方用户号，如 SL000008', text: this.searchCode })
                    .onChange((v: string): void => { this.searchCode = v; })
                    .layoutWeight(1).height(44)
                    .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
                    .fontSize(14).padding({ left: 14, right: 14 })
                  Button(this.searching ? '…' : '搜索')
                    .width(76).height(44).fontSize(14)
                    .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                    .fontColor(Color.White).borderRadius(Theme.R_MD)
                    .onClick((): void => { this.doSearch(); })
                }.width('100%')

                if (this.searchResult !== null) {
                  Row({ space: 12 }) {
                    Column() {
                      Text((this.searchResult.user.real_name || this.searchResult.user.username)
                        .substring(0, 1).toUpperCase())
                        .fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
                    }
                    .width(46).height(46).borderRadius(23)
                    .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                    Column({ space: 2 }) {
                      Text(this.searchResult.user.real_name || this.searchResult.user.username)
                        .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(`${this.roleBadge(this.searchResult.user.role)} · ${this.searchResult.user.user_code}`)
                        .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    if (this.searchResult.existing !== null && this.searchResult.existing.status === 'ACCEPTED') {
                      Text('已添加').fontSize(Theme.F_CAP).fontColor(Theme.SUCCESS)
                    } else if (this.searchResult.existing !== null && this.searchResult.existing.status === 'PENDING'
                      && this.searchResult.existing.direction === 'outgoing') {
                      Text('申请中').fontSize(Theme.F_CAP).fontColor(Theme.WARNING)
                    } else {
                      Button(this.applying ? '…' : '发送申请')
                        .height(36).fontSize(13)
                        .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                        .fontColor(Color.White).borderRadius(Theme.R_MD)
                        .onClick((): void => { this.doApply(); })
                    }
                  }
                  .width('100%').padding(12)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_LG)
                }
              }.width('100%').animation({ duration: 200 })
            }
          }
          .width('100%').padding(16)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)

          // ── 待处理申请（消息通知）──
          if (this.requests.length > 0) {
            Column({ space: 10 }) {
              Text(`🔔 收到的申请（${this.requests.length}）`)
                .fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
              ForEach(this.requests, (req: ContactRequestItem) => {
                Row({ space: 12 }) {
                  Column() {
                    Text((req.requester.real_name || req.requester.username).substring(0, 1).toUpperCase())
                      .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
                  }.width(40).height(40).borderRadius(20)
                  .backgroundColor(Theme.PRIMARY_LIGHT)
                  Column({ space: 2 }) {
                    Text(req.requester.real_name || req.requester.username)
                      .fontSize(14).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
                    Text(`${this.roleBadge(req.requester.role)} 想添加你为${req.rel_type === 'TEACHER' ? '学生' : '好友'}`)
                      .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Button('同意')
                    .height(32).fontSize(12)
                    .backgroundColor(Theme.SUCCESS_LIGHT).fontColor(Theme.SUCCESS)
                    .borderRadius(Theme.R_SM)
                    .onClick((): void => { this.handleRequest(req, true); })
                  Button('拒绝')
                    .height(32).fontSize(12)
                    .backgroundColor(Theme.INPUT_BG).fontColor(Theme.TEXT_SECOND)
                    .borderRadius(Theme.R_SM)
                    .onClick((): void => { this.handleRequest(req, false); })
                }.width('100%')
              }, (req: ContactRequestItem) => `${req.requester.id}-${req.rel_type}`)
            }.width('100%').padding(16)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
            .shadow(Theme.SHADOW_CARD)
          }

          // ── 联系人列表 ──
          if (this.loading) {
            Column({ space: 12 }) { SkeletonCard(); SkeletonCard(); }.width('100%')
          } else if (this.activeList().length === 0) {
            Column() {
              EmptyState({
                icon: this.mode === 'teacher' ? '👩‍🏫' : '👥',
                text: this.mode === 'teacher' ? '暂无关联老师，同课程会自动关联，也可按用户码添加' : '暂无好友，点击上方按用户码添加',
              })
            }.width('100%')
          } else {
            Column({ space: 10 }) {
              ForEach(this.activeList(), (item: ContactItem) => {
                Row({ space: 12 }) {
                  Stack() {
                    Column() {
                      Text((item.user.real_name || item.user.username).substring(0, 1).toUpperCase())
                        .fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White)
                    }.width(48).height(48).borderRadius(24)
                    .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                    if (item.unread > 0) {
                      Text(item.unread > 99 ? '99+' : String(item.unread))
                        .fontSize(Theme.F_CAP).fontColor(Color.White).fontWeight(FontWeight.Bold)
                        .padding({ left: 5, right: 5 }).constraintSize({ minWidth: 16 }).height(16)
                        .textAlign(TextAlign.Center)
                        .borderRadius(8).backgroundColor(Theme.DANGER)
                        .position({ x: 32, y: -2 })
                    }
                  }.width(48).height(48)
                  Column({ space: 3 }) {
                    Row({ space: 6 }) {
                      Text(item.display_name).fontSize(15).fontWeight(FontWeight.Medium)
                        .fontColor(Theme.TEXT).maxLines(1)
                      if (item.remark !== null && item.remark.length > 0) {
                        Text('备注').fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                          .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(4)
                      }
                      Text(this.roleBadge(item.user.role)).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    }
                    Text(item.last_message.length > 0 ? item.last_message : '开始对话')
                      .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND).maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  // 备注 + 聊天双操作
                  Column({ space: 6 }) {
                    Text('✏️').fontSize(16)
                      .onClick((): void => { this.openRemark(item); })
                    Text('💬').fontSize(16)
                      .onClick((): void => { this.intoChat(item); })
                  }
                }
                .width('100%').padding(14)
                .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
                .shadow(Theme.SHADOW_CARD)
                .onClick((): void => { this.intoChat(item); })
              }, (item: ContactItem) => `${item.user.id}-${item.unread}-${item.display_name}`)
            }.width('100%')
          }
        }.width('100%').padding({ left: 16, right: 16, bottom: 24 })
      }
      .scrollBar(BarState.Off).layoutWeight(1)

      // ── 备注编辑弹层 ──
      if (this.remarkTarget !== null) {
        Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
          Column({ space: 14 }) {
            Text(`备注「${this.remarkTarget.user.real_name || this.remarkTarget.user.username}」`)
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
            TextInput({ placeholder: '输入备注名', text: this.remarkInput })
              .onChange((v: string): void => { this.remarkInput = v; })
              .width('100%').height(44)
              .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
              .fontSize(14).padding({ left: 14, right: 14 })
            Row({ space: 10 }) {
              Button('取消').layoutWeight(1).height(40).fontSize(14)
                .backgroundColor(Theme.INPUT_BG).fontColor(Theme.TEXT_SECOND)
                .borderRadius(Theme.R_MD)
                .onClick((): void => { this.remarkTarget = null; })
              Button('保存').layoutWeight(1).height(40).fontSize(14)
                .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                .fontColor(Color.White).borderRadius(Theme.R_MD)
                .onClick((): void => { this.saveRemark(); })
            }.width('100%')
          }
          .width('82%').padding(20)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_XL)
          .shadow(Theme.SHADOW_FLOAT)
        }
        .width('100%').height('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .position({ x: 0, y: 0 })
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }

  @Builder ModeTab(mode: string, label: string, count: number) {
    Column({ space: 3 }) {
      Text(`${label}${count > 0 ? ` (${count})` : ''}`)
        .fontSize(14).fontWeight(this.mode === mode ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.mode === mode ? Theme.PRIMARY : Theme.TEXT_SECOND)
      Column().height(3).width(this.mode === mode ? 28 : 0)
        .borderRadius(2).backgroundColor(Theme.PRIMARY)
        .animation({ duration: 200 })
    }
    .padding({ top: 10, bottom: 10, left: 8, right: 8 })
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .onClick((): void => { this.mode = mode; })
  }
}
