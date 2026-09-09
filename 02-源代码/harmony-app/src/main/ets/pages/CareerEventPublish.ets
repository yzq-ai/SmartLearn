import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Theme } from '../common/Theme';
import { PageHeader, PrimaryButton, TagChip } from '../components/UiKit';

class EventPayload {
  title: string = '';
  event_type: string = 'TALK';
  description: string = '';
  location: string = '';
  start_time: string = '';
  end_time: string = '';
  company_id?: number;
}

@Entry
@Component
struct CareerEventPublish {
  @State title: string = '';
  @State eventType: string = 'TALK';
  @State companyId: number = 0;
  @State description: string = '';
  @State location: string = '';
  @State startTime: string = '';
  @State endTime: string = '';
  @State saving: boolean = false;
  @State message: string = '';

  private async publish(): Promise<void> {
    this.message = '';
    if (this.title.length === 0) { this.message = '请填写活动标题'; return; }
    if (this.startTime.length === 0 || this.endTime.length === 0) { this.message = '请填写起止时间'; return; }
    const start: Date = new Date(this.startTime);
    const end: Date = new Date(this.endTime);
    if (isNaN(start.getTime()) || isNaN(end.getTime())) { this.message = '时间格式有误，示例：2026-09-20 14:00'; return; }
    if (end.getTime() <= start.getTime()) { this.message = '结束时间必须晚于开始时间'; return; }
    this.saving = true;
    try {
      const payload: EventPayload = {
        title: this.title,
        event_type: this.eventType,
        description: this.description,
        location: this.location,
        start_time: this.startTime.replace(' ', 'T'),
        end_time: this.endTime.replace(' ', 'T'),
      };
      if (this.companyId > 0) { payload.company_id = this.companyId; }
      const r = await api.createCareerEvent(JSON.parse(JSON.stringify(payload)) as Record<string, object>);
      const rObj: Record<string, Object> = r as Record<string, Object>;
      const newId: string = rObj['id'] !== undefined ? String(rObj['id']) : '';
      this.message = `✓ 活动已发布${newId.length > 0 ? `（ID ${newId}）` : ''}，学生端即可浏览报名`;
      this.title = '';
      this.description = '';
      this.location = '';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '发布失败';
    }
    this.saving = false;
  }

  build() {
    Column() {
      PageHeader({ title: '发布招聘活动', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 14 }) {
          // 活动类型
          Column({ space: 8 }) {
            Text('活动类型').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
            Row({ space: 8 }) {
              this.TypeChip('🎤 宣讲会', 'TALK')
              this.TypeChip('🎪 双选会', 'FAIR')
              this.TypeChip('🧑‍💻 实习实践', 'INTERNSHIP')
            }.width('100%')
          }.alignItems(HorizontalAlign.Start).width('100%')

          this.Field('活动标题', this.title, '例：智云科技 2026 秋招宣讲会', (v: string): void => { this.title = v; })
          this.Field('主办企业 ID（可选）', this.companyId > 0 ? String(this.companyId) : '', '留空则不关联企业', (v: string): void => { this.companyId = Number(v) || 0; })
          this.Field('地点', this.location, '例：大学生活动中心 B201', (v: string): void => { this.location = v; })
          this.Field('开始时间', this.startTime, '2026-09-20 14:00', (v: string): void => { this.startTime = v; })
          this.Field('结束时间', this.endTime, '2026-09-20 16:00', (v: string): void => { this.endTime = v; })

          Column({ space: 6 }) {
            Text('活动介绍').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
            TextArea({ placeholder: '面向对象、议程安排、岗位方向等…', text: this.description })
              .onChange((v: string): void => { this.description = v; })
              .width('100%').height(90).fontSize(14)
              .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_SM)
              .caretColor(Theme.PRIMARY)
          }.alignItems(HorizontalAlign.Start).width('100%')

          if (this.message.length > 0) {
            Text(this.message).fontSize(Theme.F_SUB)
              .fontColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
              .width('100%').textAlign(TextAlign.Center)
              .padding(10)
              .backgroundColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS_LIGHT : Theme.DANGER_LIGHT)
              .borderRadius(Theme.R_SM)
          }

          PrimaryButton({ label: '🎪 发布活动', loading: this.saving, onTap: (): void => { this.publish(); } })
          Text('提示：活动将即时对学生端可见，内容经敏感词过滤校验。')
            .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%').textAlign(TextAlign.Center)
        }
        .padding(20).constraintSize({ maxWidth: 640 }).width('100%')
      }.layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }

  @Builder TypeChip(label: string, value: string) {
    Row({ space: 6 }) {
      Radio({ value: value, group: 'eventType' })
        .checked(this.eventType === value)
        .onChange((on: boolean): void => { if (on) { this.eventType = value; } })
        .width(18).height(18)
      Text(label).fontSize(Theme.F_SUB)
        .fontColor(this.eventType === value ? Theme.PRIMARY : Theme.TEXT_SECOND)
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(this.eventType === value ? Theme.PRIMARY_LIGHT : Theme.INPUT_BG)
    .borderRadius(Theme.R_MD)
  }

  @Builder Field(label: string, value: string, placeholder: string, onChange: (v: string) => void) {
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
