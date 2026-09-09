import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { QuestionItem } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, Card, PrimaryButton, TagChip } from '../components/UiKit';
interface QuestionEditParams { questionId?: number | string; }
@Entry
@Component
struct QuestionEdit {
  @State qid: number = 0;
  @State qtype: string = 'SINGLE';
  @State content: string = '';
  @State answer: string = '';
  @State optionsText: string = '';
  @State analysis: string = '';
  @State difficulty: number = 3;
  @State score: number = 5;
  @State loading: boolean = true;
  @State message: string = '';
  // 详情/编辑双模式：先看详情，点「编辑」解锁表单
  @State editMode: boolean = false;
  @State savedMsg: string = '';
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    const raw: Object | null = router.getParams();
    if (raw === null || raw === undefined) { this.message = '缺少题目编号'; this.loading = false; return; }
    const params: QuestionEditParams = raw as QuestionEditParams;
    const value: number | string | undefined = params.questionId;
    const id: number = typeof value === 'number' ? value
      : (typeof value === 'string' ? Number(value) : 0);
    if (!Number.isFinite(id) || id <= 0) {
      this.message = '缺少题目编号'; this.loading = false; return;
    }
    this.qid = id;
    try {
      const q: QuestionItem = await api.getQuestion(id);
      this.qtype = q.type;
      this.content = q.content;
      this.answer = q.answer;
      const rawOptions: string[] | null = q.options ?? [];
      this.optionsText = rawOptions !== null ? rawOptions.join(',') : '';
      this.analysis = q.analysis;
      this.difficulty = q.difficulty;
      this.score = q.score;
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }
  private async save(): Promise<void> {
    if (this.content.length === 0 || this.answer.length === 0) {
      this.message = '请填写题干与答案';
      return;
    }
    const options: string[] = this.optionsText.length > 0 ? this.optionsText.split(',') : [];
    try {
      await api.updateQuestion(this.qid, this.qtype, this.content, this.answer,
        options, this.difficulty, this.score);
      this.savedMsg = '✓ 已保存';
      // 保存后回到详情态
      this.editMode = false;
      this.message = '';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '保存失败';
    }
  }
  private optionLetters(): string[] { return ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']; }
  private splitOptions(): string[] {
    if (this.optionsText.length === 0) { return []; }
    return this.optionsText.split(',');
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
      PageHeader({
        title: this.editMode ? '编辑题目' : '题目详情',
        onBack: (): void => { router.back(); }
      })
      if (this.loading) {
        Column({ space: 12 }) {
          Column().width('100%').height(80).borderRadius(Theme.R_LG).backgroundColor(Theme.INPUT_BG)
          Column().width('100%').height(160).borderRadius(Theme.R_LG).backgroundColor(Theme.INPUT_BG)
        }.padding(20)
      } else {
        Scroll() {
          Column({ space: 14 }) {
            // ═══ 详情模式 ═══
            if (!this.editMode) {
              // 题干卡片
              Card() {
                Column({ space: 12 }) {
                  Row({ space: 8 }) {
                    TagChip({ text: this.typeLabel(this.qtype) })
                    Text(`难度 ${'★'.repeat(this.difficulty)}${'☆'.repeat(5 - this.difficulty)}`)
                      .fontSize(Theme.F_CAP).fontColor(Theme.WARNING)
                    Blank()
                    Text(`${this.score} 分`).fontSize(Theme.F_SUB).fontWeight(FontWeight.Bold)
                      .fontColor(Theme.PRIMARY)
                  }.width('100%')
                  Text(this.content).fontSize(17)
                    .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.TEXT).width('100%').lineHeight(26)
                }.width('100%')
              }
              // 选项卡片
              if (this.qtype === 'SINGLE' || this.qtype === 'MULTI') {
                Card() {
                  Column({ space: 10 }) {
                    Text('选项').fontSize(16).fontWeight(FontWeight.Bold)
                      .fontColor(Theme.TEXT).width('100%')
                    ForEach(this.splitOptions(), (opt: string, idx: number) => {
                      Row({ space: 12 }) {
                        Text(this.optionLetters()[idx] ?? '-')
                          .fontSize(Theme.F_SUB).fontWeight(FontWeight.Bold)
                          .fontColor(Color.White)
                          .width(28).height(28).borderRadius(14)
                          .backgroundColor(Theme.PRIMARY)
                          .textAlign(TextAlign.Center)
                        Text(opt).fontSize(Theme.F_BODY).fontColor(Theme.TEXT)
                          .layoutWeight(1)
                        if (this.answer.indexOf(this.optionLetters()[idx] ?? '-') >= 0
                          || this.answer === opt) {
                          Text('✓ 正确答案').fontSize(Theme.F_CAP).fontColor(Theme.SUCCESS)
                        }
                      }
                      .width('100%').padding({ left: 8, right: 8, top: 6, bottom: 6 })
                      .borderRadius(Theme.R_SM)
                    }, (opt: string, idx: number) => `${idx}-${opt}`)
                  }.width('100%')
                }
              }
              // 答案卡片
              Card() {
                Column({ space: 10 }) {
                  Text('参考答案').fontSize(16).fontWeight(FontWeight.Bold)
                    .fontColor(Theme.TEXT).width('100%')
                  Text(this.answer).fontSize(16)
                    .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.SUCCESS).width('100%')
                    .padding(12).backgroundColor(Theme.SUCCESS_LIGHT)
                    .borderRadius(Theme.R_SM)
                  if (this.analysis !== null && this.analysis !== undefined
                    && this.analysis.length > 0) {
                    Divider().color(Theme.DIVIDER).margin({ top: 4, bottom: 4 })
                    Text('解析').fontSize(Theme.F_SUB).fontWeight(FontWeight.Bold)
                      .fontColor(Theme.TEXT).width('100%')
                    Text(this.analysis).fontSize(Theme.F_BODY)
                      .fontColor(Theme.TEXT_SECOND).width('100%').lineHeight(22)
                  }
                }.width('100%')
              }
              // 操作按钮：编辑 / 返回
              Row({ space: 10 }) {
                Button('‹ 返回题库').height(48).fontSize(15).layoutWeight(1)
                  .backgroundColor(Theme.INPUT_BG).fontColor(Theme.TEXT_SECOND)
                  .borderRadius(16)
                  .onClick((): void => { router.back(); })
                Button('✏️ 编辑本题').height(48).fontSize(15).layoutWeight(2)
                  .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                  .fontColor(Color.White)
                  .shadow(Theme.SHADOW_FLOAT)
                  .borderRadius(16)
                  .onClick((): void => {
                    animateTo({ duration: 250, curve: Curve.EaseOut }, () => { this.editMode = true; });
                  })
              }.width('100%')
              if (this.savedMsg.length > 0) {
                Text(this.savedMsg).fontSize(Theme.F_SUB).fontColor(Theme.SUCCESS)
                  .width('100%').textAlign(TextAlign.Center)
              }
            } else {
              // ═══ 编辑模式 ═══
              Card() {
                Column({ space: 12 }) {
                  Text('题型').fontSize(16).fontWeight(FontWeight.Bold)
                    .fontColor(Theme.TEXT).width('100%')
                  Flex({ wrap: FlexWrap.Wrap }) {
                    this.TypeChip('单选', 'SINGLE')
                    this.TypeChip('多选', 'MULTI')
                    this.TypeChip('判断', 'JUDGE')
                    this.TypeChip('填空', 'BLANK')
                    this.TypeChip('简答', 'SHORT')
                  }.width('100%')
                }.width('100%')
              }
              Card() {
                Column({ space: 12 }) {
                  Text('题目内容').fontSize(16).fontWeight(FontWeight.Bold)
                    .fontColor(Theme.TEXT).width('100%')
                  TextArea({ placeholder: '输入题干…', text: this.content })
                    .onChange((v: string): void => { this.content = v; })
                    .width('100%').height(100).fontSize(14)
                    .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                    .caretColor(Theme.PRIMARY)
                  TextInput({ placeholder: '答案', text: this.answer })
                    .onChange((v: string): void => { this.answer = v; })
                    .width('100%').height(46).fontSize(14)
                    .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                    .caretColor(Theme.PRIMARY)
                  if (this.qtype === 'SINGLE' || this.qtype === 'MULTI') {
                    TextInput({ placeholder: '选项（逗号分隔，如：A,B,C,D）', text: this.optionsText })
                      .onChange((v: string): void => { this.optionsText = v; })
                      .width('100%').height(46).fontSize(13)
                      .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                      .caretColor(Theme.PRIMARY)
                  }
                }.width('100%')
              }
              Card() {
                Column({ space: 14 }) {
                  Text('属性设置').fontSize(16).fontWeight(FontWeight.Bold)
                    .fontColor(Theme.TEXT).width('100%')
                  Column({ space: 8 }) {
                    Row() {
                      Text('难度').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                      Blank()
                      Text(`${this.difficulty} / 5`).fontSize(Theme.F_SUB)
                        .fontWeight(FontWeight.Bold).fontColor(Theme.WARNING)
                    }.width('100%')
                    Row({ space: 8 }) {
                      ForEach([1, 2, 3, 4, 5], (d: number) => {
                        Text(d <= this.difficulty ? '★' : '☆')
                          .fontSize(26)
                          .fontColor(d <= this.difficulty ? Theme.WARNING : Theme.DIVIDER)
                          .onClick((): void => { this.difficulty = d; })
                      })
                    }.width('100%').justifyContent(FlexAlign.Center)
                  }.width('100%')
                  Row({ space: 8 }) {
                    Text('分值').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    this.ScoreChip(2)
                    this.ScoreChip(5)
                    this.ScoreChip(10)
                    this.ScoreChip(20)
                    Blank()
                    Text(`当前 ${this.score} 分`).fontSize(Theme.F_SUB)
                      .fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
                  }.width('100%')
                }.width('100%')
              }
              Row({ space: 10 }) {
                Button('取消').height(48).fontSize(15).layoutWeight(1)
                  .backgroundColor(Theme.INPUT_BG).fontColor(Theme.TEXT_SECOND)
                  .borderRadius(16)
                  .onClick((): void => {
                    animateTo({ duration: 250, curve: Curve.EaseOut }, () => { this.editMode = false; });
                  })
                PrimaryButton({
                  label: '💾 保存修改',
                  onTap: (): void => { this.save(); }
                })
              }.width('100%')
              if (this.message.length > 0) {
                Text(this.message).fontSize(Theme.F_SUB)
                  .fontColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
                  .width('100%').textAlign(TextAlign.Center)
              }
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
  @Builder TypeChip(label: string, value: string) {
    Text(label)
      .fontSize(Theme.F_SUB)
      .fontColor(this.qtype === value ? Color.White : Theme.TEXT_SECOND)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor(this.qtype === value ? Theme.PRIMARY : Theme.BG)
      .borderRadius(16)
      .margin({ right: 8, bottom: 8 })
      .onClick((): void => { this.qtype = value; })
  }
  @Builder ScoreChip(v: number) {
    Text(`${v}`)
      .fontSize(Theme.F_SUB).fontWeight(FontWeight.Bold)
      .fontColor(this.score === v ? Color.White : Theme.TEXT_SECOND)
      .width(40).height(32).textAlign(TextAlign.Center)
      .backgroundColor(this.score === v ? Theme.PRIMARY : Theme.BG)
      .borderRadius(10)
      .onClick((): void => { this.score = v; })
  }
}
