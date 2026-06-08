---
metadata:
  id: "SKILL-HM-003"
  name: "VisionKit-FaceComparator"
  version: "1.0"
  target_api: "HarmonyOS NEXT (API 12)"
  category: "AI"
  dependencies: ["@kit.CoreVisionKit", "@kit.ImageKit", "@kit.CoreFileKit", "@kit.MediaLibraryKit", "SKILL-HM-001", "SKILL-HM-002"]
  trigger_keywords: ["人脸比对", "faceComparator", "compareFaces", "similarity", "isSamePerson", "FaceCompareResult", "VisionInfo", "0~1相似度"]
  strictness: "High"
---

# VisionKit — faceComparator 人脸比对

## <purpose>
本技能定义了使用 Core Vision Kit `faceComparator` 模块进行人脸 1:1 比对的标准流程。输入两张图片的 `PixelMap`，返回相似度分数（0~1）和是否为同一人的判断。适用于 FaceCheck 的"注册人脸 vs 刷脸签到"的比对场景。
:::

## <constraints>
### [强制约束 — 违反将导致比对失败或崩溃]

- **FC-01**: 输入 PixelMap 颜色格式必须为 **RGBA_8888**（系统相机默认输出即为此格式）。
- **FC-02**: 两张图片均必须包含清晰人脸，比对结果依赖图像质量。
- **FC-03**: 必须严格遵循 `init()` → `compareFaces()` → `release()` 的生命周期顺序。
- **FC-04**: `release()` 必须在 `finally` 块中执行，确保即使比对失败也能正确释放。
- **FC-05**: 活体检测返回的 `PixelMap` 天然满足 RGBA_8888 要求，可直接传入比对；图库选择图片必须先确认格式转换。
- **FC-06**: `similarity` 取值范围为 [0, 1]，签到阈值建议 ≥ 0.6 视为同一人。
- **FC-07**: 对比结果受光线、角度、表情变化影响大，实际应用中建议设置合理阈值（如 0.6）并结合业务判断。
:::

## <logic_flow>
### [人脸比对完整流程]

```
1. [权限检查] 确保已获取 CAMERA 权限
2. [初始化] faceComparator.init() → boolean
   └── false → 报错退出
3. [获取 PixelMap A] 基准人脸（注册照 / 活体结果）
4. [获取 PixelMap B] 现场人脸（注册照 / 活体结果）
5. [封装 VisionInfo]
   ├── visionInfo1 = { pixelMap: pixelMapA }
   └── visionInfo2 = { pixelMap: pixelMapB }
6. [比对] faceComparator.compareFaces(visionInfo1, visionInfo2)
   └── 返回 FaceCompareResult { isSamePerson, similarity }
7. [释放资源] finally { pixelMapA?.release(); pixelMapB?.release(); await faceComparator.release() }
```

### [FaceCompareResult 返回值]

| 字段 | 类型 | 说明 |
|------|------|------|
| `isSamePerson` | `boolean` | true=同一人，false=非同一人 |
| `similarity` | `number` | 相似度，范围 [0, 1]，越大越相似 |
:::

## <data_structures>

### [FaceCompareResult 接口]

```typescript
// Standard Template: 比对结果
interface FaceCompareResult {
  isSamePerson: boolean;
  similarity: number; // 0.0 ~ 1.0
}
```

### [VisionInfo 封装]

```typescript
// Standard Template: VisionInfo 构造
// 用途: compareFaces 的输入必须封装为此结构
interface VisionInfo {
  pixelMap: image.PixelMap;
}
```

### [比对结果处理接口]

```typescript
// Standard Template: 比对输出封装
interface CompareOutput {
  similarity: number;    // 0.00 ~ 100.00 (百分比)
  similarityRaw: number; // 0.0 ~ 1.0 (原始值)
  isSamePerson: boolean;
  passThreshold: boolean; // similarity >= 阈值(默认0.6)
}
```
:::

## <best_practices>
### [完整比对代码模板 — 签到场景]

```typescript
// Standard Template: 人脸比对完整流程
// 文件路径参考: entry/src/main/ets/service/FaceCheckService.ets
import { faceComparator } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG = 'FaceCheckService';
const SIMILARITY_THRESHOLD = 0.6;

interface CompareResult {
  isSamePerson: boolean;
  similarity: number;
  pass: boolean;
}

async function compareFace(pixelMapA: image.PixelMap, pixelMapB: image.PixelMap): Promise<CompareResult> {
  // Step 1: 初始化
  const initResult = await faceComparator.init();
  if (!initResult) {
    hilog.error(0x0000, TAG, 'faceComparator init failed');
    throw new Error('Face comparator initialization failed');
  }

  // Step 2: 封装 VisionInfo
  const visionInfo1: faceComparator.VisionInfo = { pixelMap: pixelMapA };
  const visionInfo2: faceComparator.VisionInfo = { pixelMap: pixelMapB };

  // Step 3: 执行比对
  let compareResult: CompareResult = { isSamePerson: false, similarity: 0, pass: false };
  try {
    const data = await faceComparator.compareFaces(visionInfo1, visionInfo2);
    const similarityPercent = Number((data.similarity * 100).toFixed(2));
    const pass = data.similarity >= SIMILARITY_THRESHOLD;

    hilog.info(0x0000, TAG, 'Compare result: similarity=%{public}f, isSamePerson=%{public}s',
      data.similarity, data.isSamePerson.toString());

    compareResult = {
      isSamePerson: data.isSamePerson,
      similarity: data.similarity,
      pass: pass
    };
  } catch (err) {
    const error = err as BusinessError;
    hilog.error(0x0000, TAG, 'compareFaces failed: code=%{public}d, msg=%{public}s',
      error.code, error.message);
    throw err;
  } finally {
    // Step 4: 释放资源
    await faceComparator.release();
    pixelMapA.release();
    pixelMapB.release();
  }

  return compareResult;
}
```

### [错误码速查]

| 错误码 | 说明 | 处理建议 |
|--------|------|---------|
| 200 | 运行超时，重试 | 重新调用 `init` + `compareFaces` |
| 401 | 参数检查失败 | 确认两个 PixelMap 均有效且格式正确 |
| 1008400001 | 执行失败，重试 | 清理资源后重试 |
| 1008400002 | 服务异常 | 提示用户稍后再试 |
:::

## <verification_checklist>
- [ ] 调用前有 `faceComparator.init()`，且检查返回值
- [ ] 两个 PixelMap 均封装在 `faceComparator.VisionInfo` 中
- [ ] 比对结果判断 `similarity >= 0.6`（或业务阈值）
- [ ] `finally` 块中同时释放 `faceComparator.release()` 和两个 `PixelMap.release()`
- [ ] 错误码 200/401/1008400001 有重试逻辑或用户提示
- [ ] 使用 `hilog` 记录比对过程和结果
- [ ] `module.json5` 包含 `SystemCapability.AI.Face.Comparator`
- [ ] `BusinessError` 类型转换正确
</verification_checklist>
