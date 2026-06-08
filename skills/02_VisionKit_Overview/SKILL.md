---
metadata:
  id: "SKILL-HM-002"
  name: "VisionKit-Overview"
  version: "1.0"
  target_api: "HarmonyOS NEXT (API 12)"
  category: "AI"
  dependencies: ["@kit.CoreVisionKit", "@kit.VisionKit", "@kit.ImageKit"]
  trigger_keywords: ["VisionKit概览", "PixelMap输入", "SceneMode", "BoundingBox", "Request", "Response", "Analyzer基类", "CoreVisionKit", "视觉能力"]
  strictness: "High"
---

# VisionKit 模块概览与通用规范

## <purpose>
本技能是 Core Vision Kit 与 Vision Kit 所有子模块的共同前置知识。定义了 VisionKit 家族统一的输入输出格式、生命周期规范和 Core Vision Kit 基类结构。生成任何视觉能力代码（FaceDetector / faceComparator / ObjectDetection / InteractiveLiveness）前必须先阅读本技能。
:::

## <constraints>
### [强制约束 — VisionKit 全家族通用]

- **V-01**: VisionKit 所有接口**仅接受 `image.PixelMap`** 类型作为图像输入，不接受 fileUri、ArrayBuffer 或其他格式。
- **V-02**: 必须先将 `fileUri` / `resource` / `buffer` 转换为 `PixelMap` 后，才能传入任何 VisionKit 接口。
- **V-03**: 创建 `PixelMap` 后必须显式调用 `.release()` 释放内存（强制，参见 `SKILL-HM-001` M-03）。
- **V-04**: 所有 VisionKit 能力均需在 `module.json5` 中声明对应系统能力（`SystemCapability.AI.XXX`）。
- **V-05**: Phone + Tablet 双端兼容优先于 PC 专属功能，Tablet 设备注意活体检测支持。
- **V-06**: 活体检测（VisionKit）独占 `@kit.VisionKit`；其余三个能力（FaceDetector / faceComparator / ObjectDetection）共享 `@kit.CoreVisionKit`。
:::

## <logic_flow>
### [VisionKit 统一数据流]

```
图像来源（fileUri / resource / camera stream / liveness result）
    │
    ▼ [image.createImageSource / camera.getOutput]
[PixelMap] ──必须 RGBA_8888──▶ VisionKit 接口
    │                              │
    │                              ▼
    │                        [VisionInfo / Request]
    │                              │
    │                              ▼
    │                        [AI Engine Process]
    │                              │
    │                              ▼
    │                        [Response / Face[] / FaceCompareResult / ObjectDetectionResponse]
    │                              │
    ▼ [finally { .release() }]
```

### [VisionKit 家族速查表]

| 能力 | 模块 | 类/方法 | 场景 | PixelMap 输入方式 |
|------|------|---------|------|-----------------|
| 人脸检测 | CoreVisionKit | `faceDetector.detect(VisionInfo)` | 图片人脸框提取 | VisionInfo.pixelMap |
| 人脸比对 | CoreVisionKit | `faceComparator.compareFaces(v1, v2)` | 两图相似度 | VisionInfo.pixelMap ×2 |
| 活体检测 | VisionKit | `startLivenessDetection(config)` | 刷脸认证防伪 | 系统相机（内部） |
| 多目标识别 | CoreVisionKit | `detector.process(Request)` | 场景物体分类 | Request.inputData |
:::

## <data_structures>

### [VisionInfo — VisionKit 标准输入封装]

```typescript
// Standard Template: VisionInfo 构造
// 用途: faceDetector / faceComparator 的输入必须封装为此结构
interface VisionInfoInput {
  pixelMap: image.PixelMap;
}
```

### [visionBase.Request — ObjectDetector 标准输入]

```typescript
// Standard Template: Request 构造
// 文件路径参考: entry/src/main/ets/utils/ObjectDetectUtil.ets
import { visionBase } from '@kit.CoreVisionKit';

interface ObjectDetectRequest {
  inputData: { pixelMap: image.PixelMap };
  scene: visionBase.SceneMode.FOREGROUND; // 默认前台模式
}
```

### [visionBase.BoundingBox — 统一边界框]

```typescript
// Standard Template: 边界框结构
interface BoundingBox {
  left: number;   // 左上角 x
  top: number;    // 左上角 y
  height: number; // 高度 px
  width: number;  // 宽度 px
}
```

### [visionBase.SceneMode — 场景模式]

```typescript
// Standard Template: 场景枚举
// FOREGROUND=1 前台模式（默认）; BACKGROUND=2 后台模式
import { visionBase } from '@kit.CoreVisionKit';
const mode = visionBase.SceneMode.FOREGROUND;
```

### [visionBase.Response — 统一响应基类]

```typescript
// Standard Template: 响应基类
interface BaseResponse {
  requestId: string; // 请求唯一标识
}
```
:::

## <lifecycle_management>
### [CoreVisionKit vs VisionKit 生命周期模式]

| 模块 | 生命周期模式 | 初始化 | 销毁 |
|------|------------|--------|------|
| faceDetector | 全局单例 | `faceDetector.init()` | `faceDetector.release()` |
| faceComparator | 全局单例 | `faceComparator.init()` | `faceComparator.release()` |
| ObjectDetector | 实例化 | `ObjectDetector.create()` → 实例 | `detector.destroy()` |
| interactiveLiveness | 页面路由 | `startLivenessDetection()` 系统拉起 | 系统自动返回 |

### [ObjectDetector 实例模式 — 必须通过 create()]

```typescript
// Standard Template: ObjectDetector 生命周期
// 文件路径参考: entry/src/main/ets/utils/ObjectDetectUtil.ets
import { objectDetection, visionBase } from '@kit.CoreVisionKit';

async function objectDetectFlow(pixelMap: image.PixelMap): Promise<objectDetection.ObjectDetectionResponse> {
  let detector: objectDetection.ObjectDetector | undefined = undefined;
  try {
    detector = await objectDetection.ObjectDetector.create();
    const request: visionBase.Request = {
      inputData: { pixelMap: pixelMap },
      scene: visionBase.SceneMode.FOREGROUND
    };
    return await detector.process(request);
  } finally {
    if (detector) {
      await detector.destroy();
    }
  }
}
```

### [PixelMap + ObjectDetector 联合释放]

```typescript
// Standard Template: 资源联合释放
// 用途: 同时持有 PixelMap 和 detector 时必须全部释放
let pixelMap: image.PixelMap | undefined = undefined;
let detector: objectDetection.ObjectDetector | undefined = undefined;
let imageSource: image.ImageSource | undefined = undefined;
let file: fileIo.File | undefined = undefined;

try {
  // ... 业务逻辑 ...
} finally {
  if (pixelMap) { pixelMap.release(); }
  if (imageSource) { imageSource.release(); }
  if (file) { await fileIo.close(file); }
  if (detector) { await detector.destroy(); }
}
```
:::

## <best_practices>

### [Uri → PixelMap 标准转换链]

```typescript
// Standard Template: 文件 Uri 转 PixelMap（通用路径）
// 用途: VisionKit 所有输入前的标准预处理
// 文件路径参考: entry/src/main/ets/utils/FaceVisionUtil.ets
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';

async function uriToPixelMap(uri: string): Promise<image.PixelMap | undefined> {
  let file: fileIo.File | undefined = undefined;
  let imageSource: image.ImageSource | undefined = undefined;
  let pixelMap: image.PixelMap | undefined = undefined;
  try {
    file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
    imageSource = image.createImageSource(file.fd);
    pixelMap = await imageSource.createPixelMap();
    return pixelMap;
  } catch (err) {
    hilog.error(0x0000, 'FaceCheck', 'uriToPixelMap failed: %{public}s', (err as BusinessError).message);
    return undefined;
  } finally {
    imageSource?.release();
    if (file) { await fileIo.close(file); }
  }
}
```
:::

## <verification_checklist>
- [ ] 所有 VisionKit 输入均通过 `image.PixelMap` 传入
- [ ] 每次调用前有 `uriToPixelMap` 或等效转换
- [ ] `ObjectDetector` 使用 `.create()` 而非 `new`
- [ ] `detector` 和 `PixelMap` 均在 `finally` 中正确释放
- [ ] `module.json5` 包含 `SystemCapability.AI.XXX` 声明
- [ ] faceComparator / faceDetector 使用全局 `.init()` / `.release()` 模式
- [ ] ObjectDetector 使用实例 `.destroy()` 模式
- [ ] 活体检测使用 `@kit.VisionKit`，其余使用 `@kit.CoreVisionKit`
</verification_checklist>
