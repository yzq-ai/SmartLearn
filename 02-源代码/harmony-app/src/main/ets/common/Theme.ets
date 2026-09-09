export class Theme {
  // ═══ 动态色板：根据 AppStorage.darkMode 即时切换 ═══
  private static isDark(): boolean {
    return AppStorage.get<boolean>('darkMode') ?? false;
  }
  // 品牌色（两态通用）
  static get PRIMARY(): string { return '#3D5AFE'; }
  static get PRIMARY_DEEP(): string { return '#2A3EB1'; }
  static get PRIMARY_GRADIENT(): string { return '#7C4DFF'; }
  // 随模式切换
  static get PRIMARY_LIGHT(): string { return this.isDark() ? '#242C4F' : '#E8EAF6'; }
  static get SUCCESS(): string { return this.isDark() ? '#34C98E' : '#22A06B'; }
  static get SUCCESS_LIGHT(): string { return this.isDark() ? '#15332A' : '#E6F6EF'; }
  static get WARNING(): string { return '#F5A623'; }
  static get WARNING_LIGHT(): string { return this.isDark() ? '#3A2E14' : '#FEF4E2'; }
  static get DANGER(): string { return this.isDark() ? '#FF5C67' : '#E5484D'; }
  static get DANGER_LIGHT(): string { return this.isDark() ? '#3A1A1E' : '#FDEBEC'; }
  static get BG(): string { return this.isDark() ? '#121418' : '#F4F6FA'; }
  static get CARD(): string { return this.isDark() ? '#1C2028' : '#FFFFFF'; }
  static get TEXT(): string { return this.isDark() ? '#ECECF1' : '#1A2233'; }
  static get TEXT_SECOND(): string { return this.isDark() ? '#B4BCC9' : '#5B6474'; }
  static get TEXT_HINT(): string { return this.isDark() ? '#6B7480' : '#9AA3B2'; }
  static get DIVIDER(): string { return this.isDark() ? '#2A2F39' : '#EDF0F5'; }
  static get INPUT_BG(): string { return this.isDark() ? '#232833' : '#F0F2F7'; }

  // ═══ 尺寸常量（静态不变） ═══
  static readonly R_SM: number = 10;
  static readonly R_MD: number = 14;
  static readonly R_LG: number = 20;
  static readonly R_XL: number = 24;
  static get SHADOW_CARD(): ShadowOptions {
    return this.isDark()
      ? { radius: 18, color: 'rgba(0,0,0,0.45)', offsetX: 0, offsetY: 4 }
      : { radius: 16, color: 'rgba(26, 34, 51, 0.06)', offsetX: 0, offsetY: 4 };
  }
  static get SHADOW_FLOAT(): ShadowOptions {
    return { radius: 24, color: 'rgba(61, 90, 254, 0.28)', offsetX: 0, offsetY: 8 };
  }
  static readonly F_TITLE: number = 22;
  static readonly F_H2: number = 18;
  static readonly F_BODY: number = 15;
  static readonly F_SUB: number = 13;
  static readonly F_CAP: number = 11;
  static readonly PAGE_PAD: number = 20;
  static readonly CARD_PAD: number = 16;
  static readonly GAP: number = 12;
}
