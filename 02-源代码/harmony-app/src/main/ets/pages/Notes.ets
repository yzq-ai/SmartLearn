import { router } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { PageHeader, EmptyState } from '../components/UiKit';
interface NoteItem { id: number; text: string; time: string; }
@Entry
@Component
struct Notes {
  @State rows: NoteItem[] = [];
  @State text: string = '';
  @State nextId: number = 1;
  private add(): void {
    if (this.text.length === 0) return;
    const now: Date = new Date();
    const hh: string = `${now.getHours()}`.padStart(2, '0');
    const mm: string = `${now.getMinutes()}`.padStart(2, '0');
    const item: NoteItem = { id: this.nextId, text: this.text, time: `${hh}:${mm}` };
    const next: NoteItem[] = [];
    this.rows.forEach((n: NoteItem): void => { next.push(n); });
    next.push(item);
    this.rows = next;
    this.text = '';
    this.nextId += 1;
  }
  private remove(id: number): void {
    const next: NoteItem[] = [];
    this.rows.forEach((n: NoteItem): void => {
      if (n.id !== id) { next.push(n); }
    });
    this.rows = next;
  }
  build() {
    Column() {
      PageHeader({ title: '我的笔记', onBack: (): void => { router.back(); } })
      Row({ space: 8 }) {
        TextInput({ placeholder: '✏️ 记录学习笔记…', text: this.text })
          .onChange((v: string): void => { this.text = v; })
          .layoutWeight(1).height(46).fontSize(14)
          .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
          .caretColor(Theme.PRIMARY)
        Button('添加')
          .height(46).fontSize(14).fontWeight(FontWeight.Medium)
          .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
          .fontColor(Color.White).borderRadius(Theme.R_MD)
          .shadow(Theme.SHADOW_FLOAT)
          .onClick((): void => { this.add(); })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 12 })
      .padding({ top: 2 })
      if (this.rows.length === 0) {
        Column() {
          EmptyState({ icon: '📝', text: '还没有笔记，快记录第一条吧' })
        }.layoutWeight(1)
      } else {
        List({ space: 10 }) {
          ForEach(this.rows, (note: NoteItem) => {
            ListItem() {
              Row({ space: 12 }) {
                Column() {
                  Column().width(10).height(10).borderRadius(5).backgroundColor(Theme.PRIMARY)
                }.width(20).alignItems(HorizontalAlign.Center)
                Column({ space: 4 }) {
                  Text(note.text).fontSize(Theme.F_BODY).fontColor(Theme.TEXT).width('100%')
                  Text(note.time).fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .padding(12)
                .backgroundColor(Theme.CARD).borderRadius(Theme.R_MD)
                .shadow(Theme.SHADOW_CARD)
                Text('🗑')
                  .fontSize(16).padding(8)
                  .onClick((): void => { this.remove(note.id); })
              }
              .width('100%')
            }
          }, (note: NoteItem) => `${note.id}-${note.time}`)
        }
        .lanes({ minLength: 340, maxLength: 520 }, 12)
        .layoutWeight(1)
        .padding({ left: 20, right: 20, bottom: 20 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
