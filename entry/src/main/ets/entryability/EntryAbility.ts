// Path: entry/src/main/ets/entryability/EntryAbility.ts
// Entry Ability 入口：初始化数据库与主窗口加载

import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { initDatabase, destroyDatabase } from '../database/DataManager';
import { logger } from '../utils/Logger';

const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want, param) {
    logger.info('EntryAbility onCreate');
  }

  async onDestroy() {
    logger.info('EntryAbility onDestroy');
    try {
      await destroyDatabase(this.context);
    } catch (err) {
      logger.error('destroyDatabase failed: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    // 加载主页面前先初始化数据库
    this.initAndLoadIndex(windowStage);
  }

  private async initAndLoadIndex(windowStage: window.WindowStage): Promise<void> {
    try {
      await initDatabase(this.context);
      logger.info('Database initialized successfully');

      windowStage.setUIContent(this.context, 'pages/Index', null);
    } catch (err) {
      logger.error('Failed to init database: %{public}s', JSON.stringify(err));
      // 即使 DB 初始化失败也尝试加载页面（部分功能降级）
      windowStage.setUIContent(this.context, 'pages/Index', null);
    }
  }
}
