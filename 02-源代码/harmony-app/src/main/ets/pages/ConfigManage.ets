import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { ConfigItem } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, Card, EmptyState, SkeletonCard } from '../components/UiKit';

@Entry
@Component
struct ConfigManage {
  @State rows: ConfigItem[] = [];
  @State cfgKey: string = '';
  @State cfgValue: string = '';
  @State remark: string = '';
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    try { this.rows = await api.getConfigs(); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }

  private async save(): Promise<void> {
    if (this.cfgKey.length === 0 || this.cfgValue.length === 0) {
      this.message = '请填写配置键与值';
      return;
    }
    try {
      await api.upsertConfig(this.cfgKey, this.cfgValue, this.remark);
      this.cfgKey = '';
      this.cfgValue = '';
      this.remark = '';
      this.rows = await api.getConfigs();
      this.message = '✓ 配置已保存';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '保存失败';
    }
  }

  build() {
    Column() {
      PageHeader({ title: '系统配置', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          Card() {
            Column({ space: 12 }) {
              Text('新增 / 更新配置').fontSize(16).fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT).width('100%')
              this.Field('配置键（如 ai_enabled）', this.cfgKey,
                (v: string): void => { this.cfgKey = v; })
              this.Field('配置值', this.cfgValue,
                (v: string): void => { this.cfgValue = v; })
              this.Field('备注（可选）', this.remark,
                (v: string): void => { this.remark = v; })
              Button('💾 保存配置')
                .width('100%').height(44).fontSize(14).fontWeight(FontWeight.Medium)
                .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                .fontColor(Color.White).borderRadius(Theme.R_MD)
                .onClick((): void => { this.save(); })
            }.width('100%')
          }
          Text(`当前配置（${this.rows.length}）`).fontSize(16).fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT).width('100%')
          if (this.loading) {
            SkeletonCard(); SkeletonCard()
          } else if (this.rows.length === 0) {
            EmptyState({ icon: '🔧', text: '暂无配置项' })
          } else {
            GridRow({ gutter: { x: 12, y: 10 } }) {
              ForEach(this.rows, (config: ConfigItem) => {
                GridCol({ span: { sm: 12, md: 6 } }) {
                  Row({ space: 12 }) {
                    Column({ space: 3 }) {
                      Text(config.cfg_key).fontSize(Theme.F_BODY)
                        .fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).maxLines(1)
                      if (config.remark !== null && config.remark !== undefined
                        && config.remark.length > 0) {
                        Text(config.remark).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).maxLines(1)
                      }
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    Text(config.cfg_value).fontSize(Theme.F_SUB).fontWeight(FontWeight.Bold)
                      .fontColor(Theme.PRIMARY)
                      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                      .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(8)
                      .maxLines(1)
                  }
                  .width('100%').padding(12)
                  .backgroundColor(Theme.CARD).borderRadius(Theme.R_MD)
                  .shadow(Theme.SHADOW_CARD)
                }
              }, (config: ConfigItem) => config.cfg_key)
            }
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

  @Builder Field(placeholder: string, value: string, onChange: (v: string) => void) {
    TextInput({ placeholder: placeholder, text: value })
      .onChange((v: string): void => { onChange(v); })
      .width('100%').height(44).fontSize(14)
      .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
      .caretColor(Theme.PRIMARY)
  }
}
