import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { api } from '../common/ApiClient';

interface LocalProgress {
  courseId: number;
  percent: number;
  chapterId: number;
  timestamp: number;
}

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'SmartLearn.db',
  securityLevel: relationalStore.SecurityLevel.S1,
};

const CREATE_PROGRESS_TABLE: string = `
  CREATE TABLE IF NOT EXISTS local_progress (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    course_id INTEGER NOT NULL,
    percent REAL NOT NULL,
    chapter_id INTEGER DEFAULT 0,
    timestamp INTEGER NOT NULL,
    synced INTEGER DEFAULT 0
  )
`;

export class LocalDb {
  private rdbStore: relationalStore.RdbStore | undefined = undefined;
  private memoryQueue: LocalProgress[] = [];
  private initialized: boolean = false;

  public async init(context: common.UIAbilityContext): Promise<void> {
    if (this.initialized) return;
    try {
      this.rdbStore = await relationalStore.getRdbStore(context, STORE_CONFIG);
      await this.rdbStore.executeSql(CREATE_PROGRESS_TABLE);
      this.initialized = true;
      await this.flushUnsynced();
    } catch (error) {
      this.initialized = false;
    }
  }

  public async enqueueProgress(courseId: number, percent: number, chapterId: number): Promise<void> {
    const item: LocalProgress = { courseId, percent, chapterId, timestamp: Date.now() };
    this.memoryQueue.push(item);
    if (this.rdbStore !== undefined) {
      try {
        const valueBucket: relationalStore.ValuesBucket = {
          'course_id': courseId,
          'percent': percent,
          'chapter_id': chapterId,
          'timestamp': item.timestamp,
          'synced': 0,
        };
        await this.rdbStore.insert('local_progress', valueBucket);
      } catch (error) {
      }
    }
  }

  public async flushProgress(): Promise<number> {
    if (this.memoryQueue.length === 0) return 0;
    const batch: LocalProgress[] = this.memoryQueue.splice(0, this.memoryQueue.length);
    let flushed: number = 0;
    for (let i: number = 0; i < batch.length; i += 1) {
      const item: LocalProgress = batch[i];
      try {
        await api.updateProgress(item.courseId, item.percent, item.chapterId);
        if (this.rdbStore !== undefined) {
          const valueBucket: relationalStore.ValuesBucket = { 'synced': 1 };
          const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('local_progress');
          predicates.equalTo('timestamp', item.timestamp).and().equalTo('course_id', item.courseId);
          await this.rdbStore.update(valueBucket, predicates);
        }
        flushed += 1;
      } catch (error) {
        this.memoryQueue.push(item);
      }
    }
    return flushed;
  }

  public async flushUnsynced(): Promise<number> {
    if (this.rdbStore === undefined) return 0;
    try {
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('local_progress');
      predicates.equalTo('synced', 0).orderByAsc('timestamp');
      const resultSet: relationalStore.ResultSet = await this.rdbStore.query(predicates);
      const items: LocalProgress[] = [];
      while (resultSet.goToNextRow()) {
        const item: LocalProgress = {
          courseId: resultSet.getLong(resultSet.getColumnIndex('course_id')),
          percent: resultSet.getDouble(resultSet.getColumnIndex('percent')),
          chapterId: resultSet.getLong(resultSet.getColumnIndex('chapter_id')),
          timestamp: resultSet.getLong(resultSet.getColumnIndex('timestamp')),
        };
        items.push(item);
      }
      resultSet.close();

      let flushed: number = 0;
      for (let i: number = 0; i < items.length; i += 1) {
        const item: LocalProgress = items[i];
        try {
          await api.updateProgress(item.courseId, item.percent, item.chapterId);
          const updateBucket: relationalStore.ValuesBucket = { 'synced': 1 };
          const updatePred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('local_progress');
          updatePred.equalTo('timestamp', item.timestamp).and().equalTo('course_id', item.courseId);
          await this.rdbStore.update(updateBucket, updatePred);
          flushed += 1;
        } catch (error) {
        }
      }
      return flushed;
    } catch (error) {
      return 0;
    }
  }

  public async cleanSynced(): Promise<void> {
    if (this.rdbStore === undefined) return;
    try {
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('local_progress');
      predicates.equalTo('synced', 1);
      await this.rdbStore.delete(predicates);
    } catch (error) {
    }
  }

  public getPendingCount(): number {
    return this.memoryQueue.length;
  }
}

export const localDb: LocalDb = new LocalDb();
