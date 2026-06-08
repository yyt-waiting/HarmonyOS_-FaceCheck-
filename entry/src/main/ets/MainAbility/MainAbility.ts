// Path: entry/src/main/ets/MainAbility/MainAbility.ts
// MainAbility 入口：初始化数据库与主窗口加载

import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { initDatabase, destroyDatabase } from '../ets/database/DataManager';
import { logger } from '../ets/utils/Logger';

const TAG = 'MainAbility';

export default class MainAbility extends UIAbility {
  onCreate(want, param) {
    logger.info('MainAbility onCreate');
  }

  async onDestroy() {
    logger.info('MainAbility onDestroy');
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
