import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { AssignmentItem } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, TagChip } from '../components/UiKit';
interface StatusInfo { label: string; tone: string }
@Entry
@Component
struct AssignmentList {
  @State rows: AssignmentItem[] = [];
  @State content: string = '';
  @State activeId: number = 0;
  @State loading: boolean = true;
  @State message: string = '';
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    this.loading = true;
    this.message = '';
    try { this.rows = await api.getAssignments(); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }
  private async submit(assignmentId: number): Promise<void> {
    if (this.content.length === 0) { this.message = '请填写作业内容'; return; }
    try {
      await api.submitAssignment(assignmentId, this.content);
      this.content = '';
      this.activeId = 0;
      this.rows = await api.getAssignments();
      this.message = '✓ 作业已提交';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '提交失败';
    }
  }
  private statusInfo(item: AssignmentItem): StatusInfo {
    if (item.my_submission === null) {
      const result: StatusInfo = { label: '未提交', tone: 'danger' };
      return result;
    }
    if (item.my_submission.status === 'GRADED') {
      const result: StatusInfo = { label: `${item.my_submission.score} 分`, tone: 'success' };
      return result;
    }
    const result: StatusInfo = { label: '已提交', tone: 'primary' };
    return result;
  }
  private fmtDate(iso: string): string {
    // '2026-09-08T21:06:58.487989' -> '09-08 21:06'
    if (iso === null || iso === undefined || iso.length < 16) { return iso ?? ''; }
    const datePart: string = iso.substring(5, 10);
    const timePart: string = iso.substring(11, 16);
    return `${datePart} ${timePart}`;
  }
  build() {
    Column() {
      PageHeader({ title: '作业列表', onBack: (): void => { router.back(); } })
      if (this.loading) {
        Column({ space: 12 }) { SkeletonCard(); SkeletonCard(); SkeletonCard() }.padding(20)
      } else if (this.rows.length === 0) {
        EmptyState({ icon: '📋', text: '暂无作业安排' })
      } else {
        List({ space: 12 }) {
          ForEach(this.rows, (item: AssignmentItem) => {
            ListItem() {              Column({ space: 10 }) {
                Row({ space: 10 }) {
                  Column() {
                    Text('📋').fontSize(18)
                  }
                  .width(42).height(42).borderRadius(Theme.R_MD)
                  .backgroundColor(
                    item.my_submission === null ? Theme.WARNING_LIGHT : Theme.PRIMARY_LIGHT)
                  .alignItems(HorizontalAlign.Center)
                  Column({ space: 3 }) {
                    Text(item.title).fontSize(Theme.F_BODY).fontWeight(FontWeight.Bold)
                      .fontColor(Theme.TEXT).maxLines(1)
                    Row({ space: 6 }) {
                      Text(`满分 ${item.max_score}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                      Text(`· 截止 ${this.fmtDate(item.deadline)}`).fontSize(Theme.F_CAP)
                        .fontColor(item.is_expired ? Theme.DANGER : Theme.TEXT_HINT)
                    }
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  TagChip({
                    text: this.statusInfo(item).label,
                    tone: this.statusInfo(item).tone
                  })
                  // 已提交：点击头部行即可展开/收起详情
                  if (item.my_submission !== null) {
                    Text(this.activeId === item.id ? '▴' : '▾').fontSize(14)
                      .fontColor(Theme.PRIMARY)
                  }
                }.width('100%')
                .onClick((): void => {
                  if (item.my_submission !== null) {
                    this.activeId = this.activeId === item.id ? 0 : item.id;
                  }
                })
                if (item.description !== null && item.description !== undefined
                  && item.description.length > 0) {
                  Text(item.description).fontSize(Theme.F_SUB)
                    .fontColor(Theme.TEXT_SECOND).width('100%').maxLines(2)
                }
                if (item.my_submission !== null && item.my_submission.is_late === 1) {
                  Row({ space: 6 }) {
                    Text('⏰').fontSize(12)
                    Text('迟交提交').fontSize(Theme.F_CAP).fontColor(Theme.WARNING)
                  }
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor(Theme.WARNING_LIGHT).borderRadius(8)
                }
                if (item.my_submission !== null
                  && item.my_submission.status === 'GRADED'
                  && item.my_submission.feedback !== null
                  && item.my_submission.feedback !== undefined) {
                  Row({ space: 8 }) {
                    Text('💬').fontSize(13)
                    Text(`教师评语：${item.my_submission.feedback}`)
                      .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
                      .layoutWeight(1)
                  }
                  .width('100%').padding(10)
                  .backgroundColor(Theme.SUCCESS_LIGHT).borderRadius(Theme.R_SM)
                }
                if (item.my_submission === null) {
                  if (this.activeId === item.id) {
                    Column({ space: 10 }) {
                      TextArea({ placeholder: '填写你的作业内容…', text: this.content })
                        .onChange((v: string): void => { this.content = v; })
                        .width('100%').height(90).fontSize(14)
                        .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                        .caretColor(Theme.PRIMARY)
                      Row({ space: 10 }) {
                        Button('取消').height(38).fontSize(13).layoutWeight(1)
                          .backgroundColor(Theme.BG).fontColor(Theme.TEXT_SECOND)
                          .onClick((): void => { this.activeId = 0; this.content = ''; })
                        Button('✓ 提交作业').height(38).fontSize(13).layoutWeight(2)
                          .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                          .fontColor(Color.White)
                          .onClick((): void => { this.submit(item.id); })
                      }.width('100%')
                    }
                  } else {
                    Button('✍️ 去完成作业')
                      .width('100%').height(40).fontSize(13)
                      .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                      .fontColor(Color.White)
                      .onClick((): void => { this.activeId = item.id; this.content = ''; })
                  }
                } else {
                  // 已提交：点击查看我的提交详情
                  if (this.activeId === item.id) {
                    Column({ space: 8 }) {
                      Column({ space: 4 }) {
                        Text('📄 我的提交内容').fontSize(Theme.F_CAP)
                          .fontColor(Theme.TEXT_HINT)
                        Text(item.my_submission.content ?? '（空）')
                          .fontSize(Theme.F_SUB).fontColor(Theme.TEXT)
                          .width('100%').padding(10)
                          .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                      }.alignItems(HorizontalAlign.Start).width('100%')
                      Row({ space: 8 }) {
                        Text(`提交时间 ${this.fmtDate(item.my_submission.submitted_at ?? '')}`)
                          .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).layoutWeight(1)
                        if (item.my_submission.status === 'GRADED') {
                          Text(`得分 ${item.my_submission.score}`)
                            .fontSize(Theme.F_CAP).fontWeight(FontWeight.Bold)
                            .fontColor(Theme.SUCCESS)
                            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                            .backgroundColor(Theme.SUCCESS_LIGHT).borderRadius(8)
                        }
                      }.width('100%')
                    }
                    .padding(10).width('100%')
                    .backgroundColor(Theme.BG).borderRadius(Theme.R_MD)
                  } else {
                    Button(item.my_submission.status === 'GRADED' ? '📖 查看提交详情' : '📖 查看我的提交')
                      .width('100%').height(40).fontSize(13)
                      .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
                      .onClick((): void => { this.activeId = item.id; })
                  }
                }
              }
              .width('100%').padding(Theme.CARD_PAD)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }
          }, (item: AssignmentItem) => String(item.id))
        }
        .lanes({ minLength: 340, maxLength: 520 }, 12)
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 4, bottom: 20 })
        .scrollBar(BarState.Off)
      }
      if (this.message.length > 0) {
        Text(this.message).fontSize(Theme.F_SUB)
          .fontColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
          .padding(8).width('100%').textAlign(TextAlign.Center)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
