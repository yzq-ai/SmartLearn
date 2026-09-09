import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { Theme } from '../common/Theme';
import { PageHeader } from '../components/UiKit';

interface DocParams {
  title?: string;
  fileUri?: string;
  content?: string;
  totalPages?: number;
}

@Entry
@Component
struct DocPreview {
  @State title: string = '文档预览';
  @State currentPage: number = 1;
  @State totalPages: number = 1;
  @State zoom: number = 100;
  @State fileUri: string = '';
  @State textContent: string = '';
  @State loading: boolean = false;
  @State message: string = '';

  aboutToAppear(): void {
    const raw: Object | null = this.getUIContext().getRouter().getParams();
    if (raw !== null && raw !== undefined) {
      const params: DocParams = raw as DocParams;
      if (params.title !== undefined && params.title.length > 0) this.title = params.title;
      if (params.fileUri !== undefined && params.fileUri.length > 0) {
        this.fileUri = params.fileUri;
        this.loadFileContent();
      } else if (params.content !== undefined && params.content.length > 0) {
        this.textContent = params.content;
        this.totalPages = params.totalPages ?? 1;
      }
    }
  }

  private async loadFileContent(): Promise<void> {
    if (this.fileUri.length === 0) return;
    this.loading = true;
    try {
      if (fs.accessSync(this.fileUri)) {
        const stat: fs.Stat = fs.statSync(this.fileUri);
        const size: number = stat.size;
        if (size < 2 * 1024 * 1024) {
          const content: string = fs.readTextSync(this.fileUri);
          this.textContent = content.length > 0 ? content : '（文件内容为空或为二进制格式）';
          this.totalPages = Math.max(1, Math.ceil(content.length / 3000));
        } else {
          this.textContent = '文件较大，仅显示前 5000 字…';
          const file: fs.File = fs.openSync(this.fileUri, fs.OpenMode.READ_ONLY);
          const buf: Uint8Array = new Uint8Array(5000);
          fs.readSync(file.fd, buf.buffer);
          fs.closeSync(file);
          const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
          this.textContent = decoder.decodeToString(buf);
          this.totalPages = Math.max(1, Math.ceil(size / 3000));
        }
      }
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      this.textContent = `文件读取失败: ${err.message}`;
    }
    this.loading = false;
  }

  private zoomIn(): void { this.zoom = Math.min(200, this.zoom + 20); }
  private zoomOut(): void { this.zoom = Math.max(60, this.zoom - 20); }
  private prevPage(): void { this.currentPage = Math.max(1, this.currentPage - 1); }
  private nextPage(): void { this.currentPage = Math.min(this.totalPages, this.currentPage + 1); }

  private async exportFile(): Promise<void> {
    try {
      const docSave: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      docSave.newFileNames = [this.title.endsWith('.txt') ? this.title : `${this.title}.txt`];
      const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker();
      const uris: Array<string> = await docPicker.save(docSave);
      if (uris.length > 0 && this.textContent.length > 0) {
        const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
        fs.writeSync(file.fd, this.textContent);
        fs.closeSync(file);
        this.message = '✓ 导出成功';
      }
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      this.message = `导出失败: ${err.message}`;
    }
  }

  private getCurrentPageContent(): string {
    if (this.totalPages <= 1) return this.textContent;
    const pageSize: number = 3000;
    const start: number = (this.currentPage - 1) * pageSize;
    const end: number = Math.min(start + pageSize, this.textContent.length);
    return this.textContent.substring(start, end);
  }

  @Builder exportEntry() {
    Button('📤 导出').height(34).fontSize(13)
      .backgroundColor(Theme.PRIMARY_LIGHT).fontColor(Theme.PRIMARY)
      .onClick((): void => { this.exportFile(); })
  }

  build() {
    Column() {
      PageHeader({
        title: this.title,
        onBack: (): void => { this.getUIContext().getRouter().back(); },
        right: (): void => { this.exportEntry() }
      })
      Row({ space: 8 }) {
        this.ToolBtn('－', (): void => { this.zoomOut(); })
        Text(`${this.zoom}%`).fontSize(Theme.F_SUB).fontWeight(FontWeight.Bold)
          .fontColor(Theme.PRIMARY).width(48).textAlign(TextAlign.Center)
        this.ToolBtn('＋', (): void => { this.zoomIn(); })
        Blank()
        this.ToolBtn('‹', (): void => { this.prevPage(); }, this.currentPage > 1)
        Text(`${this.currentPage} / ${this.totalPages}`)
          .fontSize(Theme.F_SUB).fontColor(Theme.TEXT_SECOND)
        this.ToolBtn('›', (): void => { this.nextPage(); }, this.currentPage < this.totalPages)
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 10 })
      if (this.loading) {
        Column({ space: 12 }) {
          LoadingProgress().width(48).height(48).color(Theme.PRIMARY)
          Text('加载文档中…').fontSize(Theme.F_SUB).fontColor(Theme.TEXT_HINT)
        }.layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else {
        Scroll() {
          Column() {
            Column() {
              Text(this.getCurrentPageContent())
                .fontSize(16 * this.zoom / 100)
                .lineHeight(28 * this.zoom / 100)
                .fontColor(Theme.TEXT)
                .width('100%')
                .copyOption(CopyOptions.InApp)
            }
            .width('100%')
            .padding(24)
            .backgroundColor(Theme.CARD)
            .borderRadius(Theme.R_MD)
            .shadow(Theme.SHADOW_CARD)
          }
          .padding(20)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      if (this.message.length > 0) {
        Text(this.message).fontSize(Theme.F_SUB)
          .fontColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
          .padding({ left: 16, bottom: 8 }).width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }

  @Builder ToolBtn(label: string, onTap: () => void, enabled: boolean = true) {
    Text(label)
      .fontSize(16).fontWeight(FontWeight.Bold)
      .fontColor(enabled ? Theme.TEXT : Theme.TEXT_HINT)
      .width(36).height(32).textAlign(TextAlign.Center)
      .backgroundColor(enabled ? Theme.CARD : Theme.BG)
      .borderRadius(Theme.R_SM)
      .shadow(enabled ? Theme.SHADOW_CARD : { radius: 0, color: 'transparent', offsetX: 0, offsetY: 0 })
      .onClick((): void => { if (enabled) { onTap(); } })
  }
}
