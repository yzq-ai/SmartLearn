import { router } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { api } from '../common/ApiClient';
import { Resume, ResumeContent, ResumeOptimizeResult, ResumeSuggestion } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, Card, PrimaryButton, TagChip, EmptyState, SkeletonCard } from '../components/UiKit';
@Entry
@Component
struct ResumeEdit {
  @State rows: Resume[] = [];
  @State title: string = '我的简历';
  @State name: string = '';
  @State education: string = '';
  @State skills: string = '';
  @State projects: string = '';
  @State selfEval: string = '';
  @State loading: boolean = true;
  @State message: string = '';
  @State saving: boolean = false;
  // AI 优化
  @State targetRole: string = '';
  @State optimizing: boolean = false;
  @State suggestions: ResumeSuggestion[] = [];
  @State aiSource: string = '';
  @State decided: Record<string, string> = {};
  // 版本详情就地展开
  @State viewResumeId: number = 0;
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    this.loading = true;
    this.message = '';
    try {
      this.rows = await api.getResumes();
      const latest: Resume | null = this.rows.length > 0 ? this.rows[0] : null;
      if (latest !== null && latest.content !== undefined) {
        this.name = latest.content.name ?? '';
        this.education = latest.content.education ?? '';
        this.skills = latest.content.skills ?? '';
        this.projects = latest.content.projects ?? '';
        this.selfEval = latest.content.self_eval ?? '';
      }
    }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }
  private completeness(): number {
    const fields: string[] = [this.name, this.education, this.skills, this.projects, this.selfEval];
    let filled: number = 0;
    fields.forEach((f: string): void => { if (f.trim().length > 0) { filled += 1; } });
    return Math.round(filled / fields.length * 100);
  }
  private resumeText(): string {
    const lines: string[] = [];
    if (this.name.trim().length > 0) { lines.push(`姓名：${this.name}`); }
    if (this.education.trim().length > 0) { lines.push(`教育：${this.education}`); }
    if (this.skills.trim().length > 0) { lines.push(`技能：${this.skills}`); }
    if (this.projects.trim().length > 0) { lines.push(`项目：${this.projects}`); }
    if (this.selfEval.trim().length > 0) { lines.push(`自评：${this.selfEval}`); }
    return lines.join('\n');
  }
  private async runOptimize(): Promise<void> {
    if (this.resumeText().length === 0) { this.message = '请先填写简历内容'; return; }
    this.optimizing = true;
    this.message = '';
    this.suggestions = [];
    this.decided = {};
    try {
      const result: ResumeOptimizeResult = await api.optimizeResume(this.resumeText(), this.targetRole);
      this.suggestions = result.items;
      this.aiSource = result.source;
      if (this.suggestions.length === 0) { this.message = 'AI 未产生有效建议'; }
    } catch (error) {
      this.message = error instanceof Error ? error.message : 'AI 优化失败';
    }
    this.optimizing = false;
  }
  private typeLabel(t: string): string {
    if (t === 'impact' || t === '量化成果') { return '量化成果'; }
    if (t === 'keyword' || t === '关键词补齐') { return '关键词补齐'; }
    return '表达优化';
  }
  private adopt(s: ResumeSuggestion): void {
    // 将建议稿回填到对应区块（按 original 前缀定位）
    if (s.original.startsWith('姓名')) { this.name = s.suggestion.replace(/^姓名[:：]?/, '').trim(); }
    else if (s.original.startsWith('教育')) { this.education = s.suggestion.replace(/^教育[:：]?/, '').trim(); }
    else if (s.original.startsWith('技能')) { this.skills = s.suggestion.replace(/^技能[:：]?/, '').trim(); }
    else if (s.original.startsWith('项目')) { this.projects = s.suggestion.replace(/^项目[:：]?/, '').trim(); }
    else if (s.original.startsWith('自评')) { this.selfEval = s.suggestion.replace(/^自评[:：]?/, '').trim(); }
    this.decided[s.original] = 'adopted';
  }
  private dismiss(s: ResumeSuggestion): void { this.decided[s.original] = 'dismissed'; }
  private adoptedCount(): number {
    let n = 0;
    for (const k of Object.keys(this.decided)) { if (this.decided[k] === 'adopted') { n++; } }
    return n;
  }
  private async save(): Promise<void> {
    if (this.name.length === 0) { this.message = '请填写姓名'; return; }
    this.saving = true;
    this.message = '';
    const content: ResumeContent = {
      name: this.name, education: this.education, skills: this.skills,
      projects: this.projects, self_eval: this.selfEval,
    };
    try {
      await api.createResume(this.title, content);
      this.rows = await api.getResumes();
      this.message = '✓ 简历已保存';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '保存失败';
    }
    this.saving = false;
  }
  @State pdfBusy: boolean = false;
  @Builder DetailField(label: string, body: string) {
    Column({ space: 4 }) {
      Text(label).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
      Text(body).fontSize(Theme.F_SUB).fontColor(Theme.TEXT).width('100%')
        .padding(10).backgroundColor(Theme.CARD).borderRadius(Theme.R_SM)
    }.alignItems(HorizontalAlign.Start).width('100%')
  }
  private async exportPdf(r: Resume): Promise<void> {
    if (this.pdfBusy) { return; }
    this.pdfBusy = true;
    this.message = '正在生成 PDF…';
    try {
      const safe: string = (r.title.replace(/[\\/:*?"<>|\s]+/g, '_') || 'resume').substring(0, 40);
      const fileName: string = `${safe}_v${r.version}.pdf`;
      const path: string = await api.downloadResumePdf(r.id, fileName);
      this.message = `✓ PDF 已保存：${fileName}`;
      try {
        // 尝试拉起文件应用预览（失败不阻塞提示）
        const context: object | undefined = AppStorage.get<Object>('context');
        if (context !== undefined) {
          (context as common.UIAbilityContext).startAbility({
            bundleName: 'com.huawei.hmos.fileapp.myfiles',
            parameters: { 'path': path }
          } as Want);
        }
      } catch (_e) { /* 预览失败不视为导出失败 */ }
    } catch (error) {
      this.message = error instanceof Error ? error.message : 'PDF 导出失败';
    }
    this.pdfBusy = false;
  }
  build() {
    Column() {
      PageHeader({ title: '简历编辑', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 10 }) {
            Row() {
              Text('简历完成度').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
              Blank()
              Text(`${this.completeness()}%`).fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.completeness() >= 80 ? Theme.SUCCESS
                  : this.completeness() >= 40 ? Theme.WARNING : Theme.DANGER)
            }.width('100%')
            Progress({ value: this.completeness(), total: 100, type: ProgressType.Linear })
              .width('100%')
              .color(this.completeness() >= 80 ? Theme.SUCCESS
                : this.completeness() >= 40 ? Theme.WARNING : Theme.DANGER)
              .style({ strokeWidth: 6 })
            Text('完成度越高，岗位匹配推荐越精准').fontSize(Theme.F_CAP)
              .fontColor(Theme.TEXT_HINT).width('100%')
          }
          .width('100%').padding(Theme.CARD_PAD)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)
          Card() {
            Column({ space: 14 }) {
              Row({ space: 8 }) {
                Text('📝').fontSize(16)
                Text('基本信息').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                Blank()
                TagChip({ text: `${this.rows.length} 个版本` })
              }.width('100%')
              this.FormField('姓名', '请输入姓名', this.name,
                (v: string): void => { this.name = v; })
              this.FormField('教育经历', '如：XX大学 计算机科学与技术 本科', this.education,
                (v: string): void => { this.education = v; })
              Column({ space: 6 }) {
                Text('技能标签（逗号分隔）').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                TextInput({ placeholder: '如：Python,MySQL,FastAPI', text: this.skills })
                  .onChange((v: string): void => { this.skills = v; })
                  .width('100%').height(46).fontSize(14)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                  .caretColor(Theme.PRIMARY)
                if (this.skills.length > 0) {
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.skills.split(','), (s: string) => {
                      if (s.trim().length > 0) {
                        Text(s.trim()).fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                          .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(10)
                          .margin({ right: 6, bottom: 4 })
                      }
                    })
                  }.width('100%')
                }
              }.width('100%')
              Column({ space: 6 }) {
                Text('项目经历').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                TextArea({ placeholder: '项目名称、职责、成果…', text: this.projects })
                  .onChange((v: string): void => { this.projects = v; })
                  .width('100%').height(100).fontSize(14)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                  .caretColor(Theme.PRIMARY)
              }.width('100%')
              Column({ space: 6 }) {
                Text('自我评价').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                TextArea({ placeholder: '展示你的优势与学习热情…', text: this.selfEval })
                  .onChange((v: string): void => { this.selfEval = v; })
                  .width('100%').height(100).fontSize(14)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                  .caretColor(Theme.PRIMARY)
              }.width('100%')
            }.width('100%')
          }
          // ═══ AI 优化入口 ═══
          Card() {
            Column({ space: 12 }) {
              Row({ space: 8 }) {
                Text('✨').fontSize(16)
                Text('AI 简历优化').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                Blank()
                if (this.aiSource.length > 0) {
                  TagChip({ text: this.aiSource === 'llm' ? 'LLM' : '规则引擎', tone: 'primary' })
                }
              }.width('100%')
              Text('AI 逐条给出优化建议，采纳后才写入表单，绝不自动覆盖原文')
                .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
              TextInput({ placeholder: '目标岗位（选填，如：后端开发工程师）', text: this.targetRole })
                .onChange((v: string): void => { this.targetRole = v; })
                .width('100%').height(46).fontSize(14)
                .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                .caretColor(Theme.PRIMARY)
              Button(this.optimizing ? 'AI 分析中…' : '✨ 开始 AI 优化')
                .height(44).fontSize(15).width('100%')
                .linearGradient({ angle: 135, colors: [['#7C4DFF', 0], [Theme.PRIMARY, 1]] })
                .fontColor(Color.White)
                .enabled(!this.optimizing)
                .onClick((): void => { this.runOptimize(); })
              // 操作反馈就地显示（不渲染在页面底部让用户错过）
              if (this.message.length > 0 && this.suggestions.length === 0) {
                Text(this.message).fontSize(Theme.F_SUB)
                  .fontColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
                  .width('100%').textAlign(TextAlign.Center)
              }
            }.width('100%')
          }
          // ═══ 优化建议 Diff 列表（逐条采纳/忽略）═══
          if (this.suggestions.length > 0) {
            Column({ space: 10 }) {
              Row({ space: 8 }) {
                Text('📋').fontSize(15)
                Text(`优化建议 ${this.suggestions.length} 条`).fontSize(15)
                  .fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                Blank()
                Text(`已采纳 ${this.adoptedCount()} 条`).fontSize(Theme.F_CAP).fontColor(Theme.SUCCESS)
              }.width('100%')
              ForEach(this.suggestions, (s: ResumeSuggestion) => {
                Column({ space: 8 }) {
                  Row({ space: 6 }) {
                    TagChip({ text: this.typeLabel(s.type), tone: 'primary' })
                    Blank()
                    if (this.decided[s.original] === 'adopted') {
                      Text('✓ 已采纳').fontSize(Theme.F_CAP).fontColor(Theme.SUCCESS)
                    } else if (this.decided[s.original] === 'dismissed') {
                      Text('已忽略').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    }
                  }.width('100%')
                  // 原文（删除线风格）
                  Row({ space: 6 }) {
                    Text('原').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                      .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                      .backgroundColor(Theme.INPUT_BG).borderRadius(4)
                    Text(s.original).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT)
                      .decoration({ type: TextDecorationType.LineThrough })
                      .layoutWeight(1).maxLines(2)
                  }.width('100%')
                  // 建议稿
                  Row({ space: 6 }) {
                    Text('优').fontSize(Theme.F_CAP).fontColor(Color.White)
                      .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                      .backgroundColor(Theme.SUCCESS).borderRadius(4)
                    Text(s.suggestion).fontSize(Theme.F_SUB).fontColor(Theme.TEXT)
                      .layoutWeight(1).maxLines(3)
                  }.width('100%')
                  // 理由
                  Row({ space: 6 }) {
                    Text('💡').fontSize(11)
                    Text(s.reason).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_SECOND)
                      .layoutWeight(1).maxLines(2)
                  }.width('100%')
                  if (this.decided[s.original] === undefined) {
                    Row({ space: 10 }) {
                      Button('✓ 采纳').height(32).fontSize(13).layoutWeight(1)
                        .linearGradient({ angle: 135, colors: [[Theme.SUCCESS, 0], ['#3ECF8E', 1]] })
                        .fontColor(Color.White)
                        .onClick((): void => { this.adopt(s); })
                      Button('忽略').height(32).fontSize(13).layoutWeight(1)
                        .backgroundColor(Theme.INPUT_BG).fontColor(Theme.TEXT_SECOND)
                        .onClick((): void => { this.dismiss(s); })
                    }.width('100%')
                  }
                }
                .width('100%').padding(12)
                .backgroundColor(Theme.CARD).borderRadius(Theme.R_MD)
                .shadow(Theme.SHADOW_CARD)
                .opacity(this.decided[s.original] === 'dismissed' ? 0.5 : 1)
              }, (s: ResumeSuggestion) => `${s.original}-${this.decided[s.original] ?? ''}`)
            }.width('100%')
          }
          PrimaryButton({
            label: '💾 保存简历', loading: this.saving,
            onTap: (): void => { this.save(); }
          })
          Text('历史版本').fontSize(16).fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT).width('100%')
          if (this.rows.length === 0) {
            Text('暂无历史版本').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT).padding(8)
          } else {
            ForEach(this.rows, (r: Resume) => {
              Column({ space: 10 }) {
                Row({ space: 10 }) {
                  Text('📄').fontSize(18)
                    .width(40).height(40).textAlign(TextAlign.Center)
                    .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_SM)
                  Column({ space: 2 }) {
                    Text(r.title).fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium)
                      .fontColor(Theme.TEXT)
                    Text(this.viewResumeId === r.id ? '收起详情 ▴' : `版本 v${r.version} · 点击查看详情 ▾`)
                      .fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  if (r.is_default === 1) {
                    TagChip({ text: '默认', tone: 'success' })
                  }
                }
                .width('100%')
                .onClick((): void => {
                  this.viewResumeId = this.viewResumeId === r.id ? 0 : r.id;
                })
                // ═══ 就地展开的版本详情 ═══
                if (this.viewResumeId === r.id) {
                  Column({ space: 10 }) {
                    Row({ space: 8 }) {
                      Text(`版本 v${r.version}`).fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(8)
                      if (r.is_default === 1) {
                        Text('默认简历').fontSize(Theme.F_CAP).fontColor(Theme.SUCCESS)
                          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                          .backgroundColor(Theme.SUCCESS_LIGHT).borderRadius(8)
                      }
                      Blank()
                      Text(`#${r.id}`).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    }.width('100%')
                    this.DetailField('👤 姓名', r.content.name ?? '（未填写）')
                    this.DetailField('🎓 教育背景', r.content.education ?? '（未填写）')
                    this.DetailField('🛠 专业技能', r.content.skills ?? '（未填写）')
                    this.DetailField('💼 项目经历', r.content.projects ?? '（未填写）')
                    this.DetailField('💬 自我评价', r.content.self_eval ?? '（未填写）')
                  }
                  .width('100%').padding(12)
                  .backgroundColor(Theme.BG).borderRadius(Theme.R_MD)
                }
              }
              .width('100%').padding(12)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_MD)
              .shadow(Theme.SHADOW_CARD)
              Button(`📥 导出 PDF`).height(32).fontSize(13)
                .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
                .borderRadius(Theme.R_SM)
                .margin({ top: 8, bottom: 12 })
                .onClick((): void => { this.exportPdf(r); })
            }, (r: Resume) => `row-${r.id}`)
          }
          if (this.message.length > 0) {
            Text(this.message).fontSize(Theme.F_SUB)
              .fontColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
              .width('100%').textAlign(TextAlign.Center)
              .margin({ bottom: 24 })
          }
        }.padding(20)
        .constraintSize({ maxWidth: 640 })
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
  @Builder FormField(label: string, placeholder: string, value: string, onChange: (v: string) => void) {
    Column({ space: 6 }) {
      Text(label).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
      TextInput({ placeholder: placeholder, text: value })
        .onChange((v: string): void => { onChange(v); })
        .width('100%').height(46).fontSize(14)
        .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
        .caretColor(Theme.PRIMARY)
    }.width('100%')
  }
}
