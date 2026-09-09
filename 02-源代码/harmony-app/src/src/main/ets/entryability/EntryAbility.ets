import { AbilityConstant, UIAbility, Want, common, ConfigurationConstant } from '@kit.AbilityKit';
import { Configuration } from '@ohos.app.ability.Configuration';
import { window } from '@kit.ArkUI';
import { localDb } from '../db/LocalDb';
import { pushService } from '../service/PushService';
import { tokenStore } from '../common/TokenStore';
import { IBestInit } from '@ibestservices/ibest-ui-v2';

export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    // 冷启动先按系统深浅色初始化（TokenStore.restore 若发现用户历史偏好会覆盖此值）
    const sysDark: boolean = this.context.config?.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate<boolean>('darkMode', sysDark);
    AppStorage.setOrCreate<boolean>('themePrefSet', false);
  }

  /** 系统深浅色变化：用户无显式偏好时跟随系统（IBest 资源与 Theme 色板一起切换）。 */
  onConfigurationUpdated(newConfig: Configuration): void {
    const prefSet: boolean = AppStorage.get<boolean>('themePrefSet') ?? false;
    if (!prefSet) {
      const dark: boolean = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      AppStorage.setOrCreate<boolean>('darkMode', dark);
      try {
        this.context.getApplicationContext().setColorMode(
          dark ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        );
      } catch (_e) {
        // 忽略
      }
    }
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    const context: common.UIAbilityContext = this.context;
    localDb.init(context);
    pushService.init(context);
    // 供文件下载等场景使用（ApiClient.saveToFile）
    AppStorage.setOrCreate<Object>('context', context);

    // 登录态持久化：先从磁盘恢复 token，再决定首屏路由（含深色偏好恢复）
    await tokenStore.restore(context);
    const token: string | undefined = AppStorage.get<string>('token');
    windowStage.loadContent(token !== undefined && token.length > 0 ? 'pages/Home' : 'pages/Splash', () => {
      // 初始化 IBest-UI 组件库（Toast/Dialog/ActionSheet 等依赖窗口）
      IBestInit(windowStage, context);
      // 应用恢复后的深浅色（覆盖跟随系统的默认值）。
      // 关键：先标记用户偏好已设定，再 setColorMode —— 否则 setColorMode 引发的
      // onConfigurationUpdated 回调（此时 themePrefSet 仍为 false）会用系统色
      // 覆盖刚恢复的偏好，导致「深色切不过去/重启后翻转」的竞态 bug（需求 4）。
      const dark: boolean = AppStorage.get<boolean>('darkMode') ?? false;
      const hasPref: boolean = AppStorage.get<boolean>('darkModePrefRestored') ?? false;
      if (hasPref) {
        AppStorage.setOrCreate<boolean>('themePrefSet', true);
      }
      try {
        context.getApplicationContext().setColorMode(
          dark ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        );
      } catch (_e) {
        // 忽略
      }
    });

    windowStage.getMainWindow().then((win: window.Window): void => {
      const width: number = win.getWindowProperties().windowRect.width;
      const bp: string = width < 600 ? 'sm' : (width < 840 ? 'md' : 'lg');
      AppStorage.setOrCreate<string>('breakpoint', bp);
      win.on('windowSizeChange', (size: window.Size): void => {
        const newBp: string = size.width < 600 ? 'sm' : (size.width < 840 ? 'md' : 'lg');
        AppStorage.setOrCreate<string>('breakpoint', newBp);
      });
    });
  }

  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    const token: string = AppStorage.get<string>('token') ?? '';
    const role: string = AppStorage.get<string>('role') ?? '';
    const username: string = AppStorage.get<string>('username') ?? '';
    const userId: string = AppStorage.get<string>('userId') ?? '';
    wantParam['token'] = token;
    wantParam['role'] = role;
    wantParam['username'] = username;
    wantParam['userId'] = userId;
    return AbilityConstant.OnContinueResult.AGREE;
  }

  onRestoreData(wantParam: Record<string, Object>): void {
    const token: Object | undefined = wantParam['token'];
    const role: Object | undefined = wantParam['role'];
    const username: Object | undefined = wantParam['username'];
    const userId: Object | undefined = wantParam['userId'];
    if (token !== undefined) {
      AppStorage.setOrCreate<string>('token', String(token));
    }
    if (role !== undefined) {
      AppStorage.setOrCreate<string>('role', String(role));
    }
    if (username !== undefined) {
      AppStorage.setOrCreate<string>('username', String(username));
    }
    if (userId !== undefined) {
      AppStorage.setOrCreate<string>('userId', String(userId));
    }
  }

  onForeground(): void {
    localDb.flushProgress();
    localDb.flushUnsynced();
  }

  onBackground(): void {
    localDb.flushProgress();
  }
}
