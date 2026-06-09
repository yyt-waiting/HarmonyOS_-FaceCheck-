---
metadata:
  id: "SKILL-HM-004"
  name: "VisionKit-FaceDetector"
  version: "1.0"
  target_api: "HarmonyOS NEXT (API 12)"
  category: "AI"
  dependencies: ["@kit.CoreVisionKit", "@kit.ImageKit", "@kit.CoreFileKit", "@kit.MediaLibraryKit", "SKILL-HM-001", "SKILL-HM-002"]
  trigger_keywords: ["人脸检测", "faceDetector", "detect", "Face", "FaceRectangle", "FacePose", "FacePoint", "遮挡检测", "FaceRecognitionConfiguration", "五官定位"]
  strictness: "High"
---

# VisionKit — faceDetector 人脸检测

## <purpose>
本技能定义了使用 Core Vision Kit `faceDetector` 模块进行静态图片人脸检测的标准流程。返回检测到的人脸数量、位置框、姿态角度和五官关键点。与活体检测（视频流）不同，本技能专门处理静态图片的质量预检场景。
:::

## <constraints>
### [强制约束]

- **FD-01**: 输入 PixelMap 颜色格式必须为 **RGBA_8888**。
- **FD-02**: 检测结果数组按人脸框大小排序（最大人脸优先）。
- **FD-03**: 必须遵循 `init()` → `detect()` → `release()` 生命周期。
- **FD-04**: 检测无结果时返回空数组 `[]`，需业务层判断并提示"未检测到人脸"。
- **FD-05**: API 5.0.2(14) 开始支持人脸遮挡检测，通过 `FaceRecognitionConfiguration.faceBlock: true` 开启。
- **FD-06**: 人脸框坐标基于原图像素坐标系，不随设备旋转改变。
- **FD-07**: 多张人脸时 `probability` 最高的为主脸，建议取第一个结果进行后续比对。
- **FD-08**: 本技能适用于**静态图片**质量预检；视频流/人脸追踪请使用其他方案。
:::

## <logic_flow>
### [人脸检测完整流程]

```
1. [权限检查] 确保已获取 CAMERA / 媒体库权限
2. [初始化] faceDetector.init() 或 faceDetector.init(config)
   └── 需遮挡检测时传入 FaceRecognitionConfiguration
3. [获取 PixelMap] 从图库/相机/文件读取
4. [封装 VisionInfo] { pixelMap: pixelMapA }
5. [检测] faceDetector.detect(visionInfo)
   └── 返回 Array<Face>
6. [解析结果] 遍历 Face[]，检查 probability / rect / pose / points
7. [释放资源] finally { pixelMap.release(); faceDetector.release() }
```

### [Face 数据结构速查]

| 字段 | 类型 | 说明 |
|------|------|------|
| `probability` | `number` | 置信度 [0, 1]，越大越可靠 |
| `rect` | `FaceRectangle` | 人脸框 `{left, top, width, height}` |
| `pose` | `FacePose` | 三维姿态 `{yaw, pitch, roll}`，范围 [-180, 180] |
| `points` | `Array<FacePoint>` | 五官点 `[左眼, 右眼, 鼻子, 左嘴角, 右嘴角]` |
| `block` | `FaceBlock` | 遮挡状态（需开启配置）|
:::

## <data_structures>

### [Face 接口]

```typescript
// Standard Template: 人脸检测结果
interface Face {
  probability: number;           // 0.0 ~ 1.0
  rect: FaceRectangle;           // 人脸框
  pose: FacePose;                // 头部姿态
  points: Array<FacePoint>;      // 五官关键点
  block?: FaceBlock;             // 遮挡状态（API 14+）
}
```

### [FaceRectangle — 人脸框]

```typescript
// Standard Template: 人脸矩形框
interface FaceRectangle {
  left: number;   // 左上角 x 坐标（px）
  top: number;    // 左上角 y 坐标（px）
  width: number;  // 宽度（px）
  height: number; // 高度（px）
}
```

### [FacePose — 三维姿态]

```typescript
// Standard Template: 头部三维姿态
interface FacePose {
  yaw: number;   // 航向角 [-180, 180]，绕 Y 轴旋转
  pitch: number; // 俯仰角 [-180, 180]，绕 X 轴旋转
  roll: number;  // 横滚角 [-180, 180]，绕 Z 轴旋转
}
```

### [FacePoint — 五官关键点]

```typescript
// Standard Template: 五官关键点
interface FacePoint {
  x: number; // 横向像素坐标
  y: number; // 纵向像素坐标
}
// points 顺序: [左眼, 右眼, 鼻子, 左嘴角, 右嘴角]
```

### [FaceRecognitionConfiguration — 遮挡检测配置]

```typescript
// Standard Template: 遮挡检测配置
// 用途: API 14+ 开启人脸遮挡检测
interface FaceRecognitionConfig {
  faceBlock: boolean; // true=开启遮挡检测，默认 false
}
```

### [FaceBlock — 遮挡枚举]

```typescript
// Standard Template: 遮挡状态枚举
type FaceBlockStatus =
  | -1  // UNINITIALIZED: 未开启遮挡检测
  | 0   // UNBLOCKED: 无遮挡
  | 1;  // BLOCKED: 有遮挡
```
:::

## <best_practices>
### [基础检测代码模板 — 图库图片]

```typescript
// Standard Template: 人脸检测完整流程
// 文件路径参考: entry/src/main/ets/service/FaceDetectService.ets
import { faceDetector } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

const TAG = 'FaceDetectService';
const MIN_PROBABILITY = 0.5;

interface DetectOutput {
  faceCount: number;
  faces: faceDetector.Face[];
  validFace: faceDetector.Face | null;
}

async function detectFace(uri: string): Promise<DetectOutput> {
  let file: fileIo.File | undefined = undefined;
  let imageSource: image.ImageSource | undefined = undefined;
  let pixelMap: image.PixelMap | undefined = undefined;

  // Step 1: 初始化检测器
  const initResult = await faceDetector.init();
  if (!initResult) {
    throw new Error('Face detector init failed');
  }

  try {
    // Step 2: 加载图片为 PixelMap
    file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
    imageSource = image.createImageSource(file.fd);
    pixelMap = await imageSource.createPixelMap();
    if (!pixelMap) {
      throw new Error('PixelMap creation failed');
    }

    // Step 3: 执行检测
    const visionInfo: faceDetector.VisionInfo = { pixelMap: pixelMap };
    const faces = await faceDetector.detect(visionInfo);

    // Step 4: 解析结果
    const faceCount = faces.length;
    hilog.info(0x0000, TAG, 'Detected %{public}d face(s)', faceCount);

    if (faceCount === 0) {
      return { faceCount: 0, faces: [], validFace: null };
    }

    // 过滤低置信度人脸
    const validFaces = faces.filter(f => f.probability >= MIN_PROBABILITY);
    const primaryFace = validFaces[0] ?? null;

    if (primaryFace) {
      hilog.info(0x0000, TAG,
        'Primary face: prob=%{public}f, rect=[%{public}d, %{public}d, %{public}d, %{public}d]',
        primaryFace.probability,
        primaryFace.rect.left, primaryFace.rect.top,
        primaryFace.rect.width, primaryFace.rect.height);
    }

    return { faceCount, faces, validFace: primaryFace };
  } catch (err) {
    const error = err as BusinessError;
    hilog.error(0x0000, TAG, 'detectFace failed: code=%{public}d', error.code);
    throw err;
  } finally {
    pixelMap?.release();
    imageSource?.release();
    if (file) { await fileIo.close(file); }
    await faceDetector.release();
  }
}
```

### [开启遮挡检测模板]

```typescript
// Standard Template: 遮挡检测初始化
// 用途: API 14+ 开启人脸遮挡检测
const config: faceDetector.FaceRecognitionConfiguration = {
  faceBlock: true
};
const initResult = await faceDetector.init(config);
if (!initResult) {
  hilog.error(0x0000, TAG, 'Face detector with block detection init failed');
  return;
}

// 检测后检查遮挡状态
const faces = await faceDetector.detect(visionInfo);
for (const face of faces) {
  if (face.block === faceDetector.FaceBlock.BLOCKED) {
    hilog.warn(0x0000, TAG, 'Face is blocked/occluded');
    // 提示用户：请勿遮挡面部
  }
}
```

### [错误码速查]

| 错误码 | 说明 | 处理建议 |
|--------|------|---------|
| 200 | 运行超时 | 重试 |
| 401 | 参数检查失败 | 确认 PixelMap 有效 |
| 1008800001 | 执行失败 | 清理后重试 |
| 1008800002 | 服务异常 | 提示稍后再试 |
:::

## <verification_checklist>
- [ ] 调用前有 `faceDetector.init()`，且检查返回值
- [ ] PixelMap 封装在 `faceDetector.VisionInfo` 中传入
- [ ] 空数组场景有业务提示（"未检测到人脸"）
- [ ] `probability < 0.5` 的人脸被过滤或提示
- [ ] `finally` 块中同时释放 `PixelMap` 和 `faceDetector.release()`
- [ ] 五官点 `points` 顺序按 [左眼, 右眼, 鼻子, 左嘴角, 右嘴角] 解析
- [ ] 姿态角 `pose` 有合理范围判断（±60°内为正常角度）
- [ ] `module.json5` 包含 `SystemCapability.AI.Face.Detector`
</verification_checklist>
