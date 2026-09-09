import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { CheckinResult, Course, SignLatest } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, showToast } from '../components/UiKit';

/**
 * 我要签到（需求 11）：学生输入教师生成的 4 位签到码。
 * 流程：选课程 → 拉最新签到任务（倒计时 30s）→ 输入 4 位码 → 签到成功/过期/已签。
 */
@Entry
@Component
struct StudentCheckin {
  @State loading: boolean = true;
  @State courses: Course[] = [];
  @State courseId: number = 0;
  @State courseTitle: string = '';
  @State task: SignLatest | null = null;
  @State remaining: number = 0;
  @State timerId: number = -1;
  @State codeInput: string = '';
  @State signing: boolean = false;
  @State result: string = '';    // 成功/结果文案
  @State resultOk: boolean = false;
  @State message: string = '';

  aboutToAppear(): void { this.load(); }
  aboutToDisappear(): void { this.stopTimer(); }

  private stopTimer(): void {
    if (this.timerId >= 0) { clearInterval(this.timerId); this.timerId = -1; }
  }

  private async load(): Promise<void> {
    try {
      this.courses = await api.getMyCourses();
      if (this.courses.length > 0) {
        this.courseId = this.courses[0].id;
        this.courseTitle = this.courses[0].title;
        await this.refreshTask();
      }
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }

  private async refreshTask(): Promise<void> {
    this.stopTimer();
    this.task = null;
    this.result = '';
    try {
      this.task = await api.getLatestSignTask(this.courseId);
      this.remaining = this.task?.remaining_seconds ?? 0;
      this.timerId = setInterval((): void => {
        if (this.remaining > 0) { this.remaining -= 1; }
      }, 1000);
    } catch (_) {
      this.task = null; // 暂无签到任务
    }
  }

  private async checkin(): Promise<void> {
    const code: string = this.codeInput.trim();
    if (code.length !== 4) { showToast('请输入 4 位签到码', 'warning'); return; }
    const t: SignLatest | null = this.task;
    if (t === null) { showToast('当前无签到任务', 'warning'); return; }
    if (this.remaining <= 0) { showToast('签到码已过期，等待老师重新发起', 'fail'); return; }
    this.signing = true;
    try {
      const r: CheckinResult = await api.studentCheckin(t.id, code);
      this.resultOk = true;
      this.result = r.already ? '你已签到过，无需重复签到 ✓' : '签到成功 ✓ 已计入考勤';
      showToast(this.result, 'success');
      this.codeInput = '';
    } catch (error) {
      this.resultOk = false;
      this.result = error instanceof Error ? error.message : '签到失败';
      showToast(this.result, 'fail');
    }
    this.signing = false;
  }

  build() {
    Column() {
      PageHeader({ title: '我要签到', onBack: (): void => { router.back(); } })
      if (this.loading) {
        Column({ space: 12 }) { SkeletonCard(); SkeletonCard(); }.padding(20)
      } else {
        Scroll() {
          Column({ space: 16 }) {
            // ── 课程选择 ──
            Column({ space: 10 }) {
              Text('选择课程').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
              Scroll() {
                Row({ space: 8 }) {
                  ForEach(this.courses, (c: Course) => {
                    Text(c.title.length > 8 ? `${c.title.substring(0, 8)}…` : c.title)
                      .fontSize(13).padding({ left: 12, right: 12, top: 8, bottom: 8 })
                      .fontColor(this.courseId === c.id ? Color.White : Theme.TEXT)
                      .backgroundColor(this.courseId === c.id ? Theme.PRIMARY : Theme.INPUT_BG)
                      .borderRadius(18)
                      .onClick((): void => {
                        this.courseId = c.id;
                        this.courseTitle = c.title;
                        this.refreshTask();
                      })
                  }, (c: Course) => `${c.id}-${this.courseId === c.id}`)
                }
              }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
            }
            .width('100%').padding(16)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG).shadow(Theme.SHADOW_CARD)

            // ── 签到状态 ──
            Column({ space: 14 }) {
              if (this.task === null) {
                EmptyState({ icon: '🕐', text: '老师尚未发起签到\n上课后等待老师发起，再输入 4 位签到码' })
              } else {
                Text('📝 课堂签到').fontSize(18).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                // 倒计时环
                Stack() {
                  Progress({ value: this.remaining, total: 30, type: ProgressType.Ring })
                    .style({ strokeWidth: 8 }).width(96).height(96)
                    .color(this.remaining > 10 ? Theme.PRIMARY : this.remaining > 0 ? Theme.WARNING : Theme.DANGER)
                  Column({ space: 0 }) {
                    Text(this.remaining > 0 ? `${this.remaining}` : '已过期')
                      .fontSize(this.remaining > 0 ? 26 : 14).fontWeight(FontWeight.Bold)
                      .fontColor(this.remaining > 10 ? Theme.PRIMARY : this.remaining > 0 ? Theme.WARNING : Theme.DANGER)
                    if (this.remaining > 0) {
                      Text('秒').fontSize(11).fontColor(Theme.TEXT_HINT)
                    }
                  }
                }.width(96).height(96)

                if (this.remaining > 0) {
                  // 4 位码输入
                  TextInput({ placeholder: '_ _ _ _', text: this.codeInput })
                    .type(InputType.Number)
                    .maxLength(4)
                    .width(180).height(56)
                    .fontSize(26).textAlign(TextAlign.Center).fontWeight(FontWeight.Bold)
                    .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_LG)
                    .caretColor(Theme.PRIMARY)
                    .onChange((v: string): void => { this.codeInput = v; })
                  Text('输入老师屏幕上展示的 4 位数字签到码')
                    .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  Button(this.signing ? '签到中…' : '立即签到')
                    .width('100%').height(48).fontSize(15).fontWeight(FontWeight.Medium)
                    .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                    .fontColor(Color.White).borderRadius(Theme.R_MD)
                    .enabled(!this.signing && this.codeInput.trim().length === 4)
                    .opacity(this.codeInput.trim().length === 4 ? 1 : 0.5)
                    .onClick((): void => { this.checkin(); })
                } else {
                  Text('该签到码已过期（限时 30 秒），请老师重新发起')
                    .fontSize(Theme.F_SUB).fontColor(Theme.DANGER)
                  Button('刷新任务')
                    .width('100%').height(44).fontSize(14)
                    .backgroundColor(Theme.INPUT_BG).fontColor(Theme.TEXT)
                    .borderRadius(Theme.R_MD)
                    .onClick((): void => { this.refreshTask(); })
                }
              }
            }
            .width('100%').padding(20)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG).shadow(Theme.SHADOW_CARD)

            // ── 结果 ──
            if (this.result.length > 0) {
              Row({ space: 10 }) {
                Text(this.resultOk ? '✅' : '❌').fontSize(22)
                Text(this.result).fontSize(15).fontWeight(FontWeight.Medium)
                  .fontColor(this.resultOk ? Theme.SUCCESS : Theme.DANGER).layoutWeight(1)
              }
              .width('100%').padding(16)
              .backgroundColor(this.resultOk ? Theme.SUCCESS_LIGHT : Theme.DANGER_LIGHT)
              .borderRadius(Theme.R_LG)
            }
          }.padding(20).padding({ bottom: 24 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
