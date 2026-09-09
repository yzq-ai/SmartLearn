import { router } from '@kit.ArkUI';
import { SectionDetail } from '../common/Models';
import { Theme } from '../common/Theme';
import { EmptyState } from '../components/UiKit';
interface ChapterListParams {
  chapterId: number;
  chapterTitle: string;
  sections: SectionDetail[];
  course_id?: number;
}
@Entry
@Component
struct ChapterList {
  @State chapterTitle: string = '';
  @State sections: SectionDetail[] = [];
  @State courseId: number = 0;
  aboutToAppear(): void {
    const raw: Object | null = this.getUIContext().getRouter().getParams();
    if (raw !== null && raw !== undefined) {
      const params: ChapterListParams = raw as ChapterListParams;
      if (params.chapterTitle !== undefined) { this.chapterTitle = params.chapterTitle; }
      if (params.sections !== undefined) { this.sections = params.sections; }
      if (params.course_id !== undefined) { this.courseId = Number(params.course_id) || 0; }
    }
  }
  private typeIcon(type: string): string {
    if (type === 'VIDEO') return '🎬';
    if (type === 'DOC') return '📄';
    return '✏️';
  }
  private typeColor(type: string): string {
    if (type === 'VIDEO') return Theme.DANGER_LIGHT;
    if (type === 'DOC') return Theme.SUCCESS_LIGHT;
    return Theme.PRIMARY_LIGHT;
  }
  build() {
    Column() {
      Row({ space: 12 }) {
        Button('‹')
          .width(40).height(40).fontSize(20)
          .backgroundColor(Theme.CARD).fontColor(Theme.TEXT)
          .shadow(Theme.SHADOW_CARD)
          .onClick((): void => { this.getUIContext().getRouter().back(); })
        Column({ space: 2 }) {
          Text('章节学习').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
          Text(this.chapterTitle).fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT).maxLines(1)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text(`${this.sections.length} 节`).fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(8)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })
      if (this.sections.length === 0) {
        EmptyState({ icon: '📂', text: '暂无小节内容' })
      } else {
        List({ space: 12 }) {
          ForEach(this.sections, (section: SectionDetail, index: number) => {
            ListItem() {
              Row({ space: 12 }) {
                Column() {
                  Text(this.typeIcon(section.type)).fontSize(18)
                }
                .width(46).height(46).borderRadius(Theme.R_MD)
                .backgroundColor(this.typeColor(section.type))
                .alignItems(HorizontalAlign.Center)
                Column({ space: 4 }) {
                  Text(section.title).fontSize(Theme.F_BODY)
                    .fontWeight(FontWeight.Medium).fontColor(Theme.TEXT).maxLines(1)
                  Row({ space: 6 }) {
                    Text(`第 ${index + 1} 节`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    Text(`· ${section.duration_minutes} 分钟`).fontSize(Theme.F_CAP)
                      .fontColor(Theme.TEXT_HINT)
                    if (section.type !== null && section.type !== undefined && section.type.length > 0) {
                      Text(`· ${section.type}`).fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                    }
                  }
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                if (section.type === 'VIDEO') {
                  Button('▶ 播放').height(34).fontSize(12)
                    .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                    .fontColor(Color.White)
                    .onClick((): void => {
                      this.getUIContext().getRouter().pushUrl({
                        url: 'pages/SectionLearn',
                        params: { section: section, chapterTitle: this.chapterTitle, course_id: this.courseId }
                      });
                    })
                } else if (section.type === 'DOC') {
                  Button('📄 预览').height(34).fontSize(12)
                    .backgroundColor(Theme.SUCCESS_LIGHT).fontColor(Theme.SUCCESS)
                    .onClick((): void => {
                      this.getUIContext().getRouter().pushUrl({
                        url: 'pages/SectionLearn',
                        params: { section: section, chapterTitle: this.chapterTitle, course_id: this.courseId }
                      });
                    })
                } else {
                  Text('📖 阅读')
                    .fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(14)
                    .onClick((): void => {
                      this.getUIContext().getRouter().pushUrl({
                        url: 'pages/SectionLearn',
                        params: { section: section, chapterTitle: this.chapterTitle, course_id: this.courseId }
                      });
                    })
                }
              }
              .width('100%').padding(14)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }
          }, (section: SectionDetail) => String(section.id))
        }
        .lanes({ minLength: 360, maxLength: 520 }, 12)
        .layoutWeight(1)
        .padding({ left: 20, right: 20, bottom: 20 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
