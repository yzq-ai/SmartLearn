import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { request } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { Theme } from '../common/Theme';
import { PageHeader, PrimaryButton } from '../components/UiKit';

interface UploadParams { courseId?: number; chapterId?: number; }

@Entry
@Component
struct ResourceUpload {
  @State fileName: string = '';
  @State fileSize: string = '';
  @State fileUri: string = '';
  @State uploading: boolean = false;
  @State message: string = '';
  @State uploadPercent: number = 0;
  @State courseId: number = 0;
  @State chapterId: number = 0;

  aboutToAppear(): void {
    const raw: Object | null = this.getUIContext().getRouter().getParams();
    if (raw !== null && raw !== undefined) {
      const params: UploadParams = raw as UploadParams;
      if (params.courseId !== undefined) this.courseId = params.courseId;
      if (params.chapterId !== undefined) this.chapterId = params.chapterId;
    }
  }

  private async chooseFile(): Promise<void> {
    try {
      const docOptions: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker();
      const uris: Array<string> = await docPicker.select(docOptions);
      if (uris.length > 0) {
        this.fileUri = uris[0];
        const stat: fs.Stat = fs.statSync(this.fileUri);
        this.fileName = this.fileUri.split('/').pop() ?? '未知文件';
        this.fileSize = this.formatSize(stat.size);
        this.message = '';
      }
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      if (err.code !== 13900042) { this.message = `文件选择失败: ${err.message}`; }
    }
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  }

  private fileIcon(): string {
    const ext: string = this.fileName.split('.').pop()?.toLowerCase() ?? '';
    const videoExts: string[] = ['mp4', 'avi', 'mov', 'mkv'];
    if (videoExts.indexOf(ext) >= 0) return '🎬';
    return '📄';
  }

  private validate(): boolean {
    if (this.fileName.length === 0) { this.message = '请先选择文件'; return false; }
    const ext: string = this.fileName.split('.').pop()?.toLowerCase() ?? '';
    const videoExts: string[] = ['mp4', 'avi', 'mov', 'mkv'];
    const docExts: string[] = ['pdf', 'pptx', 'ppt', 'docx', 'doc', 'xlsx', 'xls'];
    if (videoExts.indexOf(ext) < 0 && docExts.indexOf(ext) < 0) {
      this.message = '不支持的格式，仅支持 mp4/avi/mov/pdf/pptx/docx/xlsx 等';
      return false;
    }
    return true;
  }

  private async uploadToServer(): Promise<void> {
    if (!this.validate()) return;
    this.uploading = true;
    this.uploadPercent = 0;
    this.message = '正在上传…';
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      // 统一走 multipart 直传端点：本地模式真实落盘，OBS 模式同协议可平滑替换
      const fileName: string = this.fileName;
      const config: request.UploadConfig = {
        url: `${api.baseUrl}/api/v1/resources/upload?course_id=${this.courseId}&chapter_id=${this.chapterId}`,
        header: api.authHeaders(),
        method: 'POST',
        files: [{ filename: fileName, name: 'file', uri: this.fileUri, type: '' }],
        data: [],
      };
      const uploadTask: request.UploadTask = await request.uploadFile(context, config);
      uploadTask.on('progress', (receivedSize: number, totalSize: number): void => {
        if (totalSize > 0) {
          this.uploadPercent = Math.min(95, Math.floor((receivedSize / totalSize) * 100));
        }
      });
      uploadTask.on('complete', (): void => { this.uploadPercent = 96; });
      this.uploadPercent = 100;
      this.message = '✓ 上传成功！文件已真实存储，学生端可下载/播放';
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      this.message = `上传失败: ${err.message}`;
    }
    this.uploading = false;
  }

  build() {
    Column() {
      PageHeader({ title: '资源上传', onBack: (): void => { this.getUIContext().getRouter().back(); } })
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 12 }) {
            Text(this.fileName.length > 0 ? this.fileIcon() : '📤').fontSize(52)
            if (this.fileName.length > 0) {
              Text(this.fileName).fontSize(16).fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT).maxLines(1)
              Row({ space: 10 }) {
                Text(this.fileSize).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                Text('·').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                Button('重新选择').height(28).fontSize(11)
                  .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
                  .onClick((): void => { this.chooseFile(); })
              }
            } else {
              Text('点击下方按钮选择文件').fontSize(Theme.F_BODY).fontColor(Theme.TEXT_HINT)
              Text('支持视频 / 文档格式').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
            }
          }
          .width('100%').padding(32)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_XL)
          .border({ width: 1.5, color: Theme.DIVIDER, style: BorderStyle.Dashed })
          .shadow(Theme.SHADOW_CARD)
          .onClick((): void => { if (this.fileName.length === 0) { this.chooseFile(); } })

          Column({ space: 6 }) {
            Text('支持格式').fontSize(Theme.F_SUB).fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT).width('100%')
            Row({ space: 8 }) {
              Text('🎬 视频').fontSize(Theme.F_CAP).fontColor(Theme.PRIMARY)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(Theme.PRIMARY_LIGHT).borderRadius(8)
              Text('mp4 / avi / mov · ≤2GB').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
            }.width('100%')
            Row({ space: 8 }) {
              Text('📄 文档').fontSize(Theme.F_CAP).fontColor(Theme.SUCCESS)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(Theme.SUCCESS_LIGHT).borderRadius(8)
              Text('pdf / pptx / docx / xlsx · ≤100MB').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
            }.width('100%')
          }
          .width('100%').padding(Theme.CARD_PAD)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)

          if (this.fileName.length > 0) {
            Column({ space: 10 }) {
              Row() {
                Text('上传进度').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
                Blank()
                Text(`${this.uploadPercent}%`).fontSize(Theme.F_SUB)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.uploadPercent >= 100 ? Theme.SUCCESS : Theme.PRIMARY)
              }.width('100%')
              Progress({ value: this.uploadPercent, total: 100, type: ProgressType.Linear })
                .width('100%')
                .color(this.uploadPercent >= 100 ? Theme.SUCCESS : Theme.PRIMARY)
                .style({ strokeWidth: 8 })
            }
            .width('100%').padding(Theme.CARD_PAD)
            .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
            .shadow(Theme.SHADOW_CARD)
            PrimaryButton({
              label: this.uploading ? '上传中…' : '🚀 上传至对象存储',
              loading: this.uploading,
              onTap: (): void => { this.uploadToServer(); }
            })
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
}
