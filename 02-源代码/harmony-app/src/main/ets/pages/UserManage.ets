import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { AdminUserItem, ImportFailedItem, ImportReport, UserImportItem } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, TagChip, Card } from '../components/UiKit';

@Entry
@Component
struct UserManage {
  @State rows: AdminUserItem[] = [];
  @State loading: boolean = true;
  @State message: string = '';
  @State filter: string = 'ALL';
  // 批量导入
  @State showImport: boolean = false;
  @State importText: string = '';
  @State importing: boolean = false;
  @State report: ImportReport | null = null;

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    try { this.rows = await api.getUsers(); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }

  private async toggleStatus(user: AdminUserItem): Promise<void> {
    try {
      await api.setUserStatus(user.id, user.status === 1 ? 0 : 1);
      this.rows = await api.getUsers();
      this.message = `✓ 已${user.status === 1 ? '禁用' : '启用'} ${user.real_name}`;
    } catch (error) {
      this.message = error instanceof Error ? error.message : '操作失败';
    }
  }

  // ═══ 批量导入：每行「用户名,姓名,角色」，角色为 学生/教师/管理员 或 STUDENT/TEACHER/ADMIN ═══
  private parseImportText(): UserImportItem[] {
    const items: UserImportItem[] = [];
    for (const raw of this.importText.split('\n')) {
      const line: string = raw.trim();
      if (line.length === 0) { continue; }
      const parts: string[] = line.split(',');
      if (parts.length < 2) { continue; }
      const username: string = parts[0].trim();
      const realName: string = parts[1].trim();
      let role: string = parts.length > 2 ? parts[2].trim().toUpperCase() : 'STUDENT';
      if (role === '学生') { role = 'STUDENT'; }
      if (role === '教师') { role = 'TEACHER'; }
      if (role === '管理员') { role = 'ADMIN'; }
      if (username.length > 0 && realName.length > 0) {
        items.push({ username, real_name: realName, role });
      }
    }
    return items;
  }

  private async runImport(): Promise<void> {
    const items: UserImportItem[] = this.parseImportText();
    if (items.length === 0) { this.message = '未解析到有效数据，每行格式：用户名,姓名,角色'; return; }
    this.importing = true;
    this.report = null;
    this.message = '';
    try {
      this.report = await api.importUsers(items);
      this.rows = await api.getUsers();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '导入失败';
    }
    this.importing = false;
  }

  private roleLabel(role: string): string {
    if (role === 'STUDENT') return '学生';
    if (role === 'TEACHER') return '教师';
    return '管理员';
  }

  private roleTone(role: string): string {
    if (role === 'ADMIN') return 'danger';
    if (role === 'TEACHER') return 'warning';
    return 'primary';
  }

  private filtered(): AdminUserItem[] {
    if (this.filter === 'ADMIN') return this.rows.filter((r): boolean => r.role === 'ADMIN');
    if (this.filter === 'TEACHER') return this.rows.filter((r): boolean => r.role === 'TEACHER');
    if (this.filter === 'STUDENT') return this.rows.filter((r): boolean => r.role === 'STUDENT');
    return this.rows;
  }

  build() {
    Column() {
      PageHeader({ title: '用户管理', onBack: (): void => { router.back(); } })
      Row({ space: 8 }) {
        this.FilterChip('全部', 'ALL')
        this.FilterChip('学生', 'STUDENT')
        this.FilterChip('教师', 'TEACHER')
        this.FilterChip('管理员', 'ADMIN')
        Blank()
        Text(`${this.rows.length} 人`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
      }.width('100%').padding({ left: 20, right: 20, top: 4, bottom: 8 })
      // ═══ 批量导入入口 ═══
      if (this.showImport) {
        Column() {
          Card() {
            Column({ space: 10 }) {
              Row({ space: 8 }) {
                Text('📥').fontSize(15)
                Text('批量导入用户').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                Blank()
                Text('×').fontSize(18).fontColor(Theme.TEXT_HINT)
                  .onClick((): void => { this.showImport = false; this.report = null; })
              }.width('100%')
              Text('每行一条：用户名,姓名,角色（学生/教师/管理员，默认学生）。示例：\nstu_201,王小明,学生\ntea_06,李华,教师')
                .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
              TextArea({ placeholder: '粘贴或输入批量数据，每行一条…', text: this.importText })
                .onChange((v: string): void => { this.importText = v; })
                .width('100%').height(120).fontSize(13)
                .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                .caretColor(Theme.PRIMARY)
              Button(this.importing ? '导入中…' : `📥 导入 ${this.parseImportText().length} 条`)
                .height(40).fontSize(14).width('100%')
                .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                .fontColor(Color.White)
                .enabled(!this.importing && this.parseImportText().length > 0)
                .onClick((): void => { this.runImport(); })
              // 校验报告
              if (this.report !== null) {
                Column({ space: 6 }) {
                  Row({ space: 10 }) {
                    Text(`✓ 成功 ${this.report!.success}`).fontSize(Theme.F_SUB)
                      .fontColor(Theme.SUCCESS).fontWeight(FontWeight.Bold)
                    if (this.report!.failed > 0) {
                      Text(`✕ 失败 ${this.report!.failed}`).fontSize(Theme.F_SUB)
                        .fontColor(Theme.DANGER).fontWeight(FontWeight.Bold)
                    }
                  }.width('100%')
                  if (this.report!.failed_list.length > 0) {
                    ForEach(this.report!.failed_list.slice(0, 8), (f: ImportFailedItem) => {
                      Row({ space: 6 }) {
                        Text(`· ${f.username}`).fontSize(Theme.F_CAP).fontColor(Theme.DANGER)
                        Blank()
                        Text(f.reason).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).maxLines(1)
                      }.width('100%')
                    }, (f: ImportFailedItem) => f.username)
                  }
                }
                .width('100%').padding(10)
                .backgroundColor(Theme.BG).borderRadius(Theme.R_SM)
              }
            }.width('100%')
          }
        }.margin({ left: 20, right: 20 }).width('100%')
      } else {
        Row() {
          Blank()
          Button('📥 批量导入').height(32).fontSize(12)
            .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
            .margin({ right: 20 })
            .onClick((): void => { this.showImport = true; })
        }.width('100%')
      }
      if (this.loading) {
        Column({ space: 12 }) { SkeletonCard(); SkeletonCard(); SkeletonCard() }.padding(20)
      } else if (this.rows.length === 0) {
        EmptyState({ icon: '👥', text: '暂无用户' })
      } else {
        List({ space: 10 }) {
          ForEach(this.filtered(), (user: AdminUserItem) => {
            ListItem() {
              Row({ space: 12 }) {
                Column() {
                  Text(user.real_name.length > 0 ? user.real_name.substring(0, 1) : '?')
                    .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
                }
                .width(44).height(44).borderRadius(22)
                .linearGradient({
                  angle: 135,
                  colors: user.role === 'ADMIN'
                    ? [[Theme.DANGER, 0], ['#FF7A7E', 1]]
                    : user.role === 'TEACHER'
                      ? [[Theme.WARNING, 0], ['#FFB74D', 1]]
                      : [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]]
                })
                Column({ space: 3 }) {
                  Text(`${user.real_name}（${user.username}）`)
                    .fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
                    .maxLines(1)
                  Row({ space: 6 }) {
                    TagChip({ text: this.roleLabel(user.role), tone: this.roleTone(user.role) })
                    TagChip({
                      text: user.status === 1 ? '正常' : '已禁用',
                      tone: user.status === 1 ? 'success' : 'danger'
                    })
                  }
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Button(user.status === 1 ? '禁用' : '启用')
                  .height(32).fontSize(12)
                  .backgroundColor(user.status === 1 ? Theme.DANGER_LIGHT : Theme.SUCCESS_LIGHT)
                  .fontColor(user.status === 1 ? Theme.DANGER : Theme.SUCCESS)
                  .onClick((): void => { this.toggleStatus(user); })
              }
              .width('100%').padding(14)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }
          }, (user: AdminUserItem) => String(user.id))
        }
        .lanes({ minLength: 360, maxLength: 520 }, 12)
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 10, bottom: 20 })
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

  @Builder FilterChip(label: string, value: string) {
    Text(label)
      .fontSize(Theme.F_SUB)
      .fontColor(this.filter === value ? Color.White : Theme.TEXT_SECOND)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.filter === value ? Theme.PRIMARY : Theme.CARD)
      .borderRadius(16)
      .onClick((): void => { this.filter = value; })
  }
}
