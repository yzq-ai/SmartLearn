import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { AssignmentItem, AssignmentSubmissionList } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, TagChip } from '../components/UiKit';
@Entry
@Component
struct AssignmentGrading {
  @State assignments: AssignmentItem[] = [];
  @State selectedAssignmentId: number = 0;
  @State expandId: number = 0;   // 展开全文的提交
  @State rows: AssignmentSubmissionList[] = [];
  @State loading: boolean = true;
  @State message: string = '';
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    this.loading = true;
    this.message = '';
    try { this.assignments = await api.getAssignments(); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }
  private async pick(assignmentId: number): Promise<void> {
    this.selectedAssignmentId = assignmentId;
    this.message = '';
    try {
      this.rows = await api.getAssignmentSubmissions(assignmentId);
    } catch (error) {
      this.message = error instanceof Error ? error.message : '获取提交失败';
    }
  }
  private async grade(sub: AssignmentSubmissionList, score: number): Promise<void> {
    try {
      await api.gradeSubmission(sub.id, score, '批改完成');
      this.message = `✓ 已给 ${sub.real_name.length > 0 ? sub.real_name : sub.username} 评分 ${score} 分`;
      if (this.selectedAssignmentId > 0) {
        this.rows = await api.getAssignmentSubmissions(this.selectedAssignmentId);
      }
    } catch (error) {
      this.message = error instanceof Error ? error.message : '批改失败';
    }
  }
  private pendingCount(): number {
    return this.rows.filter((r: AssignmentSubmissionList): boolean =>
      r.status === 'SUBMITTED').length;
  }
  build() {
    Column() {
      PageHeader({ title: '作业批改', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 10 }) {
            Text('选择作业').fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT).width('100%')
            if (this.loading) {
              SkeletonCard()
            } else if (this.assignments.length === 0) {
              Text('暂无作业').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).padding(8)
            } else {
              ForEach(this.assignments, (a: AssignmentItem) => {
                Row({ space: 10 }) {
                  Text(a.title).fontSize(Theme.F_SUB).fontColor(Theme.TEXT)
                    .layoutWeight(1).maxLines(1)
                  if (this.selectedAssignmentId === a.id) {
                    TagChip({ text: '当前', tone: 'primary' })
                  }
                  Button('查看').height(30).fontSize(12)
                    .backgroundColor(this.selectedAssignmentId === a.id
                      ? Theme.PRIMARY : Theme.PRIMARY_LIGHT)
                    .fontColor(this.selectedAssignmentId === a.id ? Color.White : Theme.PRIMARY)
                    .onClick((): void => { this.pick(a.id); })
                }
                .width('100%').padding(10)
                .backgroundColor(this.selectedAssignmentId === a.id
                  ? Theme.PRIMARY_LIGHT : Theme.BG)
                .borderRadius(Theme.R_SM)
              })
            }
          }
          .width('100%').padding(Theme.CARD_PAD)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)
          if (this.rows.length > 0) {
            Row({ space: 12 }) {
              Column({ space: 2 }) {
                Text('总提交').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                Text(`${this.rows.length}`).fontSize(19).fontWeight(FontWeight.Bold)
                  .fontColor(Theme.TEXT)
              }.layoutWeight(1)
              Column({ space: 2 }) {
                Text('待批改').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                Text(`${this.pendingCount()}`).fontSize(19).fontWeight(FontWeight.Bold)
                  .fontColor(Theme.WARNING)
              }.layoutWeight(1)
              Column({ space: 2 }) {
                Text('已批改').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                Text(`${this.rows.length - this.pendingCount()}`).fontSize(19)
                  .fontWeight(FontWeight.Bold).fontColor(Theme.SUCCESS)
              }.layoutWeight(1)
            }
            .width('100%').padding(14)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
            .shadow(Theme.SHADOW_CARD)
          }
          if (this.rows.length === 0) {
            EmptyState({ icon: '🖊', text: '选择作业后查看学生提交' })
          } else {
            ForEach(this.rows, (sub: AssignmentSubmissionList) => {
              Column({ space: 10 }) {
                Row({ space: 10 }) {
                  Column() {
                    Text((sub.real_name.length > 0 ? sub.real_name : sub.username).length > 0
                      ? (sub.real_name.length > 0 ? sub.real_name : sub.username).substring(0, 1) : '?')
                      .fontSize(15).fontWeight(FontWeight.Bold).fontColor(Color.White)
                  }
                  .width(40).height(40).borderRadius(20)
                  .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                  Column({ space: 2 }) {
                    Text(sub.real_name.length > 0 ? sub.real_name : sub.username)
                      .fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
                    Text(sub.submitted_at).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  if (sub.is_late === 1) {
                    TagChip({ text: '迟交', tone: 'warning' })
                  }
                  if (sub.status === 'GRADED') {
                    TagChip({ text: `${sub.score} 分`, tone: 'success' })
                  } else {
                    TagChip({ text: '待批改', tone: 'warning' })
                  }
                }.width('100%')
                if (sub.content !== null && sub.content !== undefined
                  && sub.content.length > 0) {
                  Text(sub.content).fontSize(Theme.F_SUB)
                    .fontColor(Theme.TEXT_SECOND).width('100%')
                    .maxLines(this.expandId === sub.id ? 100 : 4)
                    .padding(10)
                    .backgroundColor(Theme.BG).borderRadius(Theme.R_SM)
                    .onClick((): void => {
                      this.expandId = this.expandId === sub.id ? 0 : sub.id;
                    })
                  if (sub.content.length > 80 && this.expandId !== sub.id) {
                    Text('展开全文 ▾').fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                      .alignSelf(ItemAlign.Start)
                      .onClick((): void => { this.expandId = sub.id; })
                  }
                }
                if (sub.status === 'GRADED' && sub.feedback !== null
                  && sub.feedback !== undefined) {
                  Row({ space: 6 }) {
                    Text('💬').fontSize(12)
                    Text(sub.feedback).fontSize(Theme.F_CAP).fontColor(Theme.SUCCESS)
                  }
                  .width('100%').padding(8)
                  .backgroundColor(Theme.SUCCESS_LIGHT).borderRadius(Theme.R_SM)
                }
                if (sub.status !== 'GRADED') {
                  Row({ space: 8 }) {
                    Text('快速评分：').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    Button('及格').height(32).fontSize(12).layoutWeight(1)
                      .backgroundColor(Theme.WARNING_LIGHT).fontColor(Theme.WARNING)
                      .onClick((): void => { this.grade(sub, 60); })
                    Button('良好').height(32).fontSize(12).layoutWeight(1)
                      .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
                      .onClick((): void => { this.grade(sub, 85); })
                    Button('优秀').height(32).fontSize(12).layoutWeight(1)
                      .linearGradient({ angle: 135, colors: [[Theme.SUCCESS, 0], ['#3ECF8E', 1]] })
                      .fontColor(Color.White)
                      .onClick((): void => { this.grade(sub, 95); })
                  }.width('100%')
                }
              }
              .width('100%').padding(Theme.CARD_PAD)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }, (sub: AssignmentSubmissionList) => String(sub.id))
          }
          if (this.message.length > 0) {
            Text(this.message).fontSize(Theme.F_SUB)
              .fontColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
              .width('100%').textAlign(TextAlign.Center)
              .margin({ bottom: 24 })
          }
        }.padding(20)
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
