---
metadata:
  id: "SKILL-HM-001"
  name: "HarmonyOS-Next-Stage-Baseline"
  version: "1.0"
  target_api: "HarmonyOS NEXT (API 12)"
  category: "Foundation"
  dependencies: ["@kit.AbilityKit", "@kit.BasicServicesKit", "@kit.PerformanceAnalysisKit", "@kit.ImageKit"]
  trigger_keywords: ["Stage模型", "ArkTS强类型", "权限申请", "async/await", "MVVM分层", "hilog日志", "BusinessError", "资源释放", "PixelMap释放"]
  strictness: "High"
---

# HarmonyOS NEXT (API 12) ArkTS 基础规范

## <purpose>
本技能定义了 FaceCheck 项目所有 ArkTS 代码必须遵守的底层约束，涵盖开发范式、权限申请、图像处理、类型安全、架构分层、异常处理和日志规范。任何 Vision Kit / Database 技能的代码生成都必须以本技能为前置基础。
:::

## <constraints>
### [强制约束 — 违反即闪退或编译失败]

- **M-01**: 严禁使用 `@ohos.xxx` 旧版导入，必须使用 `@kit.XXXKit` 命名空间。
- **M-02**: 调用任何相机/存储 API 前，必须先在 `module.json5` 中声明权限，然后调用 `requestPermissionsFromUser` 获取动态授权。
- **M-03**: 任何从文件 Uri、相机流、资源 ID 创建的 `PixelMap`，使用完毕后**必须在 `finally` 块中显式调用 `.release()`**。未释放将导致 C++ 层 OOM 闪退。
- **M-04**: 禁止使用 `console.log`，统一使用 `hilog.info/error/warn`。
- **M-05**: 禁止隐式 `any`，所有 API 返回值必须定义 `interface` 或使用显式类型标注。
- **M-06**: 严禁将 `PixelMap` 直接存入 SQLite 数据库，只允许存文件 Uri/Base64 字符串。
- **M-07**: 所有涉及 AI 运算、文件 I/O 的操作必须使用 `async/await`，禁止阻塞 UI 主线程。
- **M-08**: 类属性（`@State` 变量）必须在声明时初始化，或在构造函数中初始化。
- **M-09**: 所有系统调用必须包裹在 `try-catch` 块中，捕获 `BusinessError` 类型。
- **M-10**: `module.json5` 缺失 `ohos.permission.CAMERA` 声明将导致活体检测直接崩溃。
:::

## <logic_flow>
### [开发流程 — 每一次代码生成必须遵循]

```
1. [前置检查] 确认目标页面所需权限
   └── 查 M-02 → 权限是否已在 module.json5 声明？
2. [权限申请] 生成 atManager.requestPermissionsFromUser 代码
   └── grantStatus === 0 才继续，否则提示用户
3. [类型定义] 先定义 Input/Output interface，再写业务逻辑
   └── 查 M-05
4. [async 包装] 所有系统调用和文件 I/O 包裹在 async 函数
   └── 查 M-07, M-09
5. [资源释放] PixelMap / fileIo / stream 全部在 finally 块释放
   └── 查 M-03, M-06
6. [日志注入] 每一步关键节点使用 hilog 记录
   └── 查 M-04
```

### [PixelMap 全生命周期]

```
Uri/FilePath/Resource
    │
    ▼
image.createImageSource(fd/uri)   ← image.createPixelMap() 构造 PixelMap
    │                                （必须类型标注: PixelMap | undefined）
    ▼
[业务使用: VisionKit / AI Kit]
    │
    ▼
finally {
    pixelMap?.release();           ← 强制释放
}
```
:::

## <data_structures>
### [必须预定义的 ArkTS 接口]

```typescript
// Standard Template: ArkTS 强制类型声明
// 用途: 每次调用系统 API 前必须先定义返回类型 interface
import { BusinessError } from '@kit.BasicServicesKit';

interface SystemCallResult {
  success: boolean;
  message: string;
}

interface PermissionResult {
  grantStatus: number;
  authToken: string;
}
```
:::

## <best_practices>
### [权限申请标准流程]

```typescript
// Standard Template: 动态权限申请
// 文件路径参考: entry/src/main/ets/utils/PermissionUtil.ets
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';

async function requestCameraPermission(context: common.UIAbilityContext): Promise<boolean> {
  const permissions: Permissions[] = ['ohos.permission.CAMERA'];
  const atManager = abilityAccessCtrl.createAtManager();
  try {
    const result = await atManager.requestPermissionsFromUser(context, permissions);
    const grantStatus = result.authResults[0];
    return grantStatus === 0;
  } catch (err) {
    const error = err as BusinessError;
    return false;
  }
}
```

### [BusinessError 标准处理]

```typescript
// Standard Template: 异常捕获
// 用途: 所有 try-catch 块必须使用此模板
try {
  // 系统调用
} catch (err) {
  const error = err as BusinessError;
  hilog.error(0x0000, 'FaceCheck', `Code: ${error.code}, Msg: ${error.message}`);
}
```

### [PixelMap 文件读取与释放]

```typescript
// Standard Template: 文件 PixelMap 读取 + 释放
// 文件路径参考: entry/src/main/ets/utils/FaceVisionUtil.ets
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';

async function loadPixelMapFromFile(filePath: string): Promise<image.PixelMap | undefined> {
  let file: fileIo.File | undefined = undefined;
  let imageSource: image.ImageSource | undefined = undefined;
  let pixelMap: image.PixelMap | undefined = undefined;
  try {
    file = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY);
    imageSource = image.createImageSource(file.fd);
    pixelMap = await imageSource.createPixelMap();
    return pixelMap;
  } catch (err) {
    hilog.error(0x0000, 'FaceCheck', 'loadPixelMap failed: %{public}s', (err as BusinessError).message);
    return undefined;
  } finally {
    imageSource?.release();
    if (file) {
      await fileIo.close(file);
    }
  }
}
```

### [hilog 日志规范]

```typescript
// Standard Template: 日志标签
// 用法: hilog.info(0x0000, 'FaceCheck', '格式化字符串', ...args)
hilog.info(0x0000, 'FaceCheck', 'Face registered: %{public}s', studentId);
hilog.error(0x0000, 'FaceCheck', 'Camera error: %{public}d', error.code);
hilog.warn(0x0000, 'FaceCheck', 'Permission denied, code: %{public}d', code);
```
:::

## <quick_reference>
| 场景 | 操作 | 规范 |
|------|------|------|
| 相机调用前 | 权限检查 | `grantStatus === 0` 才继续 |
| PixelMap 使用 | 资源释放 | `finally { pixelMap?.release() }` |
| 系统 API 调用 | 异常捕获 | `try-catch` + `BusinessError` |
| 日志输出 | 禁止 console | `hilog.info/error/warn` |
| 数据库存储 | PixelMap 禁止 | 只存 Uri / Base64 |
| 类型声明 | 禁止隐式 any | `PixelMap \| undefined` |
| 字符串资源 | UI 文本 | `$r('app.string.xxx')` |
| 图片资源 | 图标 | `$r('app.media.xxx')` |
:::

## <verification_checklist>
- [ ] 所有导入使用 `@kit` 而非 `@ohos`
- [ ] 相机调用前有 `requestPermissionsFromUser` 代码
- [ ] `PixelMap` 有对应的 `finally { .release() }` 释放
- [ ] `hilog` 替代了所有 `console.log`
- [ ] 所有系统调用包裹在 `try-catch` 中
- [ ] 无隐式 `any` 类型（编译无警告）
- [ ] 所有 `async/await` 函数返回值类型标注
- [ ] `module.json5` 包含目标权限声明
</verification_checklist>
