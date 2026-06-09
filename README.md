# FaceCheck — 鸿蒙 AI 刷脸签到应用

基于 HarmonyOS NEXT (API 12, Stage 模型) 的原生刷脸签到应用，实现人脸注册、活体检测、1:1 人脸比对、签到记录持久化的完整业务闭环。

## 项目结构

```
Facing-recognition/
├── entry/                          # 应用模块
│   └── src/main/
│       ├── ets/                    # ArkTS 源码
│       │   ├── entryability/       # EntryAbility 入口
│       │   ├── database/           # 数据库层 (RDB)
│       │   ├── model/              # 数据模型
│       │   ├── pages/              # 页面组件
│       │   ├── service/            # 业务服务 (VisionKit 封装)
│       │   └── utils/              # 工具类
│       ├── module.json5             # 模块配置
│       └── resources/              # 资源文件
├── AppScope/                       # 全局应用配置
├── Doc/                            # 实施计划与文档
└── skills/                         # AI Skill 参考文档
```

## 技术栈

| 能力 | SDK | 说明 |
|------|-----|------|
| 人脸比对 | `@kit.CoreVisionKit` / `faceComparator` | 1:1 注册照与现场照比对 |
| 人脸检测 | `@kit.CoreVisionKit` / `faceDetector` | 静态图片人脸检测 |
| 活体检测 | `@kit.VisionKit` / `interactiveLiveness` | 防照片/视频攻击 |
| 数据库 | `@kit.ArkData` / `relationalStore` | SQLite 持久化 |
| 图片处理 | `@kit.ImageKit` / `ImagePacker` | PixelMap → JPG 存储 |
| 文件管理 | `@kit.CoreFileKit` / `fileIo` | 沙箱文件操作 |

## 在 DevEco Studio 中打开和运行

### 前置要求

- **DevEco Studio** NEXT 版本（推荐 5.0.3.900+）
- **HarmonyOS SDK** API 12 及以上
- **Node.js** 18+（hvigor 构建工具依赖）
- 真机或模拟器（**推荐使用真机**，活体检测需要实际摄像头）

### 步骤 1: 克隆项目

在终端中执行：

```bash
git clone https://github.com/yyt-waiting/HarmonyOS_-FaceCheck-.git
cd HarmonyOS_-FaceCheck-
```

### 步骤 2: 用 DevEco Studio 打开项目

1. 打开 **DevEco Studio**
2. 选择 `File` → `Open`
3. 选择项目根目录 `HarmonyOS_-FaceCheck-`
4. 点击 `OK`，等待索引建立完成（约 1-2 分钟）

### 步骤 3: 配置签名（真机运行必需）

1. 在 DevEco Studio 中打开 `entry` 模块
2. 进入 `File` → `Project Structure` → `Signing Configs`
3. 选择 **Automatically generate signature**（自动签名）
4. 填入华为账号信息（推荐）或手动配置已有的签名文件
5. 点击 `Sign In` 完成认证

> 如果没有华为开发者账号：[注册入口](https://developer.huawei.com/consumer/cn/)

### 步骤 4: 配置模拟器或连接真机

#### 连接真机（推荐）
1. 开启手机**开发者模式**：`设置` → `关于手机` → 连续点击 `版本号` 7 次
2. 开启 **USB 调试**：`设置` → `系统和更新` → `开发人员选项` → 开启 `USB 调试`
3. 用 USB 线连接电脑
4. 手机上弹出"允许 USB 调试"弹窗，点击**允许**
5. DevEco Studio 右上角设备选择器中选中你的手机

#### 使用模拟器
1. 进入 `Tools` → `Device Manager`
2. 点击 `Phone` → 选择一个 API 12+ 的镜像
3. 点击 `Start` 启动模拟器

### 步骤 5: 运行项目

1. 在 DevEco Studio 顶部工具栏，选择目标设备（真机或模拟器）
2. 点击绿色 **运行按钮** (▶️)
3. 等待编译完成（约 30-60 秒，首次编译较慢）
4. 应用自动安装并启动

> **注意**：如果编译报错，检查以下几点：
> - SDK 版本是否匹配（API 12+）
> - Node.js 是否安装（`node -v` 确认）
> - 签名是否配置成功

## 应用功能

### Tab 1 — 人脸注册
- 输入学号 + 姓名
- 点击"开始注册"，按提示完成活体检测动作
- 活体通过后自动保存人脸照片到沙箱，并写入数据库

### Tab 2 — 刷脸签到
- 输入已注册的学号
- 点击"开始签到"，完成活体检测
- 系统自动加载注册照，与现场照进行 1:1 比对
- 比对成功（相似度 ≥ 60%）则签到成功，写入签到记录

### Tab 3 — 签到记录
- 查看全部签到历史
- 输入学号筛选特定用户的签到记录
- 显示签到时间、相似度和状态

## 配置说明

### 权限说明

应用请求以下权限（已在 `module.json5` 中声明）：

| 权限 | 用途 |
|------|------|
| `ohos.permission.CAMERA` | 活体检测、系统相机 |
| `ohos.permission.READ_MEDIA` | 读取媒体文件 |
| `ohos.permission.WRITE_MEDIA` | 保存人脸照片 |

### 人脸比对阈值

默认阈值为 **0.6**（60% 相似度），可在 `Constants.ets` 中调整：

```typescript
static readonly SIMILARITY_THRESHOLD: number = 0.6;
```

### 活体动作数量

默认使用 **3 个随机动作**，可在 `Constants.ets` 中改为 4：

```typescript
static readonly LIVENESS_ACTIONS_NUM: number = 3;  // 改为 4 可增加难度
```

## 添加应用图标

1. 准备一张 **1024 x 1024** 的 PNG 图标
2. 保存为 `entry/src/main/resources/base/media/icon.png`
3. 在 DevEco Studio 中 `Build` → `Generate Bundle` / 运行即可自动使用

## 构建 HAP 包（可选）

如果只需要生成安装包而不运行：

1. `Build` → `Build Module(s) [entry]`
2. 等待编译完成
3. HAP 文件位于 `entry/build/default/outputs/default/entry-default-signed.hap`

## 常见问题

**Q: 模拟器无法使用活体检测？**
A: 活体检测需要真实摄像头，请在真机上运行。模拟器仅支持 UI 调试。

**Q: 编译报错 "Cannot find module @kit/xxx"？**
A: 检查 SDK 是否包含对应 Kit。打开 `File` → `Settings` → `SDK` 确认 Core Vision Kit 和 Vision Kit 已安装。

**Q: 真机运行提示"应用未签名"？**
A: 进入 `Project Structure` → `Signing Configs`，按步骤配置自动签名或手动签名。

**Q: 数据库初始化失败？**
A: 确保 `EntryAbility.onWindowStageCreate` 中 `initDatabase` 被正确调用，检查日志输出。
