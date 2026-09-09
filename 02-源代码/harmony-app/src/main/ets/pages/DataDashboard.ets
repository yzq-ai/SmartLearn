import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Dashboard } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, PrimaryButton, Card } from '../components/UiKit';
import { DonutChart } from '../components/DonutChart';
import { BarChart } from '../components/BarChart';

@Entry
@Component
struct DataDashboard {
  @State data: Dashboard | null = null;
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    try { this.data = await api.getDashboard(); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }

  private totalPending(): number {
    return this.data === null ? 0 : this.data.pending_jobs;
  }

  build() {
    Column() {
      PageHeader({ title: '数据大屏', onBack: (): void => { router.back(); } })
      if (this.loading) {
        Column({ space: 14 }) {
          Column().width('100%').height(100).borderRadius(Theme.R_LG).backgroundColor(Theme.INPUT_BG)
          Column().width('100%').height(220).borderRadius(Theme.R_LG).backgroundColor(Theme.INPUT_BG)
        }.padding(20)
      } else if (this.data === null) {
        Column() {
          Text('📊').fontSize(52)
          Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER).margin({ top: 12 })
        }.layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else {
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 8 }) {
              Text('平台总览').fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.8)')
              Row({ space: 16 }) {
                Column({ space: 2 }) {
                  Text(`${this.data.users}`).fontSize(30).fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                  Text('总用户').fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.75)')
                }.layoutWeight(1)
                Column().width(1).height(40).backgroundColor('rgba(255,255,255,0.2)')
                Column({ space: 2 }) {
                  Text(`${this.data.courses}`).fontSize(30).fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                  Text('课程').fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.75)')
                }.layoutWeight(1)
                Column().width(1).height(40).backgroundColor('rgba(255,255,255,0.2)')
                Column({ space: 2 }) {
                  Text(`${this.data.exams}`).fontSize(30).fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                  Text('考试').fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.75)')
                }.layoutWeight(1)
              }.width('100%')
            }
            .width('100%').padding(24)
            .linearGradient({ angle: 145, colors: [[Theme.PRIMARY_DEEP, 0], [Theme.PRIMARY_GRADIENT, 1]] })
            .borderRadius(Theme.R_XL)
            .shadow(Theme.SHADOW_FLOAT)
            GridRow({ gutter: { x: 12, y: 12 } }) {
              GridCol({ span: 6 }) { this.Metric('💼', '岗位总数', `${this.data.jobs}`, Theme.PRIMARY_LIGHT, Theme.PRIMARY) }
              GridCol({ span: 6 }) { this.Metric('⏳', '待审岗位', `${this.data.pending_jobs}`, Theme.WARNING_LIGHT, Theme.WARNING) }
              GridCol({ span: 6 }) { this.Metric('📨', '投递总量', `${this.data.applications}`, Theme.SUCCESS_LIGHT, Theme.SUCCESS) }
              GridCol({ span: 6 }) { this.Metric('📈', '待处理率', this.data.jobs > 0
                ? `${Math.round(this.totalPending() / this.data.jobs * 100)}%` : '0%',
                Theme.DANGER_LIGHT, Theme.DANGER) }
            }
            // ═══ 图表 1：平台内容分布（环形图）═══
            Card() {
              Column({ space: 14 }) {
                Row({ space: 8 }) {
                  Text('🍩').fontSize(15)
                  Text('内容分布占比').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                }.width('100%')
                DonutChart({
                  labels: ['课程', '考试', '岗位', '投递'],
                  values: [this.data.courses, this.data.exams, this.data.jobs, this.data.applications],
                  colors: ['#3D5AFE', '#7C4DFF', '#00C9A7', '#F5A623'],
                  centerLabel: '内容总量'
                })
              }.width('100%')
            }
            // ═══ 图表 2：核心指标对比（柱状图）═══
            Card() {
              Column({ space: 14 }) {
                Row({ space: 8 }) {
                  Text('📊').fontSize(15)
                  Text('核心指标对比').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                }.width('100%')
                BarChart({
                  labels: ['总用户', '课程', '考试', '岗位', '投递'],
                  values: [this.data.users, this.data.courses, this.data.exams, this.data.jobs, this.data.applications]
                })
              }.width('100%')
            }
            PrimaryButton({
              label: '🔄 刷新数据',
              onTap: (): void => { this.load(); }
            })
          }.padding(20)
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }

  @Builder Metric(icon: string, label: string, value: string, bg: string, fg: string) {
    Column({ space: 6 }) {
      Text(icon).fontSize(22)
      Text(value).fontSize(24).fontWeight(FontWeight.Bold).fontColor(fg)
      Text(label).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
    }
    .width('100%').padding(16)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
    .alignItems(HorizontalAlign.Start)
  }
}
