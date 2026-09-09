import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { WrongQuestion } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, TagChip } from '../components/UiKit';
import { gridLanes } from '../components/UiKit';
@Entry
@Component
struct WrongBook {
  @State rows: WrongQuestion[] = [];
  @State loading: boolean = true;
  @State message: string = '';
  @State filter: string = 'ALL';
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    this.loading = true;
    this.message = '';
    try { this.rows = await api.getWrongQuestions(); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }
  private filtered(): WrongQuestion[] {
    if (this.filter === 'UNMASTERED') return this.rows.filter((r): boolean => r.is_mastered !== 1);
    if (this.filter === 'MASTERED') return this.rows.filter((r): boolean => r.is_mastered === 1);
    return this.rows;
  }
  private async markMastered(id: number): Promise<void> {
    try {
      await api.markWrongMastered(id);
      this.rows = await api.getWrongQuestions();
      this.message = '✓ 已标记掌握';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '操作失败';
    }
  }
  private sourceLabel(source: string | null): string {
    if (source === 'EXAM') return '考试';
    if (source === 'PRACTICE') return '练习';
    return '学习';
  }
  @Builder practiceEntry() {
    Button('🔁 重练')
      .height(34).fontSize(13)
      .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
      .fontColor(Color.White)
      .onClick((): void => { router.pushUrl({ url: 'pages/WrongPractice' }); })
  }
  build() {
    Column() {
      PageHeader({
        title: '错题本',
        onBack: (): void => { router.back(); },
        right: (): void => { this.practiceEntry() }
      })
      Row({ space: 8 }) {
        this.FilterChip('全部', 'ALL')
        this.FilterChip('未掌握', 'UNMASTERED')
        this.FilterChip('已掌握', 'MASTERED')
        Blank()
        Text(`共 ${this.rows.length} 题`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 4, bottom: 8 })
      if (this.loading) {
        Column({ space: 12 }) { SkeletonCard(); SkeletonCard(); SkeletonCard() }.padding(20)
      } else if (this.rows.length === 0) {
        Column() {
          EmptyState({ icon: '🎉', text: '太棒了，没有错题！' })
        }.layoutWeight(1)
      } else {
        List({ space: 12 }) {
          ForEach(this.filtered(), (row: WrongQuestion) => {
            ListItem() {
              WrongItemView({ row: row, onAi: (): void => {
                router.pushUrl({
                  url: 'pages/WrongAnalysisPage',
                  params: {
                    question: row.question_text,
                    answer: row.my_answer ?? '',
                    correct: row.correct_answer
                  }
                });
              }, onMastered: (): void => { this.markMastered(row.id); } })
            }
          }, (row: WrongQuestion) => String(row.id))
        }
        .lanes({ minLength: 340, maxLength: 520 }, 12)
        .layoutWeight(1)
        .padding({ left: 20, right: 20, bottom: 20 })
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
  @Builder FilterChip(label: string, value: string) {
    Text(label)
      .fontSize(Theme.F_SUB)
      .fontColor(this.filter === value ? Color.White : Theme.TEXT_SECOND)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .backgroundColor(this.filter === value ? Theme.PRIMARY : Theme.CARD)
      .borderRadius(16)
      .shadow(this.filter === value ? Theme.SHADOW_FLOAT : { radius: 0, color: 'transparent', offsetX: 0, offsetY: 0 })
      .onClick((): void => { this.filter = value; })
  }
}

// ═════════ 错题卡片（stagger 入场 + 按压回弹）═════════
@Component
struct WrongItemView {
  @Prop row: WrongQuestion;
  onAi: () => void = () => {};
  onMastered: () => void = () => {};
  @State appeared: boolean = false;
  @State pressed: boolean = false;
  private sourceLabel(source: string | null): string {
    if (source === 'EXAM') return '考试';
    if (source === 'PRACTICE') return '练习';
    return '学习';
  }
  build() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        TagChip({ text: this.sourceLabel(this.row.source_type) })
        Text(`错 ${this.row.wrong_count} 次`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
        Blank()
        TagChip({
          text: this.row.is_mastered === 1 ? '✓ 已掌握' : '未掌握',
          tone: this.row.is_mastered === 1 ? 'success' : 'danger'
        })
      }.width('100%')
      Text(this.row.question_text).fontSize(Theme.F_BODY)
        .fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
        .width('100%').maxLines(3)
      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Text('你的答案').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
          Text(`${this.row.my_answer ?? '—'}`).fontSize(Theme.F_SUB)
            .fontColor(Theme.DANGER).fontWeight(FontWeight.Medium)
        }
        .layoutWeight(1).padding(8)
        .backgroundColor(Theme.DANGER_LIGHT).borderRadius(Theme.R_SM)
        Column({ space: 2 }) {
          Text('正确答案').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
          Text(this.row.correct_answer).fontSize(Theme.F_SUB)
            .fontColor(Theme.SUCCESS).fontWeight(FontWeight.Medium)
        }
        .layoutWeight(1).padding(8)
        .backgroundColor(Theme.SUCCESS_LIGHT).borderRadius(Theme.R_SM)
      }.width('100%')
      if (this.row.analysis !== null && this.row.analysis.length > 0) {
        Text(`📖 ${this.row.analysis}`).fontSize(Theme.F_CAP)
          .fontColor(Theme.TEXT_SECOND).width('100%').maxLines(2)
      }
      Row({ space: 10 }) {
        Button('🤖 AI 分析')
          .height(36).fontSize(13).layoutWeight(1)
          .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
          .fontColor(Color.White)
          .onClick((): void => { this.onAi(); })
        if (this.row.is_mastered !== 1) {
          Button('✓ 标记掌握')
            .height(36).fontSize(13).layoutWeight(1)
            .backgroundColor(Theme.SUCCESS_LIGHT).fontColor(Theme.SUCCESS)
            .onClick((): void => { this.onMastered(); })
        }
      }.width('100%')
    }
    .width('100%').padding(Theme.CARD_PAD)
    .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
    .shadow(Theme.SHADOW_CARD)
    .translate({ y: this.appeared ? 0 : 26 })
    .opacity(this.appeared ? 1 : 0)
    .scale({ x: this.pressed ? 0.97 : 1, y: this.pressed ? 0.97 : 1 })
    .animation({ duration: 240, curve: Curve.EaseOut })
    .onTouch((e: TouchEvent): void => {
      if (e.type === TouchType.Down) { this.pressed = true; }
      else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = false; }
    })
    .onAppear((): void => {
      animateTo({ duration: 380, curve: Curve.EaseOut, delay: Math.min(400, (this.row.id % 8) * 45) }, (): void => {
        this.appeared = true;
      });
    })
  }
}
