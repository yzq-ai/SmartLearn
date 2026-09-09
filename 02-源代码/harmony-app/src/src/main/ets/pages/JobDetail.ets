import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Job } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, Card, TagChip } from '../components/UiKit';
import { RadarChart } from '../components/RadarChart';
interface JobDetailParams { jobId?: number | string; }
@Entry
@Component
struct JobDetail {
  @State job: Job | null = null;
  @State message: string = '';
  @State loading: boolean = true;
  @State skillLabels: string[] = [];
  @State skillValues: number[] = [];
  @State aiExplaining: boolean = false;
  @State aiExplanation: string = '';
  @State aiSuggestions: string[] = [];
  @State aiSource: string = '';
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    const raw: Object | null = router.getParams();
    if (raw === null || raw === undefined) { this.message = '缺少参数'; this.loading = false; return; }
    const params: JobDetailParams = raw as JobDetailParams;
    const value: number | string | undefined = params.jobId;
    const id: number = typeof value === 'number' ? value
      : (typeof value === 'string' ? Number(value) : 0);
    if (!Number.isFinite(id) || id <= 0) {
      this.message = '缺少岗位编号'; this.loading = false; return;
    }
    try {
      this.job = await api.getJobDetail(id);
      this.buildSkillRadar();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }
  private buildSkillRadar(): void {
    if (this.job === null) return;
    const allTags: string[] = [];
    const allValues: number[] = [];
    const matched: string[] = this.job!.matched_tags;
    const gaps: string[] = this.job!.gap_tags;
    const scores: Record<string, number> | undefined = this.job!.skill_scores;
    // 优先后端真值（归一后的个人掌握分）；缺省退化为匹配 85 / 缺口 40 基线
    for (let i: number = 0; i < matched.length && i < 6; i += 1) {
      const v: number | undefined = scores !== undefined ? scores[matched[i]] : undefined;
      allTags.push(matched[i]);
      allValues.push(v !== undefined ? v : 85);
    }
    for (let i: number = 0; i < gaps.length && allTags.length < 6; i += 1) {
      const v: number | undefined = scores !== undefined ? scores[gaps[i]] : undefined;
      allTags.push(gaps[i]);
      allValues.push(v !== undefined ? v : 40);
    }
    if (allTags.length < 3) {
      while (allTags.length < 3) { allTags.push('综合'); allValues.push(60); }
    }
    this.skillLabels = allTags;
    this.skillValues = allValues;
  }
  private async apply(): Promise<void> {
    if (this.job === null) return;
    try {
      await api.applyJob(this.job.id);
      this.job = await api.getJobDetail(this.job.id);
      this.message = '✓ 投递成功，等待企业查看';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '投递失败';
    }
  }
  private async favorite(): Promise<void> {
    if (this.job === null) return;
    try {
      await api.favoriteJob(this.job.id);
      this.job = await api.getJobDetail(this.job.id);
      this.message = this.job.is_favorite ? '✓ 已收藏' : '已取消收藏';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '收藏失败';
    }
  }
  private async runAiExplain(): Promise<void> {
    if (this.job === null || this.aiExplaining) return;
    this.aiExplaining = true;
    this.aiExplanation = '';
    this.aiSuggestions = [];
    this.aiSource = '';
    try {
      // 传岗位 id：后端取真实 JD、技能权重与学生画像，调用真实 AI 分析
      const r = await api.aiJobExplainById(this.job.id, this.job.title, this.job.match_score, this.job.matched_tags, this.job.gap_tags);
      this.aiExplanation = r.explanation;
      this.aiSuggestions = r.suggestions;
      this.aiSource = r.source ?? 'rules';
    } catch (error) {
      this.message = error instanceof Error ? error.message : 'AI 解析失败';
    }
    this.aiExplaining = false;
  }
  build() {
    Column() {
      PageHeader({ title: '岗位详情', onBack: (): void => { router.back(); } })
      if (this.loading) {
        Column({ space: 14 }) {
          Column().width('100%').height(130).borderRadius(Theme.R_LG).backgroundColor(Theme.INPUT_BG)
          Column().width('100%').height(200).borderRadius(Theme.R_LG).backgroundColor(Theme.INPUT_BG)
        }.padding(20).layoutWeight(1)
      } else if (this.job === null) {
        Column() {
          Text('😕').fontSize(52)
          Text(this.message).fontSize(Theme.F_SUB).fontColor(Theme.DANGER).margin({ top: 12 })
        }.layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else {
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 12 }) {
              Row({ space: 14 }) {
                Column() {
                  Text('💼').fontSize(26)
                }
                .width(56).height(56).borderRadius(Theme.R_MD)
                .backgroundColor('rgba(255,255,255,0.18)')
                .alignItems(HorizontalAlign.Center)
                Column({ space: 4 }) {
                  Text(this.job.title).fontSize(21).fontWeight(FontWeight.Bold)
                    .fontColor(Color.White).maxLines(2)
                  Text(this.job.company).fontSize(Theme.F_SUB)
                    .fontColor('rgba(255,255,255,0.8)')
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              }.width('100%')
              Column({ space: 6 }) {
                Row() {
                  Text('能力匹配度').fontSize(Theme.F_CAP).fontColor('rgba(255,255,255,0.8)')
                  Blank()
                  Text(`${this.job.match_score}%`).fontSize(16)
                    .fontWeight(FontWeight.Bold).fontColor(Color.White)
                }.width('100%')
                Progress({ value: this.job.match_score, total: 100, type: ProgressType.Linear })
                  .width('100%').color(Color.White).style({ strokeWidth: 6 })
              }.width('100%')
            }
            .width('100%').padding(22)
            .linearGradient({ angle: 145, colors: [[Theme.PRIMARY_DEEP, 0], [Theme.PRIMARY_GRADIENT, 1]] })
            .borderRadius(Theme.R_XL)
            .shadow(Theme.SHADOW_FLOAT)
            Card() {
              Column({ space: 10 }) {
                Text('能力画像').fontSize(16).fontWeight(FontWeight.Bold)
                  .fontColor(Theme.TEXT).width('100%')
                RadarChart({ labels: this.skillLabels, values: this.skillValues })
              }.width('100%').alignItems(HorizontalAlign.Center)
            }
            Card() {
              Column({ space: 8 }) {
                Row({ space: 8 }) {
                  Text('📄').fontSize(16)
                  Text('岗位描述').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                }.width('100%')
                Text(this.job.description).fontSize(Theme.F_BODY)
                  .fontColor(Theme.TEXT_SECOND).width('100%').lineHeight(24)
              }.width('100%')
            }
            Card() {
              Column({ space: 12 }) {
                Text('技能匹配分析').fontSize(15).fontWeight(FontWeight.Bold)
                  .fontColor(Theme.TEXT).width('100%')
                if (this.job.matched_tags.length > 0) {
                  Text('✓ 已具备技能').fontSize(Theme.F_CAP).fontColor(Theme.SUCCESS).width('100%')
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.job.matched_tags, (tag: string) => {
                      Text(tag).fontSize(Theme.F_CAP).fontColor(Theme.SUCCESS)
                        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                        .backgroundColor(Theme.SUCCESS_LIGHT).borderRadius(14)
                        .margin({ right: 8, bottom: 8 })
                    })
                  }.width('100%')
                }
                if (this.job.gap_tags.length > 0) {
                  Text('↑ 待提升技能').fontSize(Theme.F_CAP).fontColor(Theme.WARNING).width('100%')
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.job.gap_tags, (tag: string) => {
                      Text(tag).fontSize(Theme.F_CAP).fontColor(Theme.WARNING)
                        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                        .backgroundColor(Theme.WARNING_LIGHT).borderRadius(14)
                        .margin({ right: 8, bottom: 8 })
                    })
                  }.width('100%')
                }
              }.width('100%')
            }
            Card() {
              Column({ space: 12 }) {
                Row({ space: 8 }) {
                  Text('🤖').fontSize(16)
                  Text('AI 匹配解析').fontSize(15).fontWeight(FontWeight.Bold)
                    .fontColor(Theme.TEXT).layoutWeight(1)
                  if (this.aiSource.length > 0) {
                    Text(this.aiSource === 'llm' ? '真实 AI' : '规则引擎')
                      .fontSize(Theme.F_CAP)
                      .fontColor(this.aiSource === 'llm' ? Theme.SUCCESS : Theme.TEXT_HINT)
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                      .backgroundColor(this.aiSource === 'llm' ? Theme.SUCCESS_LIGHT : Theme.BG)
                      .borderRadius(10)
                  }
                }.width('100%')
                if (this.aiExplanation.length === 0) {
                  Text('结合你的真实技能画像与本岗位 JD，AI 解释为什么推荐这个岗位，并给出补强建议。')
                    .fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).width('100%')
                  Button(this.aiExplaining ? 'AI 分析中…' : '🤖 生成 AI 匹配解析')
                    .width('100%').height(44).fontSize(14).fontWeight(FontWeight.Bold)
                    .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                    .fontColor(Color.White).borderRadius(Theme.R_MD)
                    .enabled(!this.aiExplaining)
                    .opacity(this.aiExplaining ? 0.6 : 1)
                    .onClick(() => { this.runAiExplain(); })
                } else {
                  Text(this.aiExplanation).fontSize(Theme.F_BODY)
                    .fontColor(Theme.TEXT).width('100%').lineHeight(24)
                  if (this.aiSuggestions.length > 0) {
                    Text('行动建议').fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                      .fontWeight(FontWeight.Bold).width('100%')
                    Column({ space: 8 }) {
                      ForEach(this.aiSuggestions, (tip: string, idx: number) => {
                        Row({ space: 8 }) {
                          Text(`${idx + 1}`).fontSize(12).fontWeight(FontWeight.Bold)
                            .fontColor(Color.White).width(22).height(22)
                            .textAlign(TextAlign.Center).backgroundColor(Theme.PRIMARY).borderRadius(11)
                          Text(tip).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
                            .layoutWeight(1)
                        }.width('100%').alignItems(VerticalAlign.Top)
                      }, (tip: string) => tip)
                    }.width('100%')
                  }
                  Button('换一个角度再分析')
                    .width('100%').height(38).fontSize(13)
                    .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
                    .borderRadius(Theme.R_MD)
                    .enabled(!this.aiExplaining)
                    .onClick(() => { this.runAiExplain(); })
                }
              }.width('100%')
            }
            Row({ space: 10 }) {
              Button(this.job.is_favorite ? '★ 已收藏' : '☆ 收藏')
                .layoutWeight(1).height(48).fontSize(14)
                .backgroundColor(this.job.is_favorite ? Theme.WARNING_LIGHT : Theme.CARD)
                .fontColor(this.job.is_favorite ? Theme.WARNING : Theme.TEXT)
                .borderRadius(Theme.R_MD)
                .shadow(Theme.SHADOW_CARD)
                .onClick((): void => { this.favorite(); })
              Button(this.job.application_status !== null ? '✓ 已投递' : '🚀 立即投递')
                .layoutWeight(2).height(48).fontSize(15).fontWeight(FontWeight.Bold)
                .linearGradient({
                  angle: 135,
                  colors: this.job.application_status !== null
                    ? [[Theme.SUCCESS, 0], ['#3ECF8E', 1]]
                    : [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]]
                })
                .fontColor(Color.White)
                .borderRadius(Theme.R_MD)
                .enabled(this.job.application_status === null)
                .opacity(this.job.application_status === null ? 1 : 0.8)
                .onClick((): void => { this.apply(); })
            }.width('100%')
            if (this.message.length > 0) {
              Text(this.message).fontSize(Theme.F_SUB)
                .fontColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
                .width('100%').textAlign(TextAlign.Center)
                .margin({ bottom: 24 })
            }
          }.padding(20)
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
