import { api } from '../common/ApiClient';

export class AuthService {
  public async login(username: string, password: string): Promise<Record<string, Object>> {
    const result = await api.login({ username, password });
    api.setToken(result.access_token);
    AppStorage.setOrCreate<string>('token', result.access_token);
    AppStorage.setOrCreate<string>('refresh_token', result.refresh_token);
    AppStorage.setOrCreate<string>('username', result.user.username);
    AppStorage.setOrCreate<string>('role', result.user.role);
    return result as Record<string, Object>;
  }

  public logout(): void {
    api.setToken('');
    AppStorage.delete('token');
    AppStorage.delete('refresh_token');
    AppStorage.delete('role');
    AppStorage.delete('username');
    AppStorage.delete('avatar');
    AppStorage.delete('userId');
  }

  public isLoggedIn(): boolean {
    return api.hasToken();
  }

  public getRole(): string {
    return AppStorage.get<string>('role') ?? 'STUDENT';
  }

  public getUsername(): string {
    return AppStorage.get<string>('username') ?? '';
  }
}

export const authService: AuthService = new AuthService();
