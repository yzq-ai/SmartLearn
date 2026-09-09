import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { request } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { api } from '../common/ApiClient';
import { UserProfile } from '../common/Models';
import { Theme } from '../common/Theme';
import { PageHeader, PrimaryButton, FieldInput } from '../components/UiKit';
@Entry
@Component
struct ProfileEdit {
  @State profile: UserProfile | null = null;
  @State editUsername: string = '';
  @State editSignature: string = '';
  @State editEmail: string = '';
  @State editPhone: string = '';
  @State avatarUrl: string = '';
  @State message: string = '';
  @State loading: boolean = false;
  @State avatarUploading: boolean = false;
  aboutToAppear(): void {
    this.loadProfile();
  }
  private async loadProfile(): Promise<void> {
    this.loading = true;
    this.message = '';
    try {
      const p: UserProfile = await api.getUserProfile();
      this.profile = p;
      this.editUsername = p.username;
      this.editSignature = p.signature;
      this.editEmail = p.email;
      this.editPhone = p.phone;
      this.avatarUrl = p.avatar;
      AppStorage.setOrCreate<string>('avatar', p.avatar);
      AppStorage.setOrCreate<string>('userId', `${p.id}`);
    } catch (error) {
      this.message = error instanceof Error ? error.message : '加载失败';
    }
    this.loading = false;
  }
  private async saveProfile(): Promise<void> {
    this.loading = true;
    this.message = '';
    try {
      const data: Record<string, string> = {};
      data['username'] = this.editUsername;
      data['signature'] = this.editSignature;
      data['email'] = this.editEmail;
      data['phone'] = this.editPhone;
      const updated: UserProfile = await api.updateUserProfile(data);
      this.profile = updated;
      AppStorage.setOrCreate<string>('username', updated.username);
      AppStorage.setOrCreate<string>('avatar', updated.avatar);
      this.message = '✓ 保存成功';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '保存失败';
    }
    this.loading = false;
  }
  private async pickAndUploadAvatar(): Promise<void> {
    try {
      const photoSelect: picker.PhotoSelectOptions = {
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };
      const photoViewPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker();
      const selectResult: picker.PhotoSelectResult = await photoViewPicker.select(photoSelect);
      if (selectResult.photoUris.length === 0) return;
      const uri: string = selectResult.photoUris[0];
      this.avatarUploading = true;
      this.message = '';
      const tokenResult: Record<string, string> = await api.getUploadToken('avatar.jpg', '0');
      const uploadUrl: string = tokenResult.upload_url ?? '';
      if (uploadUrl.length > 0) {
        // OBS 模式：直传对象存储后用 oss_key 登记。
        const uploadConfig: request.UploadConfig = {
          url: uploadUrl,
          header: {},
          method: 'PUT',
          files: [{ filename: 'avatar.jpg', name: 'file', uri: uri, type: 'image/jpeg' }],
          data: []
        };
        const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
        await request.uploadFile(context, uploadConfig);
      }
      // local 模式无直传地址：直接把对象键登记为头像标识。
      const ossKey: string = tokenResult.oss_key ?? tokenResult.object_key ?? 'avatar.jpg';
      const result: UserProfile = await api.uploadAvatar(ossKey);
      this.profile = result;
      this.avatarUrl = result.avatar;
      AppStorage.setOrCreate<string>('avatar', result.avatar);
      this.message = '✓ 头像已更新';
    } catch (error) {
      const e: BusinessError = error as BusinessError;
      this.message = `头像上传失败：${e.message ?? '未知错误'}`;
    }
    this.avatarUploading = false;
  }
  private avatarDisplayable(): boolean {
    return this.avatarUrl.startsWith('http://') || this.avatarUrl.startsWith('https://');
  }
  build() {
    Column() {
      PageHeader({ title: '编辑资料', onBack: (): void => { router.back(); } })
      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 12 }) {
            Stack() {
              if (this.avatarDisplayable()) {
                Image(this.avatarUrl).width(80).height(80).borderRadius(40)
                  .objectFit(ImageFit.Cover)
              } else {
                Column() {
                  Text(this.editUsername.length > 0 ? this.editUsername.substring(0, 1).toUpperCase() : '?')
                    .fontSize(30).fontWeight(FontWeight.Bold).fontColor(Color.White)
                }
                .width(80).height(80).borderRadius(40)
                .linearGradient({ angle: 135, colors: [[Theme.PRIMARY, 0], [Theme.PRIMARY_GRADIENT, 1]] })
              }
              Column() {
                Text('📷').fontSize(14).fontColor(Color.White)
              }
              .width(28).height(28).borderRadius(14)
              .backgroundColor(Theme.PRIMARY)
              .justifyContent(FlexAlign.Center)
              .position({ x: 54, y: 54 })
              .shadow({ radius: 8, color: 'rgba(0,0,0,0.3)', offsetY: 2 })
            }
            .width(80).height(80)
            .onClick((): void => { this.pickAndUploadAvatar(); })
            if (this.avatarUploading) {
              LoadingProgress().width(20).height(20).color(Theme.PRIMARY)
            }
            if (this.profile !== null) {
              Row({ space: 6 }) {
                Text('用户号').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
                Text(this.profile.user_code.length > 0 ? this.profile.user_code : `SL${this.profile.id}`)
                  .fontSize(Theme.F_SUB).fontWeight(FontWeight.Bold)
                  .fontColor(Theme.PRIMARY).letterSpacing(1)
                Text('（唯一，可用于添加好友/老师）').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT)
              }
            }
          }
          .width('100%')
          .padding(24)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)
          Column({ space: 12 }) {
            Column({ space: 6 }) {
              Text('用户名').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
              TextInput({ placeholder: '输入用户名', text: this.editUsername })
                .onChange((v: string): void => { this.editUsername = v; })
                .width('100%').height(48).fontSize(15)
                .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
                .caretColor(Theme.PRIMARY)
            }
            Column({ space: 6 }) {
              Text('个性签名').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
              TextArea({ placeholder: '写点什么介绍一下自己…', text: this.editSignature })
                .onChange((v: string): void => { this.editSignature = v; })
                .width('100%').height(80).fontSize(14)
                .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
                .caretColor(Theme.PRIMARY)
            }
            Column({ space: 6 }) {
              Text('邮箱').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
              TextInput({ placeholder: '输入邮箱', text: this.editEmail })
                .onChange((v: string): void => { this.editEmail = v; })
                .width('100%').height(48).fontSize(15)
                .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
                .caretColor(Theme.PRIMARY)
            }
            Column({ space: 6 }) {
              Text('手机号').fontSize(Theme.F_CAP).fontColor(Theme.TEXT_HINT).width('100%')
              TextInput({ placeholder: '输入手机号', text: this.editPhone })
                .onChange((v: string): void => { this.editPhone = v; })
                .width('100%').height(48).fontSize(15)
                .backgroundColor(Theme.INPUT_BG).borderRadius(Theme.R_MD)
                .caretColor(Theme.PRIMARY)
            }
          }
          .width('100%').padding(Theme.CARD_PAD)
          .backgroundColor(Theme.CARD).borderRadius(Theme.R_LG)
          .shadow(Theme.SHADOW_CARD)
          if (this.message.length > 0) {
            Row({ space: 6 }) {
              Text(this.message.indexOf('✓') >= 0 ? '✅' : '⚠').fontSize(13)
              Text(this.message).fontSize(Theme.F_SUB)
                .fontColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS : Theme.DANGER)
            }
            .width('100%').padding(10)
            .backgroundColor(this.message.indexOf('✓') >= 0 ? Theme.SUCCESS_LIGHT : Theme.DANGER_LIGHT)
            .borderRadius(Theme.R_SM)
          }
          PrimaryButton({
            label: '保存修改', loading: this.loading,
            onTap: (): void => { this.saveProfile(); }
          })
        }
        .padding(20)
        .constraintSize({ maxWidth: 640 })
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
