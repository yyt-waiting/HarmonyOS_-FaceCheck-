# HarmonyOS NEXT (API 12) ArkTS 基础与硬件交互规范

## 1. 核心开发范式

- **模型**: Stage 模型 (API 12)
- **语言**: ArkTS (严格模式)
- **核心库**: 必须优先从 `@kit` 导入

## 2. 硬件权限申请规范

在调用相机、存储之前，必须先生成动态授权代码，否则应用会崩溃。

- **模块**: `import { abilityAccessCtrl, common } from '@kit.AbilityKit';`
- **逻辑**:
  1. 在 `module.json5` 声明权限
  2. 调用 `atManager.requestPermissionsFromUser` 弹窗
  3. 只有在 `grantStatus === 0` 时才允许启动相机或 AI 引擎

## 3. 图像处理与转换 (ImageKit)

VisionKit 仅接受 `PixelMap`。必须掌握从不同来源获取 PixelMap 的标准路径：

- **路径 A — 文件 Uri → PixelMap**: `image.createImageSource(uri)` → `source.createPixelMap()`
- **路径 B — 资源回收**: 任何转换出来的 `PixelMap` 必须在使用完毕后显式调用 `.release()`，且必须包裹在 `finally` 块中

## 4. ArkTS 静态检查红线

1. **禁止隐式 any**: 必须为所有 API 调用结果定义接口 (interface)
2. **显式空校验**: 鸿蒙 API 常返回 `undefined`，必须使用 `if (result)` 或 `result?.` 进行安全访问
3. **构造函数约束**: 类属性必须在构造函数中初始化，或使用 `state: string = ''` 形式

## 5. UI 架构规范 (MVVM)

为防止代码混乱，必须遵循以下分层：

- **View 层 (Page/Component)**: 只负责声明 UI 结构，使用 `@State` 驱动视图
- **ViewModel 层 (Logic/Util)**: 处理复杂的计算、AI Kit 调用、数据库读写
- **数据层 (Model)**: 定义 `interface` 数据结构

## 6. 标准异常处理 (BusinessError)

API 12 中所有系统报错均为 `BusinessError`：

```typescript
import { BusinessError } from '@kit.BasicServicesKit';

try {
  // 系统调用
} catch (err) {
  let error = err as BusinessError;
  hilog.error(0x0000, 'FaceCheck', `Code: ${error.code}, Msg: ${error.message}`);
}
```

## 7. 资源文件管理 (resources/)

- **字符串**: 界面文本应放在 `resources/base/element/string.json`
- **图片**: 图标资源放在 `resources/base/media`
- **调用**: 使用 `$r('app.string.xxx')` 或 `$r('app.media.xxx')`

## 8. 日志与调试 (hilog)

- 禁止使用 `console.log`
- 统一使用 `hilog.info(0x0000, 'FaceCheck', 'format_string', ...args)`
