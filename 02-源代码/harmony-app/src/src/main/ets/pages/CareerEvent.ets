import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { CareerEventItem } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, TagChip } from '../components/UiKit';

@Entry
@Component
struct CareerEventPage {
  @State events: CareerEventItem[] = [];
  @State filter: string = 'ALL';
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    this.message = '';
    try { this.events = await api.getCareerEvents(); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }

  private async signup(e: CareerEventItem): Promise<void> {
    if (e.signed_up) return;
    try {
      const r = await api.signupCareerEvent(e.id);
      this.message = r.first_time ? `✓ 已报名「${e.title}」` : '已报名过该活动';
      this.events = await api.getCareerEvents();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '报名失败';
    }
  }

  private typeLabel(t: string): string {
    if (t === 'TALK') return '宣讲会';
    if (t === 'FAIR') return '双选会';
    if (t === 'INTERNSHIP') return '实习实践';
    return '招聘活动';
  }
  private typeIcon(t: string): string {
    if (t === 'TALK') return '🎤';
    if (t === 'FAIR') return '🎪';
    if (t === 'INTERNSHIP') return '🧑‍💻';
    return '📅';
  }
  private typeTone(t: string): string {
    if (t === 'TALK') return 'primary';
    if (t === 'FAIR') return 'warning';
    return 'success';
  }

  private filtered(): CareerEventItem[] {
    if (this.filter === 'ALL') return this.events;
    return this.events.filter((e): boolean => e.event_type === this.filter);
  }

  private fmtTime(iso: string): string {
    if (iso === null || iso === undefined || iso.length < 16) return '';
    return `${iso.substring(5, 10)} ${iso.substring(11, 16)}`;
  }

  build() {
    Column() {
      PageHeader({ title: '招聘活动', onBack: (): void => { router.back(); } })
      // 类型过滤
      Row({ space: 8 }) {
        this.FilterChip('全部', 'ALL')
        this.FilterChip('🎤 宣讲会', 'TALK')
        this.FilterChip('🎪 双选会', 'FAIR')
        this.FilterChip('🧑‍💻 实习实践', 'INTERNSHIP')
      }
      .width('100%').padding({ left: 20, right: 20, top: 4, bottom: 8 })

      if (this.loading) {
        Column({ space: 12 }) { SkeletonCard(); SkeletonCard(); SkeletonCard() }.padding(20)
      } else if (this.filtered().length === 0) {
        EmptyState({ icon: '🎪', text: '暂无招聘活动\n敬请期待宣讲会与双选会' })
      } else {
        List({ space: 12 }) {
          ForEach(this.filtered(), (e: CareerEventItem) => {
            ListItem() {
              Column({ space: 10 }) {
                Row({ space: 10 }) {
                  Text(this.typeIcon(e.event_type)).fontSize(22)
                    .width(46).height(46).textAlign(TextAlign.Center)
                    .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_MD)
                  Column({ space: 3 }) {
                    Text(e.title).fontSize(Theme.F_BODY).fontWeight(FontWeight.Bold)
                      .fontColor(Theme.TEXT).maxLines(1)
                    Text(`${e.company.length > 0 ? e.company + ' · ' : ''}${e.location ?? ''}`)
                      .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).maxLines(1)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  TagChip({ text: this.typeLabel(e.event_type), tone: this.typeTone(e.event_type) })
                }.width('100%')

                if (e.description !== null && e.description.length > 0) {
                  Text(e.description).fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
                    .width('100%').maxLines(2)
                }

                Row({ space: 10 }) {
                  Text(`🕐 ${this.fmtTime(e.start_time)} 开始`).fontSize(Theme.F_CAP)
                    .fontColor(e.is_ended ? Theme.TEXT_HINT : Theme.PRIMARY)
                    .fontWeight(FontWeight.Medium).layoutWeight(1)
                  Text(`${e.signup_count} 人报名`).fontSize(Theme.F_CAP)
                    .fontColor(Theme.TEXT_HINT)
                }.width('100%')

                Button(e.signed_up ? '✓ 已报名' : (e.is_ended ? '活动已结束' : '📢 立即报名'))
                  .width('100%').height(40).fontSize(13)
                  .backgroundColor(e.signed_up || e.is_ended ? Theme.INPUT_BG : Theme.PRIMARY)
                  .fontColor(e.signed_up || e.is_ended ? Theme.TEXT_HINT : Color.White)
                  .enabled(!e.signed_up && !e.is_ended)
                  .onClick((): void => { this.signup(e); })
              }
              .width('100%').padding(Theme.CARD_PAD)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }
          }, (e: CareerEventItem) => `${e.id}-${e.signed_up ? 1 : 0}-${e.signup_count}`)
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
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.filter === value ? Theme.PRIMARY : Theme.CARD)
      .borderRadius(16)
      .shadow(this.filter === value ? Theme.SHADOW_FLOAT : { radius: 0, color: 'transparent', offsetX: 0, offsetY: 0 })
      .onClick((): void => { this.filter = value; })
  }
}
