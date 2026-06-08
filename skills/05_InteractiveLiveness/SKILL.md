---
metadata:
  id: "SKILL-HM-005"
  name: "VisionKit-InteractiveLiveness"
  version: "1.0"
  target_api: "HarmonyOS NEXT (API 12)"
  category: "AI"
  dependencies: ["@kit.VisionKit", "@kit.ImageKit", "@kit.BasicServicesKit", "@kit.PerformanceAnalysisKit", "SKILL-HM-001"]
  trigger_keywords: ["活体检测", "interactiveLiveness", "startLivenessDetection", "眨眼", "点头", "张嘴", "摇头", "注视", "动作活体", "mPixelMap", "LivenessType"]
  strictness: "High"
---

# VisionKit — InteractiveLiveness 活体检测

## <purpose>
本技能定义了使用 VisionKit `interactiveLiveness` 模块进行人脸活体检测的标准流程。通过系统拉起的相机 UI 要求用户完成随机动作（点头/张嘴/眨眼/摇头/注视），验证用户为真实活体，有效抵御照片/视频/面具攻击。成功返回最清晰的人脸 PixelMap，供后续 faceComparator 比对使用。
:::

## <constraints>
### [强制约束]

- **LV-01**: 必须提前申请 **`ohos.permission.CAMERA`** 动态权限，否则直接抛出 201 Permission denied。
- **LV-02**: 本模块为**页面路由模式**，`startLivenessDetection` 会跳转到系统活体检测页面，检测完成后通过 `routeMode` 返回。
- **LV-03**: `startLivenessDetection` 有两种签名：
  - 无 callback：仅返回 Promise\<boolean\>（跳转是否成功），结果通过 `getInteractiveLivenessResult()` 获取。
  - 带 callback：Promise 返回跳转结果，callback 中获取检测结果（仅 `BACK_MODE` 支持）。
- **LV-04**: 动作活体支持 3~4 个随机动作组合，动作不可相邻重复。
- **LV-05**: 隐私模式（`isPrivacyMode: true`）需额外申请 `ohos.permission.PRIVACY_WINDOW` 权限。
- **LV-06**: 成功检测后返回的 `mPixelMap`（最清晰帧）**必须手动 `.release()`**。
- **LV-07**: 本模块**仅 Phone + Tablet 支持**，PC 不支持。
- **LV-08**: 检测结果 `LivenessType` = `NOT_LIVENESS(2)` 表示失败，跳转失败页面，无回调数据返回。
:::

## <logic_flow>
### [活体检测流程 — 两种模式]

```
【模式 A：无 callback（REPLACE_MODE / 默认）】
1. [权限检查] requestPermissionsFromUser(CAMERA)
2. [配置] InteractiveLivenessConfig
   ├── isSilentMode: INTERACTIVE_MODE（动作活体）
   ├── actionsNum: THREE_ACTION(3) 或 FOUR_ACTION(4)
   ├── routeMode: REPLACE_MODE
   └── successfulRouteUrl / failedRouteUrl
3. [跳转] startLivenessDetection(config)
   └── 返回 true = 跳转成功
4. [系统 UI] 用户完成动作
5. [返回] 系统跳转到成功/失败页面
6. [获取结果] 成功页面调用 getInteractiveLivenessResult()

【模式 B：带 callback（BACK_MODE）】
1-2. 同上
3. [跳转+回调] startLivenessDetection(config, callback)
   └── Promise<boolean> = 跳转结果
   └── callback(InteractiveLivenessResult) = 检测结果
```

### [动作说明]

| 动作ID | 动作 | 描述 |
|--------|------|------|
| 1 | 点头 | 上下点头 |
| 2 | 张嘴 | 张开嘴巴 |
| 3 | 眨眼 | 眨眼 |
| 4 | 左摇头 | 向左摇头 |
| 5 | 右摇头 | 向右摇头 |
| 6 | 注视 | 注视屏幕中心 |

### [返回数据结构]

| 字段 | 类型 | 说明 |
|------|------|------|
| `livenessType` | `LivenessType` | 0=动作活体，1=静默活体(未支持)，2=非活体(失败) |
| `mPixelMap` | `image.PixelMap` | 检测成功后的最清晰人脸图（RGBA_8888）|
| `securedImageBuffer` | `ArrayBuffer` | 安全摄像头场景专用（需开通Device Security服务）|
| `certificate` | `Array<string>` | 安全摄像头场景证书链 |
:::

## <data_structures>

### [InteractiveLivenessConfig — 活体配置]

```typescript
// Standard Template: 活体检测配置
// 用途: startLivenessDetection 的输入参数
interface LivenessConfig {
  isSilentMode: 'SILENT_MODE' | 'INTERACTIVE_MODE'; // 默认 INTERACTIVE_MODE
  actionsNum?: 3 | 4;    // 动作数量，默认3
  successfulRouteUrl?: string; // 成功跳转页面路径
  failedRouteUrl?: string;    // 失败跳转页面路径
  routeMode: 'back' | 'replace'; // 返回模式，默认 replace
  speechSwitch?: boolean;      // 语音播报，默认 true
  isPrivacyMode?: boolean;     // 隐私模式，默认 false
  challenge?: string;          // 安全摄像头场景，长度[16,128]
}
```

### [InteractiveLivenessResult — 检测结果]

```typescript
// Standard Template: 活体检测结果
// 用途: getInteractiveLivenessResult() 返回值
interface LivenessResult {
  livenessType: 0 | 1 | 2;   // 0=动作活体成功，2=失败
  mPixelMap: image.PixelMap;  // 最清晰帧（仅成功时有效）
}
```

### [LivenessType 枚举]

```typescript
// Standard Template: 活体类型
type LivenessType =
  | 0  // INTERACTIVE_LIVENESS: 动作活体检测
  | 1  // SILENT_LIVENESS: 静默活体（暂未支持）
  | 2; // NOT_LIVENESS: 检测失败
```
:::

## <best_practices>
### [模式 A — REPLACE_MODE 模板（推荐签到场景）]

```typescript
// Standard Template: 活体检测 REPLACE_MODE 流程
// 文件路径参考: entry/src/main/ets/pages/SignInPage.ets
import { interactiveLiveness } from '@kit.VisionKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG = 'LivenessService';

async function startLivenessFlow(): Promise<interactiveLiveness.InteractiveLivenessResult | undefined> {
  const config: interactiveLiveness.InteractiveLivenessConfig = {
    isSilentMode: interactiveLiveness.DetectionMode.INTERACTIVE_MODE,
    actionsNum: interactiveLiveness.ActionsNumber.THREE_ACTION,
    routeMode: interactiveLiveness.RouteRedirectionMode.REPLACE_MODE,
    successfulRouteUrl: 'pages/LivenessSuccessPage',
    failedRouteUrl: 'pages/LivenessFailPage'
  };

  try {
    const jumpResult = await interactiveLiveness.startLivenessDetection(config);
    hilog.info(0x0000, TAG, 'Liveness jump result: %{public}s', jumpResult.toString());
    if (!jumpResult) {
      hilog.error(0x0000, TAG, 'Liveness redirect failed');
      return undefined;
    }
    // 结果在成功页面通过 getInteractiveLivenessResult() 获取
    return undefined;
  } catch (err) {
    const error = err as BusinessError;
    hilog.error(0x0000, TAG, 'Liveness start failed: code=%{public}d', error.code);
    throw err;
  }
}
```

### [成功页面获取结果]

```typescript
// Standard Template: 成功页面获取活体结果 PixelMap
// 文件路径参考: entry/src/main/ets/pages/LivenessSuccessPage.ets
async function onPageShow(): Promise<image.PixelMap | undefined> {
  let pixelMap: image.PixelMap | undefined = undefined;
  try {
    const result = await interactiveLiveness.getInteractiveLivenessResult();
    if (result.livenessType === interactiveLiveness.LivenessType.INTERACTIVE_LIVENESS) {
      pixelMap = result.mPixelMap;
      hilog.info(0x0000, TAG, 'Liveness detected successfully');
      return pixelMap;
    }
  } catch (err) {
    hilog.error(0x0000, TAG, 'getInteractiveLivenessResult failed');
  }
  return undefined;
  // 注意: 返回的 pixelMap 使用完毕后必须在 finally 中 .release()
}
```

### [模式 B — BACK_MODE 模板（内嵌场景）]

```typescript
// Standard Template: 活体检测 BACK_MODE + Callback
// 用途: 检测完成后自动返回原页面，结果通过 callback 获得
import { interactiveLiveness } from '@kit.VisionKit';
import { BusinessError } from '@kit.BasicServicesKit';

async function startLivenessWithCallback(): Promise<void> {
  const config: interactiveLiveness.InteractiveLivenessConfig = {
    isSilentMode: interactiveLiveness.DetectionMode.INTERACTIVE_MODE,
    actionsNum: interactiveLiveness.ActionsNumber.THREE_ACTION,
    routeMode: interactiveLiveness.RouteRedirectionMode.BACK_MODE
  };

  const jumpResult = await interactiveLiveness.startLivenessDetection(
    config,
    (err: BusinessError, result: interactiveLiveness.InteractiveLivenessResult | undefined) => {
      if (err.code !== 0 && !result) {
        hilog.error(0x0000, TAG, 'Liveness failed: code=%{public}d', err.code);
        return;
      }
      if (result) {
        hilog.info(0x0000, TAG, 'Liveness success, pixelMap available');
        result.mPixelMap?.release(); // 立即释放
      }
    }
  );
}
```

### [错误码速查]

| 错误码 | 说明 | 处理建议 |
|--------|------|---------|
| 201 | 权限被拒绝 | 提示用户授予相机权限 |
| 401 | 参数错误 | 检查 config 参数合法性 |
| 1008301002 | 路由跳转失败 | 检查页面路径是否存在 |
| 1008302000 | 算法初始化失败 | 重试 |
| 1008302001 | 检测超时 | 提示用户动作太慢，重试 |
| 1008302002 | 动作互斥错误 | 系统问题，重试 |
| 1008302003 | 连续性检查失败 | 提示用户靠近镜头，重试 |
| 1008302004 | 检测未完成 | 用户主动退出，引导重试 |
:::

## <verification_checklist>
- [ ] 调用前有 `requestPermissionsFromUser(CAMERA)` 且 `grantStatus === 0`
- [ ] `config.actionsNum` 设置为 3 或 4
- [ ] `config.isSilentMode` 明确指定为 `INTERACTIVE_MODE`
- [ ] `routeMode` 根据场景选择 `REPLACE_MODE` 或 `BACK_MODE`
- [ ] 成功获取 `mPixelMap` 后，`finally` 块中有 `.release()` 调用
- [ ] `NOT_LIVENESS(2)` 结果有对应的用户提示
- [ ] `isPrivacyMode: true` 时额外申请了 `PRIVACY_WINDOW` 权限
- [ ] `module.json5` 包含 `SystemCapability.AI.Component.LivenessDetect`
- [ ] `BusinessError` 类型转换和错误码处理完整
</verification_checklist>
