import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { router } from '@kit.ArkUI';
import { api } from '../common/ApiClient';
import { localDb } from '../db/LocalDb';
import { Theme } from '../common/Theme';

interface VideoParams {
  title?: string;
  videoUrl?: string;
  courseId?: number;
  sectionId?: number;
}

@Entry
@Component
struct VideoPlayer {
  @State title: string = '课程视频';
  @State playing: boolean = false;
  @State currentTime: number = 0;
  @State duration: number = 0;
  @State speed: number = 1.0;
  @State message: string = '';
  @State sectionId: number = 0;
  @State courseId: number = 0;
  private avPlayer: media.AVPlayer | undefined = undefined;
  private surfaceId: string = '';
  private xComponentController: XComponentController = new XComponentController();
  private progressTimerId: number = -1;
  private lastReportPct: number = -1;

  aboutToAppear(): void {
    const raw: Object | null = router.getParams();
    if (raw !== null && raw !== undefined) {
      const params: VideoParams = raw as VideoParams;
      if (params.title !== undefined && params.title.length > 0) this.title = params.title;
      if (params.courseId !== undefined) this.courseId = params.courseId;
      if (params.sectionId !== undefined) this.sectionId = params.sectionId;
    }
    this.initPlayer();
  }

  aboutToDisappear(): void {
    this.stopProgressReport();
    this.releasePlayer();
  }

  private async initPlayer(): Promise<void> {
    try {
      this.avPlayer = await media.createAVPlayer();
      this.setPlayerCallbacks();
      const raw: Object | null = router.getParams();
      let url: string = 'https://www.w3schools.com/html/mov_bbb.mp4';
      if (raw !== null && raw !== undefined) {
        const p: VideoParams = raw as VideoParams;
        if (p.videoUrl !== undefined && p.videoUrl.length > 0) url = p.videoUrl;
      }
      if (this.avPlayer !== undefined) { this.avPlayer.url = url; }
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      this.message = `播放器初始化失败: ${err.message}`;
    }
  }

  private setPlayerCallbacks(): void {
    if (this.avPlayer === undefined) return;
    const player: media.AVPlayer = this.avPlayer!;

    player.on('stateChange', (state: string): void => {
      if (state === 'prepared') { this.duration = player.duration; }
      else if (state === 'playing') { this.playing = true; this.startProgressReport(); }
      else if (state === 'paused' || state === 'stopped') {
        this.playing = false; this.stopProgressReport();
      }
      else if (state === 'completed') {
        this.playing = false; this.stopProgressReport(); this.reportProgress();
      }
    });

    player.on('timeUpdate', (time: number): void => { this.currentTime = time; });

    player.on('error', (error: BusinessError): void => {
      this.message = `播放错误: ${error.message}`;
      this.playing = false;
    });
  }

  private startProgressReport(): void {
    if (this.progressTimerId >= 0) return;
    this.progressTimerId = setInterval((): void => { this.reportProgress(); }, 10000);
  }

  private stopProgressReport(): void {
    if (this.progressTimerId >= 0) {
      clearInterval(this.progressTimerId); this.progressTimerId = -1;
    }
  }

  private reportProgress(): void {
    if (this.courseId <= 0 || this.duration <= 0) return;
    const pct: number = Math.min(100, Math.round(this.currentTime / this.duration * 100));
    if (pct !== this.lastReportPct) {
      this.lastReportPct = pct;
      localDb.enqueueProgress(this.courseId, pct, this.sectionId);
    }
  }

  private async releasePlayer(): Promise<void> {
    if (this.avPlayer !== undefined) {
      try { this.avPlayer!.release(); } catch (error) { }
      this.avPlayer = undefined;
    }
  }

  private async togglePlay(): Promise<void> {
    if (this.avPlayer === undefined) return;
    try {
      if (this.playing) { this.avPlayer!.pause(); } else { this.avPlayer!.play(); }
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      this.message = `操作失败: ${err.message}`;
    }
  }

  private async seekTo(positionMs: number): Promise<void> {
    if (this.avPlayer === undefined) return;
    try { this.avPlayer!.seek(positionMs); } catch (error) { }
  }

  private async setSpeed(rate: number): Promise<void> {
    if (this.avPlayer === undefined) return;
    try {
      let speedMode: media.PlaybackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
      if (rate <= 0.75) { speedMode = media.PlaybackSpeed.SPEED_FORWARD_0_75_X; }
      else if (rate <= 1.0) { speedMode = media.PlaybackSpeed.SPEED_FORWARD_1_00_X; }
      else if (rate <= 1.25) { speedMode = media.PlaybackSpeed.SPEED_FORWARD_1_25_X; }
      else if (rate <= 1.75) { speedMode = media.PlaybackSpeed.SPEED_FORWARD_1_75_X; }
      else { speedMode = media.PlaybackSpeed.SPEED_FORWARD_2_00_X; }
      this.avPlayer!.setSpeed(speedMode);
      this.speed = rate;
    } catch (error) { }
  }

  private formatTime(ms: number): string {
    const totalSec: number = Math.max(0, Math.floor(ms / 1000));
    const min: number = Math.floor(totalSec / 60);
    const sec: number = totalSec % 60;
    return `${min}:${sec < 10 ? '0' : ''}${sec}`;
  }

  private cycleSpeed(): void {
    const speeds: number[] = [0.75, 1.0, 1.25, 1.5, 2.0];
    const idx: number = speeds.indexOf(this.speed);
    this.setSpeed(speeds[(idx + 1) % speeds.length]);
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Button('‹')
          .width(38).height(38).fontSize(18)
          .backgroundColor('rgba(255,255,255,0.15)').fontColor(Color.White)
          .onClick((): void => {
            this.reportProgress();
            localDb.flushProgress();
            router.back();
          })
        Text(this.title)
          .fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor(Color.White).maxLines(1).layoutWeight(1).textAlign(TextAlign.Center)
        Text(`${this.speed}x`)
          .fontSize(Theme.F_SUB).fontColor('rgba(255,255,255,0.7)')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('rgba(255,255,255,0.15)').borderRadius(10)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#12141C')

      Stack({ alignContent: Alignment.Center }) {
        XComponent({
          id: 'videoSurface',
          type: XComponentType.SURFACE,
          controller: this.xComponentController
        })
          .width('100%')
          .height(230)
          .onLoad((): void => {
            this.surfaceId = this.xComponentController.getXComponentSurfaceId();
            if (this.avPlayer !== undefined) { this.avPlayer!.surfaceId = this.surfaceId; }
          })
          .backgroundColor('#000000')
        if (!this.playing) {
          Column() {
            Text('▶').fontSize(30).fontColor(Color.White)
          }
          .width(64).height(64).borderRadius(32)
          .backgroundColor('rgba(0,0,0,0.55)')
          .shadow({ radius: 16, color: 'rgba(0,0,0,0.4)' })
          .onClick((): void => { this.togglePlay(); })
        }
      }
      .width('100%').height(230)

      Column({ space: 12 }) {
        Row({ space: 10 }) {
          Text(this.formatTime(this.currentTime)).fontSize(Theme.F_CAP)
            .fontColor(Theme.TEXT_HINT).width(44)
          Progress({ value: this.currentTime, total: Math.max(this.duration, 1), type: ProgressType.Linear })
            .layoutWeight(1).color(Theme.PRIMARY).style({ strokeWidth: 5 })
          Text(this.formatTime(this.duration)).fontSize(Theme.F_CAP)
            .fontColor(Theme.TEXT_HINT).width(44).textAlign(TextAlign.End)
        }.width('100%')

        Row({ space: 10 }) {
          this.CtrlButton(this.playing ? '⏸ 暂停' : '▶ 播放', (): void => { this.togglePlay(); }, 2)
          this.CtrlButton('⏪ 10s', (): void => { this.seekTo(Math.max(0, this.currentTime - 10000)); }, 1)
          this.CtrlButton('⏩ 10s', (): void => { this.seekTo(this.currentTime + 10000); }, 1)
          this.CtrlButton(`${this.speed}x`, (): void => { this.cycleSpeed(); }, 1)
        }.width('100%')

        if (this.message.length > 0) {
          Row({ space: 6 }) {
            Text('⚠').fontSize(12)
            Text(this.message).fontSize(Theme.F_CAP).fontColor(Theme.DANGER)
          }
          .width('100%').padding(8)
          .backgroundColor(Theme.DANGER_LIGHT).borderRadius(Theme.R_SM)
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Theme.CARD)
      .borderRadius({ topLeft: Theme.R_LG, topRight: Theme.R_LG })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }

  @Builder CtrlButton(label: string, onTap: () => void, weight: number) {
    Button(label)
      .layoutWeight(weight).height(42).fontSize(13)
      .backgroundColor(Theme.BG).fontColor(Theme.TEXT)
      .borderRadius(Theme.R_SM)
      .onClick((): void => { onTap(); })
  }
}
