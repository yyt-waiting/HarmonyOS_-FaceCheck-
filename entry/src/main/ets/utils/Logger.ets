// Path: entry/src/main/ets/utils/Logger.ets
// 统一日志输出工具，所有模块必须使用此类而非 console.log

import { hilog } from '@kit.PerformanceAnalysisKit';
import { Constants } from './Constants';

class Logger {
  private tag: string;

  constructor(tag: string = Constants.LOG_TAG) {
    this.tag = tag;
  }

  info(message: string, ...args: Object[]): void {
    hilog.info(0x0000, this.tag, message, ...args);
  }

  warn(message: string, ...args: Object[]): void {
    hilog.warn(0x0000, this.tag, message, ...args);
  }

  error(message: string, ...args: Object[]): void {
    hilog.error(0x0000, this.tag, message, ...args);
  }

  debug(message: string, ...args: Object[]): void {
    hilog.debug(0x0000, this.tag, message, ...args);
  }
}

export const logger = new Logger();
export default logger;
