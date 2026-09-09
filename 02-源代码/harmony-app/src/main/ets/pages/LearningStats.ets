import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { LearningStats, CourseStat, WrongStat, ExamStat } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, Card, EmptyState } from '../components/UiKit';
import { RadarChart } from '../components/RadarChart';
import { ScoreRingChart } from '../components/ScoreRingChart';
import { BarChart } from '../components/BarChart';
@Entry
@Component
struct LearningStatsPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State stats: LearningStats | undefined = undefined;
  @State loading: boolean = true;
  @State message: string = '';
  @State radarLabels: string[] = ['选择题', '判断题', '填空题', '简答题', '综合'];
  @State radarValues: number[] = [0, 0, 0, 0, 0];
  @State totalScore: number = 0;
  @State maxScore: number = 100;
  aboutToAppear(): void { this.loadStats(); }
  private async loadStats(): Promise<void> {
    this.loading = true;
    this.message = '';
    try {
      this.stats = await api.getLearningStats();
      this.buildRadarFromStats();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }
  private buildRadarFromStats(): void {
    if (this.stats === undefined) return;
    // 需求 13 修复：全部使用后端真实判分数据（此前为 records 参与度 + 硬编码偏移假数据）
    const st: LearningStats = this.stats;
    // 1) 平均分环：全库归一化平均分（后端已按 score*100/total 计算）
    this.totalScore = Math.round(st.overall_avg_score ?? 0);
    // 2) 雷达：各题型真实正确率
    const names: Record<string, string> = {
      'SINGLE': '单选题', 'MULTI': '多选题', 'JUDGE': '判断题', 'BLANK': '填空题', 'SHORT': '简答题'
    };
    const labels: string[] = [];
    const values: number[] = [];
    if (st.type_rates !== undefined && st.type_rates !== null) {
      const keys: string[] = Object.keys(st.type_rates);
      for (const key of keys) {
        labels.push(names[key] ?? key);
        values.push(Math.round(st.type_rates[key]));
      }
    }
    // 有真实判分数据时替换默认假雷达
    if (labels.length > 0) {
      this.radarLabels = labels;
      this.radarValues = values;
    }
  }
  @Builder refreshEntry() {
    Button('🔄').height(34).width(34).fontSize(14)
      .backgroundColor(Theme.CARD).fontColor(Theme.PRIMARY)
      .shadow(Theme.SHADOW_CARD)
      .onClick((): void => { this.loadStats(); })
  }
  // ═══ 图表数据辅助 ═══
  private courseLabels(): string[] {
    const list: string[] = [];
    if (this.stats !== undefined) {
      for (const c of this.stats.courses) { list.push(c.title); }
    }
    return list;
  }
  private courseStudents(): number[] {
    const list: number[] = [];
    if (this.stats !== undefined) {
      for (const c of this.stats.courses) { list.push(c.student_count); }
    }
    return list;
  }
  private wrongLabels(): string[] {
    const list: string[] = [];
    if (this.stats !== undefined) {
      for (const w of this.stats.top_wrong) {
        const short: string = w.text.length > 10 ? `${w.text.substring(0, 10)}…` : w.text;
        list.push(`TOP${list.length + 1} ${short}`);
      }
    }
    return list;
  }
  private wrongCounts(): number[] {
    const list: number[] = [];
    if (this.stats !== undefined) {
      for (const w of this.stats.top_wrong) { list.push(w.count); }
    }
    return list;
  }
  private examLabels(): string[] {
    const list: string[] = [];
    if (this.stats !== undefined) {
      for (const e of this.stats.exams) { list.push(e.title); }
    }
    return list;
  }
  private examRecords(): number[] {
    const list: number[] = [];
    if (this.stats !== undefined) {
      for (const e of this.stats.exams) { list.push(e.records); }
    }
    return list;
  }
  build() {
    Column() {
      PageHeader({
        title: '学情统计',
        onBack: (): void => { this.getUIContext().getRouter().back(); },
        right: (): void => { this.refreshEntry() }
      })
      if (this.loading) {
        Column({ space: 14 }) {
          Column().width('100%').height(220).borderRadius(Theme.R_LG).backgroundColor(Theme.INPUT_BG)
          Column().width('100%').height(120).borderRadius(Theme.R_LG).backgroundColor(Theme.INPUT_BG)
        }.padding(20)
      } else if (this.stats === undefined) {
        EmptyState({ icon: '📊', text: this.message.length > 0 ? this.message : '暂无统计数据' })
      } else {
        Scroll() {
          Column({ space: 14 }) {
            // 手机：两图上下排列；平板/大屏：左右并排
            if (this.bp === 'sm') {
              Column({ space: 8 }) {
                ScoreRingChart({ score: this.totalScore, total: this.maxScore, label: '平均分' })
              }
              .width('100%')
              .padding(12)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
              .alignItems(HorizontalAlign.Center)
              Column({ space: 8 }) {
                RadarChart({ labels: this.radarLabels, values: this.radarValues })
              }
              .width('100%')
              .padding(12)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
              .alignItems(HorizontalAlign.Center)
            } else {
              Row({ space: 12 }) {
                Column({ space: 8 }) {
                  ScoreRingChart({ score: this.totalScore, total: this.maxScore, label: '平均分' })
                }
                .layoutWeight(1).padding(12)
                .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
                .shadow(Theme.SHADOW_CARD)
                .alignItems(HorizontalAlign.Center)
                Column({ space: 8 }) {
                  RadarChart({ labels: this.radarLabels, values: this.radarValues })
                }
                .layoutWeight(1).padding(12)
                .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
                .shadow(Theme.SHADOW_CARD)
                .alignItems(HorizontalAlign.Center)
              }.width('100%')
            }
            this.SectionTitle('📚', '课程概览')
            GridRow({ gutter: { x: 12, y: 10 } }) {
              ForEach(this.stats.courses, (course: CourseStat) => {
                GridCol({ span: { sm: 12, md: 6 } }) {
                  Row({ space: 12 }) {
                    Column({ space: 2 }) {
                      Text(course.title).fontSize(Theme.F_BODY)
                        .fontWeight(FontWeight.Medium).fontColor(Theme.TEXT).maxLines(1)
                      Text(`${course.teacher}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    Column({ space: 2 }) {
                      Text(`${course.student_count}`).fontSize(16)
                        .fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
                      Text('学生').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    }
                    Column({ space: 2 }) {
                      Text(`${course.exam_count}`).fontSize(16)
                        .fontWeight(FontWeight.Bold).fontColor(Theme.SUCCESS)
                      Text('考试').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    }
                  }
                  .width('100%').padding(12)
                  .backgroundColor(Theme.CARD).borderRadius(Theme.R_MD)
                  .shadow(Theme.SHADOW_CARD)
                }
              }, (course: CourseStat) => course.title)
            }
            // ═══ 图表：各课程选课人数柱状图 ═══
            Card() {
              Column({ space: 14 }) {
                Row({ space: 8 }) {
                  Text('👥').fontSize(15)
                  Text('各课程选课人数').fontSize(15).fontWeight(FontWeight.Bold)
                    .fontColor(Theme.TEXT)
                }.width('100%')
                BarChart({
                  labels: this.courseLabels(),
                  values: this.courseStudents(),
                  unit: ' 人'
                })
              }.width('100%')
            }
            // ═══ 图表：高频错题次数柱状图 ═══
            if (this.stats.top_wrong.length > 0) {
              Card() {
                Column({ space: 14 }) {
                  Row({ space: 8 }) {
                    Text('📉').fontSize(15)
                    Text('高频错题次数').fontSize(15).fontWeight(FontWeight.Bold)
                      .fontColor(Theme.TEXT)
                  }.width('100%')
                  BarChart({
                    labels: this.wrongLabels(),
                    values: this.wrongCounts(),
                    unit: ' 次',
                    colors: ['', '', '', Theme.WARNING, Theme.DANGER],
                    chartHeight: 2000  // 需求 7：条目多时不裁切重叠
                  })
                }.width('100%')
              }
            }
            // ═══ 图表：考试参与人数柱状图 ═══
            if (this.stats.exams.length > 0) {
              Card() {
                Column({ space: 14 }) {
                  Row({ space: 8 }) {
                    Text('📝').fontSize(15)
                    Text('考试参与人数').fontSize(15).fontWeight(FontWeight.Bold)
                      .fontColor(Theme.TEXT)
                  }.width('100%')
                  BarChart({
                    labels: this.examLabels(),
                    values: this.examRecords(),
                    unit: ' 人',
                    colors: ['#00C9A7', '#7C4DFF']
                  })
                }.width('100%')
              }
            }
            this.SectionTitle('🔥', '高频错题 TOP')
            if (this.stats.top_wrong.length === 0) {
              Card() {
                Text('太棒了，暂无高频错题！').fontSize(Theme.F_SUB)
                  .fontColor(Theme.SUCCESS).width('100%').textAlign(TextAlign.Center)
              }
            } else {
              ForEach(this.stats.top_wrong, (item: WrongStat, index: number) => {
                Row({ space: 10 }) {
                  Text(`#${index + 1}`)
                    .fontSize(Theme.F_CAP).fontWeight(FontWeight.Bold)
                    .fontColor(index < 3 ? Theme.DANGER : Theme.TEXT_HINT)
                    .width(28)
                  Text(item.text).fontSize(Theme.F_SUB).fontColor(Theme.TEXT)
                    .layoutWeight(1).maxLines(2)
                  Text(`${item.count} 次`)
                    .fontSize(Theme.F_CAP).fontWeight(FontWeight.Bold)
                    .fontColor(Theme.DANGER)
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .backgroundColor(Theme.DANGER_LIGHT).borderRadius(8)
                }
                .width('100%').padding(12)
                .backgroundColor(Theme.CARD).borderRadius(Theme.R_MD)
                .shadow(Theme.SHADOW_CARD)
              }, (item: WrongStat, index: number) => String(index))
            }
            this.SectionTitle('📝', '考试记录')
            if (this.stats.exams.length === 0) {
              Card() {
                Text('暂无考试记录').fontSize(Theme.F_SUB)
                  .fontColor(Theme.TEXT_HINT).width('100%').textAlign(TextAlign.Center)
              }
            } else {
              ForEach(this.stats.exams, (exam: ExamStat) => {
                Row({ space: 12 }) {
                  Text('📝').fontSize(16)
                    .width(36).height(36).textAlign(TextAlign.Center)
                    .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_SM)
                  Column({ space: 2 }) {
                    Text(exam.title).fontSize(Theme.F_BODY).fontColor(Theme.TEXT)
                      .maxLines(1)
                    Text(`${exam.records} 人参考${exam.graded ? ' · 已判分' : ''}`)
                      .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  // 真实平均分（归一化百分制；未判分考试显示「未判分」）
                  if (exam.avg_score !== undefined && exam.avg_score !== null) {
                    Column({ space: 2 }) {
                      Text(`${exam.avg_score}`)
                        .fontSize(16).fontWeight(FontWeight.Bold)
                        .fontColor(exam.avg_score >= 60 ? Theme.SUCCESS : Theme.DANGER)
                      Text('平均分').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    }
                  } else {
                    Text('未判分').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  }
                }
                .width('100%').padding(12)
                .backgroundColor(Theme.CARD).borderRadius(Theme.R_MD)
                .shadow(Theme.SHADOW_CARD)
              }, (exam: ExamStat) => exam.title)
            }
          }.padding(20)
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
  @Builder SectionTitle(icon: string, title: string) {
    Row({ space: 8 }) {
      Text(icon).fontSize(15)
      Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
    }.width('100%').margin({ top: 6 })
  }
}
