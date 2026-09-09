import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Course } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, TagChip } from '../components/UiKit';

/**
 * 我的课程页（需求 8）：学生查看已绑定课程的完整课表信息。
 * 起始/截至日期、上课时间、上课地点、考试时间、任课老师（教师端录入）。
 */
@Entry
@Component
struct MyCourses {
  @State loading: boolean = true;
  @State courses: Course[] = [];
  @State message: string = '';
  @State expandId: number = -1; // 展开详情的课程 id（-1 全收起）

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    try {
      this.courses = await api.getMyCourses();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }

  build() {
    Column() {
      PageHeader({ title: '我的课程', onBack: (): void => { router.back(); } })
      if (this.loading) {
        Column({ space: 12 }) { SkeletonCard(); SkeletonCard(); SkeletonCard(); }.padding(20)
      } else if (this.courses.length === 0) {
        Column() {
          EmptyState({ icon: '📚', text: this.message.length > 0 ? this.message : '暂无绑定课程' })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 14 }) {
            Text(`共 ${this.courses.length} 门课程 · 课表信息由任课教师维护`)
              .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
            ForEach(this.courses, (c: Course) => {
              Column({ space: 12 }) {
                // 头部：课程名 + 教师
                Row({ space: 12 }) {
                  Column() {
                    Text('📘').fontSize(22)
                  }.width(44).height(44).justifyContent(FlexAlign.Center)
                  .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_SM)
                  Column({ space: 3 }) {
                    Text(c.title).fontSize(16).fontWeight(FontWeight.Bold)
                      .fontColor(Theme.TEXT).maxLines(1)
                    Row({ space: 6 }) {
                      Text(`👩‍🏫 ${c.teacher}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
                      if ((c.semester ?? '').length > 0) {
                        TagChip({ text: c.semester ?? '', tone: 'primary' })
                      }
                    }
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text(this.expandId === c.id ? '收起 ▲' : '详情 ▼')
                    .fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                }.width('100%')
                .onClick((): void => {
                  this.expandId = this.expandId === c.id ? -1 : c.id;
                })

                // 摘要行：上课时间（一眼可见）
                if ((c.class_time ?? '').length > 0) {
                  Row({ space: 8 }) {
                    Text('⏰').fontSize(13)
                    Text(c.class_time ?? '').fontSize(Theme.F_SUB).fontColor(Theme.TEXT)
                      .layoutWeight(1)
                  }
                  .width('100%').padding({ top: 8, bottom: 8, left: 10, right: 10 })
                  .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_MD)
                }

                // 展开详情
                if (this.expandId === c.id) {
                  Column({ space: 9 }) {
                    this.Field('🗓', '起始日期', c.start_date ?? '教师待录入')
                    this.Field('🏁', '截止日期', c.end_date ?? '教师待录入')
                    this.Field('⏰', '上课时间', c.class_time ?? '教师待录入')
                    this.Field('📍', '上课地点', c.location ?? '教师待录入')
                    this.Field('📝', '考试时间', c.exam_time ?? '待公布')
                  }
                  .width('100%').padding(12)
                  .backgroundColor(Theme.BG).borderRadius(Theme.R_MD)
                  .animation({ duration: 200 })
                }

                // 章节速览
                if (this.expandId === c.id && c.chapters.length > 0) {
                  Text(`章节（${c.chapters.length}）：${c.chapters.slice(0, 4).join('、')}${c.chapters.length > 4 ? '…' : ''}`)
                    .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
                    .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                }

                Row({ space: 0 }) {
                  Text('进入课程').fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                  Text('›').fontSize(14).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
                }.width('100%').justifyContent(FlexAlign.End)
                .onClick((): void => {
                  router.pushUrl({ url: 'pages/CourseDetail', params: { courseId: c.id } });
                })
              }
              .width('100%').padding(16)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }, (c: Course) => `${c.id}-${this.expandId === c.id}`)
          }.padding(20).padding({ bottom: 24 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }

  @Builder Field(icon: string, label: string, value: string) {
    Row({ space: 10 }) {
      Text(icon).fontSize(15).width(24)
      Text(label).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND).width(64)
      Text(value).fontSize(Theme.F_SUB).fontColor(Theme.TEXT).layoutWeight(1)
    }.width('100%')
  }
}
