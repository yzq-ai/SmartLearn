import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Course } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard } from '../components/UiKit';

@Entry
@Component
struct CourseManage {
  @State rows: Course[] = [];
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    try { this.rows = await api.getCourses(); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }

  @Builder createEntry() {
    Button('＋ 新建').height(34).fontSize(13)
      .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
      .fontColor(Color.White)
      .onClick((): void => { router.pushUrl({ url: 'pages/CourseEdit' }); })
  }
  build() {
    Column() {
      PageHeader({
        title: '课程管理',
        onBack: (): void => { router.back(); },
        right: (): void => { this.createEntry() }
      })
      if (this.loading) {
        Column({ space: 12 }) { SkeletonCard(); SkeletonCard(); SkeletonCard() }.padding(20)
      } else if (this.rows.length === 0) {
        EmptyState({ icon: '📚', text: '暂无课程' })
      } else {
        List({ space: 12 }) {
          ForEach(this.rows, (course: Course) => {
            ListItem() {
              Row({ space: 12 }) {
                Column() {
                  Text(course.title.length > 0 ? course.title.substring(0, 1) : '?')
                    .fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White)
                }
                .width(48).height(48).borderRadius(Theme.R_MD)
                .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                Column({ space: 3 }) {
                  Text(course.title).fontSize(Theme.F_BODY)
                    .fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).maxLines(1)
                  Text(`${course.chapters.length} 章 · ${course.teacher}`)
                    .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Button('编辑').height(32).fontSize(12)
                  .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
                  .onClick((): void => {
                    router.pushUrl({ url: 'pages/CourseEdit', params: { courseId: course.id } });
                  })
                // 需求 6：章节 / 小节 / 视频内容管理
                Button('内容').height(32).fontSize(12)
                  .backgroundColor(Theme.WARNING_LIGHT).fontColor(Theme.WARNING)
                  .borderRadius(16)
                  .onClick((): void => {
                    router.pushUrl({
                      url: 'pages/CourseContentManage',
                      params: { course_id: course.id, course_title: course.title }
                    });
                  })
              }
              .width('100%').padding(14)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }
          }, (course: Course) => String(course.id))
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
