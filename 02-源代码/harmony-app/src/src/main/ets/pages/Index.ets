import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { ChapterDetail, Course, CourseDetail, Progress } from '../common/Models';
import { Theme } from '../common/Theme';
import { SkeletonCard, EmptyState, PrimaryButton } from '../components/UiKit';
@Component
struct CourseCard {
  @Prop course: Course;
  @Prop progress: number = 0;
  onOpen: (id: number) => void = (_id: number): void => {};
  build() {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Column() {
          Text(this.course.title.length > 0 ? this.course.title.substring(0, 1) : '?')
            .fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
        }
        .width(48).height(48).borderRadius(Theme.R_MD)
        .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
        .shadow(Theme.SHADOW_FLOAT)
        Column({ space: 3 }) {
          Text(this.course.title).fontSize(16).fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT).maxLines(1)
          Text(`${this.course.chapters.length} 个章节 · ${this.course.teacher}`)
            .fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.width('100%')
      Row({ space: 10 }) {
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .layoutWeight(1).color(Theme.PRIMARY)
          .style({ strokeWidth: 6 })
        Text(`${this.progress}%`).fontSize(Theme.F_CAP)
          .fontColor(Theme.PRIMARY).fontWeight(FontWeight.Bold)
      }.width('100%')
      Button('继续学习')
        .width('100%').height(40).fontSize(14)
        .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
        .borderRadius(Theme.R_MD)
        .onClick(() => { this.onOpen(this.course.id); })
    }
    .width('100%').padding(Theme.CARD_PAD)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
  }
}
@Entry
@Component
struct Index {
  @State courses: Course[] = [];
  @State loading: boolean = true;
  @State syncing: boolean = false;
  @State message: string = '';
  @State selectedCourse: CourseDetail | undefined = undefined;
  @State progress: number = 0;
  private progressByCourse: Record<string, number> = {};
  aboutToAppear(): void {
    const token: string = AppStorage.get<string>('token') ?? '';
    if (token.length > 0) api.setToken(token);
    this.loadCourses();
  }
  private async loadCourses(): Promise<void> {
    this.loading = true;
    this.message = '';
    try {
      const courses: Course[] = await api.getCourses();
      this.courses = courses;
      if (api.hasToken()) {
        const progressList: Progress[] = await api.getProgress();
        const map: Record<string, number> = {};
        progressList.forEach((item: Progress): void => {
          map[String(item.course_id)] = Math.round(item.percent);
        });
        this.progressByCourse = map;
      }
    } catch (error) {
      this.message = error instanceof Error ? error.message : '课程加载失败';
    }
    this.loading = false;
  }
  private async openCourse(id: number): Promise<void> {
    this.message = '';
    try {
      this.selectedCourse = await api.getCourse(id);
      this.progress = this.progressByCourse[String(id)] ?? 0;
    } catch (error) {
      this.message = error instanceof Error ? error.message : '详情加载失败';
    }
  }
  private async completeChapter(index: number): Promise<void> {
    const course: CourseDetail | undefined = this.selectedCourse;
    if (course === undefined || course.chapters.length === 0 || this.syncing) return;
    const previous: number = this.progress;
    const next: number = Math.min(100, Math.round(((index + 1) / course.chapters.length) * 100));
    this.progress = next;
    this.syncing = true;
    this.message = '正在同步学习进度…';
    try {
      const saved: Progress = await api.updateProgress(course.id, next, index + 1);
      this.progress = Math.round(saved.percent);
      this.progressByCourse[String(course.id)] = this.progress;
      this.message = '✓ 学习进度已同步';
    } catch (error) {
      this.progress = previous;
      this.message = error instanceof Error ? error.message : '进度同步失败，请重试';
    }
    this.syncing = false;
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
  @Builder CourseDetail() {
    if (this.selectedCourse !== undefined) {
      Column({ space: 14 }) {
        Row() {
          Button('‹').width(40).height(40).fontSize(20)
            .backgroundColor(Theme.CARD).fontColor(Theme.TEXT)
            .onClick(() => { this.selectedCourse = undefined; });
          Blank();
          Text('课程详情').fontSize(18).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
          Blank().width(40)
        }.width('100%')
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 8 }) {
              Text(this.selectedCourse.title).fontSize(24).fontWeight(FontWeight.Bold)
                .fontColor(Color.White).width('100%')
              Text(this.selectedCourse.description).fontSize(Theme.F_SUB)
                .fontColor('rgba(255,255,255,0.8)').width('100%').maxLines(2)
              Text(`授课教师：${this.selectedCourse.teacher}`).fontSize(Theme.F_SUB)
                .fontColor('rgba(255,255,255,0.9)').width('100%')
            }
            .width('100%').padding(22)
            .linearGradient({ angle: 140, colors: [[Theme.PRIMARY_DEEP, 0], [Theme.PRIMARY_GRADIENT, 1]] })
            .borderRadius(Theme.R_LG)
            .shadow(Theme.SHADOW_FLOAT)
            Column({ space: 10 }) {
              Row() {
                Text('学习进度').fontSize(Theme.F_BODY).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                Blank()
                Text(`${this.progress}%${this.syncing ? '（同步中）' : ''}`)
                  .fontSize(Theme.F_BODY).fontColor(Theme.PRIMARY).fontWeight(FontWeight.Bold)
              }.width('100%')
              Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
                .width('100%').color(Theme.PRIMARY).style({ strokeWidth: 8 })
            }
            .width('100%').padding(16)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
            .shadow(Theme.SHADOW_CARD)
            Text('章节列表').fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT).width('100%')
            GridRow({ gutter: { x: 12, y: 10 } }) {
              ForEach(this.selectedCourse.chapters, (chapter: ChapterDetail, index: number) => {
                GridCol({ span: { sm: 12, md: 6 } }) {
                  Row({ space: 12 }) {
                    Text(`${index + 1}`)
                      .fontColor(Color.White).width(30).height(30)
                      .textAlign(TextAlign.Center)
                      .backgroundColor(index < Math.round(this.progress * this.selectedCourse!.chapters.length / 100)
                        ? Theme.SUCCESS : Theme.PRIMARY)
                      .borderRadius(15).fontSize(13)
                    Text(chapter.title).fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium)
                      .fontColor(Theme.TEXT).layoutWeight(1).maxLines(1)
                    Text(index < Math.round(this.progress * this.selectedCourse!.chapters.length / 100)
                      ? '✓ 已完成' : '未开始')
                      .fontSize(Theme.F_CAP)
                      .fontColor(index < Math.round(this.progress * this.selectedCourse!.chapters.length / 100)
                        ? Theme.SUCCESS : Theme.TEXT_HINT)
                  }
                  .width('100%').padding(14)
                  .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
                  .shadow(Theme.SHADOW_CARD)
                  .enabled(!this.syncing)
                  .onClick(() => { this.completeChapter(index); })
                }
              }, (chapter: ChapterDetail) => chapter.title)
            }
            if (this.message.length > 0) {
              Text(this.message).fontSize(Theme.F_SUB)
                .fontColor(this.message.indexOf('失败') >= 0 ? Theme.DANGER : Theme.SUCCESS)
                .width('100%').textAlign(TextAlign.Center)
            }
            PrimaryButton({
              label: '进入课程',
              onTap: (): void => {
                const course: CourseDetail | undefined = this.selectedCourse;
                if (course !== undefined) {
                  router.pushUrl({ url: 'pages/CourseDetail', params: { courseId: course.id } });
                }
              }
            })
          }.padding(20)
        }.layoutWeight(1).scrollBar(BarState.Off)
      }.width('100%').height('100%')
    }
  }
  build() {
    if (this.selectedCourse !== undefined) {
      this.CourseDetail()
    } else {
      Column() {
        Row({ space: 12 }) {
          Column({ space: 2 }) {
            Text('学习中心').fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
            Text(`你好，${AppStorage.get<string>('username') ?? '同学'}`)
              .fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button('退出').fontSize(12).height(34)
            .backgroundColor(Theme.CARD).fontColor(Theme.TEXT_HINT)
            .shadow(Theme.SHADOW_CARD)
            .onClick(() => { this.logout(); })
        }
        .width('100%').padding({ left: 20, right: 20, top: 18, bottom: 12 })
        Scroll() {
          Column({ space: 14 }) {
            if (this.loading) {
              SkeletonCard()
              SkeletonCard()
              SkeletonCard()
            } else if (this.courses.length === 0) {
              EmptyState({ icon: '📚', text: '暂无课程，请联系教师开通' })
            } else {
              GridRow({ gutter: { x: 12, y: 14 } }) {
                ForEach(this.courses, (course: Course) => {
                  GridCol({ span: { sm: 12, md: 6, lg: 4 } }) {
                    CourseCard({
                      course,
                      progress: this.progressByCourse[String(course.id)] ?? 0,
                      onOpen: (id: number): void => { this.openCourse(id); }
                    })
                  }
                }, (course: Course) => String(course.id))
              }
            }
            if (this.message.length > 0 && !this.loading) {
              Text(this.message).fontColor(Theme.DANGER).fontSize(Theme.F_SUB)
              Button('重试加载').width('100%').height(44)
                .backgroundColor(Theme.CARD).fontColor(Theme.PRIMARY)
                .onClick(() => { this.loadCourses(); })
            }
          }.padding({ left: 20, right: 20, bottom: 24 })
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
      .width('100%').height('100%').backgroundColor(Theme.BG)
    }
  }
}
