import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Profile, WrongQuestion } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, Card } from '../components/UiKit';
import { RadarChart } from '../components/RadarChart';
import { DonutChart } from '../components/DonutChart';
import { BarChart } from '../components/BarChart';
import { ScoreRingChart } from '../components/ScoreRingChart';

interface SkillEntry { name: string; value: number; }

/**
 * 能力画像独立页（需求 1）：雷达图 + 综合得分环 + 技能分布环形 + 技能条形图 + 错题维度。
 * 数据源：profile（skill_scores/radar_data）+ 错题本（题型分布）。
 */
@Entry
@Component
struct AbilityProfile {
  @State loading: boolean = true;
  @State profile: Profile | null = null;
  @State wrongs: WrongQuestion[] = [];
  @State message: string = '';
  @State barAnim: number = 0;
  @State floatY: number = 0;

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    try {
      this.profile = await api.getProfile();
      this.wrongs = await api.getWrongQuestions();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
    animateTo({ duration: 900, curve: Curve.Friction }, (): void => { this.barAnim = 1; });
  }

  /** 技能条目（score 0-100）。 */
  private entries(): SkillEntry[] {
    const out: SkillEntry[] = [];
    const p: Profile | null = this.profile;
    if (p !== null && p.skill_scores !== undefined) {
      Object.keys(p.skill_scores).forEach((key: string): void => {
        out.push({ name: key, value: p.skill_scores[key] });
      });
    }
    return out.sort((a: SkillEntry, b: SkillEntry): number => b.value - a.value);
  }

  private radarLabels(): string[] {
    return this.entries().map((e: SkillEntry): string => e.name);
  }
  private radarValues(): number[] {
    return this.entries().map((e: SkillEntry): number => Math.round(e.value));
  }

  /** 综合能力分：技能均值。 */
  private overall(): number {
    const list: SkillEntry[] = this.entries();
    if (list.length === 0) { return 0; }
    let sum: number = 0;
    list.forEach((e: SkillEntry): void => { sum += e.value; });
    return Math.round(sum / list.length);
  }

  /** 技能分层：优势(≥70)/待提升(40-70)/薄弱(<40)。 */
  private tierOf(v: number): string {
    return v >= 70 ? '优势' : v >= 40 ? '待提升' : '薄弱';
  }
  private tierCount(tier: string): number {
    return this.entries().filter((e: SkillEntry): boolean => this.tierOf(e.value) === tier).length;
  }
  private tierColor(tier: string): string {
    return tier === '优势' ? Theme.SUCCESS : tier === '待提升' ? Theme.WARNING : Theme.DANGER;
  }

  /** 错题题型分布。 */
  private wrongByType(): string[] {
    const counter: Record<string, number> = {};
    this.wrongs.forEach((w: WrongQuestion): void => {
      const t: string = w.question_type ?? '其他';
      counter[t] = (counter[t] ?? 0) + Math.max(1, w.wrong_count);
    });
    return Object.keys(counter).sort((a: string, b: string): number => counter[b] - counter[a]);
  }
  private wrongValues(): number[] {
    const counter: Record<string, number> = {};
    this.wrongs.forEach((w: WrongQuestion): void => {
      const t: string = w.question_type ?? '其他';
      counter[t] = (counter[t] ?? 0) + Math.max(1, w.wrong_count);
    });
    return this.wrongByType().map((t: string): number => counter[t]);
  }

  build() {
    Column() {
      PageHeader({ title: '能力画像', onBack: (): void => { router.back(); } })
      if (this.loading) {
        Column({ space: 14 }) {
          SkeletonCard()
          SkeletonCard()
          SkeletonCard()
        }.padding(20)
      } else if (this.profile === null) {
        Column() {
          EmptyState({ icon: '📊', text: this.message.length > 0 ? this.message : '暂无画像数据' })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 16 }) {
            // ── 顶部综合分 ─────────────────────────
            Row({ space: 18 }) {
              ScoreRingChart({ score: this.overall(), total: 100, label: '综合能力', chartSize: 130 })
              Column({ space: 6 }) {
                Text('能力综合评估').fontSize(18).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                Text('基于考试得分、错题分布与知识点掌握度综合计算，随学习记录持续更新。')
                  .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND).lineHeight(18)
                Row({ space: 8 }) {
                  ForEach(['优势', '待提升', '薄弱'], (tier: string) => {
                    Row({ space: 4 }) {
                      Circle({ width: 8, height: 8 }).fill(this.tierColor(tier))
                      Text(`${tier} ${this.tierCount(tier)}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
                    }
                  }, (tier: string) => tier)
                }.margin({ top: 4 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }
            .width('100%').padding(20)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_XL)
            .shadow(Theme.SHADOW_CARD)

            // ── 雷达图 ─────────────────────────
            Card() {
              Column({ space: 10 }) {
                Text('技能雷达').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
                if (this.radarValues().length >= 3) {
                  RadarChart({ labels: this.radarLabels(), values: this.radarValues() })
                    .width('100%').height(260)
                } else {
                  Text('技能维度不足，完成更多章节测验后生成').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    .padding({ top: 30, bottom: 30 })
                }
              }.padding(18).width('100%')
            }

            // ── 技能条（动画生长）─────────────────
            Card() {
              Column({ space: 12 }) {
                Text('技能掌握度').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
                ForEach(this.entries(), (e: SkillEntry) => {
                  Column({ space: 6 }) {
                    Row() {
                      Text(e.name).fontSize(Theme.F_SUB).fontColor(Theme.TEXT).layoutWeight(1)
                      Text(this.tierOf(e.value)).fontSize(Theme.F_CAP)
                        .fontColor(this.tierColor(this.tierOf(e.value)))
                      Text(`${Math.round(e.value * this.barAnim)}`).fontSize(Theme.F_SUB)
                        .fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width(34).textAlign(TextAlign.End)
                    }.width('100%')
                    Progress({ value: e.value * this.barAnim, total: 100, type: ProgressType.Linear })
                      .width('100%').style({ strokeWidth: 8 })
                      .color(this.tierColor(this.tierOf(e.value)))
                      .borderRadius(4)
                  }
                }, (e: SkillEntry) => e.name)
              }.padding(18).width('100%')
            }

            // ── 分布环形 ─────────────────────────
            Card() {
              Column({ space: 10 }) {
                Text('技能分层占比').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
                DonutChart({
                  labels: ['优势', '待提升', '薄弱'],
                  values: [this.tierCount('优势'), this.tierCount('待提升'), this.tierCount('薄弱')],
                  colors: [Theme.SUCCESS, Theme.WARNING, Theme.DANGER],
                  centerLabel: '技能项',
                }).width('100%').height(230)
              }.padding(18).width('100%')
            }

            // ── 错题题型分布 ─────────────────────
            Card() {
              Column({ space: 10 }) {
                Text('错题题型分布').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).width('100%')
                if (this.wrongValues().length > 0) {
                  BarChart({
                    labels: this.wrongByType(),
                    values: this.wrongValues(),
                    unit: '题',
                    chartHeight: 200,
                  }).width('100%')
                } else {
                  EmptyState({ icon: '🎉', text: '暂无错题记录，继续保持！' })
                }
              }.padding(18).width('100%')
            }

            // ── 画像说明 ─────────────────────────
            Card() {
              Column({ space: 8 }) {
                Row({ space: 8 }) {
                  Text('ℹ️').fontSize(16)
                  Text('画像说明').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                }.width('100%')
                Text('· 综合能力 = 各技能维度均值；\n· 技能值由对应知识点的测验正确率加权计算；\n· 完成章节随堂测验与考试后自动更新；\n· 深浅色模式下图表自动适配配色。')
                  .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND).lineHeight(20)
              }.padding(18).width('100%')
            }
          }.padding(20).padding({ bottom: 30 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
