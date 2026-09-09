export class DistributedSync {
  private static instance: DistributedSync | undefined = undefined;

  public static getInstance(): DistributedSync {
    if (DistributedSync.instance === undefined) {
      DistributedSync.instance = new DistributedSync();
    }
    return DistributedSync.instance!;
  }

  public saveExamState(recordId: number, currentQuestion: number, answers: Record<string, string>): void {
    try {
      const key: string = `exam_state_${recordId}`;
      const data: string = JSON.stringify({ recordId, currentQuestion, answers, ts: Date.now() });
      AppStorage.setOrCreate<string>(key, data);
    } catch (error) {
    }
  }

  public loadExamState(recordId: number): Record<string, string> | undefined {
    try {
      const key: string = `exam_state_${recordId}`;
      const data: string | undefined = AppStorage.get<string>(key);
      if (data !== undefined && data.length > 0) {
        const parsed: Record<string, Object> = JSON.parse(data) as Record<string, Object>;
        const answersObj: Object | undefined = parsed['answers'];
        if (answersObj !== undefined) {
          return answersObj as Record<string, string>;
        }
      }
    } catch (error) {
    }
    return undefined;
  }

  public saveVideoPosition(sectionId: number, positionMs: number): void {
    try {
      const key: string = `video_pos_${sectionId}`;
      AppStorage.setOrCreate<number>(key, positionMs);
    } catch (error) {
    }
  }

  public loadVideoPosition(sectionId: number): number {
    try {
      const key: string = `video_pos_${sectionId}`;
      const pos: number | undefined = AppStorage.get<number>(key);
      if (pos !== undefined) return pos;
    } catch (error) {
    }
    return 0;
  }

  public clearState(prefix: string): void {
    try {
      AppStorage.setOrCreate<string>(prefix, '');
    } catch (error) {
    }
  }
}

export const distributedSync: DistributedSync = DistributedSync.getInstance();
