import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { AiPlan, AiPlanDay, AiPlanTask } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, PrimaryButton, EmptyState } from '../components/UiKit';
@Entry
@Component
struct StudyPlanPage {
  @State goal: string = '';
  @State dailyMinutes: number = 60;
  @State days: number = 7;
  @State plan: AiPlanDay[] = [];
  @State loading: boolean = false;
  @State message: string = '';
  private async generatePlan(): Promise<void> {
    if (this.goal.length === 0) { this.message = '请输入学习目标'; return; }
    this.loading = true;
    this.message = '';
    try {
      const result: AiPlan = await api.aiPlan(this.goal, this.dailyMinutes, [], this.days);
      this.plan = result.plan;
      this.message = '✓ 学习计划已生成';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '生成失败';
    }
    this.loading = false;
  }
  private totalMinutes(): number {
    let total: number = 0;
    this.plan.forEach((day: AiPlanDay): void => {
      day.tasks.forEach((t: AiPlanTask): void => { total += t.minutes; });
    });
    return total;
  }
  private totalTasks(): number {
    let count: number = 0;
    this.plan.forEach((d: AiPlanDay): void => { count += d.tasks.length; });
    return count;
  }
  build() {
    Column() {
      PageHeader({ title: 'AI 学习计划', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 14 }) {
            Row({ space: 10 }) {
              Text('🎯').fontSize(22)
              Text('制定学习计划').fontSize(17).fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }.width('100%')
            TextInput({ placeholder: '学习目标（如：掌握 Python 基础）', text: this.goal })
              .onChange((v: string): void => { this.goal = v; })
              .width('100%').height(48).fontSize(14)
              .backgroundColor('rgba(255,255,255,0.18)')
              .borderRadius(Theme.R_MD)
              .fontColor(Color.White)
              .placeholderColor('rgba(255,255,255,0.6)')
              .caretColor(Color.White)
            Row({ space: 10 }) {
              Column({ space: 6 }) {
                Text('每日时长(分钟)').fontSize(Theme.F_CAP)
                  .fontColor('rgba(255,255,255,0.8)')
                TextInput({ text: `${this.dailyMinutes}` })
                  .type(InputType.Number)
                  .onChange((v: string): void => { this.dailyMinutes = Number(v); })
                  .width('100%').height(44).fontSize(14)
                  .backgroundColor('rgba(255,255,255,0.18)')
                  .borderRadius(Theme.R_SM).fontColor(Color.White)
                  .caretColor(Color.White)
              }.layoutWeight(1)
              Column({ space: 6 }) {
                Text('计划天数').fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.8)')
                TextInput({ text: `${this.days}` })
                  .type(InputType.Number)
                  .onChange((v: string): void => { this.days = Number(v); })
                  .width('100%').height(44).fontSize(14)
                  .backgroundColor('rgba(255,255,255,0.18)')
                  .borderRadius(Theme.R_SM).fontColor(Color.White)
                  .caretColor(Color.White)
              }.layoutWeight(1)
            }.width('100%')
            Button(this.loading ? '生成中…' : '✨ AI 生成学习计划')
              .width('100%').height(48).fontSize(15).fontWeight(FontWeight.Medium)
              .backgroundColor(Color.White)
              .fontColor(Theme.PRIMARY)
              .borderRadius(Theme.R_MD)
              .enabled(!this.loading)
              .opacity(this.loading ? 0.7 : 1)
              .onClick((): void => { this.generatePlan(); })
          }
          .width('100%').padding(22)
          .linearGradient({ angle: 145, colors: [[Theme.PRIMARY_DEEP, 0], [Theme.PRIMARY_GRADIENT, 1]] })
          .borderRadius(Theme.R_XL)
          .shadow(Theme.SHADOW_FLOAT)
          if (this.plan.length > 0) {
            Row({ space: 12 }) {
              Column({ space: 2 }) {
                Text('计划天数').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                Text(`${this.plan.length} 天`).fontSize(17).fontWeight(FontWeight.Bold)
                  .fontColor(Theme.PRIMARY)
              }.layoutWeight(1)
              Column({ space: 2 }) {
                Text('总时长').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                Text(`${this.totalMinutes()} 分钟`).fontSize(17).fontWeight(FontWeight.Bold)
                  .fontColor(Theme.SUCCESS)
              }.layoutWeight(1)
              Column({ space: 2 }) {
                Text('知识点').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                Text(`${this.totalTasks()} 个`)
                  .fontSize(17).fontWeight(FontWeight.Bold).fontColor(Theme.WARNING)
              }.layoutWeight(1)
            }
            .width('100%').padding(14)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
            .shadow(Theme.SHADOW_CARD)
          }
          if (this.plan.length > 0) {
            Text('📅 我的学习计划').fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT).width('100%')
            ForEach(this.plan, (day: AiPlanDay, dayIndex: number) => {
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Column() {
                    Text(`${dayIndex + 1}`)
                      .fontSize(13).fontWeight(FontWeight.Bold).fontColor(Color.White)
                      .width(28).height(28).textAlign(TextAlign.Center)
                      .borderRadius(14).backgroundColor(Theme.PRIMARY)
                  }
                  if (dayIndex < this.plan.length - 1) {
                    Column().width(2).layoutWeight(1).backgroundColor(Theme.DIVIDER)
                  }
                }.width(28)
                Column({ space: 8 }) {
                  Text(`第 ${dayIndex + 1} 天 · ${day.date}`)
                    .fontSize(Theme.F_SUB).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                  ForEach(day.tasks, (task: AiPlanTask) => {
                    Row({ space: 8 }) {
                      Text('●').fontColor(Theme.PRIMARY).fontSize(12)
                      Text(task.kp).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
                        .layoutWeight(1).maxLines(1)
                      Text(`${task.minutes} 分钟`).fontSize(Theme.F_CAP)
                        .fontColor(Theme.PRIMARY).fontWeight(FontWeight.Bold)
                    }
                    .width('100%').padding(8)
                    .backgroundColor(Theme.BG).borderRadius(Theme.R_SM)
                  })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .padding(12)
                .backgroundColor(Theme.CARD).borderRadius(Theme.R_MD)
                .shadow(Theme.SHADOW_CARD)
              }
              .width('100%').alignItems(VerticalAlign.Top)
            })
          } else if (!this.loading) {
            EmptyState({ icon: '📅', text: '填写目标，让 AI 为你定制学习路线' })
          }
          if (this.message.length > 0) {
            Text(this.message).fontSize(Theme.F_SUB)
              .fontColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
              .width('100%').textAlign(TextAlign.Center)
              .margin({ bottom: 24 })
          }
        }.padding(20)
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
