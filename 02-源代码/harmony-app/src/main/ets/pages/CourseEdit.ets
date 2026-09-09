import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { CourseDetail } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, Card, PrimaryButton } from '../components/UiKit';

interface CourseEditParams { courseId?: number | string }

@Entry
@Component
struct CourseEdit {
  @State courseId: number = 0;
  @State title: string = '';
  @State description: string = '';
  @State loading: boolean = true;
  @State message: string = '';
  @State saving: boolean = false;

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    const raw: Object | null = router.getParams();
    if (raw === null || raw === undefined) {
      this.message = '新建课程模式：填写标题后保存';
      this.loading = false;
      return;
    }
    const params: CourseEditParams = raw as CourseEditParams;
    const value: number | string | undefined = params.courseId;
    const id: number = typeof value === 'number' ? value
      : (typeof value === 'string' ? Number(value) : 0);
    this.courseId = id;
    if (!Number.isFinite(id) || id <= 0) {
      this.message = '新建课程模式：填写标题后保存';
      this.loading = false;
      return;
    }
    try {
      const course: CourseDetail = await api.getCourse(id);
      this.title = course.title;
      this.description = course.description;
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }

  private async save(): Promise<void> {
    if (this.title.length === 0) { this.message = '请填写标题'; return; }
    this.saving = true;
    try {
      if (this.courseId > 0) {
        await api.updateCourse(this.courseId, this.title, this.description);
        this.message = '✓ 课程已保存';
      } else {
        await api.createCourse(this.title, this.description);
        this.message = '✓ 课程已创建';
        this.title = '';
        this.description = '';
      }
    } catch (error) {
      this.message = error instanceof Error ? error.message : '保存失败';
    }
    this.saving = false;
  }

  build() {
    Column() {
      PageHeader({
        title: this.courseId > 0 ? '编辑课程' : '新建课程',
        onBack: (): void => { router.back(); }
      })
      if (this.loading) {
        Column({ space: 12 }) {
          Column().width('100%').height(200).borderRadius(Theme.R_LG).backgroundColor(Theme.INPUT_BG)
        }.padding(20)
      } else {
        Scroll() {
          Column({ space: 14 }) {
            Card() {
              Column({ space: 14 }) {
                this.FormField('课程标题', '如：Python 后端开发', this.title,
                  (v: string): void => { this.title = v; })
                Column({ space: 6 }) {
                  Text('课程简介').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  TextArea({ placeholder: '介绍课程内容与学习目标…', text: this.description })
                    .onChange((v: string): void => { this.description = v; })
                    .width('100%').height(120).fontSize(14)
                    .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                    .caretColor(Theme.PRIMARY)
                }.width('100%')
              }.width('100%')
            }
            PrimaryButton({
              label: this.courseId > 0 ? '💾 保存修改' : '✓ 创建课程',
              loading: this.saving,
              onTap: (): void => { this.save(); }
            })
            if (this.message.length > 0) {
              Text(this.message).fontSize(Theme.F_SUB)
                .fontColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
                .width('100%').textAlign(TextAlign.Center)
                .margin({ bottom: 24 })
            }
          }.padding(20)
          .constraintSize({ maxWidth: 640 })
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }

  @Builder FormField(label: string, placeholder: string, value: string, onChange: (v: string) => void) {
    Column({ space: 6 }) {
      Text(label).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
      TextInput({ placeholder: placeholder, text: value })
        .onChange((v: string): void => { onChange(v); })
        .width('100%').height(46).fontSize(14)
        .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
        .caretColor(Theme.PRIMARY)
    }.width('100%')
  }
}
