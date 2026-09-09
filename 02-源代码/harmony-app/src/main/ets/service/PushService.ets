import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class PushService {
  private static instance: PushService | undefined = undefined;
  private pushToken: string = '';

  public static getInstance(): PushService {
    if (PushService.instance === undefined) {
      PushService.instance = new PushService();
    }
    return PushService.instance!;
  }

  public async init(context: common.UIAbilityContext): Promise<void> {
    try {
      const pushToken: string = await this.requestPushToken(context);
      if (pushToken.length > 0) {
        this.pushToken = pushToken;
      }
    } catch (error) {
    }
  }

  private async requestPushToken(context: common.UIAbilityContext): Promise<string> {
    return '';
  }

  public getPushToken(): string {
    return this.pushToken;
  }

  public async registerTokenToServer(apiBaseUrl: string, userToken: string): Promise<void> {
    if (this.pushToken.length === 0 || userToken.length === 0) return;
    try {
    } catch (error) {
    }
  }
}

export const pushService: PushService = PushService.getInstance();
