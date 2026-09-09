import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Course, Job } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard } from '../components/UiKit';
@Entry
@Component
struct SearchPage {
  @State keyword: string = '';
  @State courses: Course[] = [];
  @State jobs: Job[] = [];
  @State loading: boolean = true;
  @State message: string = '';
  @State tab: number = 0;
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    this.loading = true;
    this.message = '';
    try {
      this.courses = await api.getCourses();
      this.jobs = await api.getJobs();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }
  private filteredCourses(): Course[] {
    if (this.keyword.length === 0) return this.courses;
    return this.courses.filter((c: Course): boolean =>
      c.title.indexOf(this.keyword) >= 0 || c.description.indexOf(this.keyword) >= 0);
  }
  private filteredJobs(): Job[] {
    if (this.keyword.length === 0) return this.jobs;
    return this.jobs.filter((j: Job): boolean =>
      j.title.indexOf(this.keyword) >= 0 || j.company.indexOf(this.keyword) >= 0);
  }
  private highlightText(text: string): string { return text; }
  build() {
    Column() {
      PageHeader({ title: '搜索', onBack: (): void => { router.back(); } })
      Row({ space: 8 }) {
        Row({ space: 8 }) {
          Text('🔍').fontSize(15)
          TextInput({ placeholder: '搜索课程 / 岗位…', text: this.keyword })
            .onChange((v: string): void => { this.keyword = v; })
            .layoutWeight(1).height(44).fontSize(14)
            .backgroundColor(Color.Transparent)
            .caretColor(Theme.PRIMARY)
          if (this.keyword.length > 0) {
            Text('✕').fontSize(14).fontColor(Theme.TEXT_HINT)
              .padding(6)
              .onClick((): void => { this.keyword = ''; })
          }
        }
        .layoutWeight(1)
        .padding({ left: 12, right: 8 })
        .backgroundColor(Theme.CARD)
        .borderRadius(Theme.R_MD)
        .shadow(Theme.SHADOW_CARD)
        Button('搜索')
          .height(44).fontSize(14).fontWeight(FontWeight.Medium)
          .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
          .fontColor(Color.White).borderRadius(Theme.R_MD)
          .onClick((): void => { this.load(); })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 4, bottom: 8 })
      Row({ space: 12 }) {
        Text(`课程 ${this.filteredCourses().length}`)
          .fontSize(Theme.F_CAP)
          .fontColor(this.tab === 0 ? Theme.PRIMARY : Theme.TEXT_HINT)
          .fontWeight(this.tab === 0 ? FontWeight.Bold : FontWeight.Normal)
        Text(`岗位 ${this.filteredJobs().length}`)
          .fontSize(Theme.F_CAP)
          .fontColor(this.tab === 1 ? Theme.PRIMARY : Theme.TEXT_HINT)
          .fontWeight(this.tab === 1 ? FontWeight.Bold : FontWeight.Normal)
        Blank()
        if (this.keyword.length > 0) {
          Text(`关键词：「${this.keyword}」`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 8 })
      Tabs({ barPosition: BarPosition.Start, index: this.tab }) {
        TabContent() {
          if (this.loading) {
            Column({ space: 12 }) { SkeletonCard(); SkeletonCard() }.padding({ left: 20, right: 20 })
          } else if (this.filteredCourses().length === 0) {
            EmptyState({ icon: '🔍', text: '没有找到相关课程' })
          } else {
            List({ space: 10 }) {
              ForEach(this.filteredCourses(), (course: Course) => {
                ListItem() {
                  Row({ space: 12 }) {
                    Column() {
                      Text('📚').fontSize(18)
                    }
                    .width(42).height(42).borderRadius(Theme.R_MD)
                    .backgroundColor(Theme.PRIMARY_LIGHT)
                    .alignItems(HorizontalAlign.Center)
                    Column({ space: 3 }) {
                      Text(course.title).fontSize(Theme.F_BODY)
                        .fontWeight(FontWeight.Medium).fontColor(Theme.TEXT).maxLines(1)
                      Text(course.description).fontSize(Theme.F_CAP)
                        .fontColor(Theme.TEXT_HINT).maxLines(1)
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    Text('›').fontSize(18).fontColor(Theme.TEXT_HINT)
                  }
                  .width('100%').padding(12)
                  .backgroundColor(Theme.CARD).borderRadius(Theme.R_MD)
                  .shadow(Theme.SHADOW_CARD)
                  .onClick((): void => {
                    router.pushUrl({ url: 'pages/CourseDetail', params: { courseId: course.id } });
                  })
                }
              })
            }
            .lanes({ minLength: 340, maxLength: 520 }, 12)
            .padding({ left: 20, right: 20, top: 4, bottom: 20 })
            .scrollBar(BarState.Off)
          }
        }.tabBar('📚 课程')
        TabContent() {
          if (this.loading) {
            Column({ space: 12 }) { SkeletonCard(); SkeletonCard() }.padding({ left: 20, right: 20 })
          } else if (this.filteredJobs().length === 0) {
            EmptyState({ icon: '🔍', text: '没有找到相关岗位' })
          } else {
            List({ space: 10 }) {
              ForEach(this.filteredJobs(), (job: Job) => {
                ListItem() {
                  Row({ space: 12 }) {
                    Column() {
                      Text('💼').fontSize(18)
                    }
                    .width(42).height(42).borderRadius(Theme.R_MD)
                    .backgroundColor(Theme.PRIMARY_LIGHT)
                    .alignItems(HorizontalAlign.Center)
                    Column({ space: 3 }) {
                      Text(job.title).fontSize(Theme.F_BODY)
                        .fontWeight(FontWeight.Medium).fontColor(Theme.TEXT).maxLines(1)
                      Text(`${job.company} · 匹配 ${job.match_score}%`)
                        .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    Text('›').fontSize(18).fontColor(Theme.TEXT_HINT)
                  }
                  .width('100%').padding(12)
                  .backgroundColor(Theme.CARD).borderRadius(Theme.R_MD)
                  .shadow(Theme.SHADOW_CARD)
                  .onClick((): void => {
                    router.pushUrl({ url: 'pages/JobDetail', params: { jobId: job.id } });
                  })
                }
              })
            }
            .lanes({ minLength: 340, maxLength: 520 }, 12)
            .padding({ left: 20, right: 20, top: 4, bottom: 20 })
            .scrollBar(BarState.Off)
          }
        }.tabBar('💼 岗位')
      }
      .barMode(BarMode.Fixed)
      .layoutWeight(1)
      .onTabBarClick((index: number): void => { this.tab = index; })
      if (this.message.length > 0) {
        Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER).padding(8)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
