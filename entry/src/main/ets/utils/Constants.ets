// Path: entry/src/main/ets/utils/Constants.ets
// 全局常量定义，所有业务模块共享此文件中的常量

export class Constants {
  // 日志 Tag
  static readonly LOG_TAG: string = 'FaceCheck';

  // 数据库
  static readonly DB_NAME: string = 'FaceCheck.db';
  static readonly DB_VERSION: number = 1;

  // 沙箱目录
  static readonly FACE_IMAGES_DIR: string = 'faces';

  // AI 阈值
  static readonly SIMILARITY_THRESHOLD: number = 0.6;  // 人脸比对阈值 [0,1]，≥0.6 视为同一人

  // 活体检测配置
  static readonly LIVENESS_ACTIONS_NUM: number = 3;   // 随机动作数量（3 或 4）

  // 签到状态枚举
  static readonly STATUS_SIGN_SUCCESS: number = 1;     // 签到成功
  static readonly STATUS_LIVENESS_FAIL: number = 0;    // 活体检测失败
  static readonly STATUS_MATCH_FAIL: number = -1;      // 人脸比对失败

  // 错误码常量
  static readonly ERR_UNIQUE_CONSTRAINT: number = 1501307;  // SQLite UNIQUE 约束冲突
  static readonly ERR_FILE_EXIST: number = 13900002;        // 文件已存在
}
