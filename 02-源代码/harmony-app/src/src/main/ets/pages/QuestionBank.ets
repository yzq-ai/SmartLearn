import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { QuestionItem } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, TagChip, PrimaryButton } from '../components/UiKit';
@Entry
@Component
struct QuestionBank {
  @State rows: QuestionItem[] = [];
  @State total: number = 0;
  @State page: number = 1;
  @State pages: number = 1;
  @State loading: boolean = true;
  @State message: string = '';
  @State generating: boolean = false;
  @State keyword: string = '';
  @State qtype: string = 'SINGLE';
  @State content: string = '';
  @State answer: string = '';
  @State difficulty: number = 3;
  @State filter: string = 'ALL';
  private static readonly PAGE_SIZE: number = 20;
  aboutToAppear(): void { this.load(1); }
  private async load(page: number): Promise<void> {
    this.loading = true;
    this.message = '';
    try {
      const result = await api.getQuestionsPaged(page, QuestionBank.PAGE_SIZE, this.keyword);
      this.rows = result.items;
      this.total = result.total;
      this.pages = Math.max(1, result.pages);
      this.page = page;
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }
  private async aiGenerate(): Promise<void> {
    if (this.generating) return;
    this.generating = true;
    this.message = '';
    try {
      await api.aiGenerateQuestions(['Python 基础'], this.qtype, 2);
      await this.load(1);
      this.message = '✓ AI 草稿已生成，请采纳或丢弃';
    } catch (error) {
      this.message = error instanceof Error ? error.message : 'AI 出题失败';
    }
    this.generating = false;
  }
  private async createManual(): Promise<void> {
    if (this.content.length === 0 || this.answer.length === 0) {
      this.message = '请填写题干与答案';
      return;
    }
    try {
      await api.createQuestion(this.qtype, this.content, this.answer, [], this.difficulty, 5);
      this.content = '';
      this.answer = '';
      await this.load(1);
      this.message = '✓ 题目已创建';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '创建失败';
    }
  }
  private async approve(id: number): Promise<void> {
    try {
      await api.approveDraft(id);
      await this.load(this.page);
      this.message = '✓ 草稿已采纳';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '采纳失败';
    }
  }
  private async discard(id: number): Promise<void> {
    try {
      await api.discardDraft(id);
      await this.load(this.page);
      this.message = '✓ 草稿已丢弃';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '丢弃失败';
    }
  }
  private filtered(): QuestionItem[] {
    if (this.filter === 'DRAFT') return this.rows.filter((r): boolean => r.status === 'DRAFT');
    if (this.filter === 'PUBLISHED') return this.rows.filter((r): boolean => r.status === 'PUBLISHED');
    return this.rows;
  }
  private typeLabel(t: string): string {
    if (t === 'SINGLE') return '单选';
    if (t === 'MULTI') return '多选';
    if (t === 'JUDGE') return '判断';
    if (t === 'BLANK') return '填空';
    if (t === 'SHORT') return '简答';
    return t;
  }
  build() {
    Column() {
      PageHeader({ title: '题库管理', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 12 }) {
            Text('快速新增').fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT).width('100%')
            Row({ space: 6 }) {
              this.TypeChip('单选', 'SINGLE')
              this.TypeChip('多选', 'MULTI')
              this.TypeChip('判断', 'JUDGE')
              this.TypeChip('填空', 'BLANK')
              this.TypeChip('简答', 'SHORT')
            }.width('100%')
            Row({ space: 8 }) {
              TextInput({ placeholder: '题干', text: this.content })
                .onChange((v: string): void => { this.content = v; })
                .layoutWeight(1).height(42).fontSize(13)
                .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                .caretColor(Theme.PRIMARY)
              TextInput({ placeholder: '答案', text: this.answer })
                .onChange((v: string): void => { this.answer = v; })
                .width(90).height(42).fontSize(13)
                .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                .caretColor(Theme.PRIMARY)
            }.width('100%')
            Row({ space: 10 }) {
              Button('＋ 手动新增').height(40).fontSize(13).layoutWeight(1)
                .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
                .onClick((): void => { this.createManual(); })
              PrimaryButton({
                label: '🤖 AI 出题×2', loading: this.generating,
                onTap: (): void => { this.aiGenerate(); }
              })
            }.width('100%')
            .alignItems(VerticalAlign.Center)
          }
          .width('100%').padding(Theme.CARD_PAD)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)
          // 搜索 + 筛选
          Row({ space: 8 }) {
            TextInput({ placeholder: '🔍 搜索题干关键词', text: this.keyword })
              .onChange((v: string): void => { this.keyword = v; })
              .layoutWeight(1).height(38).fontSize(13)
              .backgroundColor(Theme.INPUT_BG).borderRadius(19)
              .caretColor(Theme.PRIMARY)
              .onSubmit((): void => { this.load(1); })
            Button('搜索').height(38).fontSize(13)
              .backgroundColor(Theme.PRIMARY).fontColor(Color.White).borderRadius(19)
              .onClick((): void => { this.load(1); })
          }.width('100%')
          Row({ space: 8 }) {
            this.FilterChip('全部', 'ALL')
            this.FilterChip('已发布', 'PUBLISHED')
            this.FilterChip('草稿', 'DRAFT')
            Blank()
            Text(`共 ${this.total} 题 · 第 ${this.page}/${this.pages} 页`)
              .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
          }.width('100%')
          if (this.loading) {
            SkeletonCard(); SkeletonCard(); SkeletonCard()
          } else if (this.rows.length === 0) {
            EmptyState({ icon: '❓', text: this.keyword.length > 0 ? `未搜到「${this.keyword}」相关题目` : '题库为空，快添加第一题' })
          } else {
            GridRow({ gutter: { x: 12, y: 12 } }) {
              ForEach(this.filtered(), (q: QuestionItem) => {
                GridCol({ span: { sm: 12, md: 6, lg: 4 } }) {
                  Column({ space: 8 }) {
                    Row({ space: 8 }) {
                      TagChip({ text: this.typeLabel(q.type) })
                      Text(`难度 ${'★'.repeat(q.difficulty)}${'☆'.repeat(5 - q.difficulty)}`)
                        .fontSize(Theme.F_CAP).fontColor(Theme.WARNING)
                      Blank()
                      if (q.status === 'DRAFT') {
                        TagChip({ text: '草稿', tone: 'warning' })
                      }
                      Text(`${q.score} 分`).fontSize(Theme.F_CAP)
                        .fontColor(Theme.TEXT_HINT)
                    }.width('100%')
                    Text(q.content).fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium)
                      .fontColor(Theme.TEXT).width('100%').maxLines(3)
                    Text(`答案：${q.answer}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
                      .width('100%').maxLines(1)
                    if (q.status === 'DRAFT') {
                      Row({ space: 8 }) {
                        Button('✓ 采纳').height(32).fontSize(12).layoutWeight(1)
                          .linearGradient({ angle: 135, colors: [[Theme.SUCCESS, 0], ['#3ECF8E', 1]] })
                          .fontColor(Color.White)
                          .onClick((): void => { this.approve(q.id); })
                        Button('✕ 丢弃').height(32).fontSize(12).layoutWeight(1)
                          .backgroundColor(Theme.DANGER_LIGHT).fontColor(Theme.DANGER)
                          .onClick((): void => { this.discard(q.id); })
                      }.width('100%')
                    }
                    // 点击查看详情 / 编辑
                    Row({ space: 4 }) {
                      Text('查看详情与编辑').fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                      Text('›').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
                    }
                    .width('100%').justifyContent(FlexAlign.End)
                  }
                  .width('100%').padding(Theme.CARD_PAD)
                  .backgroundColor(q.status === 'DRAFT' ? Theme.WARNING_LIGHT : Theme.CARD)
                  .borderRadius(Theme.R_LG)
                  .shadow(Theme.SHADOW_CARD)
                  // 整卡可点：点击题目即可查看详情并编辑
                  .onClick((): void => {
                    router.pushUrl({ url: 'pages/QuestionEdit', params: { questionId: q.id } });
                  })
                }
              }, (q: QuestionItem) => String(q.id))
            }
            // 分页条
            if (this.pages > 1) {
              Row({ space: 10 }) {
                Button(this.page <= 1 ? '首页' : '‹ 上一页').height(36).fontSize(13)
                  .backgroundColor(Theme.CARD).fontColor(this.page <= 1 ? Theme.TEXT_HINT : Theme.PRIMARY)
                  .borderRadius(18)
                  .enabled(this.page > 1)
                  .onClick((): void => { this.load(this.page - 1); })
                Text(`${this.page} / ${this.pages}`).fontSize(Theme.F_SUB)
                  .fontColor(Theme.TEXT).padding({ left: 12, right: 12 })
                Button(this.page >= this.pages ? '末页' : '下一页 ›').height(36).fontSize(13)
                  .backgroundColor(Theme.CARD).fontColor(this.page >= this.pages ? Theme.TEXT_HINT : Theme.PRIMARY)
                  .borderRadius(18)
                  .enabled(this.page < this.pages)
                  .onClick((): void => { this.load(this.page + 1); })
              }
              .width('100%').justifyContent(FlexAlign.Center)
              .padding({ top: 8 })
            }
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
  @Builder TypeChip(label: string, value: string) {
    Text(label)
      .fontSize(Theme.F_CAP)
      .fontColor(this.qtype === value ? Color.White : Theme.TEXT_SECOND)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.qtype === value ? Theme.PRIMARY : Theme.BG)
      .borderRadius(14)
      .onClick((): void => { this.qtype = value; })
  }
  @Builder FilterChip(label: string, value: string) {
    Text(label)
      .fontSize(Theme.F_SUB)
      .fontColor(this.filter === value ? Color.White : Theme.TEXT_SECOND)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .backgroundColor(this.filter === value ? Theme.PRIMARY : Theme.CARD)
      .borderRadius(16)
      .onClick((): void => { this.filter = value; })
  }
}
