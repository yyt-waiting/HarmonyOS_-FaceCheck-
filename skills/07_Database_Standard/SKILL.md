---
metadata:
  id: "SKILL-HM-007"
  name: "Database-RDB-Persistence"
  version: "1.0"
  target_api: "HarmonyOS NEXT (API 12)"
  category: "Database"
  dependencies: ["@kit.ArkData", "@kit.CoreFileKit", "@kit.ImageKit", "SKILL-HM-001", "SKILL-HM-008"]
  trigger_keywords: ["relationalStore", "RDB", "SQLite", "建表", "CRUD", "ValuesBucket", "RdbPredicates", "ResultSet", "DataManager", "用户存储", "签到记录"]
  strictness: "High"
---

# HarmonyOS NEXT — RDB 数据持久化规范

## <purpose>
本技能定义了 FaceCheck 项目使用 `relationalStore`（RDB）进行结构化数据持久化的完整规范。涵盖数据库初始化、表结构设计、CRUD 操作封装、事务处理和文件路径存储策略。绝对禁止将 PixelMap 直接存入数据库。
:::

## <constraints>
### [强制约束 — 违反将导致数据丢失或内存泄漏]

- **DB-01**: **严禁将 `PixelMap` 以任何形式（Blob / Base64 / 序列化）存入 SQLite**，只允许存文件 Uri 或文件名。
- **DB-02**: `module.json5` 中必须声明 `@kit.ArkData` 的使用权限及数据库名称配置。
- **DB-03**: 所有 RDB 操作必须使用 `async/await`，禁止在 UI 主线程进行同步数据库操作。
- **DB-04**: 每次查询后必须显式调用 `resultSet.close()`，否则将导致内存泄漏。
- **DB-05**: `ValuesBucket` 插入数据时必须为所有 `NOT NULL` 字段提供值。
- **DB-06**: 学号（`student_id`）设置 `UNIQUE` 约束，插入冲突必须捕获错误码 **1501307** 并提示用户。
- **DB-07**: 数据库路径只存**文件名**，运行时通过 `getContext().filesDir` 拼接完整路径。
- **DB-08**: `StoreConfig` 必须指定 `securityLevel`，API 12 推荐 `S1` 或更高。
- **DB-09**: 数据库迁移（表结构变更）需要在版本管理中实现 `onUpgrade` 逻辑。
:::

## <logic_flow>
### [数据库全生命周期]

```
1. [初始化] relationalStore.getRdbStore(context, config) → store
2. [建表] store.executeSql(SQL_CREATE_XXX)
3. [业务 CRUD] store.insert / store.update / store.query / store.delete
4. [结果集处理] resultSet.goToFirstRow() → while loop → resultSet.close()
5. [销毁] store.deleteRdbStore(context, storeName)
```

### [持久化策略 — 图像路径分离原则]

```
注册流程:
  [相机/图库] → PixelMap → ImagePacker → 沙箱文件(face_1001.jpg)
                                          │
                                          ▼
                                    face_uri = "face_1001.jpg"
                                    UserTable{..., face_uri: "face_1001.jpg"}

比对流程:
  UserTable{face_uri: "face_1001.jpg"}
      │
      ▼
  filePath = getContext().filesDir + "/face_1001.jpg"
      │
      ▼
  uriToPixelMap(filePath) → PixelMap → faceComparator.compareFaces()
```
:::

## <data_structures>

### [UserTable — 用户注册表]

```typescript
// Standard Template: 用户表 DDL
// 用途: 建表 SQL 和数据操作
interface UserRecord {
  id: number;           // 主键自增
  studentId: string;    // 学号/工号 (UNIQUE, NOT NULL)
  userName: string;    // 姓名 (NOT NULL)
  faceUri: string;     // 沙箱文件名 (NOT NULL)
  gmtCreate: number;   // 注册时间戳 (NOT NULL)
}
```

### [SignRecordTable — 签到记录表]

```typescript
// Standard Template: 签到记录表 DDL
// 用途: 记录每次签到流水
interface SignRecord {
  id: number;          // 主键自增
  studentId: string;  // 关联学号 (NOT NULL)
  signTime: number;   // 签到时间戳 (NOT NULL)
  status: number;     // 状态: 1=成功, 0=活体失败, -1=匹配失败
  similarity: number; // 相似度 0.0~1.0
}
```

### [ValuesBucket — 插入数据结构]

```typescript
// Standard Template: 插入数据封装
// 用途: store.insert(tableName, valuesBucket)
interface UserInsertBucket {
  student_id: string;
  user_name: string;
  face_uri: string;
  gmt_create: number;
}
```
:::

## <best_practices>
### [数据库初始化模板]

```typescript
// Standard Template: RDB 初始化 + 建表
// 文件路径参考: entry/src/main/ets/database/DataManager.ets
import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG = 'DataManager';
const STORE_NAME = 'FaceCheck.db';
const STORE_VERSION = 1;

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: STORE_NAME,
  securityLevel: relationalStore.SecurityLevel.S1
};

const SQL_CREATE_USER = `
CREATE TABLE IF NOT EXISTS UserTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id TEXT UNIQUE NOT NULL,
  user_name TEXT NOT NULL,
  face_uri TEXT NOT NULL,
  gmt_create INTEGER NOT NULL
)`;

const SQL_CREATE_RECORD = `
CREATE TABLE IF NOT EXISTS SignRecordTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id TEXT NOT NULL,
  sign_time INTEGER NOT NULL,
  status INTEGER NOT NULL,
  similarity REAL DEFAULT 0
)`;

let rdbStore: relationalStore.RdbStore | undefined = undefined;

async function initDatabase(context: Context): Promise<void> {
  try {
    rdbStore = await relationalStore.getRdbStore(context, STORE_CONFIG);
    hilog.info(0x0000, TAG, 'RDB store initialized');

    await rdbStore.executeSql(SQL_CREATE_USER);
    hilog.info(0x0000, TAG, 'UserTable created');

    await rdbStore.executeSql(SQL_CREATE_RECORD);
    hilog.info(0x0000, TAG, 'SignRecordTable created');
  } catch (err) {
    const error = err as BusinessError;
    hilog.error(0x0000, TAG, 'initDatabase failed: %{public}d', error.code);
    throw err;
  }
}
```

### [用户注册 — insert with 冲突处理]

```typescript
// Standard Template: 用户插入
// 用途: 注册新人脸记录，处理 student_id UNIQUE 冲突
async function insertUser(user: UserRecord): Promise<{ success: boolean; message: string }> {
  if (!rdbStore) {
    return { success: false, message: 'Database not initialized' };
  }

  const bucket: relationalStore.ValuesBucket = {
    student_id: user.studentId,
    user_name: user.userName,
    face_uri: user.faceUri,
    gmt_create: user.gmtCreate
  };

  try {
    const rowId = await rdbStore.insert('UserTable', bucket);
    hilog.info(0x0000, TAG, 'User inserted, rowId=%{public}d', rowId);
    return { success: true, message: '注册成功' };
  } catch (err) {
    const error = err as BusinessError;
    // 1501307 = UNIQUE constraint failed
    if (error.code === 1501307) {
      hilog.warn(0x0000, TAG, 'Duplicate student_id: %{public}s', user.studentId);
      return { success: false, message: '学号已注册，请勿重复注册' };
    }
    hilog.error(0x0000, TAG, 'Insert user failed: %{public}d', error.code);
    return { success: false, message: `注册失败: ${error.message}` };
  }
}
```

### [用户查询 — query with ResultSet]

```typescript
// Standard Template: 用户查询
// 用途: 按 studentId 查询用户信息
async function queryUser(studentId: string): Promise<UserRecord | null> {
  if (!rdbStore) {
    return null;
  }

  const predicates = new relationalStore.RdbPredicates('UserTable');
  predicates.equalTo('student_id', studentId);

  let resultSet: relationalStore.ResultSet | undefined = undefined;
  try {
    resultSet = await rdbStore.query(predicates, ['id', 'student_id', 'user_name', 'face_uri', 'gmt_create']);

    if (resultSet.goToFirstRow()) {
      const user: UserRecord = {
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        studentId: resultSet.getString(resultSet.getColumnIndex('student_id')),
        userName: resultSet.getString(resultSet.getColumnIndex('user_name')),
        faceUri: resultSet.getString(resultSet.getColumnIndex('face_uri')),
        gmtCreate: resultSet.getLong(resultSet.getColumnIndex('gmt_create'))
      };
      hilog.info(0x0000, TAG, 'User found: %{public}s', user.studentId);
      return user;
    }
    return null;
  } catch (err) {
    hilog.error(0x0000, TAG, 'Query user failed');
    return null;
  } finally {
    resultSet?.close();
  }
}
```

### [签到记录插入]

```typescript
// Standard Template: 签到记录插入
// 用途: 记录每次签到结果
async function insertSignRecord(record: SignRecord): Promise<number> {
  if (!rdbStore) {
    return -1;
  }

  const bucket: relationalStore.ValuesBucket = {
    student_id: record.studentId,
    sign_time: record.signTime,
    status: record.status,
    similarity: record.similarity
  };

  try {
    return await rdbStore.insert('SignRecordTable', bucket);
  } catch (err) {
    hilog.error(0x0000, TAG, 'Insert sign record failed');
    return -1;
  }
}
```

### [签到记录查询]

```typescript
// Standard Template: 签到记录查询
// 用途: 查询某学号的最近 N 条签到记录
async function querySignRecords(studentId: string, limit: number = 50): Promise<SignRecord[]> {
  if (!rdbStore) {
    return [];
  }

  const predicates = new relationalStore.RdbPredicates('SignRecordTable');
  predicates.equalTo('student_id', studentId);
  predicates.orderByDesc('sign_time');
  predicates.limitAs(limit);

  let resultSet: relationalStore.ResultSet | undefined = undefined;
  const records: SignRecord[] = [];

  try {
    resultSet = await rdbStore.query(predicates,
      ['id', 'student_id', 'sign_time', 'status', 'similarity']);

    while (resultSet.goToNextRow()) {
      records.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        studentId: resultSet.getString(resultSet.getColumnIndex('student_id')),
        signTime: resultSet.getLong(resultSet.getColumnIndex('sign_time')),
        status: resultSet.getLong(resultSet.getColumnIndex('status')),
        similarity: resultSet.getDouble(resultSet.getColumnIndex('similarity'))
      });
    }
    return records;
  } finally {
    resultSet?.close();
  }
}
```

### [ResultSet 读取方法速查]

```typescript
// Standard Template: ResultSet 字段类型读取
// 注意: 必须先 goToFirstRow() 再读取
resultSet.getString(columnIndex: number): string
resultSet.getLong(columnIndex: number): number      // INTEGER
resultSet.getDouble(columnIndex: number): number    // REAL
resultSet.getBlob(columnIndex: number): Uint8Array // BLOB (禁止用于 PixelMap)
resultSet.getColumnIndex(columnName: string): number
resultSet.goToFirstRow(): boolean
resultSet.goToNextRow(): boolean
resultSet.close(): void
```
:::

## <verification_checklist>
- [ ] `relationalStore` 使用 `@kit.ArkData` 导入
- [ ] `StoreConfig` 包含 `securityLevel` 设置
- [ ] 建表 SQL 使用 `IF NOT EXISTS` 防止重复建表
- [ ] 所有 `store.query` 后有 `resultSet.close()`
- [ ] `insert` 操作有错误码 1501307 冲突处理
- [ ] `ValuesBucket` 的字段名与数据库列名完全一致
- [ ] `faceUri` 字段只存文件名，不存完整路径
- [ ] `module.json5` 包含 `@kit.ArkData` 相关配置
- [ ] 签到记录有 `status` 状态区分（1成功/0活体失败/-1匹配失败）
</verification_checklist>
