import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';

/**
 * 登录态磁盘持久化（preferences 实现）。
 * - restore():  EntryAbility 启动时调用，把 token/role 等恢复进 AppStorage；
 * - save():    登录成功或资料更新时调用，立即落盘；
 * - clear():   退出登录时清空。
 * PersistentStorage 在部分模拟器镜像上恢复时机不稳定，故用显式 preferences。
 */
export class TokenStore {
  private store: preferences.Preferences | null = null;

  private async ready(context: Context): Promise<preferences.Preferences> {
    if (this.store !== null) { return this.store; }
    const options: preferences.Options = { name: 'smartlearn_session' };
    this.store = await preferences.getPreferences(context, options);
    return this.store;
  }

  /** 启动时恢复登录态到 AppStorage（未登录时值为空字符串）；同时恢复深色模式偏好。 */
  async restore(context: Context): Promise<void> {
    try {
      const p: preferences.Preferences = await this.ready(context);
      const keys: string[] = ['token', 'refresh_token', 'role', 'username', 'userId', 'avatar'];
      for (const key of keys) {
        const val: preferences.ValueType = await p.get(key, '');
        AppStorage.setOrCreate<string>(key, typeof val === 'string' ? val : String(val));
      }
      const dark: preferences.ValueType = await p.get('darkMode', false);
      const hasDarkPref: boolean = await p.has('darkMode');
      AppStorage.setOrCreate<boolean>('darkMode', dark === true || dark === 'true');
      // 磁盘上确有深色偏好 → 标记「偏好已恢复」，供 EntryAbility 在 setColorMode 前设置 themePrefSet，
      // 防止 setColorMode 触发的 onConfigurationUpdated 用系统色覆盖用户偏好（需求 4 竞态修复）。
      if (hasDarkPref) {
        AppStorage.setOrCreate<boolean>('darkModePrefRestored', true);
      }
    } catch (_e) {
      // 恢复失败按未登录处理
    }
  }

  /** 把 AppStorage 当前登录态写入磁盘（含深色模式偏好）。 */
  async save(context: Context): Promise<void> {
    try {
      const p: preferences.Preferences = await this.ready(context);
      const keys: string[] = ['token', 'refresh_token', 'role', 'username', 'userId', 'avatar'];
      for (const key of keys) {
        const val: string = AppStorage.get<string>(key) ?? '';
        await p.put(key, val);
      }
      await p.put('darkMode', AppStorage.get<boolean>('darkMode') ?? false);
      await p.flush();
    } catch (_e) {
      // 忽略写盘失败（不影响主流程）
    }
  }

  /** 清空磁盘与 AppStorage 登录态。 */
  async clear(context: Context): Promise<void> {
    try {
      const p: preferences.Preferences = await this.ready(context);
      const keys: string[] = ['token', 'refresh_token', 'role', 'username', 'userId', 'avatar'];
      for (const key of keys) {
        await p.delete(key);
        AppStorage.setOrCreate<string>(key, '');
      }
      await p.flush();
    } catch (_e) {
      // 忽略
    }
  }
}

/** 退出登录等时机需要 context 的便捷入口由页面自行传 context 调用。 */
export const tokenStore: TokenStore = new TokenStore();
