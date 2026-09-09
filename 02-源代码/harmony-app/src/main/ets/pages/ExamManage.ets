import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { ExamSummary } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard } from '../components/UiKit';
@Entry
@Component
struct ExamManage {
  @State rows: ExamSummary[] = [];
  @State loading: boolean = true;
  @State message: string = '';
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    this.loading = true;
    this.message = '';
    try { this.rows = await api.getExams(); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }
  private statusLabel(status: number): string {
    if (status === 1) return '已发布';
    if (status === 2) return '已结束';
    return '未发布';
  }
  @Builder createEntry() {
    Button('＋ 组卷').height(34).fontSize(13)
      .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
      .fontColor(Color.White)
      .onClick((): void => { router.pushUrl({ url: 'pages/ExamEdit' }); })
  }
  build() {
    Column() {
      PageHeader({
        title: '考试管理',
        onBack: (): void => { router.back(); },
        right: (): void => { this.createEntry() }
      })
      if (this.loading) {
        Column({ space: 12 }) { SkeletonCard(); SkeletonCard(); SkeletonCard() }.padding(20)
      } else if (this.rows.length === 0) {
        EmptyState({ icon: '📝', text: '暂无考试，点击右上角创建' })
      } else {
        List({ space: 12 }) {
          ForEach(this.rows, (exam: ExamSummary) => {
            ListItem() {
              Row({ space: 12 }) {
                Column() {
                  Text('📝').fontSize(20)
                }
                .width(46).height(46).borderRadius(Theme.R_MD)
                .backgroundColor(Theme.PRIMARY_LIGHT)
                .alignItems(HorizontalAlign.Center)
                Column({ space: 3 }) {
                  Text(exam.title).fontSize(Theme.F_BODY).fontWeight(FontWeight.Bold)
                    .fontColor(Theme.TEXT).maxLines(1)
                  Text(`时长 ${exam.duration_min} 分钟 · ${this.statusLabel(exam.status)}`)
                    .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text('👁 监控')
                  .fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(14)
                  .onClick((): void => { router.pushUrl({ url: 'pages/ExamMonitor' }); })
              }
              .width('100%').padding(14)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }
          }, (exam: ExamSummary) => String(exam.id))
        }
        .lanes({ minLength: 360, maxLength: 520 }, 12)
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 4, bottom: 20 })
        .scrollBar(BarState.Off)
      }
      if (this.message.length > 0) {
        Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER).padding(8)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
