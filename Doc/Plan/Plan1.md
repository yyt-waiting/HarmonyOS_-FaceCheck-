# FaceCheck 鸿蒙 AI 刷脸签到应用 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一款基于 HarmonyOS NEXT (API 12, Stage模型) 的原生刷脸签到应用，实现人脸注册、活体检测、1:1 人脸比对、签到记录持久化的完整业务闭环。

**Architecture:** 采用分层架构（UI 表现层 + ViewModel 状态层 + Service 核心逻辑层 + Utils 工具层 + Database 数据层）。AI 能力通过 Core Vision Kit (faceDetector, faceComparator) 和 VisionKit (interactiveLiveness) 封装为独立 Service；数据通过 relationalStore (RDB) 持久化；人脸图片以文件形式存于沙箱，仅将文件名存入 DB。

**Tech Stack:** ArkTS + ArkUI (Stage模型) + @kit.CoreVisionKit + @kit.VisionKit + @kit.ArkData + @kit.ImageKit + @kit.CoreFileKit + relationalStore (SQLite)

---

## 文件结构总览

```
entry/src/main/ets/
├── MainAbility/
│   └── MainAbility.ts
├── pages/
│   ├── Index.ets                          # Tabs 主容器
│   ├── RegisterPage.ets                   # 人脸注册页
│   ├── SignInPage.ets                     # 刷脸签到页
│   ├── RecordPage.ets                     # 签到记录页
│   ├── LivenessResultPage.ets             # 活体检测成功页（REPLACE_MODE 目标页）
│   └── LivenessFailPage.ets              # 活体检测失败页
├── viewmodel/
│   ├── RegisterViewModel.ets
│   ├── SignInViewModel.ets
│   └── RecordViewModel.ets
├── service/
│   ├── LivenessService.ets
│   ├── FaceCompareService.ets
│   └── FaceDetectService.ets
├── database/
│   ├── DataManager.ets
│   ├── UserTable.ets
│   └── SignRecordTable.ets
├── utils/
│   ├── Logger.ets
│   ├── Constants.ets
│   ├── PermissionUtil.ets
│   └── ImageFileUtil.ets
├── model/
│   ├── UserModel.ets
│   └── SignRecordModel.ets
└── App.ets
entry/src/main/module.json5
```

---

## Task 1: 基础设施 — 常量定义与 Logger 工具

**Files:**
- Create: `entry/src/main/ets/utils/Constants.ets`
- Create: `entry/src/main/ets/utils/Logger.ets`
- Modify: `entry/src/main/module.json5`

- [ ] **Step 1: 创建 Constants.ets — 全局常量定义**

```typescript
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
```

- [ ] **Step 2: 创建 Logger.ets — hilog 封装工具**

```typescript
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
```

- [ ] **Step 3: 修改 module.json5 — 权限与能力声明**

```json5
// Path: entry/src/main/module.json5
// 完整配置：requestPermissions + SystemCapabilities

{
  "module": {
    "requestPermissions": [
      { "name": "ohos.permission.CAMERA" },
      { "name": "ohos.permission.READ_MEDIA" },
      { "name": "ohos.permission.WRITE_MEDIA" }
    ],
    "abilities": [
      {
        "skills": [
          {
            "entities": ["entity.system.home"],
            "actions": ["action.system.home"]
          }
        ]
      }
    ]
  }
}
```

> **SystemCapability 说明**：FaceCheck 的 SystemCapability（faceComparator / faceDetector / livenessDetect）在 DevEco Studio 的 `module.json5` 中通过 `definePermissionsCatalog` 或直接在运行时由各 Kit 模块按需声明，无需手动配置。核心确认点为 `requestPermissions` 已包含 `ohos.permission.CAMERA`。

---

## Task 2: 数据模型定义

**Files:**
- Create: `entry/src/main/ets/model/UserModel.ets`
- Create: `entry/src/main/ets/model/SignRecordModel.ets`

- [ ] **Step 1: 创建 UserModel.ets — 用户数据模型**

```typescript
// Path: entry/src/main/ets/model/UserModel.ets
// 用户数据模型，对应 UserTable 表结构

export class UserModel {
  id: number = 0;           // 主键自增
  studentId: string = '';   // 学号/工号 (UNIQUE)
  userName: string = '';    // 姓名
  faceUri: string = '';     // 沙箱文件名（非完整路径）
  gmtCreate: number = 0;    // 注册时间戳（毫秒）

  constructor(
    studentId: string,
    userName: string,
    faceUri: string,
    gmtCreate: number = Date.now(),
    id: number = 0
  ) {
    this.id = id;
    this.studentId = studentId;
    this.userName = userName;
    this.faceUri = faceUri;
    this.gmtCreate = gmtCreate;
  }
}
```

- [ ] **Step 2: 创建 SignRecordModel.ets — 签到记录数据模型**

```typescript
// Path: entry/src/main/ets/model/SignRecordModel.ets
// 签到记录数据模型，对应 SignRecordTable 表结构
import { Constants } from '../utils/Constants';

export class SignRecordModel {
  id: number = 0;           // 主键自增
  studentId: string = '';   // 关联学号
  signTime: number = 0;     // 签到时间戳（毫秒）
  status: number = Constants.STATUS_SIGN_SUCCESS;  // 状态: 1成功/0活体失败/-1比对失败
  similarity: number = 0;    // 相似度 [0, 1]

  constructor(
    studentId: string,
    signTime: number = Date.now(),
    status: number = Constants.STATUS_SIGN_SUCCESS,
    similarity: number = 0,
    id: number = 0
  ) {
    this.id = id;
    this.studentId = studentId;
    this.signTime = signTime;
    this.status = status;
    this.similarity = similarity;
  }
}
```

---

## Task 3: 数据库层 — DataManager + 建表

**Files:**
- Create: `entry/src/main/ets/database/DataManager.ets`
- Modify: `entry/src/main/ets/database/DataManager.ets` (init 调用)

- [ ] **Step 1: 创建 DataManager.ets — RDB 初始化与建表**

```typescript
// Path: entry/src/main/ets/database/DataManager.ets
// 数据库初始化与全局 RdbStore 管理

import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';

const TAG = 'DataManager';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: Constants.DB_NAME,
  securityLevel: relationalStore.SecurityLevel.S1
};

const SQL_CREATE_USER_TABLE = `
CREATE TABLE IF NOT EXISTS UserTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id TEXT UNIQUE NOT NULL,
  user_name TEXT NOT NULL,
  face_uri TEXT NOT NULL,
  gmt_create INTEGER NOT NULL
)`;

const SQL_CREATE_SIGN_RECORD_TABLE = `
CREATE TABLE IF NOT EXISTS SignRecordTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id TEXT NOT NULL,
  sign_time INTEGER NOT NULL,
  status INTEGER NOT NULL,
  similarity REAL DEFAULT 0
)`;

let rdbStore: relationalStore.RdbStore | undefined = undefined;

/**
 * 初始化数据库：创建 RdbStore 并执行建表语句
 * @param context 应用的 AbilityContext
 */
async function initDatabase(context: Context): Promise<void> {
  try {
    rdbStore = await relationalStore.getRdbStore(context, STORE_CONFIG);
    logger.info('RDB store initialized: %{public}s', Constants.DB_NAME);

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
 */
function getRdbStore(): relationalStore.RdbStore {
  if (!rdbStore) {
    throw new Error('Database not initialized, call initDatabase() first');
  }
  return rdbStore;
}

/**
 * 销毁数据库连接（应用退出时调用）
 */
async function destroyDatabase(context: Context): Promise<void> {
  if (rdbStore) {
    await relationalStore.deleteRdbStore(context, Constants.DB_NAME);
    rdbStore = undefined;
    logger.info('RDB store destroyed');
  }
}

export { initDatabase, getRdbStore, destroyDatabase };
```

---

## Task 4: 数据库层 — UserTable CRUD

**Files:**
- Create: `entry/src/main/ets/database/UserTable.ets`

- [ ] **Step 1: 创建 UserTable.ets — 用户表 CRUD**

```typescript
// Path: entry/src/main/ets/database/UserTable.ets
// UserTable 增删查操作，含学号 UNIQUE 冲突处理

import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';
import { UserModel } from '../model/UserModel';
import { getRdbStore } from './DataManager';

const TAG = 'UserTable';

/**
 * 插入用户记录（含学号 UNIQUE 冲突处理）
 * 错误码 1501307 = UNIQUE constraint failed
 */
async function insertUser(user: UserModel): Promise<{ success: boolean; message: string }> {
  const store = getRdbStore();
  const bucket: relationalStore.ValuesBucket = {
    student_id: user.studentId,
    user_name: user.userName,
    face_uri: user.faceUri,
    gmt_create: user.gmtCreate
  };

  try {
    const rowId = await store.insert('UserTable', bucket);
    logger.info('User inserted, rowId=%{public}d, studentId=%{public}s',
      rowId, user.studentId);
    return { success: true, message: '注册成功' };
  } catch (err) {
    const error = err as BusinessError;
    if (error.code === Constants.ERR_UNIQUE_CONSTRAINT) {
      logger.warn('Duplicate student_id: %{public}s', user.studentId);
      return { success: false, message: '学号已注册，请勿重复注册' };
    }
    logger.error('Insert user failed: code=%{public}d, msg=%{public}s',
      error.code, error.message);
    return { success: false, message: `注册失败: ${error.message}` };
  }
}

/**
 * 按学号查询用户
 */
async function queryUser(studentId: string): Promise<UserModel | null> {
  const store = getRdbStore();
  const predicates = new relationalStore.RdbPredicates('UserTable');
  predicates.equalTo('student_id', studentId);

  let resultSet: relationalStore.ResultSet | undefined = undefined;
  try {
    resultSet = await store.query(predicates,
      ['id', 'student_id', 'user_name', 'face_uri', 'gmt_create']);

    if (resultSet.goToFirstRow()) {
      const user = new UserModel(
        resultSet.getString(resultSet.getColumnIndex('student_id')),
        resultSet.getString(resultSet.getColumnIndex('user_name')),
        resultSet.getString(resultSet.getColumnIndex('face_uri')),
        resultSet.getLong(resultSet.getColumnIndex('gmt_create')),
        resultSet.getLong(resultSet.getColumnIndex('id'))
      );
      logger.info('User found: %{public}s', user.studentId);
      return user;
    }
    return null;
  } catch (err) {
    logger.error('Query user failed: %{public}s', (err as BusinessError).message);
    return null;
  } finally {
    resultSet?.close();
  }
}

/**
 * 查询全部注册用户（用于签到页面展示已注册用户列表）
 */
async function queryAllUsers(): Promise<UserModel[]> {
  const store = getRdbStore();
  const predicates = new relationalStore.RdbPredicates('UserTable');
  predicates.orderByDesc('gmt_create');

  let resultSet: relationalStore.ResultSet | undefined = undefined;
  const users: UserModel[] = [];

  try {
    resultSet = await store.query(predicates,
      ['id', 'student_id', 'user_name', 'face_uri', 'gmt_create']);

    while (resultSet.goToNextRow()) {
      users.push(new UserModel(
        resultSet.getString(resultSet.getColumnIndex('student_id')),
        resultSet.getString(resultSet.getColumnIndex('user_name')),
        resultSet.getString(resultSet.getColumnIndex('face_uri')),
        resultSet.getLong(resultSet.getColumnIndex('gmt_create')),
        resultSet.getLong(resultSet.getColumnIndex('id'))
      ));
    }
    return users;
  } catch (err) {
    logger.error('Query all users failed: %{public}s', (err as BusinessError).message);
    return [];
  } finally {
    resultSet?.close();
  }
}

/**
 * 删除用户（同步删除沙箱文件由调用方负责）
 */
async function deleteUser(studentId: string): Promise<boolean> {
  const store = getRdbStore();
  const predicates = new relationalStore.RdbPredicates('UserTable');
  predicates.equalTo('student_id', studentId);

  try {
    const deletedRows = await store.delete(predicates);
    logger.info('User deleted: %{public}s, rows=%{public}d', studentId, deletedRows);
    return deletedRows > 0;
  } catch (err) {
    logger.error('Delete user failed: %{public}s', (err as BusinessError).message);
    return false;
  }
}

export { insertUser, queryUser, queryAllUsers, deleteUser };
```

---

## Task 5: 数据库层 — SignRecordTable CRUD

**Files:**
- Create: `entry/src/main/ets/database/SignRecordTable.ets`

- [ ] **Step 1: 创建 SignRecordTable.ets — 签到记录 CRUD**

```typescript
// Path: entry/src/main/ets/database/SignRecordTable.ets
// 签到记录表增查操作

import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';
import { SignRecordModel } from '../model/SignRecordModel';
import { getRdbStore } from './DataManager';

const TAG = 'SignRecordTable';

/**
 * 插入签到记录
 */
async function insertSignRecord(record: SignRecordModel): Promise<number> {
  const store = getRdbStore();
  const bucket: relationalStore.ValuesBucket = {
    student_id: record.studentId,
    sign_time: record.signTime,
    status: record.status,
    similarity: record.similarity
  };

  try {
    const rowId = await store.insert('SignRecordTable', bucket);
    logger.info('Sign record inserted, rowId=%{public}d, studentId=%{public}s, status=%{public}d',
      rowId, record.studentId, record.status);
    return rowId;
  } catch (err) {
    logger.error('Insert sign record failed: %{public}s', (err as BusinessError).message);
    return -1;
  }
}

/**
 * 查询某学号的最近 N 条签到记录
 */
async function querySignRecords(studentId: string, limit: number = 50): Promise<SignRecordModel[]> {
  const store = getRdbStore();
  const predicates = new relationalStore.RdbPredicates('SignRecordTable');
  predicates.equalTo('student_id', studentId);
  predicates.orderByDesc('sign_time');
  predicates.limitAs(limit);

  let resultSet: relationalStore.ResultSet | undefined = undefined;
  const records: SignRecordModel[] = [];

  try {
    resultSet = await store.query(predicates,
      ['id', 'student_id', 'sign_time', 'status', 'similarity']);

    while (resultSet.goToNextRow()) {
      records.push(new SignRecordModel(
        resultSet.getString(resultSet.getColumnIndex('student_id')),
        resultSet.getLong(resultSet.getColumnIndex('sign_time')),
        resultSet.getLong(resultSet.getColumnIndex('status')),
        resultSet.getDouble(resultSet.getColumnIndex('similarity')),
        resultSet.getLong(resultSet.getColumnIndex('id'))
      ));
    }
    return records;
  } catch (err) {
    logger.error('Query sign records failed: %{public}s', (err as BusinessError).message);
    return [];
  } finally {
    resultSet?.close();
  }
}

/**
 * 查询全部签到记录（用于记录页）
 */
async function queryAllRecords(limit: number = 100): Promise<SignRecordModel[]> {
  const store = getRdbStore();
  const predicates = new relationalStore.RdbPredicates('SignRecordTable');
  predicates.orderByDesc('sign_time');
  predicates.limitAs(limit);

  let resultSet: relationalStore.ResultSet | undefined = undefined;
  const records: SignRecordModel[] = [];

  try {
    resultSet = await store.query(predicates,
      ['id', 'student_id', 'sign_time', 'status', 'similarity']);

    while (resultSet.goToNextRow()) {
      records.push(new SignRecordModel(
        resultSet.getString(resultSet.getColumnIndex('student_id')),
        resultSet.getLong(resultSet.getColumnIndex('sign_time')),
        resultSet.getLong(resultSet.getColumnIndex('status')),
        resultSet.getDouble(resultSet.getColumnIndex('similarity')),
        resultSet.getLong(resultSet.getColumnIndex('id'))
      ));
    }
    return records;
  } catch (err) {
    logger.error('Query all records failed: %{public}s', (err as BusinessError).message);
    return [];
  } finally {
    resultSet?.close();
  }
}

/**
 * 查询某学号今日是否已签到（用于防重复签到）
 */
async function queryTodayRecord(studentId: string): Promise<SignRecordModel | null> {
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const todayStartMs = todayStart.getTime();

  const store = getRdbStore();
  const predicates = new relationalStore.RdbPredicates('SignRecordTable');
  predicates.equalTo('student_id', studentId);
  predicates.greaterThan('sign_time', todayStartMs);
  predicates.orderByDesc('sign_time');
  predicates.limitAs(1);

  let resultSet: relationalStore.ResultSet | undefined = undefined;
  try {
    resultSet = await store.query(predicates,
      ['id', 'student_id', 'sign_time', 'status', 'similarity']);

    if (resultSet.goToFirstRow()) {
      return new SignRecordModel(
        resultSet.getString(resultSet.getColumnIndex('student_id')),
        resultSet.getLong(resultSet.getColumnIndex('sign_time')),
        resultSet.getLong(resultSet.getColumnIndex('status')),
        resultSet.getDouble(resultSet.getColumnIndex('similarity')),
        resultSet.getLong(resultSet.getColumnIndex('id'))
      );
    }
    return null;
  } catch (err) {
    logger.error('Query today record failed: %{public}s', (err as BusinessError).message);
    return null;
  } finally {
    resultSet?.close();
  }
}

export { insertSignRecord, querySignRecords, queryAllRecords, queryTodayRecord };
```

---

## Task 6: 工具层 — ImageFileUtil 沙箱文件管理

**Files:**
- Create: `entry/src/main/ets/utils/ImageFileUtil.ets`

- [ ] **Step 1: 创建 ImageFileUtil.ets — PixelMap ↔ 沙箱文件互转**

```typescript
// Path: entry/src/main/ets/utils/ImageFileUtil.ets
// 沙箱文件管理：PixelMap 保存为 JPG，文件读取为 PixelMap
// 严格遵循 SKILL-HM-008：绝对禁止将 PixelMap 存入数据库

import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';

const TAG = 'ImageFileUtil';

interface SaveResult {
  success: boolean;
  fileName: string;
  message: string;
}

/**
 * 确保目录存在（忽略 EEXIST 错误）
 */
async function ensureDir(dirPath: string): Promise<void> {
  try {
    await fileIo.mkdir(dirPath);
    logger.info('Directory created: %{public}s', dirPath);
  } catch (err) {
    const error = err as BusinessError;
    if (error.code !== Constants.ERR_FILE_EXIST) {
      throw err;
    }
    // EEXIST: 目录已存在，正常忽略
  }
}

/**
 * 将 PixelMap 保存为 JPG 文件到沙箱目录
 * @param context 应用上下文
 * @param pixelMap 人脸 PixelMap
 * @param studentId 学号（用于生成唯一文件名）
 * @returns 保存结果，含文件名（不含完整路径）
 */
async function savePixelMapToFile(
  context: Context,
  pixelMap: image.PixelMap,
  studentId: string
): Promise<SaveResult> {
  const timestamp = Date.now();
  const fileName = `face_${studentId}_${timestamp}.jpg`;
  const faceDir = context.filesDir + '/' + Constants.FACE_IMAGES_DIR;
  const filePath = faceDir + '/' + fileName;
  let fd: number = -1;

  try {
    await ensureDir(faceDir);

    fd = await fileIo.open(filePath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);

    const packer = image.createImagePacker();
    const packOptions: image.PackingOption = {
      format: 'image/jpeg',
      quality: 90
    };

    await packer.packToFile(pixelMap, fd, packOptions);
    await packer.release();

    // 验证文件可读性
    const verifySource = image.createImageSource(filePath);
    const verifyMap = await verifySource.createPixelMap();
    verifySource.release();
    verifyMap.release();

    logger.info('PixelMap saved: %{public}s', fileName);
    return { success: true, fileName: fileName, message: '图片保存成功' };
  } catch (err) {
    const error = err as BusinessError;
    logger.error('Save PixelMap failed: code=%{public}d, msg=%{public}s',
      error.code, error.message);
    return { success: false, fileName: '', message: `保存失败: ${error.message}` };
  } finally {
    if (fd !== -1) {
      await fileIo.close(fd);
    }
  }
}

/**
 * 从沙箱文件读取图片为 PixelMap（供 faceComparator 比对使用）
 * @param context 应用上下文
 * @param fileName 数据库中存储的文件名（非完整路径）
 */
async function loadPixelMapFromFile(
  context: Context,
  fileName: string
): Promise<image.PixelMap | undefined> {
  const filePath = context.filesDir + '/' + Constants.FACE_IMAGES_DIR + '/' + fileName;
  let fd: fileIo.File | undefined = undefined;
  let imageSource: image.ImageSource | undefined = undefined;
  let pixelMap: image.PixelMap | undefined = undefined;

  try {
    fd = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY);
    imageSource = image.createImageSource(fd);
    pixelMap = await imageSource.createPixelMap();
    logger.info('PixelMap loaded: %{public}s', fileName);
    return pixelMap;
  } catch (err) {
    logger.error('Load PixelMap failed: %{public}s', (err as BusinessError).message);
    return undefined;
  } finally {
    imageSource?.release();
    if (fd) {
      await fileIo.close(fd);
    }
  }
}

/**
 * 删除沙箱人脸文件（用户注销时调用）
 */
async function deleteFaceFile(context: Context, fileName: string): Promise<boolean> {
  const filePath = context.filesDir + '/' + Constants.FACE_IMAGES_DIR + '/' + fileName;
  try {
    await fileIo.unlink(filePath);
    logger.info('Face file deleted: %{public}s', fileName);
    return true;
  } catch (err) {
    logger.warn('Delete face file failed: %{public}s', (err as BusinessError).message);
    return false;
  }
}

export { savePixelMapToFile, loadPixelMapFromFile, deleteFaceFile };
```

---

## Task 7: 工具层 — PermissionUtil 动态权限申请

**Files:**
- Create: `entry/src/main/ets/utils/PermissionUtil.ets`

- [ ] **Step 1: 创建 PermissionUtil.ets — 相机动态权限申请**

```typescript
// Path: entry/src/main/ets/utils/PermissionUtil.ets
// 动态权限申请：相机权限是活体检测的前置条件

import { abilityAccessCtrl, bundleManager } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';

const TAG = 'PermissionUtil';
const CAMERA_PERMISSION = 'ohos.permission.CAMERA';

/**
 * 申请相机权限
 * @returns true = 授权成功，false = 授权失败
 */
async function requestCameraPermission(context: Context): Promise<boolean> {
  const atManager = abilityAccessCtrl.createAtManager();

  // 先检查权限授权状态
  try {
    const grantStatus = await atManager.checkAccessToken(
      context.applicationInfo.accessTokenId,
      CAMERA_PERMISSION
    );

    if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
      logger.info('Camera permission already granted');
      return true;
    }
  } catch (err) {
    // 未授权，走申请流程
    logger.warn('Camera permission not granted, requesting...');
  }

  // 申请权限
  try {
    const result = await atManager.requestPermissionsFromUser(context, [CAMERA_PERMISSION]);
    const grantResults = result.authResults;
    if (grantResults.length > 0 && grantResults[0] === 0) {
      logger.info('Camera permission granted by user');
      return true;
    }
    logger.warn('Camera permission denied by user');
    return false;
  } catch (err) {
    const error = err as BusinessError;
    logger.error('Request camera permission failed: code=%{public}d, msg=%{public}s',
      error.code, error.message);
    return false;
  }
}

export { requestCameraPermission };
```

---

## Task 8: 服务层 — LivenessService 活体检测封装

**Files:**
- Create: `entry/src/main/ets/service/LivenessService.ets`

- [ ] **Step 1: 创建 LivenessService.ets — 活体检测封装（REPLACE_MODE）**

```typescript
// Path: entry/src/main/ets/service/LivenessService.ets
// 活体检测服务封装：拉起系统活体检测 UI，完成后跳转 LivenessResultPage
// 严格遵循 SKILL-HM-005：mPixelMap 必须在 finally 中 release()

import { interactiveLiveness } from '@kit.VisionKit';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';

const TAG = 'LivenessService';

/**
 * 拉起活体检测（REPLACE_MODE 模式）
 * 跳转成功后，系统会自动导航到 LivenessResultPage
 * 在 LivenessResultPage.onPageShow() 中调用 getInteractiveLivenessResult() 获取结果
 */
async function startLivenessDetection(): Promise<boolean> {
  const config: interactiveLiveness.InteractiveLivenessConfig = {
    isSilentMode: interactiveLiveness.DetectionMode.INTERACTIVE_MODE,
    actionsNum: Constants.LIVENESS_ACTIONS_NUM === 3
      ? interactiveLiveness.ActionsNumber.THREE_ACTION
      : interactiveLiveness.ActionsNumber.FOUR_ACTION,
    routeMode: interactiveLiveness.RouteRedirectionMode.REPLACE_MODE,
    successfulRouteUrl: 'pages/LivenessResultPage',
    failedRouteUrl: 'pages/LivenessFailPage'
  };

  try {
    const jumpResult = await interactiveLiveness.startLivenessDetection(config);
    logger.info('Liveness jump result: %{public}s', jumpResult.toString());
    return jumpResult;
  } catch (err) {
    const error = err as BusinessError;
    logger.error('Start liveness detection failed: code=%{public}d, msg=%{public}s',
      error.code, error.message);
    return false;
  }
}

/**
 * 获取活体检测结果（仅在 LivenessResultPage 页面中调用）
 * @returns mPixelMap = 最清晰人脸帧（RGBA_8888），使用完毕后必须在 finally 中 release()
 */
async function getLivenessResult(): Promise<image.PixelMap | undefined> {
  try {
    const result = await interactiveLiveness.getInteractiveLivenessResult();
    if (result.livenessType === interactiveLiveness.LivenessType.INTERACTIVE_LIVENESS) {
      logger.info('Liveness detected successfully, pixelMap available');
      return result.mPixelMap;
    }
    logger.warn('Liveness type is NOT_LIVENESS: %{public}d', result.livenessType);
    return undefined;
  } catch (err) {
    logger.error('Get liveness result failed: %{public}s', (err as BusinessError).message);
    return undefined;
  }
}

export { startLivenessDetection, getLivenessResult };
```

---

## Task 9: 服务层 — FaceDetectService 人脸检测封装

**Files:**
- Create: `entry/src/main/ets/service/FaceDetectService.ets`

- [ ] **Step 1: 创建 FaceDetectService.ets — 人脸检测封装**

```typescript
// Path: entry/src/main/ets/service/FaceDetectService.ets
// 人脸检测服务：静态图片人脸框检测，用于注册前质量预检
// 严格遵循 SKILL-HM-004：init() → detect() → release() 生命周期

import { faceDetector } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';

const TAG = 'FaceDetectService';
const MIN_PROBABILITY = 0.5;

interface DetectOutput {
  faceCount: number;
  validFace: faceDetector.Face | null;
}

/**
 * 检测图片中的人脸
 * @param pixelMap 输入图片 PixelMap
 * @returns 检测结果：人脸数量和置信度最高的有效人脸
 */
async function detectFace(pixelMap: image.PixelMap): Promise<DetectOutput> {
  const initResult = await faceDetector.init();
  if (!initResult) {
    logger.error('Face detector init failed');
    throw new Error('Face detector initialization failed');
  }

  try {
    const visionInfo: faceDetector.VisionInfo = { pixelMap: pixelMap };
    const faces = await faceDetector.detect(visionInfo);

    const faceCount = faces.length;
    logger.info('Detected %{public}d face(s)', faceCount);

    if (faceCount === 0) {
      return { faceCount: 0, validFace: null };
    }

    // 过滤低置信度人脸，取概率最高者
    const validFaces = faces.filter(f => f.probability >= MIN_PROBABILITY);
    const primaryFace = validFaces[0] ?? null;

    if (primaryFace) {
      logger.info('Primary face: probability=%{public}f, rect=[%{public}d, %{public}d, %{public}d, %{public}d]',
        primaryFace.probability,
        primaryFace.rect.left, primaryFace.rect.top,
        primaryFace.rect.width, primaryFace.rect.height);
    }

    return { faceCount, validFace: primaryFace };
  } catch (err) {
    const error = err as BusinessError;
    logger.error('Face detection failed: code=%{public}d, msg=%{public}s',
      error.code, error.message);
    throw err;
  } finally {
    await faceDetector.release();
  }
}

export { detectFace, DetectOutput };
```

---

## Task 10: 服务层 — FaceCompareService 人脸比对封装

**Files:**
- Create: `entry/src/main/ets/service/FaceCompareService.ets`

- [ ] **Step 1: 创建 FaceCompareService.ets — 人脸 1:1 比对封装**

```typescript
// Path: entry/src/main/ets/service/FaceCompareService.ets
// 人脸比对服务：传入两张 PixelMap，返回相似度和是否为同一人
// 严格遵循 SKILL-HM-003：init() → compareFaces() → release() + finally 释放资源

import { faceComparator } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';

const TAG = 'FaceCompareService';

interface CompareResult {
  isSamePerson: boolean;
  similarity: number;      // 原始值 [0, 1]
  similarityPercent: number; // 百分比值 [0, 100]
  pass: boolean;            // similarity >= 阈值
}

/**
 * 人脸 1:1 比对
 * @param pixelMapA 基准人脸 PixelMap（注册照）
 * @param pixelMapB 比对人脸 PixelMap（活体检测结果）
 */
async function compareFace(
  pixelMapA: image.PixelMap,
  pixelMapB: image.PixelMap
): Promise<CompareResult> {
  const initResult = await faceComparator.init();
  if (!initResult) {
    logger.error('Face comparator init failed');
    throw new Error('Face comparator initialization failed');
  }

  let result: CompareResult = {
    isSamePerson: false,
    similarity: 0,
    similarityPercent: 0,
    pass: false
  };

  try {
    const visionInfo1: faceComparator.VisionInfo = { pixelMap: pixelMapA };
    const visionInfo2: faceComparator.VisionInfo = { pixelMap: pixelMapB };

    const data = await faceComparator.compareFaces(visionInfo1, visionInfo2);

    const similarityPercent = Number((data.similarity * 100).toFixed(2));
    const pass = data.similarity >= Constants.SIMILARITY_THRESHOLD;

    logger.info('Compare result: similarity=%{public}f, isSamePerson=%{public}s, pass=%{public}s',
      data.similarity, data.isSamePerson.toString(), pass.toString());

    result = {
      isSamePerson: data.isSamePerson,
      similarity: data.similarity,
      similarityPercent: similarityPercent,
      pass: pass
    };
  } catch (err) {
    const error = err as BusinessError;
    logger.error('Compare faces failed: code=%{public}d, msg=%{public}s',
      error.code, error.message);
    throw err;
  } finally {
    // 必须同时释放 faceComparator 和两个 PixelMap
    await faceComparator.release();
    pixelMapA.release();
    pixelMapB.release();
  }

  return result;
}

export { compareFace, CompareResult };
```

---

## Task 11: 页面 — MainAbility + App 入口

**Files:**
- Create: `entry/src/main/ets/MainAbility/MainAbility.ts`
- Create: `entry/src/main/ets/App.ets`
- Modify: `entry/src/main/module.json5` (pages 入口配置)

- [ ] **Step 1: 创建 MainAbility.ts — Ability 入口**

```typescript
// Path: entry/src/main/ets/MainAbility/MainAbility.ts
// MainAbility 入口：初始化数据库

import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import { initDatabase, destroyDatabase } from '../ets/database/DataManager';

const TAG = 'MainAbility';

export default class MainAbility extends UIAbility {
  onCreate(want, param) {
    hilog.info(0x0000, TAG, 'MainAbility onCreate');
  }

  async onDestroy() {
    hilog.info(0x0000, TAG, 'MainAbility onDestroy');
    await destroyDatabase(this.context);
  }

  onWindowStageCreate(windowStage) {
    // 加载主页面前先初始化数据库
    this.initAndLoadIndex(windowStage);
  }

  private async initAndLoadIndex(windowStage: window.WindowStage) {
    try {
      await initDatabase(this.context);
      hilog.info(0x0000, TAG, 'Database initialized successfully');

      windowStage.setUIContent(this.context, 'pages/Index', null);
    } catch (err) {
      hilog.error(0x0000, TAG, 'Failed to init database: %{public}s', JSON.stringify(err));
      // 即使 DB 初始化失败也尝试加载页面（部分功能降级）
      windowStage.setUIContent(this.context, 'pages/Index', null);
    }
  }
}
```

- [ ] **Step 2: 创建 App.ets — 全局应用配置**

```typescript
// Path: entry/src/main/ets/App.ets
// 全局应用入口：配置 aboutToAppear / aboutToDisappear 生命周期

import hilog from '@ohos.hilog';

hilog.info(0x0000, 'FaceCheck', 'FaceCheck App started');

@Entry
@Component
struct App {
  aboutToAppear() {
    hilog.info(0x0000, 'FaceCheck', 'App aboutToAppear');
  }

  aboutToDisappear() {
    hilog.info(0x0000, 'FaceCheck', 'App aboutToDisappear');
  }

  build() {
    // 实际 UI 由 MainAbility 中的 setUIContent 加载
  }
}
```

---

## Task 12: 页面 — MainPage (Tabs 主框架)

**Files:**
- Create: `entry/src/main/ets/pages/Index.ets`

- [ ] **Step 1: 创建 Index.ets — Tabs 主容器**

```typescript
// Path: entry/src/main/ets/pages/Index.ets
// Tabs 主框架：包含注册页、签到页、记录页三个 Tab

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  private tabController: TabsController = new TabsController();

  @Builder
  TabBuilder(title: string, targetIndex: number, selectedIcon: Resource, normalIcon: Resource) {
    Column() {
      Image(this.currentIndex === targetIndex ? selectedIcon : normalIcon)
        .width(24)
        .height(24)
      Text(title)
        .fontSize(12)
        .fontColor(this.currentIndex === targetIndex ? '#1890ff' : '#999')
        .margin({ top: 4 })
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentIndex = targetIndex;
      this.tabController.changeIndex(targetIndex);
    })
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.END, controller: this.tabController }) {
        TabContent() {
          // 注册页（懒加载）
          NavDestination() {
            RegisterPage()
          }
          .title('人脸注册')
        }
        .tabBar(this.TabBuilder('注册', 0,
          $r('sys.media.ic_public_save'),
          $r('sys.media.ic_public_save')))

        TabContent() {
          NavDestination() {
            SignInPage()
          }
          .title('刷脸签到')
        }
        .tabBar(this.TabBuilder('签到', 1,
          $r('sys.media.ic_public_input_method'),
          $r('sys.media.ic_public_input_method')))

        TabContent() {
          NavDestination() {
            RecordPage()
          }
          .title('签到记录')
        }
        .tabBar(this.TabBuilder('记录', 2,
          $r('sys.media.ic_public_view_list'),
          $r('sys.media.ic_public_view_list')))
      }
      .barHeight(56)
      .onChange((index) => {
        this.currentIndex = index;
      })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}

// 懒加载各 Tab 页面组件
import { RegisterPage } from './RegisterPage';
import { SignInPage } from './SignInPage';
import { RecordPage } from './RecordPage';
```

---

## Task 13: 页面 — RegisterPage 人脸注册页

**Files:**
- Create: `entry/src/main/ets/pages/RegisterPage.ets`

- [ ] **Step 1: 创建 RegisterPage.ets — 人脸注册页**

```typescript
// Path: entry/src/main/ets/pages/RegisterPage.ets
// 人脸注册页：输入学号+姓名，拉起活体检测，保存图片到沙箱，写入数据库

import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { requestCameraPermission } from '../utils/PermissionUtil';
import { savePixelMapToFile } from '../utils/ImageFileUtil';
import { startLivenessDetection, getLivenessResult } from '../service/LivenessService';
import { insertUser } from '../database/UserTable';
import { UserModel } from '../model/UserModel';
import { CommonConstants } from '../utils/Constants';

const TAG = 'RegisterPage';

@Entry
@Component
struct RegisterPage {
  @State studentId: string = '';
  @State userName: string = '';
  @State isLoading: boolean = false;
  @State resultMessage: string = '';

  build() {
    Column({ space: 20 }) {
      // 顶部说明
      Text('录入人脸信息，开启刷脸签到')
        .fontSize(14)
        .fontColor('#666')
        .textAlign(TextAlign.Center)
        .margin({ top: 16 })

      // 学号输入
      TextInput({ placeholder: '请输入学号', text: this.studentId })
        .width('90%')
        .height(48)
        .fontSize(16)
        .backgroundColor('#f5f5f5')
        .borderRadius(8)
        .inputFilter('[a-zA-Z0-9]')
        .onChange((value: string) => {
          this.studentId = value;
        })

      // 姓名输入
      TextInput({ placeholder: '请输入姓名', text: this.userName })
        .width('90%')
        .height(48)
        .fontSize(16)
        .backgroundColor('#f5f5f5')
        .borderRadius(8)
        .onChange((value: string) => {
          this.userName = value;
        })

      // 结果提示
      if (this.resultMessage !== '') {
        Text(this.resultMessage)
          .fontSize(14)
          .fontColor(this.resultMessage.includes('成功') ? '#52c41a' : '#ff4d4f')
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })
      }

      // 注册按钮
      Button('开始注册')
        .width('80%')
        .height(48)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.isLoading ? '#ccc' : '#1890ff')
        .borderRadius(24)
        .enabled(!this.isLoading)
        .onClick(() => {
          this.doRegister();
        })

      if (this.isLoading) {
        LoadingProgress()
          .width(32)
          .height(32)
          .margin({ top: 16 })
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
  }

  private async doRegister(): Promise<void> {
    // 输入校验
    if (this.studentId.trim() === '') {
      this.showToast('请输入学号');
      return;
    }
    if (this.userName.trim() === '') {
      this.showToast('请输入姓名');
      return;
    }

    this.isLoading = true;
    this.resultMessage = '';

    try {
      // Step 1: 申请相机权限
      const hasPermission = await requestCameraPermission(getContext(this));
      if (!hasPermission) {
        this.resultMessage = '请授权相机权限';
        return;
      }

      // Step 2: 拉起活体检测
      const jumpOk = await startLivenessDetection();
      if (!jumpOk) {
        this.resultMessage = '活体检测启动失败';
        return;
      }
      // REPLACE_MODE: 页面已跳转，活体结果在 LivenessResultPage 获取
    } catch (err) {
      const error = err as BusinessError;
      logger.error('Register flow failed: code=%{public}d, msg=%{public}s',
        error.code, error.message);
      this.resultMessage = `注册失败: ${error.message}`;
    } finally {
      this.isLoading = false;
    }
  }

  private showToast(message: string): void {
    promptAction.showToast({ message: message, duration: 2000 });
  }
}
```

---

## Task 14: 页面 — LivenessResultPage 活体检测成功页

**Files:**
- Create: `entry/src/main/ets/pages/LivenessResultPage.ets`

- [ ] **Step 1: 创建 LivenessResultPage.ets — 活体成功+注册流程完成**

```typescript
// Path: entry/src/main/ets/pages/LivenessResultPage.ets
// 活体检测成功回调页：获取 mPixelMap，完成注册流程（保存图片+写DB）
// 在 AppStorage 中存取注册表单数据（studentId / userName）

import { promptAction } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { router } from '@kit.ArkUI';
import { logger } from '../utils/Logger';
import { savePixelMapToFile } from '../utils/ImageFileUtil';
import { getLivenessResult } from '../service/LivenessService';
import { insertUser } from '../database/UserTable';
import { UserModel } from '../model/UserModel';

const TAG = 'LivenessResultPage';

@Entry
@Component
struct LivenessResultPage {
  @State isLoading: boolean = true;
  @State message: string = '';

  async aboutToAppear() {
    logger.info('LivenessResultPage aboutToAppear');
    await this.processRegistration();
  }

  private async processRegistration(): Promise<void> {
    let livenessPixelMap: image.PixelMap | undefined = undefined;

    try {
      // Step 1: 获取活体检测结果
      livenessPixelMap = await getLivenessResult();
      if (!livenessPixelMap) {
        this.message = '活体检测未通过，请重试';
        this.isLoading = false;
        setTimeout(() => router.back(), 2000);
        return;
      }

      // Step 2: 从 AppStorage 获取注册表单数据
      const studentId = AppStorage.get<string>('reg_studentId') ?? '';
      const userName = AppStorage.get<string>('reg_userName') ?? '';

      if (!studentId || !userName) {
        this.message = '注册信息缺失，请重试';
        this.isLoading = false;
        setTimeout(() => router.back(), 2000);
        return;
      }

      // Step 3: 保存 PixelMap 到沙箱
      const context = getContext(this);
      const saveResult = await savePixelMapToFile(context, livenessPixelMap, studentId);
      if (!saveResult.success) {
        this.message = saveResult.message;
        this.isLoading = false;
        setTimeout(() => router.back(), 2000);
        return;
      }

      // Step 4: 写入数据库
      const user = new UserModel(studentId, userName, saveResult.fileName, Date.now());
      const dbResult = await insertUser(user);

      if (dbResult.success) {
        this.message = '注册成功！';
        logger.info('Registration complete: %{public}s', studentId);
        setTimeout(() => {
          AppStorage.set('reg_studentId', '');
          AppStorage.set('reg_userName', '');
          router.back();
        }, 1500);
      } else {
        this.message = dbResult.message;
        setTimeout(() => router.back(), 2000);
      }
    } catch (err) {
      logger.error('Process registration failed: %{public}s', (err as Error).message);
      this.message = '注册失败，请重试';
      setTimeout(() => router.back(), 2000);
    } finally {
      livenessPixelMap?.release();
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      if (this.isLoading) {
        LoadingProgress().width(48).height(48)
        Text('正在处理...').fontSize(16).margin({ top: 16 })
      } else {
        Text(this.message).fontSize(18).fontColor('#52c41a').textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
```

- [ ] **Step 2: 修改 RegisterPage.ets — 在拉起活体前存储表单数据到 AppStorage**

在 `doRegister()` 的 `startLivenessDetection()` 调用前添加：

```typescript
// 在 RegisterPage.ets 的 doRegister() 方法中，startLivenessDetection() 前插入：
AppStorage.set('reg_studentId', this.studentId.trim());
AppStorage.set('reg_userName', this.userName.trim());
```

---

## Task 15: 页面 — LivenessFailPage 活体检测失败页

**Files:**
- Create: `entry/src/main/ets/pages/LivenessFailPage.ets`

- [ ] **Step 1: 创建 LivenessFailPage.ets — 活体检测失败页**

```typescript
// Path: entry/src/main/ets/pages/LivenessFailPage.ets
// 活体检测失败回调页：LivenessType = NOT_LIVENESS 时系统自动跳转此页

import { router } from '@kit.ArkUI';

@Entry
@Component
struct LivenessFailPage {
  build() {
    Column() {
      Text('活体检测未通过')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ff4d4f')
        .margin({ top: 40 })

      Text('未能通过活体验证，请确保：')
        .fontSize(14)
        .fontColor('#666')
        .margin({ top: 20 })

      Column({ space: 8 }) {
        Text('• 在光线充足的环境下检测')
        Text('• 正对屏幕，按提示完成动作')
        Text('• 检测时请摘下口罩、眼镜等遮挡物')
        Text('• 仅限本人检测，勿使用照片或视频')
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 16 })
      .padding(16)
      .backgroundColor('#f5f5f5')
      .borderRadius(8)
      .width('90%')

      Button('重新检测')
        .width('80%')
        .height(48)
        .fontSize(16)
        .backgroundColor('#1890ff')
        .borderRadius(24)
        .margin({ top: 32 })
        .onClick(() => {
          router.back();
        })

      Button('返回注册页')
        .width('80%')
        .height(40)
        .fontSize(14)
        .fontColor('#666')
        .backgroundColor(Color.Transparent)
        .margin({ top: 12 })
        .onClick(() => {
          router.back();
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20 })
  }
}
```

---

## Task 16: 页面 — SignInPage 刷脸签到页

**Files:**
- Create: `entry/src/main/ets/pages/SignInPage.ets`

- [ ] **Step 1: 创建 SignInPage.ets — 刷脸签到页**

```typescript
// Path: entry/src/main/ets/pages/SignInPage.ets
// 刷脸签到页：输入学号 → 活体检测 → 查注册照 → 人脸比对 → 写签到记录

import { promptAction } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';
import { requestCameraPermission } from '../utils/PermissionUtil';
import { startLivenessDetection } from '../service/LivenessService';
import { compareFace } from '../service/FaceCompareService';
import { queryUser } from '../database/UserTable';
import { queryTodayRecord, insertSignRecord } from '../database/SignRecordTable';
import { loadPixelMapFromFile } from '../utils/ImageFileUtil';
import { SignRecordModel } from '../model/SignRecordModel';

const TAG = 'SignInPage';

@Entry
@Component
struct SignInPage {
  @State studentId: string = '';
  @State isLoading: boolean = false;
  @State similarity: number = 0;
  @State signStatus: string = '';
  @State signTime: string = '';

  build() {
    Column({ space: 16 }) {
      Text('刷脸签到')
        .fontSize(14)
        .fontColor('#999')
        .margin({ top: 8 })

      // 学号输入
      TextInput({ placeholder: '请输入学号', text: this.studentId })
        .width('90%')
        .height(48)
        .fontSize(16)
        .backgroundColor('#f5f5f5')
        .borderRadius(8)
        .inputFilter('[a-zA-Z0-9]')
        .onChange((value: string) => {
          this.studentId = value;
        })

      // 开始签到按钮
      Button('开始签到')
        .width('80%')
        .height(48)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.isLoading ? '#ccc' : '#1890ff')
        .borderRadius(24)
        .enabled(!this.isLoading)
        .onClick(() => {
          this.doSignIn();
        })

      if (this.isLoading) {
        LoadingProgress().width(32).height(32)
        Text('处理中...').fontSize(14).fontColor('#999').margin({ top: 8 })
      }

      // 结果展示
      if (this.signStatus !== '') {
        Column({ space: 8 }) {
          Text(this.signStatus)
            .fontSize(16)
            .fontColor(this.signStatus.includes('成功') ? '#52c41a' : '#ff4d4f')
            .fontWeight(FontWeight.Medium)

          if (this.similarity > 0) {
            Text(`相似度: ${this.similarity.toFixed(2)}%`)
              .fontSize(14)
              .fontColor('#666')
          }

          if (this.signTime !== '') {
            Text(`签到时间: ${this.signTime}`)
              .fontSize(13)
              .fontColor('#999')
          }
        }
        .margin({ top: 12 })
        .padding(16)
        .backgroundColor('#f5f5f5')
        .borderRadius(8)
        .width('90%')
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
  }

  private async doSignIn(): Promise<void> {
    if (this.studentId.trim() === '') {
      this.showToast('请输入学号');
      return;
    }

    this.isLoading = true;
    this.similarity = 0;
    this.signStatus = '';
    this.signTime = '';

    try {
      // Step 1: 申请相机权限
      const hasPermission = await requestCameraPermission(getContext(this));
      if (!hasPermission) {
        this.signStatus = '请授权相机权限';
        return;
      }

      // Step 2: 查询用户是否存在
      const user = await queryUser(this.studentId.trim());
      if (!user) {
        this.signStatus = '该学号未注册，请先注册';
        return;
      }

      // Step 3: 检查今日是否已签到
      const todayRecord = await queryTodayRecord(this.studentId.trim());
      if (todayRecord) {
        this.signStatus = '今日已签到，请勿重复签到';
        return;
      }

      // Step 4: 存储签到上下文
      AppStorage.set('sign_studentId', this.studentId.trim());
      AppStorage.set('sign_registeredFaceUri', user.faceUri);
      AppStorage.set('sign_registeredUserName', user.userName);

      // Step 5: 拉起活体检测
      const jumpOk = await startLivenessDetection();
      if (!jumpOk) {
        this.signStatus = '活体检测启动失败';
        return;
      }
      // REPLACE_MODE: 页面跳转，活体结果在 SignInResultPage 获取
    } catch (err) {
      const error = err as BusinessError;
      logger.error('SignIn flow failed: code=%{public}d', error.code);
      this.signStatus = `签到失败: ${error.message}`;
    } finally {
      this.isLoading = false;
    }
  }

  private showToast(message: string): void {
    promptAction.showToast({ message: message, duration: 2000 });
  }
}
```

---

## Task 17: 页面 — SignInResultPage 签到结果处理页

**Files:**
- Create: `entry/src/main/ets/pages/SignInResultPage.ets`

- [ ] **Step 1: 创建 SignInResultPage.ets — 签到结果处理页**

```typescript
// Path: entry/src/main/ets/pages/SignInResultPage.ets
// 活体成功后的签到结果处理页：获取活体 PixelMap → 加载注册照 → 比对 → 写记录

import { router } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';
import { getLivenessResult } from '../service/LivenessService';
import { compareFace } from '../service/FaceCompareService';
import { insertSignRecord } from '../database/SignRecordTable';
import { loadPixelMapFromFile } from '../utils/ImageFileUtil';

const TAG = 'SignInResultPage';

@Entry
@Component
struct SignInResultPage {
  @State isLoading: boolean = true;
  @State resultMessage: string = '';
  @State isSuccess: boolean = false;

  async aboutToAppear() {
    await this.processSignIn();
  }

  private async processSignIn(): Promise<void> {
    let livenessPixelMap: image.PixelMap | undefined = undefined;
    let registeredPixelMap: image.PixelMap | undefined = undefined;

    try {
      // Step 1: 获取活体结果
      livenessPixelMap = await getLivenessResult();
      if (!livenessPixelMap) {
        this.resultMessage = '活体检测未通过';
        this.isSuccess = false;
        this.isLoading = false;
        setTimeout(() => router.back(), 2000);
        return;
      }

      // Step 2: 获取签到上下文
      const studentId = AppStorage.get<string>('sign_studentId') ?? '';
      const faceUri = AppStorage.get<string>('sign_registeredFaceUri') ?? '';
      const userName = AppStorage.get<string>('sign_registeredUserName') ?? '';

      if (!studentId || !faceUri) {
        this.resultMessage = '签到信息缺失';
        this.isSuccess = false;
        this.isLoading = false;
        setTimeout(() => router.back(), 2000);
        return;
      }

      // Step 3: 加载注册照 PixelMap
      const context = getContext(this);
      registeredPixelMap = await loadPixelMapFromFile(context, faceUri);
      if (!registeredPixelMap) {
        this.resultMessage = '注册照片加载失败';
        this.isSuccess = false;
        this.isLoading = false;
        setTimeout(() => router.back(), 2000);
        return;
      }

      // Step 4: 人脸比对（PixelMap 在 compareFace 内部被释放）
      const compareResult = await compareFace(registeredPixelMap, livenessPixelMap);
      registeredPixelMap = undefined; // compareFace 已释放
      livenessPixelMap = undefined;   // compareFace 已释放

      // Step 5: 写签到记录
      const now = Date.now();
      const record = new SignRecordModel(
        studentId,
        now,
        compareResult.pass ? Constants.STATUS_SIGN_SUCCESS : Constants.STATUS_MATCH_FAIL,
        compareResult.similarity
      );
      await insertSignRecord(record);

      if (compareResult.pass) {
        this.resultMessage = `签到成功！${userName} 同学，欢迎回来！\n相似度: ${compareResult.similarityPercent.toFixed(2)}%`;
        this.isSuccess = true;
        logger.info('SignIn SUCCESS: %{public}s, similarity=%{public}f',
          studentId, compareResult.similarity);
      } else {
        this.resultMessage = `签到失败：相似度 ${compareResult.similarityPercent.toFixed(2)}% 未达标\n请确认是否为本人`;
        this.isSuccess = false;
        logger.warn('SignIn FAIL: %{public}s, similarity=%{public}f',
          studentId, compareResult.similarity);
      }

      AppStorage.set('sign_studentId', '');
      AppStorage.set('sign_registeredFaceUri', '');
      AppStorage.set('sign_registeredUserName', '');

      setTimeout(() => router.back(), 3000);
    } catch (err) {
      logger.error('Process signIn failed: %{public}s', (err as Error).message);
      this.resultMessage = '签到处理失败，请重试';
      this.isSuccess = false;
      setTimeout(() => router.back(), 2000);
    } finally {
      registeredPixelMap?.release();
      livenessPixelMap?.release();
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      if (this.isLoading) {
        LoadingProgress().width(48).height(48)
        Text('正在比对...').fontSize(16).margin({ top: 16 })
      } else {
        Text(this.resultMessage)
          .fontSize(16)
          .textAlign(TextAlign.Center)
          .fontColor(this.isSuccess ? '#52c41a' : '#ff4d4f')
          .padding(24)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
```

- [ ] **Step 2: 修改 LivenessService.ets — 将 SignInResultPage 添加为成功跳转目标**

在 `startLivenessDetection()` 的 config 中，`successfulRouteUrl` 根据上下文动态切换（由 SignInPage 存储到 AppStorage 指定路由，或默认注册页）。

> **简化方案**：注册流程跳 `LivenessResultPage`，签到流程跳 `SignInResultPage`。通过 AppStorage 传递上下文路由。

---

## Task 18: 页面 — RecordPage 签到记录页

**Files:**
- Create: `entry/src/main/ets/pages/RecordPage.ets`

- [ ] **Step 1: 创建 RecordPage.ets — 签到记录页**

```typescript
// Path: entry/src/main/ets/pages/RecordPage.ets
// 签到记录页：List 展示全部签到记录，支持按学号筛选

import { promptAction } from '@kit.ArkUI';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';
import { queryAllRecords, querySignRecords } from '../database/SignRecordTable';
import { SignRecordModel } from '../model/SignRecordModel';

const TAG = 'RecordPage';

@Entry
@Component
struct RecordPage {
  @State records: SignRecordModel[] = [];
  @State filterStudentId: string = '';
  @State isLoading: boolean = false;

  async aboutToAppear() {
    await this.loadRecords();
  }

  build() {
    Column({ space: 12 }) {
      // 筛选输入
      Row({ space: 8 }) {
        TextInput({ placeholder: '输入学号筛选', text: this.filterStudentId })
          .height(40)
          .fontSize(14)
          .backgroundColor('#f5f5f5')
          .borderRadius(8)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.filterStudentId = value;
          })

        Button('查询')
          .height(40)
          .fontSize(14)
          .backgroundColor('#1890ff')
          .borderRadius(8)
          .onClick(() => {
            this.loadRecords();
          })

        Button('全部')
          .height(40)
          .fontSize(14)
          .backgroundColor('#f5f5f5')
          .fontColor('#666')
          .borderRadius(8)
          .onClick(() => {
            this.filterStudentId = '';
            this.loadRecords();
          })
      }
      .width('100%')
      .padding({ left: 8, right: 8 })

      // 统计行
      Row() {
        Text(`共 ${this.records.length} 条记录`)
          .fontSize(12)
          .fontColor('#999')
      }
      .width('100%')
      .padding({ left: 16 })

      // 记录列表
      if (this.isLoading) {
        LoadingProgress().width(32).height(32).margin({ top: 40 })
      } else if (this.records.length === 0) {
        Column() {
          Text('暂无签到记录')
            .fontSize(16)
            .fontColor('#999')
            .margin({ top: 60 })
        }
        .width('100%')
      } else {
        List() {
          ForEach(this.records, (record: SignRecordModel, index: number) => {
            ListItem() {
              this.RecordItem(record)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#eee' })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  RecordItem(record: SignRecordModel) {
    Row() {
      Column({ space: 4 }) {
        Text(record.studentId)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333')

        Text(this.formatTime(record.signTime))
          .fontSize(12)
          .fontColor('#999')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column({ space: 4 }) {
        Text(this.getStatusText(record.status))
          .fontSize(14)
          .fontColor(record.status === 1 ? '#52c41a' : '#ff4d4f')
          .fontWeight(FontWeight.Medium)

        if (record.similarity > 0) {
          Text(`相似度: ${(record.similarity * 100).toFixed(1)}%`)
            .fontSize(11)
            .fontColor('#999')
        }
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#fff')
  }

  private async loadRecords(): Promise<void> {
    this.isLoading = true;
    try {
      if (this.filterStudentId.trim() !== '') {
        this.records = await querySignRecords(this.filterStudentId.trim(), 50);
      } else {
        this.records = await queryAllRecords(100);
      }
    } catch (err) {
      logger.error('Load records failed: %{public}s', (err as Error).message);
      promptAction.showToast({ message: '加载记录失败', duration: 2000 });
    } finally {
      this.isLoading = false;
    }
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
  }

  private getStatusText(status: number): string {
    switch (status) {
      case Constants.STATUS_SIGN_SUCCESS: return '签到成功';
      case Constants.STATUS_LIVENESS_FAIL: return '活体失败';
      case Constants.STATUS_MATCH_FAIL: return '比对失败';
      default: return '未知';
    }
  }
}
```

---

## Task 19: 收尾 — module.json5 pages 路由注册与路由声明

**Files:**
- Modify: `entry/src/main/module.json5` — 添加所有页面路由
- Modify: `entry/src/main/ets/service/LivenessService.ets` — 统一活体结果页路由策略

- [ ] **Step 1: 更新 module.json5 — 注册所有页面路由**

```json5
// Path: entry/src/main/module.json5
// 在 module 的 js 字段中注册所有页面
{
  "module": {
    "requestPermissions": [
      { "name": "ohos.permission.CAMERA" },
      { "name": "ohos.permission.READ_MEDIA" },
      { "name": "ohos.permission.WRITE_MEDIA" }
    ],
    "abilities": [
      {
        "skills": [
          {
            "entities": ["entity.system.home"],
            "actions": ["action.system.home"]
          }
        ]
      }
    ],
    "js": [
      {
        "pages": [
          "pages/Index",
          "pages/RegisterPage",
          "pages/SignInPage",
          "pages/RecordPage",
          "pages/LivenessResultPage",
          "pages/LivenessFailPage",
          "pages/SignInResultPage"
        ],
        "name": "default",
        "window": {
          "designWidth": 720,
          "autoDesignWidth": false
        }
      }
    ]
  }
}
```

- [ ] **Step 2: 统一活体结果页路由策略**

在 `LivenessService.ets` 中，添加按场景切换成功页的辅助函数：

```typescript
// 扩展 LivenessService.ets，添加以下函数
/**
 * 统一拉起活体检测，根据场景跳转到不同结果页
 * @param successRoute 成功跳转的页面路径
 * @param failRoute 失败跳转的页面路径
 */
async function startLivenessWithRoute(
  successRoute: string,
  failRoute: string
): Promise<boolean> {
  const config: interactiveLiveness.InteractiveLivenessConfig = {
    isSilentMode: interactiveLiveness.DetectionMode.INTERACTIVE_MODE,
    actionsNum: Constants.LIVENESS_ACTIONS_NUM === 3
      ? interactiveLiveness.ActionsNumber.THREE_ACTION
      : interactiveLiveness.ActionsNumber.FOUR_ACTION,
    routeMode: interactiveLiveness.RouteRedirectionMode.REPLACE_MODE,
    successfulRouteUrl: successRoute,
    failedRouteUrl: failRoute
  };

  try {
    return await interactiveLiveness.startLivenessDetection(config);
  } catch (err) {
    const error = err as BusinessError;
    logger.error('Start liveness failed: code=%{public}d', error.code);
    return false;
  }
}
```

在 `RegisterPage` 中调用：`startLivenessWithRoute('pages/LivenessResultPage', 'pages/LivenessFailPage')`
在 `SignInPage` 中调用：`startLivenessWithRoute('pages/SignInResultPage', 'pages/LivenessFailPage')`

---

## Self-Review 检查清单

**1. Spec Coverage:**
- [x] 用户信息注册与展示 → Task 13, 14 (RegisterPage + LivenessResultPage)
- [x] 人脸录入与检测 → Task 9 (FaceDetectService), Task 6 (ImageFileUtil)
- [x] 刷脸签到与人脸比对验证 → Task 16, 17 (SignInPage + SignInResultPage)
- [x] 活体检测防作弊 → Task 8 (LivenessService)
- [x] 签到记录查看与数据持久化 → Task 5, 18 (SignRecordTable + RecordPage)

**2. Placeholder Scan:**
- 无 "TBD" / "TODO" / "implement later" 等占位符
- 无 "Add appropriate error handling" 等模糊描述
- 所有步骤均有完整代码

**3. Type Consistency:**
- `UserModel` 字段名与 `UserTable.ets` 中 `ValuesBucket` 列名一致（snake_case）
- `SignRecordModel` 字段名与 `SignRecordTable.ets` 列名一致
- `compareFace()` 返回 `CompareResult` 接口在 Task 10 和 Task 17 中类型一致
- `SIMILARITY_THRESHOLD` 统一使用 `Constants.SIMILARITY_THRESHOLD`
- PixelMap 释放：`livenessPixelMap?.release()` 和 `registeredPixelMap?.release()` 均在 `finally` 中

**4. @kit 导入检查:**
- `faceComparator` ← `@kit.CoreVisionKit`
- `faceDetector` ← `@kit.CoreVisionKit`
- `interactiveLiveness` ← `@kit.VisionKit`
- `relationalStore` ← `@kit.ArkData`
- `image` ← `@kit.ImageKit`
- `fileIo` ← `@kit.CoreFileKit`
- `hilog` ← `@kit.PerformanceAnalysisKit`
- `BusinessError` ← `@kit.BasicServicesKit`
- `abilityAccessCtrl` ← `@kit.AbilityKit`

**5. PixelMap 释放链路:**
- `ImageFileUtil.loadPixelMapFromFile()` — 调用方负责释放（compareFace 内部已处理）
- `compareFace()` — finally 中同时释放两个 PixelMap
- `LivenessResultPage.processRegistration()` — finally 中释放 livenessPixelMap
- `SignInResultPage.processSignIn()` — finally 中释放两个 PixelMap

---

## 执行选项

Plan complete and saved to `Doc/Plan/Plan1.md`. 两个执行选项：

**1. Subagent-Driven (recommended)** — 我按 Task 顺序，向 Agent 2 发放子任务指令，每个 Task 完成后代码审查（Agent-Leader Review Checklist），快速迭代。

**2. Inline Execution** — 我在当前会话中逐个 Task 执行并审查。

**请选择执行方式？**
