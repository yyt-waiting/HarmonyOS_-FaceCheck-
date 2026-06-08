# HarmonyOS NEXT 数据持久化与 RDB 数据库规范

## 1. 持久化核心策略

为确保应用性能与稳定性，严禁将大体积图片数据直接存入数据库。

- **数据库 (RDB)**: 仅存储结构化文本、数值及指向图片的**沙箱相对路径**
- **文件系统 (Sandbox)**: 存储采集到的原始人脸图片（.jpg 或 .png 格式）
- **关联机制**: 数据库字段 `face_uri` 存储文件名，运行时通过 `getContext().filesDir` 拼接完整路径进行读取

## 2. 技术栈约束

- **模块导入**: `import { relationalStore } from '@kit.ArkData';`
- **异步范式**: 强制使用 `async/await`，禁止在主线程进行同步阻塞操作
- **数据库版本**: 应用首选持久化方案，API 12 增强版 RDB

## 3. 数据库表结构设计

### 3.1 用户注册表 (UserTable)

用于存储学生人脸特征基准信息。

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | 内部自增 ID |
| student_id | TEXT | UNIQUE, NOT NULL | 学号/工号（业务主键）|
| user_name | TEXT | NOT NULL | 学生姓名 |
| face_uri | TEXT | NOT NULL | 沙箱图片文件名（如: face_1001.jpg）|
| gmt_create | INTEGER | NOT NULL | 注册时间戳 |

### 3.2 签到记录表 (SignRecordTable)

用于记录每日打卡流水。

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | 记录 ID |
| student_id | TEXT | NOT NULL | 对应 UserTable 的学号 |
| sign_time | INTEGER | NOT NULL | 签到时间戳 |
| status | INTEGER | NOT NULL | 状态（1: 成功，0: 活体失败，-1: 匹配失败）|
| similarity | REAL | DEFAULT 0 | 人脸比对得分（0.0 - 1.0）|

## 4. 标准实现参考

### 4.1 初始化与建表

生成 `DataManager.ets` 时需包含初始化逻辑：

```typescript
import { relationalStore } from '@kit.ArkData';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'FaceCheck.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const SQL_CREATE_USER = `CREATE TABLE IF NOT EXISTS UserTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id TEXT UNIQUE NOT NULL,
  user_name TEXT NOT NULL,
  face_uri TEXT NOT NULL,
  gmt_create INTEGER NOT NULL
)`;
```

### 4.2 关键业务逻辑 (DAO)

- **注册逻辑**: 先将 PixelMap 保存到文件系统，再将返回的 fileName 存入数据库
- **查询逻辑**: 使用 `relationalStore.RdbPredicates` 构建条件
- **结果解析**: 必须显式调用 `resultSet.goToFirstRow()` 并循环读取，最后必须在 `finally` 块中调用 `resultSet.close()`

## 5. 图像沙箱存储规范

AI 必须实现以下工具函数以处理图片持久化：

- **保存图片**: 路径为 `getContext().filesDir + '/' + fileName`，使用 `image.ImagePacker` 将 PixelMap 压缩为 JPG 写入文件流
- **读取图片**: 使用 `image.createImageSource` 加载沙箱文件路径，返回 PixelMap 供 AI Kit 比对

## 6. 自检红线

- **严禁存储 Blob**: 绝对禁止在数据库字段中使用 Blob 存储 PixelMap 原始字节
- **必须关闭结果集**: 忘记调用 `resultSet.close()` 会导致内存泄漏，AI 必须生成该逻辑
- **学号冲突处理**: 插入 UserTable 时必须处理 **1501307** 错误码（唯一性冲突），并告知用户"学号已注册"
- **硬编码路径**: 禁止直接存储 `/data/storage/...` 全路径，应只存文件名，因为沙箱根路径在应用升级或重新安装后可能会变
