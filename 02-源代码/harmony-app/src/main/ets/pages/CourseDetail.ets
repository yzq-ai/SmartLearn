import { api } from '../common/ApiClient';
import { CourseDetail as CourseDetailModel, ChapterDetail, ExamSummary } from '../common/Models';
import { Theme } from '../common/Theme';
import { PrimaryButton, SkeletonCard } from '../components/UiKit';
interface CourseParams { courseId?: number | string; }
@Entry
@Component
struct CourseDetailPage {
  @State course: CourseDetailModel | undefined = undefined;
  @State loading: boolean = true;
  @State message: string = '';
  @State examLoading: boolean = false;
  @State examId: number = 0;
  private courseId: number = 0;
  aboutToAppear(): void {
    const raw: Object | null = this.getUIContext().getRouter().getParams();
    if (raw !== null && raw !== undefined) {
      const params: CourseParams = raw as CourseParams;
      if (params.courseId !== undefined) {
        const value: number | string = params.courseId;
        this.courseId = typeof value === 'number' ? value : Number(value);
      }
    }
    this.loadCourse();
  }
  private async loadCourse(): Promise<void> {
    this.loading = true;
    this.message = '';
    try { this.course = await api.getCourse(this.courseId); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }
  private async enterExam(): Promise<void> {
    if (this.examLoading) return;
    this.examLoading = true;
    this.message = '';
    try {
      const exams: ExamSummary[] = await api.getExams();
      const matched: ExamSummary | undefined = exams.find(
        (e: ExamSummary): boolean => e.course_id === this.courseId);
      if (matched === undefined) {
        this.message = '该课程暂未安排考试';
        this.examLoading = false;
        return;
      }
      this.examId = matched.id;
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/ExamNotice', params: { examId: this.examId }
      });
    } catch (error) {
      this.message = error instanceof Error ? error.message : '获取考试信息失败';
    }
    this.examLoading = false;
  }
  private totalSections(): number {
    if (this.course === undefined) return 0;
    let n: number = 0;
    this.course.chapters.forEach((c: ChapterDetail): void => { n += c.sections.length; });
    return n;
  }
  private chaptersCount(): number {
    if (this.course === undefined) return 0;
    return this.course.chapters.length;
  }
  build() {
    Column() {
      if (this.loading) {
        Column({ space: 14 }) {
          Column().width('100%').height(160).borderRadius(Theme.R_XL).backgroundColor(Theme.INPUT_BG)
          SkeletonCard(); SkeletonCard()
        }.padding(20).layoutWeight(1)
      } else if (this.course === undefined) {
        Column() {
          Text('😕').fontSize(52)
          Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER).margin({ top: 12 })
        }.layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else {
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 10 }) {
              Row() {
                Button('‹')
                  .width(38).height(38).fontSize(18)
                  .backgroundColor('rgba(255,255,255,0.22)').fontColor(Color.White)
                  .borderRadius(Theme.R_MD)
                  .onClick((): void => { this.getUIContext().getRouter().back(); })
                Blank()
              }.width('100%')
              Row({ space: 10 }) {
                Text('📚').fontSize(24)
                Text(this.course.title).fontSize(22).fontWeight(FontWeight.Bold)
                  .fontColor(Color.White).layoutWeight(1).maxLines(2)
              }.width('100%')
              Text(this.course.description).fontSize(Theme.F_SUB)
                .fontColor('rgba(255,255,255,0.8)').width('100%').maxLines(3)
              Row({ space: 8 }) {
                Text(`👨‍🏫 ${this.course.teacher}`).fontSize(Theme.F_CAP)
                  .fontColor('rgba(255,255,255,0.85)')
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .backgroundColor('rgba(255,255,255,0.15)').borderRadius(8)
                Text(`${this.course.chapters.length} 章 · ${this.totalSections()} 节`)
                  .fontSize(Theme.F_CAP)
                  .fontColor('rgba(255,255,255,0.85)')
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .backgroundColor('rgba(255,255,255,0.15)').borderRadius(8)
              }.width('100%')
            }
            .width('100%').padding(24)
            .linearGradient({ angle: 145, colors: [[Theme.PRIMARY_DEEP, 0], [Theme.PRIMARY_GRADIENT, 1]] })
            .borderRadius(Theme.R_XL)
            .shadow(Theme.SHADOW_FLOAT)
            Text('章节目录').fontSize(17).fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT).width('100%')
            // 需求 15：紧凑单行章节（此前大卡片一屏仅 1-2 章，观感像“只有一个章节”）
            Column({ space: 8 }) {
            ForEach(this.course.chapters, (chapter: ChapterDetail, index: number) => {
              Row({ space: 12 }) {
                Text(`${index + 1}`)
                  .fontColor(Color.White).width(30).height(30)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(Theme.PRIMARY).borderRadius(15).fontSize(13)
                  .fontWeight(FontWeight.Bold)
                Column({ space: 2 }) {
                  Text(chapter.title).fontSize(Theme.F_BODY)
                    .fontWeight(FontWeight.Medium).fontColor(Theme.TEXT).maxLines(1)
                  Text(chapter.description).fontSize(Theme.F_CAP)
                    .fontColor(Theme.TEXT_HINT).maxLines(1)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Column({ space: 3 }) {
                  Text(`${chapter.sections.length} 节`)
                    .fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                  Text('›').fontSize(14).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT_HINT)
                }.alignItems(HorizontalAlign.End)
              }
              .width('100%').padding({ top: 10, bottom: 10, left: 14, right: 14 })
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_MD)
              .shadow(Theme.SHADOW_CARD)
              .onClick((): void => {
                this.getUIContext().getRouter().pushUrl({
                  url: 'pages/ChapterList',
                  params: {
                    chapterId: chapter.id,
                    chapterTitle: chapter.title,
                    sections: chapter.sections,
                    course_id: this.courseId
                  }
                });
              })
            }, (chapter: ChapterDetail) => String(chapter.id))
            }.width('100%')
            Row({ space: 10 }) {
              Text('🤖').fontSize(18)
              Column({ space: 2 }) {
                Text('AI 智能摘要').fontSize(Theme.F_BODY)
                  .fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                Text('一键提炼课程核心要点').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text('›').fontSize(18).fontColor(Theme.TEXT_HINT)
            }
            .width('100%').padding(14)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
            .shadow(Theme.SHADOW_CARD)
            .onClick((): void => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/AISummary' });
            })
            PrimaryButton({
              label: this.examLoading ? '查找考试中…' : '📝 进入课程考试',
              loading: this.examLoading,
              onTap: (): void => { this.enterExam(); }
            })
            if (this.message.length > 0) {
              Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER)
                .width('100%').textAlign(TextAlign.Center)
                .margin({ bottom: 24 })
            }
          }.padding(20)
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
