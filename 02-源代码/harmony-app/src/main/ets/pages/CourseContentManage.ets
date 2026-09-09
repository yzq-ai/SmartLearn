import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { ManagedChapter, ManagedSection } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, Card, EmptyState, SkeletonCard, TagChip, showToast } from '../components/UiKit';

/**
 * 单课程内容管理（需求 6）：教师对课程的所有内容可编辑 ——
 * 章节：新增 / 改标题与简介 / 删除；
 * 小节：新增 / 编辑（标题、类型、正文、视频地址、时长）/ 删除。
 */
@Entry
@Component
struct CourseContentManage {
  @State courseTitle: string = '';
  @State courseId: number = 0;
  @State chapters: ManagedChapter[] = [];
  @State loading: boolean = true;
  @State message: string = '';
  // 章节编辑
  @State editingChapter: number = 0;
  @State chapterTitleInput: string = '';
  @State chapterDescInput: string = '';
  @State newChapterTitle: string = '';
  @State newChapterDesc: string = '';
  // 小节编辑
  @State editingSection: number = 0;
  @State sectionTitle: string = '';
  @State sectionType: string = 'TEXT';
  @State sectionContent: string = '';
  @State sectionVideo: string = '';
  @State sectionDurMin: number = 0;
  @State sectionDurSec: number = 0;
  // 小节新建目标章节
  @State addSectionTo: number = 0;
  @State busy: boolean = false;
  @State expandedChapter: number = 0;

  aboutToAppear(): void {
    const params: Record<string, object> = router.getParams() as Record<string, object>;
    if (params !== null && params !== undefined) {
      this.courseId = Number(params.course_id) || 0;
      this.courseTitle = String(params.course_title ?? '');
    }
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    try {
      this.chapters = await api.getManagedChapters(this.courseId);
      if (this.chapters.length > 0 && this.expandedChapter === 0) {
        this.expandedChapter = this.chapters[0].id;
      }
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败（仅授课教师可管理）';
    }
    this.loading = false;
  }

  // ── 章节操作 ──
  private async createChapter(): Promise<void> {
    if (this.newChapterTitle.trim().length === 0) { return; }
    this.busy = true;
    try {
      await api.createChapter(this.courseId, this.newChapterTitle.trim(), this.newChapterDesc.trim());
      this.newChapterTitle = '';
      this.newChapterDesc = '';
      showToast('✓ 章节已添加', 'success');
      await this.load();
    } catch (error) {
      showToast(error instanceof Error ? error.message : '添加失败', 'fail');
    }
    this.busy = false;
  }

  private async saveChapter(ch: ManagedChapter): Promise<void> {
    this.busy = true;
    try {
      await api.updateChapter(ch.id, this.chapterTitleInput.trim(), this.chapterDescInput.trim());
      this.editingChapter = 0;
      showToast('✓ 章节已更新', 'success');
      await this.load();
    } catch (error) {
      showToast(error instanceof Error ? error.message : '保存失败', 'fail');
    }
    this.busy = false;
  }

  private async removeChapter(ch: ManagedChapter): Promise<void> {
    this.busy = true;
    try {
      await api.deleteChapter(ch.id);
      showToast('已删除章节', 'success');
      await this.load();
    } catch (error) {
      showToast(error instanceof Error ? error.message : '删除失败', 'fail');
    }
    this.busy = false;
  }

  // ── 小节操作 ──
  private async createSection(): Promise<void> {
    if (this.sectionTitle.trim().length === 0 || this.addSectionTo === 0) { return; }
    this.busy = true;
    try {
      await api.createSection(this.addSectionTo, this.sectionTitle.trim(), this.sectionType,
        this.sectionContent, this.sectionVideo.trim(), this.sectionDurMin, this.sectionDurSec);
      this.sectionTitle = '';
      this.sectionContent = '';
      this.sectionVideo = '';
      this.sectionDurMin = 0;
      this.sectionDurSec = 0;
      this.addSectionTo = 0;
      showToast('✓ 小节已添加', 'success');
      await this.load();
    } catch (error) {
      showToast(error instanceof Error ? error.message : '添加失败', 'fail');
    }
    this.busy = false;
  }

  private async saveSection(s: ManagedSection): Promise<void> {
    this.busy = true;
    try {
      await api.updateSection(s.id, this.sectionTitle.trim(), this.sectionType,
        this.sectionContent, this.sectionVideo.trim(), this.sectionDurMin, this.sectionDurSec);
      this.editingSection = 0;
      showToast('✓ 小节已更新', 'success');
      await this.load();
    } catch (error) {
      showToast(error instanceof Error ? error.message : '保存失败', 'fail');
    }
    this.busy = false;
  }

  private async removeSection(s: ManagedSection): Promise<void> {
    this.busy = true;
    try {
      await api.deleteSection(s.id);
      showToast('已删除小节', 'success');
      await this.load();
    } catch (error) {
      showToast(error instanceof Error ? error.message : '删除失败', 'fail');
    }
    this.busy = false;
  }

  private typeName(t: string): string {
    if (t === 'VIDEO') { return '视频'; }
    if (t === 'QUIZ') { return '练习'; }
    return '图文';
  }

  build() {
    Column() {
      PageHeader({
        title: this.courseTitle.length > 0 ? `内容 · ${this.courseTitle}` : '课程内容管理',
        onBack: (): void => { router.back(); }
      })
      Scroll() {
        Column({ space: 14 }) {
          if (this.loading) {
            SkeletonCard(); SkeletonCard(); SkeletonCard()
          } else {
            // ═══ 新增章节卡 ═══
            Card() {
              Column({ space: 10 }) {
                Row({ space: 8 }) {
                  Text('➕').fontSize(16)
                  Text('新增章节').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                }.width('100%')
                TextInput({ placeholder: '章节标题', text: this.newChapterTitle })
                  .onChange((v: string): void => { this.newChapterTitle = v; })
                  .height(42).fontSize(13).width('100%')
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
                TextInput({ placeholder: '章节简介（可选）', text: this.newChapterDesc })
                  .onChange((v: string): void => { this.newChapterDesc = v; })
                  .height(42).fontSize(13).width('100%')
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
                Button('添加章节').height(40).fontSize(13).width('100%')
                  .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                  .fontColor(Color.White).borderRadius(Theme.R_MD)
                  .enabled(this.newChapterTitle.trim().length > 0 && !this.busy)
                  .onClick((): void => { this.createChapter(); })
              }.width('100%')
            }

            // ═══ 章节列表 ═══
            if (this.chapters.length === 0) {
              EmptyState({ icon: '📚', text: this.message.length > 0 ? this.message : '暂无章节，先添加第一章' })
            } else {
              ForEach(this.chapters, (ch: ManagedChapter, idx: number) => {
                Card() {
                  Column({ space: 10 }) {
                    // 章节头
                    Row({ space: 10 }) {
                      Text(`${idx + 1}`)
                        .fontSize(13).fontWeight(FontWeight.Bold).fontColor(Color.White)
                        .width(28).height(28).textAlign(TextAlign.Center)
                        .backgroundColor(Theme.PRIMARY).borderRadius(14)
                      if (this.editingChapter === ch.id) {
                        Column({ space: 8 }) {
                          TextInput({ text: this.chapterTitleInput })
                            .onChange((v: string): void => { this.chapterTitleInput = v; })
                            .height(38).fontSize(13).width('100%')
                            .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                          TextInput({ text: this.chapterDescInput })
                            .onChange((v: string): void => { this.chapterDescInput = v; })
                            .height(38).fontSize(13).width('100%')
                            .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                          Row({ space: 8 }) {
                            Button('保存').height(32).fontSize(12)
                              .backgroundColor(Theme.PRIMARY).fontColor(Color.White).borderRadius(16)
                              .onClick((): void => { this.saveChapter(ch); })
                            Button('取消').height(32).fontSize(12)
                              .backgroundColor(Theme.INPUT_BG).fontColor(Theme.TEXT).borderRadius(16)
                              .onClick((): void => { this.editingChapter = 0; })
                          }
                        }.layoutWeight(1)
                      } else {
                        Column({ space: 2 }) {
                          Text(ch.title).fontSize(15).fontWeight(FontWeight.Bold)
                            .fontColor(Theme.TEXT).maxLines(1)
                          Text(ch.description).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                            .maxLines(1).width('100%')
                        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                      }
                      Blank()
                      Column({ space: 6 }) {
                        Text(this.expandedChapter === ch.id ? '收起 ▴' : `${ch.sections.length} 小节 ▾`)
                          .fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                          .onClick((): void => {
                            this.expandedChapter = this.expandedChapter === ch.id ? 0 : ch.id;
                          })
                        if (this.editingChapter !== ch.id) {
                          Row({ space: 10 }) {
                            Text('✏️').fontSize(13).onClick((): void => {
                              this.editingChapter = ch.id;
                              this.chapterTitleInput = ch.title;
                              this.chapterDescInput = ch.description;
                            })
                            Text('🗑').fontSize(13).onClick((): void => { this.removeChapter(ch); })
                          }
                        }
                      }.alignItems(HorizontalAlign.End)
                    }.width('100%')

                    // ═══ 展开的小节列表 ═══
                    if (this.expandedChapter === ch.id) {
                      Divider().strokeWidth(0.5).color(Theme.DIVIDER)
                      if (ch.sections.length === 0) {
                        Text('暂无小节').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
                      } else {
                        ForEach(ch.sections, (s: ManagedSection, sidx: number) => {
                          Column({ space: 6 }) {
                            if (this.editingSection === s.id) {
                              Column({ space: 8 }) {
                                Text(`编辑小节 ${sidx + 1}`).fontSize(Theme.F_SUB).fontWeight(FontWeight.Bold)
                                  .fontColor(Theme.TEXT)
                                TextInput({ placeholder: '小节标题', text: this.sectionTitle })
                                  .onChange((v: string): void => { this.sectionTitle = v; })
                                  .height(38).fontSize(13).width('100%')
                                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                                Row({ space: 6 }) {
                                  ForEach(['TEXT', 'VIDEO', 'QUIZ'], (t: string) => {
                                    Text(this.typeName(t)).fontSize(11)
                                      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                                      .fontColor(this.sectionType === t ? Color.White : Theme.TEXT)
                                      .backgroundColor(this.sectionType === t ? Theme.PRIMARY : Theme.INPUT_BG)
                                      .borderRadius(12)
                                      .onClick((): void => { this.sectionType = t; })
                                  }, (t: string) => t)
                                }.width('100%')
                                TextArea({ placeholder: '小节正文内容', text: this.sectionContent })
                                  .onChange((v: string): void => { this.sectionContent = v; })
                                  .fontSize(12).width('100%').constraintSize({ minHeight: 70 })
                                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                                if (this.sectionType === 'VIDEO') {
                                  TextInput({ placeholder: '视频地址（http…）', text: this.sectionVideo })
                                    .onChange((v: string): void => { this.sectionVideo = v; })
                                    .height(38).fontSize(12).width('100%')
                                    .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                                }
                                Row({ space: 8 }) {
                                  TextInput({ placeholder: '分', text: `${this.sectionDurMin}` })
                                    .type(InputType.Number)
                                    .onChange((v: string): void => { this.sectionDurMin = Number(v) || 0; })
                                    .height(38).fontSize(12).layoutWeight(1)
                                    .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                                  TextInput({ placeholder: '秒', text: `${this.sectionDurSec}` })
                                    .type(InputType.Number)
                                    .onChange((v: string): void => { this.sectionDurSec = Number(v) || 0; })
                                    .height(38).fontSize(12).layoutWeight(1)
                                    .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                                }.width('100%')
                                Row({ space: 8 }) {
                                  Button('保存').height(32).fontSize(12)
                                    .backgroundColor(Theme.PRIMARY).fontColor(Color.White).borderRadius(16)
                                    .onClick((): void => { this.saveSection(s); })
                                  Button('取消').height(32).fontSize(12)
                                    .backgroundColor(Theme.INPUT_BG).fontColor(Theme.TEXT).borderRadius(16)
                                    .onClick((): void => { this.editingSection = 0; })
                                }
                              }.width('100%')
                            } else {
                              Row({ space: 8 }) {
                                TagChip({ text: this.typeName(s.type), tone: s.type === 'VIDEO' ? 'warning' : 'default' })
                                Text(s.title).fontSize(Theme.F_SUB).fontColor(Theme.TEXT)
                                  .maxLines(1).layoutWeight(1)
                                if (s.type === 'VIDEO' && s.duration_minutes + s.duration_sec > 0) {
                                  Text(`${s.duration_minutes}:${s.duration_sec < 10 ? '0' : ''}${s.duration_sec}`)
                                    .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                                }
                                Text('✏️').fontSize(12).onClick((): void => {
                                  this.editingSection = s.id;
                                  this.sectionTitle = s.title;
                                  this.sectionType = s.type;
                                  this.sectionContent = s.content;
                                  this.sectionVideo = s.video_url;
                                  this.sectionDurMin = s.duration_minutes;
                                  this.sectionDurSec = s.duration_sec;
                                })
                                Text('🗑').fontSize(12).onClick((): void => { this.removeSection(s); })
                              }.width('100%')
                            }
                          }.width('100%')
                        }, (s: ManagedSection) => `${s.id}-${this.editingSection === s.id ? 'edit' : 'view'}`)
                      }
                      // 添加小节
                      if (this.addSectionTo === ch.id) {
                        Column({ space: 8 }) {
                          TextInput({ placeholder: '小节标题', text: this.sectionTitle })
                            .onChange((v: string): void => { this.sectionTitle = v; })
                            .height(38).fontSize(13).width('100%')
                            .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                          Row({ space: 6 }) {
                            ForEach(['TEXT', 'VIDEO', 'QUIZ'], (t: string) => {
                              Text(this.typeName(t)).fontSize(11)
                                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                                .fontColor(this.sectionType === t ? Color.White : Theme.TEXT)
                                .backgroundColor(this.sectionType === t ? Theme.PRIMARY : Theme.INPUT_BG)
                                .borderRadius(12)
                                .onClick((): void => { this.sectionType = t; })
                            }, (t: string) => t)
                          }.width('100%')
                          TextArea({ placeholder: '正文内容', text: this.sectionContent })
                            .onChange((v: string): void => { this.sectionContent = v; })
                            .fontSize(12).width('100%').constraintSize({ minHeight: 60 })
                            .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                          if (this.sectionType === 'VIDEO') {
                            TextInput({ placeholder: '视频地址（http…）', text: this.sectionVideo })
                              .onChange((v: string): void => { this.sectionVideo = v; })
                              .height(38).fontSize(12).width('100%')
                              .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                          }
                          Row({ space: 8 }) {
                            Button('保存小节').height(34).fontSize(12)
                              .backgroundColor(Theme.PRIMARY).fontColor(Color.White).borderRadius(17)
                              .enabled(this.sectionTitle.trim().length > 0 && !this.busy)
                              .onClick((): void => { this.createSection(); })
                            Button('取消').height(34).fontSize(12)
                              .backgroundColor(Theme.INPUT_BG).fontColor(Theme.TEXT).borderRadius(17)
                              .onClick((): void => { this.addSectionTo = 0; })
                          }
                        }.width('100%').padding(10)
                        .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_MD)
                      } else {
                        Text('＋ 添加小节').fontSize(Theme.F_SUB).fontColor(Theme.PRIMARY)
                          .padding({ top: 6, bottom: 6 })
                          .onClick((): void => {
                            this.addSectionTo = ch.id;
                            this.editingSection = 0;
                            this.sectionTitle = '';
                            this.sectionType = 'TEXT';
                            this.sectionContent = '';
                            this.sectionVideo = '';
                            this.sectionDurMin = 0;
                            this.sectionDurSec = 0;
                          })
                      }
                    }
                  }.width('100%')
                }
              }, (ch: ManagedChapter) => `${ch.id}-${ch.sections.length}-${this.expandedChapter === ch.id ? 'open' : 'closed'}-${this.editingChapter === ch.id ? 'edit' : 'view'}`)
            }
          }
        }.padding(20)
        .constraintSize({ maxWidth: 640 })
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
