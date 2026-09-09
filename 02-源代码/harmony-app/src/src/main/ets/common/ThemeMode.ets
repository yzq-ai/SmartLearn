import { ConfigurationConstant, common } from '@kit.AbilityKit';
import { tokenStore } from './TokenStore';

/**
 * 深浅色模式统一管理：
 * - AppStorage.darkMode 驱动本项目 Theme 动态色板；
 * - ApplicationContext.setColorMode 驱动系统资源（IBest-UI 的 base/dark 色板自动切换）；
 * - themePrefSet 标记用户显式偏好（设置后不再跟随系统）；
 * - tokenStore.save 持久化偏好，冷启动恢复。
 */
export class ThemeMode {
  /** 当前是否深色。 */
  static isDark(): boolean {
    return AppStorage.get<boolean>('darkMode') ?? false;
  }

  /** 应用指定模式：AppStorage + setColorMode + 持久化 + 标记用户偏好。 */
  static apply(dark: boolean): void {
    AppStorage.setOrCreate<boolean>('darkMode', dark);
    AppStorage.setOrCreate<boolean>('themePrefSet', true);
    try {
      const ctxObj: Object | undefined = AppStorage.get<Object>('context');
      const abilityCtx: common.UIAbilityContext = ctxObj as common.UIAbilityContext;
      abilityCtx.getApplicationContext().setColorMode(
        dark ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
      );
    } catch (_e) {
      // context 未就绪时忽略：AppStorage 已生效，Theme getter 仍正确
    }
    // 持久化偏好（下次启动恢复）
    try {
      const ctxObj: Object | undefined = AppStorage.get<Object>('context');
      if (ctxObj !== undefined) {
        tokenStore.save(ctxObj as common.UIAbilityContext).catch((): void => {});
      }
    } catch (_e) {
      // 忽略
    }
  }

  /** 切换。 */
  static toggle(): void {
    ThemeMode.apply(!ThemeMode.isDark());
  }
}
