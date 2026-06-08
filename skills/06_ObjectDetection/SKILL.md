---
metadata:
  id: "SKILL-HM-006"
  name: "VisionKit-ObjectDetection"
  version: "1.0"
  target_api: "HarmonyOS NEXT (API 12)"
  category: "AI"
  dependencies: ["@kit.CoreVisionKit", "@kit.ImageKit", "@kit.CoreFileKit", "@kit.MediaLibraryKit", "SKILL-HM-001", "SKILL-HM-002"]
  trigger_keywords: ["多目标识别", "objectDetection", "ObjectDetector", "process", "VisionObject", "boundingBox", "labels", "目标分类", "物体检测"]
  strictness: "High"
---

# VisionKit — ObjectDetection 多目标识别

## <purpose>
本技能定义了使用 Core Vision Kit `objectDetection` 模块进行静态图片多目标识别的标准流程。检测图像中的多个物体（人脸、风景、动物、植物等），返回类别标签、置信度和边界框。适用于图库图片内容分析或签到场景前的图片质量校验。
:::

## <constraints>
### [强制约束]

- **OD-01**: 输入 PixelMap 颜色格式必须为 **RGBA_8888**。
- **OD-02**: `ObjectDetector` 必须通过**静态方法 `.create()`** 创建实例，禁止 `new ObjectDetector()`。
- **OD-03**: 检测完成后必须调用 `detector.destroy()` 销毁实例，释放内存。
- **OD-04**: 检测结果按置信度排序，同一目标可对应多个标签（如同时检测到"人体"和"人脸"）。
- **OD-05**: `process()` 仅支持**单张图片**输入，不支持批量多图。
- **OD-06**: 本模块支持 **Phone + PC + Tablet**，Tablet 全功能支持。
- **OD-07**: 检测结果为空数组 `[]` 时需业务层判断提示"未检测到目标"。
:::

## <logic_flow>
### [多目标识别完整流程]

```
1. [PixelMap 加载] uri → fileIo.open → image.createImageSource → createPixelMap
2. [创建检测器] ObjectDetector.create() → detector 实例
3. [封装 Request] { inputData: { pixelMap }, scene: FOREGROUND }
4. [执行检测] detector.process(request)
   └── 返回 ObjectDetectionResponse { objects: VisionObject[] }
5. [解析结果] 遍历 VisionObject[]，提取 labels/boundingBox/score
6. [资源释放] finally { pixelMap.release(); imageSource.release(); detector.destroy() }
```

### [目标标签速查表]

| 标签ID | 类别 | 标签ID | 类别 |
|--------|------|--------|------|
| 0 | 风景 | 9 | 猫头 |
| 1 | 动物 | 10 | 狗头 |
| 2 | 植物 | 11 | 食物 |
| 3 | 建筑 | 12 | 汽车 |
| 5 | 人脸 | 13 | 人体 |
| 6 | 表格 | 21 | 文档 |
| 7 | 文本 | 22 | 卡证 |
| 8 | 人头 | | |
:::

## <data_structures>

### [VisionObject — 单个目标]

```typescript
// Standard Template: 识别出的单个目标对象
interface VisionObject {
  boundingBox: BoundingBox;      // 目标边界框
  score: number;                 // 置信度 (0, 1)，越大越可靠
  labels: Array<number>;         // 类别标签 ID 数组
  id: number;                    // 目标唯一 ID（从0递增）
}
```

### [BoundingBox — 边界框]

```typescript
// Standard Template: 边界框
interface BoundingBox {
  left: number;
  top: number;
  height: number;
  width: number;
}
```

### [ObjectDetectionResponse — 检测响应]

```typescript
// Standard Template: 检测结果
interface ObjectDetectionResponse {
  objects: Array<VisionObject>; // 检测到的所有目标
}
```

### [Label 名称映射]

```typescript
// Standard Template: 标签 ID → 中文名称
const LABEL_NAMES: Record<number, string> = {
  0: '风景', 1: '动物', 2: '植物', 3: '建筑',
  5: '人脸', 6: '表格', 7: '文本', 8: '人头',
  9: '猫头', 10: '狗头', 11: '食物',
  12: '汽车', 13: '人体', 21: '文档', 22: '卡证'
};
```
:::

## <best_practices>
### [完整检测代码模板]

```typescript
// Standard Template: 多目标识别完整流程
// 文件路径参考: entry/src/main/ets/utils/ObjectDetectUtil.ets
import { objectDetection, visionBase } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';

const TAG = 'ObjectDetectUtil';
const MIN_SCORE = 0.3;

const LABEL_NAMES: Record<number, string> = {
  0: '风景', 1: '动物', 2: '植物', 3: '建筑',
  5: '人脸', 6: '表格', 7: '文本', 8: '人头',
  9: '猫头', 10: '狗头', 11: '食物',
  12: '汽车', 13: '人体', 21: '文档', 22: '卡证'
};

interface DetectResult {
  totalCount: number;
  objects: objectDetection.VisionObject[];
  hasFace: boolean;
  faceCount: number;
}

async function detectObjects(uri: string): Promise<DetectResult> {
  let file: fileIo.File | undefined = undefined;
  let imageSource: image.ImageSource | undefined = undefined;
  let pixelMap: image.PixelMap | undefined = undefined;
  let detector: objectDetection.ObjectDetector | undefined = undefined;

  try {
    // Step 1: 加载图片
    file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
    imageSource = image.createImageSource(file.fd);
    pixelMap = await imageSource.createPixelMap();
    if (!pixelMap) {
      throw new Error('PixelMap creation failed');
    }

    // Step 2: 创建检测器
    detector = await objectDetection.ObjectDetector.create();
    hilog.info(0x0000, TAG, 'ObjectDetector created');

    // Step 3: 封装请求并检测
    const request: visionBase.Request = {
      inputData: { pixelMap: pixelMap },
      scene: visionBase.SceneMode.FOREGROUND
    };
    const response = await detector.process(request);

    // Step 4: 解析结果
    const objects = response.objects;
    hilog.info(0x0000, TAG, 'Detected %{public}d object(s)', objects.length);

    const hasFace = objects.some(obj => obj.labels.includes(5));
    const faceCount = objects.filter(obj => obj.labels.includes(5)).length;

    for (const obj of objects) {
      const labelNames = obj.labels.map(id => LABEL_NAMES[id] ?? `未知(${id})`).join(', ');
      hilog.info(0x0000, TAG,
        'Object id=%{public}d, score=%{public}f, labels=%{public}s, box=[%{public}d,%{public}d,%{public}d,%{public}d]',
        obj.id, obj.score, labelNames,
        obj.boundingBox.left, obj.boundingBox.top,
        obj.boundingBox.width, obj.boundingBox.height);
    }

    return { totalCount: objects.length, objects, hasFace, faceCount };
  } catch (err) {
    const error = err as BusinessError;
    hilog.error(0x0000, TAG, 'detectObjects failed: code=%{public}d', error.code);
    throw err;
  } finally {
    pixelMap?.release();
    imageSource?.release();
    if (file) { await fileIo.close(file); }
    if (detector) { await detector.destroy(); }
  }
}
```

### [错误码速查]

| 错误码 | 说明 | 处理建议 |
|--------|------|---------|
| 401 | 参数检查失败 | 确认 PixelMap 有效 |
| 1011000001 | 执行失败 | 重试 |
| 1011000003 | 模型加载失败 | 确认设备支持 |
| 1011000004 | 运行超时 | 重试 |
:::

## <verification_checklist>
- [ ] `ObjectDetector` 使用 `.create()` 创建，非 `new`
- [ ] `detector` 在 `finally` 中调用 `.destroy()`
- [ ] `pixelMap`、`imageSource`、`file`、`detector` 全部在 `finally` 中释放
- [ ] 标签 ID 有对应的中文名称映射展示
- [ ] 空结果 `[]` 有用户提示
- [ ] `request.scene` 设为 `FOREGROUND`
- [ ] `module.json5` 包含 `SystemCapability.AI.Vision.ObjectDetection`
- [ ] 标签过滤逻辑正确（`labels.includes(5)` 对应人脸）
</verification_checklist>
