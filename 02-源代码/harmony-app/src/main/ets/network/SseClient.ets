import http from '@ohos.net.http';

interface SseEvent {
  data: string;
  event?: string;
}

type SseEventHandler = (event: SseEvent) => void;

export class SseClient {
  private baseUrl: string = 'http://10.0.2.2:8000';
  private token: string = '';

  public setBaseUrl(url: string): void { this.baseUrl = url; }
  public setToken(token: string): void { this.token = token; }

  public async stream(path: string, body: string, onEvent: SseEventHandler, onDone: () => void): Promise<void> {
    const client: http.HttpRequest = http.createHttp();
    try {
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      };
      if (this.token.length > 0) {
        headers.Authorization = `Bearer ${this.token}`;
      }
      const response: http.HttpResponse = await client.request(`${this.baseUrl}${path}`, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        connectTimeout: 10000,
        readTimeout: 120000,
      });
      const raw: string = response.result as string;
      const lines: string[] = raw.split('\n');
      for (let i: number = 0; i < lines.length; i += 1) {
        const line: string = lines[i];
        if (line.startsWith('data:')) {
          const data: string = line.substring(5).trim();
          if (data === '{"done": true}' || data === '[DONE]') {
            onDone();
            return;
          }
          onEvent({ data });
        }
      }
      onDone();
    } catch (error) {
      throw new Error('SSE 连接失败');
    } finally {
      client.destroy();
    }
  }
}

export const sseClient: SseClient = new SseClient();
