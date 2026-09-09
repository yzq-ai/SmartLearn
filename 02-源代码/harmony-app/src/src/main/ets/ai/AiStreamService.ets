import { sseClient } from '../network/SseClient';

export class AiStreamService {
  public async streamChat(query: string, onDelta: (text: string) => void, onDone: () => void, onError: (msg: string) => void): Promise<void> {
    try {
      await sseClient.stream(
        '/api/v1/ai/chat/stream',
        JSON.stringify({ query }),
        (event): void => {
          try {
            const parsed: Record<string, Object> = JSON.parse(event.data) as Record<string, Object>;
            const delta: Object | undefined = parsed['delta'];
            if (delta !== undefined) {
              onDelta(String(delta));
            }
          } catch (e) {
            onDelta(event.data);
          }
        },
        onDone,
      );
    } catch (error) {
      onError(error instanceof Error ? error.message : 'AI 连接失败');
    }
  }
}

export const aiStreamService: AiStreamService = new AiStreamService();
