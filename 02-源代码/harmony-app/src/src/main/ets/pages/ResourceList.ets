import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { ResourceItem } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState, SkeletonCard, TagChip } from '../components/UiKit';

@Entry
@Component
struct ResourceList {
  @State items: ResourceItem[] = [];
  @State filter: string = 'ALL';
  @State loading: boolean = true;
  @State message: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    this.message = '';
    try {
      const r = await api.getResources(this.filter === 'ALL' ? '' : this.filter);
      this.items = r.items;
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }

  private fmtSize(bytes: number | null): string {
    if (bytes === null || bytes === undefined || bytes <= 0) return '—';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  }

  build() {
    Column() {
      PageHeader({ title: '学习资料', onBack: (): void => { router.back(); } })
      Row({ space: 8 }) {
        this.FilterChip('全部', 'ALL')
        this.FilterChip('🎬 视频', 'video')
        this.FilterChip('📄 文档', 'doc')
      }
      .width('100%').padding({ left: 20, right: 20, top: 4, bottom: 8 })

      if (this.loading) {
        Column({ space: 12 }) { SkeletonCard(); SkeletonCard(); SkeletonCard() }.padding(20)
      } else if (this.items.length === 0) {
        EmptyState({ icon: '📂', text: '暂无学习资料\n教师上传后将在此展示' })
      } else {
        List({ space: 12 }) {
          ForEach(this.items, (item: ResourceItem) => {
            ListItem() {
              Column({ space: 10 }) {
                Row({ space: 10 }) {
                  Text(item.file_type === 'video' ? '🎬' : '📄').fontSize(24)
                    .width(48).height(48).textAlign(TextAlign.Center)
                    .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_MD)
                  Column({ space: 3 }) {
                    Text(item.file_name).fontSize(Theme.F_BODY).fontWeight(FontWeight.Bold)
                      .fontColor(Theme.TEXT).maxLines(1)
                    Text(`${this.fmtSize(item.file_size)}${item.duration ? ` · ${item.duration} 分钟` : ''}`)
                      .fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  TagChip({ text: item.is_local ? '可下载' : '云端', tone: 'success' })
                }.width('100%')
                Row({ space: 10 }) {
                  Button(item.file_type === 'video' ? '▶ 在线播放' : '📥 下载')
                    .height(36).fontSize(13).layoutWeight(1)
                    .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
                    .fontColor(Color.White)
                    .onClick((): void => {
                      if (item.file_type === 'video') {
                        router.pushUrl({
                          url: 'pages/VideoPlayer',
                          params: { title: item.file_name, videoUrl: `${api.baseUrl}${item.download_url}`, courseId: item.course_id ?? 0 }
                        });
                      } else {
                        // 文档下载：走系统下载
                        this.message = `开始下载 ${item.file_name}`;
                        api.downloadResource(item.download_url);
                      }
                    })
                  Text('🔗 分享')
                    .fontSize(13).fontColor(Theme.PRIMARY).textAlign(TextAlign.Center)
                    .height(36).layoutWeight(1)
                    .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(Theme.R_SM)
                    .onClick((): void => {
                      this.message = `已复制链接（资源 #${item.id}）`;
                    })
                }.width('100%')
              }
              .width('100%').padding(Theme.CARD_PAD)
              .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
              .shadow(Theme.SHADOW_CARD)
            }
          }, (item: ResourceItem) => String(item.id))
        }
        .lanes({ minLength: 340, maxLength: 520 }, 12)
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 4, bottom: 20 })
        .scrollBar(BarState.Off)
      }
      if (this.message.length > 0) {
        Text(this.message).fontSize(Theme.F_SUB)
          .fontColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.PRIMARY)
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
      .onClick((): void => { this.filter = value; this.load(); })
  }
}
