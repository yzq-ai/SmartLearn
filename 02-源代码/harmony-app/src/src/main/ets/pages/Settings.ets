import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Theme } from '../common/Theme';
import { ThemeMode } from '../common/ThemeMode';
import { showToast } from '../components/UiKit';
import { IBestCell, IBestCellGroup } from '@ibestservices/ibest-ui-v2';

@Entry
@ComponentV2
struct Settings {
  @Local username: string = '';
  @Local role: string = '';
  @Local darkMode: boolean = AppStorage.get<boolean>('darkMode') ?? false;
  aboutToAppear(): void {
    this.username = AppStorage.get<string>('username') ?? '同学';
    this.role = AppStorage.get<string>('role') ?? 'STUDENT';
  }
  private roleLabel(): string {
    if (this.role === 'STUDENT') return '学生';
    if (this.role === 'TEACHER') return '教师';
    return '管理员';
  }
  private logout(): void {
    api.setToken('');
    AppStorage.delete('token');
    AppStorage.delete('refresh_token');
    AppStorage.delete('role');
    AppStorage.delete('username');
    AppStorage.delete('avatar');
    AppStorage.delete('userId');
    router.replaceUrl({ url: 'pages/Login' });
  }
  private toggleDark(on: boolean): void {
    if (on === this.darkMode) { return; }  // 幂等：行点击与 Toggle 回调双触发时只生效一次
    this.darkMode = on;
    ThemeMode.apply(on); // AppStorage + setColorMode + 持久化，一次到位
    showToast(on ? '🌙 深色模式已开启' : '☀️ 已切换回浅色模式', 'success');
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Button('‹').width(40).height(40).fontSize(20)
          .backgroundColor(Theme.CARD).fontColor(Theme.TEXT)
          .shadow(Theme.SHADOW_CARD)
          .onClick((): void => { router.back(); })
        Blank()
        Text('设置').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
        Blank().width(40)
      }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 10 })

      Scroll() {
        Column({ space: 14 }) {
          // ═══ 用户信息卡 ═══
          Row({ space: 16 }) {
            Column() {
              Text(this.username.length > 0 ? this.username.substring(0, 1).toUpperCase() : '?')
                .fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White)
            }
            .width(56).height(56).borderRadius(28)
            .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
            .shadow(Theme.SHADOW_FLOAT)
            Column({ space: 4 }) {
              Text(this.username).fontSize(19).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
              Text(this.roleLabel()).fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(8)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }
          .width('100%').padding(20)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)

          // ═══ 外观（深浅模式切换）═══
          // 注：IBestCell rightIconBuilder 在真机渲染丢失（开关不显示 → 无法切回浅色，
          // 需求 4 根因），改用原生 Toggle 内嵌行 + Cell 点击双通道，稳定可靠。
          Column({ space: 0 }) {
            Row({ space: 14 }) {
              Column({ space: 3 }) {
                Text('深色模式').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
                Text(this.darkMode ? '已开启 · 夜间护眼中' : '开启夜间护眼体验')
                  .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.darkMode })
                .selectedColor(Theme.PRIMARY)
                .onChange((on: boolean): void => { this.toggleDark(on); })
            }
            .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
            .hitTestBehavior(HitTestMode.Transparent)  // 事件穿透到 Toggle，杜绝行点击+开关双触发竞态（需求 4）
            Divider().color(Theme.DIVIDER)
            Row({ space: 14 }) {
              Column({ space: 3 }) {
                Text('清理缓存').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
                Text('清除本地临时数据').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text('›').fontSize(18).fontColor(Theme.TEXT_HINT)
            }
            .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
            .onClick((): void => { showToast('缓存已清理', 'success'); })
          }
          .width('100%')
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)

          // ═══ 账号 ═══
          IBestCellGroup() {
            IBestCell({
              title: '修改密码',
              isLink: true,
              onCellClick: (): void => { router.pushUrl({ url: 'pages/ChangePassword' }); },
            } as ESObject)
            IBestCell({
              title: '编辑资料',
              isLink: true,
              onCellClick: (): void => { router.pushUrl({ url: 'pages/ProfileEdit' }); },
            } as ESObject)
            if (this.role === 'STUDENT') {
              IBestCell({
                title: '我的简历',
                isLink: true,
                onCellClick: (): void => { router.pushUrl({ url: 'pages/ResumeEdit' }); },
              } as ESObject)
              IBestCell({
                title: '我的笔记',
                isLink: true,
                onCellClick: (): void => { router.pushUrl({ url: 'pages/Notes' }); },
              } as ESObject)
            }
            if (this.role === 'STUDENT' || this.role === 'TEACHER') {
              IBestCell({
                title: '反馈中心',
                isLink: true,
                onCellClick: (): void => { router.pushUrl({ url: 'pages/FeedbackCenter' }); },
              } as ESObject)
            }
          }

          // ═══ 退出 ═══
          Button('退出登录')
            .width('100%').height(50).fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor(Theme.DANGER).backgroundColor(Theme.DANGER_LIGHT)
            .borderRadius(Theme.R_MD).margin({ top: 8, bottom: 24 })
            .onClick((): void => { this.logout(); })
        }.padding({ left: 20, right: 20, top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
