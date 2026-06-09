// Path: entry/src/main/ets/App.ets
// 全局应用入口：配置 aboutToAppear / aboutToDisappear 生命周期

import { logger } from '../utils/Logger';

@Entry
@Component
struct App {
  aboutToAppear() {
    logger.info('App aboutToAppear');
  }

  aboutToDisappear() {
    logger.info('App aboutToDisappear');
  }

  build() {
    // 实际 UI 由 MainAbility 中的 setUIContent 加载
  }
}
