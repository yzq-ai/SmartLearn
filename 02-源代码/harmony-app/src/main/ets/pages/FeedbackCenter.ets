import { promptAction, router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { FeedbackItem } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, TagChip, EmptyState, SkeletonCard, BottomSpace } from '../components/UiKit';

interface CategoryOption {
  key: string;
  label: string;
  icon: string;
  desc: string;
}

@Entry
@Component
struct FeedbackCenter {
  @State rows: FeedbackItem[] = [];
  @State loading: boolean = true;
  @State message: string = '';
  // 表单
  @State categories: CategoryOption[] = [
    { key: 'BUG', label: '缺陷反馈', icon: '🐞', desc: '功能异常、报错、数据问题' },
    { key: 'FEATURE', label: '功能建议', icon: '💡', desc: '希望新增或改进的功能' },
    { key: 'EXPERIENCE', label: '体验问题', icon: '🎨', desc: '界面、交互、性能体验' },
    { key: 'CONTENT', label: '内容纠错', icon: '📝', desc: '讲义、题目、文案错误' },
    { key: 'OTHER', label: '其他', icon: '💬', desc: ' anything else' },
  ];
  @State selected: string = 'BUG';
  @State title: string = '';
  @State content: string = '';
  @State contact: string = '';
  @State submitting: boolean = false;
  @State showForm: boolean = true;
  // 状态配色
  private statusTone(status: string): string {
    if (status === 'RESOLVED') return 'success';
    if (status === 'PROCESSING') return 'primary';
    if (status === 'REJECTED') return 'danger';
    return 'warning';
  }
  private catTone(cat: string): string {
    if (cat === 'BUG') return 'danger';
    if (cat === 'FEATURE') return 'primary';
    if (cat === 'EXPERIENCE') return 'warning';
    if (cat === 'CONTENT') return 'success';
    return 'primary';
  }
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    this.loading = true;
    this.message = '';
    try {
      this.rows = await api.getMyFeedback();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }
  private async submit(): Promise<void> {
    if (this.title.trim().length < 2) {
      promptAction.showToast({ message: '标题至少 2 个字', duration: 1800 });
      return;
    }
    if (this.content.trim().length < 5) {
      promptAction.showToast({ message: '内容至少 5 个字，说详细一点', duration: 1800 });
      return;
    }
    this.submitting = true;
    try {
      await api.submitFeedback(this.selected, this.title.trim(), this.content.trim(), this.contact.trim());
      promptAction.showToast({ message: '反馈已提交，感谢你的声音', duration: 2200 });
      this.title = '';
      this.content = '';
      this.contact = '';
      this.showForm = false;
      this.load();
    } catch (error) {
      promptAction.showToast({ message: error instanceof Error ? error.message : '提交失败', duration: 2200 });
    }
    this.submitting = false;
  }
  build() {
    Column() {
      PageHeader({
        title: '反馈中心',
        subtitle: `你的每一条反馈都会被认真处理${AppStorage.get<string>('username') ? ` · ${AppStorage.get<string>('username')}` : ''}`,
        onBack: (): void => { router.back(); },
      })
      Scroll() {
        Column({ space: 14 }) {
          // ═══ 提交表单 ═══
          Column({ space: 14 }) {
            SectionTitle({ text: this.rows.length > 0 ? (this.showForm ? '提交新反馈' : '✎ 继续提交') : '提交反馈' })
            // 分类选择
            Row() {
              ForEach(this.categories, (c: CategoryOption) => {
                Column({ space: 4 }) {
                  Text(c.icon).fontSize(22)
                  Text(c.label).fontSize(Theme.F_CAP)
                    .fontColor(this.selected === c.key ? Theme.PRIMARY : Theme.TEXT_SECOND)
                  if (this.selected === c.key) {
                    Divider().strokeWidth(2).color(Theme.PRIMARY).width(16).borderRadius(2)
                  }
                }
                .layoutWeight(1)
                .padding({ top: 10, bottom: 6 })
                .onClick((): void => {
                  this.selected = c.key;
                  if (this.showForm === false) { this.showForm = true; }
                })
              }, (c: CategoryOption) => c.key)
            }
            .width('100%')
            .backgroundColor(Theme.INPUT_BG)
            .borderRadius(Theme.R_MD)
            if (this.showForm) {
              Column({ space: 12 }) {
                Text(`${this.categories.find((c: CategoryOption): boolean => c.key === this.selected)?.desc ?? ''}`)
                  .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
                TextInput({ placeholder: '一句话概括问题（2-40 字）', text: this.title })
                  .onChange((v: string) => { this.title = v; })
                  .height(44).fontSize(Theme.F_BODY)
                TextArea({ placeholder: '详细描述：什么页面、做了什么、期望结果…', text: this.content })
                  .onChange((v: string) => { this.content = v; })
                  .height(110).fontSize(Theme.F_BODY)
                TextInput({ placeholder: '联系方式（选填，便于回访）', text: this.contact })
                  .onChange((v: string) => { this.contact = v; })
                  .height(44).fontSize(Theme.F_BODY)
                Button(this.submitting ? '提交中…' : '提交反馈')
                  .width('100%').height(46).fontSize(15).fontWeight(FontWeight.Medium)
                  .backgroundColor(Theme.PRIMARY).fontColor(Color.White)
                  .borderRadius(Theme.R_MD)
                  .enabled(!this.submitting)
                  .onClick((): void => { this.submit(); })
                Text('提交后可在下方跟踪处理进度；紧急问题请联系任课教师。')
                  .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
              }.width('100%')
            }
          }
          .width('100%').padding(16)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)

          // ═══ 我的反馈列表 ═══
          SectionTitle({ text: `我的反馈（${this.rows.length}）` })
          if (this.loading) {
            Column({ space: 12 }) {
              SkeletonCard(); SkeletonCard()
            }
          } else if (this.rows.length === 0) {
            EmptyState({ icon: '📮', text: '还没有反馈记录', hint: '你的建议会让我们变得更好' })
          } else {
            ForEach(this.rows, (f: FeedbackItem) => {
              Column({ space: 10 }) {
                Row({ space: 8 }) {
                  TagChip({ text: f.category_label, tone: this.catTone(f.category) })
                  Text(f.title).fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium)
                    .fontColor(Theme.TEXT).layoutWeight(1).maxLines(1)
                  TagChip({ text: f.status_label, tone: this.statusTone(f.status) })
                }.width('100%')
                Text(f.content).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
                  .width('100%').maxLines(2)
                if (f.reply !== null && f.reply !== undefined && f.reply.length > 0) {
                  Row({ space: 8 }) {
                    Column().width(3).height('100%').backgroundColor(Theme.PRIMARY_LIGHT)
                    Column({ space: 4 }) {
                      Text(`${f.handler_name ?? '管理员'} 回复：`).fontSize(Theme.F_CAP)
                        .fontColor(Theme.PRIMARY).fontWeight(FontWeight.Medium)
                      Text(f.reply).fontSize(Theme.F_SUB).fontColor(Theme.TEXT).width('100%')
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  }.width('100%').padding(10)
                  .backgroundColor(Theme.PRIMARY_LIGHT)
                  .borderRadius(Theme.R_MD)
                }
                Text(f.handled_at !== null ? `处理于 ${f.handled_at}` : `提交于 ${f.created_at}`)
                  .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
              }
              .width('100%').padding(14)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }, (f: FeedbackItem) => `${f.id}-${f.status}`)
          }
          BottomSpace()
        }
        .padding({ left: 20, right: 20, top: 12 })
      }
      .layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}

@Component
struct SectionTitle {
  @Prop text: string = '';
  build() {
    Row({ space: 8 }) {
      Column().width(4).height(16).backgroundColor(Theme.PRIMARY).borderRadius(2)
      Text(this.text).fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).layoutWeight(1)
    }.width('100%')
  }
}
