import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { CompanyItem } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, TagChip } from '../components/UiKit';

interface VerifyInfo {
  label: string;
  tone: string;
}

@Entry
@Component
struct CompanyManage {
  @State rows: CompanyItem[] = [];
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    try { this.rows = await api.getCompanies(); }
    catch (error) { this.message = error instanceof Error ? error.message : '加载失败'; }
    this.loading = false;
  }

  private async decide(company: CompanyItem, action: string): Promise<void> {
    try {
      // 后端 REJECT 必须携带非空 reason，否则 422
      const reason: string = action === 'REJECT' ? '企业资质待补充' : '';
      await api.decideReview('COMPANY', company.id, action, reason);
      this.rows = await api.getCompanies();
      this.message = action === 'APPROVE' ? '✓ 已通过' : '✓ 已驳回';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '操作失败';
    }
  }

  private verifyInfo(status: number): VerifyInfo {
    if (status === 0) {
      const info: VerifyInfo = { label: '待审核', tone: 'warning' };
      return info;
    }
    if (status === 1) {
      const info: VerifyInfo = { label: '已通过', tone: 'success' };
      return info;
    }
    const info: VerifyInfo = { label: '已驳回', tone: 'danger' };
    return info;
  }

  private pendingCount(): number {
    return this.rows.filter((r): boolean => r.verify_status === 0).length;
  }

  build() {
    Column() {
      PageHeader({ title: '企业管理', onBack: (): void => { router.back(); } })
      if (this.pendingCount() > 0) {
        Row({ space: 8 }) {
          Text('⏳').fontSize(14)
          Text(`有 ${this.pendingCount()} 家企业等待审核`)
            .fontSize(Theme.F_SUB).fontColor(Theme.WARNING).fontWeight(FontWeight.Medium)
        }
        .width('100%').padding(10)
        .backgroundColor(Theme.WARNING_LIGHT).borderRadius(Theme.R_SM)
        .margin({ left: 20, right: 20, bottom: 8 })
      }
      if (this.loading) {
        Column({ space: 12 }) { SkeletonCard(); SkeletonCard() }.padding(20)
      } else if (this.rows.length === 0) {
        EmptyState({ icon: '🏢', text: '暂无企业' })
      } else {
        List({ space: 12 }) {
          ForEach(this.rows, (company: CompanyItem) => {
            ListItem() {
              Column({ space: 10 }) {
                Row({ space: 12 }) {
                  Column() {
                    Text('🏢').fontSize(20)
                  }
                  .width(46).height(46).borderRadius(Theme.R_MD)
                  .backgroundColor(Theme.PRIMARY_LIGHT)
                  .alignItems(HorizontalAlign.Center)
                  Column({ space: 3 }) {
                    Text(company.name).fontSize(Theme.F_BODY)
                      .fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
                    if (company.industry !== null && company.industry !== undefined) {
                      Text(company.industry).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                    }
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  TagChip({
                    text: this.verifyInfo(company.verify_status).label,
                    tone: this.verifyInfo(company.verify_status).tone
                  })
                }.width('100%')
                if (company.verify_status === 0) {
                  Row({ space: 10 }) {
                    Button('✕ 驳回').height(36).fontSize(13).layoutWeight(1)
                      .backgroundColor(Theme.DANGER_LIGHT).fontColor(Theme.DANGER)
                      .onClick((): void => { this.decide(company, 'REJECT'); })
                    Button('✓ 通过').height(36).fontSize(13).layoutWeight(2)
                      .linearGradient({ angle: 135, colors: [[Theme.SUCCESS, 0], ['#3ECF8E', 1]] })
                      .fontColor(Color.White)
                      .onClick((): void => { this.decide(company, 'APPROVE'); })
                  }.width('100%')
                }
              }
              .width('100%').padding(Theme.CARD_PAD)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }
          }, (company: CompanyItem) => String(company.id))
        }
        .lanes({ minLength: 340, maxLength: 520 }, 12)
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 4, bottom: 20 })
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
}
