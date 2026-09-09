import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { SkillTagItem } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, Card, EmptyState, SkeletonCard } from '../components/UiKit';

@Entry
@Component
struct SkillTagManage {
  @State rows: SkillTagItem[] = [];
  @State name: string = '';
  @State category: string = '';
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    try { this.rows = await api.getSkillTags(); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }

  private async add(): Promise<void> {
    if (this.name.length === 0) { this.message = '请输入标签名'; return; }
    try {
      await api.addSkillTag(this.name, this.category);
      this.name = '';
      this.category = '';
      this.rows = await api.getSkillTags();
      this.message = '✓ 标签已添加';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '添加失败';
    }
  }

  private async remove(id: number): Promise<void> {
    try {
      await api.deleteSkillTag(id);
      this.rows = await api.getSkillTags();
      this.message = '✓ 已删除';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '删除失败';
    }
  }

  build() {
    Column() {
      PageHeader({ title: '技能标签字典', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          Card() {
            Column({ space: 12 }) {
              Text('新增标签').fontSize(16).fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT).width('100%')
              Row({ space: 8 }) {
                TextInput({ placeholder: '标签名', text: this.name })
                  .onChange((v: string): void => { this.name = v; })
                  .layoutWeight(1).height(44).fontSize(14)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
                TextInput({ placeholder: '分类', text: this.category })
                  .onChange((v: string): void => { this.category = v; })
                  .width(100).height(44).fontSize(14)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
              }.width('100%')
              Button('＋ 新增标签')
                .width('100%').height(44).fontSize(14).fontWeight(FontWeight.Medium)
                .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                .fontColor(Color.White).borderRadius(Theme.R_MD)
                .onClick((): void => { this.add(); })
            }.width('100%')
          }
          Text(`标签云（${this.rows.length}）`).fontSize(16).fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT).width('100%')
          if (this.loading) {
            SkeletonCard()
          } else if (this.rows.length === 0) {
            EmptyState({ icon: '🏷', text: '暂无标签' })
          } else {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.rows, (tag: SkillTagItem) => {
                Row({ space: 8 }) {
                  Column({ space: 1 }) {
                    Text(tag.name).fontSize(Theme.F_SUB).fontWeight(FontWeight.Medium)
                      .fontColor(Theme.TEXT)
                    if (tag.category !== null && tag.category !== undefined) {
                      Text(tag.category).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    }
                  }.alignItems(HorizontalAlign.Center)
                  Text('×').fontSize(14).fontColor(Theme.DANGER).fontWeight(FontWeight.Bold)
                    .onClick((): void => { this.remove(tag.id); })
                }
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .backgroundColor(Theme.CARD).borderRadius(20)
                .shadow(Theme.SHADOW_CARD)
                .margin({ right: 8, bottom: 8 })
              }, (tag: SkillTagItem) => String(tag.id))
            }.width('100%')
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
