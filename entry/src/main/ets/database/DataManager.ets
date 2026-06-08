// Path: entry/src/main/ets/database/DataManager.ets
// 数据库初始化与全局 RdbStore 管理

import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';

const TAG = 'DataManager';

/**
 * 数据库配置
 * - name: 数据库文件名（FaceCheck.db）
 * - securityLevel: 安全级别 S1（API 12 推荐）
 */
const STORE_CONFIG: relationalStore.StoreConfig = {
  name: Constants.DB_NAME,
  securityLevel: relationalStore.SecurityLevel.S1
};

/**
 * 建表 SQL：用户注册表
 * - id: 自增主键
 * - student_id: 学号（UNIQUE，确保不重复注册）
 * - user_name: 姓名
 * - face_uri: 沙箱人脸图片文件名（禁止存 PixelMap）
 * - gmt_create: 注册时间戳
 */
const SQL_CREATE_USER_TABLE = `
CREATE TABLE IF NOT EXISTS UserTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id TEXT UNIQUE NOT NULL,
  user_name TEXT NOT NULL,
  face_uri TEXT NOT NULL,
  gmt_create INTEGER NOT NULL
)`;

/**
 * 建表 SQL：签到记录表
 * - id: 自增主键
 * - student_id: 关联学号
 * - sign_time: 签到时间戳
 * - status: 签到状态（1=成功, 0=活体失败, -1=匹配失败）
 * - similarity: 人脸比对相似度得分
 */
const SQL_CREATE_SIGN_RECORD_TABLE = `
CREATE TABLE IF NOT EXISTS SignRecordTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id TEXT NOT NULL,
  sign_time INTEGER NOT NULL,
  status INTEGER NOT NULL,
  similarity REAL DEFAULT 0
)`;

/**
 * 全局 RdbStore 实例（单例模式）
 * 初始化前为 undefined，initDatabase() 后赋值
 */
let rdbStore: relationalStore.RdbStore | undefined = undefined;

/**
 * 初始化数据库：创建 RdbStore 并执行建表语句
 * 应用启动时调用一次，确保数据库和表结构已就绪
 * @param context 应用的 AbilityContext（通常传入 UIAbilityContext）
 */
async function initDatabase(context: Context): Promise<void> {
  try {
    // 获取或创建 RdbStore 实例
    rdbStore = await relationalStore.getRdbStore(context, STORE_CONFIG);
    logger.info('RDB store initialized: %{public}s', Constants.DB_NAME);

    // 执行建表语句（IF NOT EXISTS 防止重复创建）
    await rdbStore.executeSql(SQL_CREATE_USER_TABLE);
    logger.info('UserTable created or already exists');

    await rdbStore.executeSql(SQL_CREATE_SIGN_RECORD_TABLE);
    logger.info('SignRecordTable created or already exists');
  } catch (err) {
    const error = err as BusinessError;
    logger.error('initDatabase failed: code=%{public}d, message=%{public}s',
      error.code, error.message);
    throw err;
  }
}

/**
 * 获取全局 RdbStore 实例（供 CRUD 操作使用）
 * 调用前必须确保已执行 initDatabase()
 * @throws Error 如果数据库未初始化
 */
function getRdbStore(): relationalStore.RdbStore {
  if (!rdbStore) {
    throw new Error('Database not initialized, call initDatabase() first');
  }
  return rdbStore;
}

/**
 * 销毁数据库连接（应用退出时调用）
 * 释放 RDB 资源，防止内存泄漏
 * @param context 应用的 AbilityContext
 */
async function destroyDatabase(context: Context): Promise<void> {
  if (rdbStore) {
    await relationalStore.deleteRdbStore(context, Constants.DB_NAME);
    rdbStore = undefined;
    logger.info('RDB store destroyed');
  }
}

export { initDatabase, getRdbStore, destroyDatabase };
