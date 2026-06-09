# 人脸活体检测 (interactiveLiveness)

在人脸识别应用中，活体检测能实时捕捉人脸或者通过眨眼、张嘴、摇头、点头等组合动作，使用人脸关键点定位和人脸追踪等技术，验证用户是否为真实活体操作。可有效抵御照片、视频、面具、遮挡以及屏幕翻拍等常见的攻击手段。

> 起始版本: 5.0.0(12)

## 导入模块

```typescript
import { interactiveLiveness } from '@kit.VisionKit';
```

> 系统能力: `SystemCapability.AI.Component.LivenessDetect`
> 支持设备: Phone, Tablet

---

## 数据结构

### DetectionMode — 检测模式枚举

> 元服务 API: 从版本 5.0.0(12) 开始支持
> 起始版本: 5.0.0(12)

| 名称 | 值 | 说明 |
|------|-----|------|
| SILENT_MODE | SILENT_MODE | 静默活体检测模式，暂未支持 |
| INTERACTIVE_MODE | INTERACTIVE_MODE | 动作活体检测模式 |

### ActionsNumber — 动作数量枚举

> 元服务 API: 从版本 5.0.0(12) 开始支持
> 起始版本: 5.0.0(12)

| 名称 | 值 | 说明 |
|------|-----|------|
| ONE_ACTION | 1 | 随机选择一个动作，暂未支持 |
| TWO_ACTION | 2 | 随机选择两个动作，暂未支持 |
| THREE_ACTION | 3 | 随机选择三个动作 |
| FOUR_ACTION | 4 | 随机选择四个动作 |

### RouteRedirectionMode — 路由跳转模式枚举

> 元服务 API: 从版本 5.0.0(12) 开始支持
> 起始版本: 5.0.0(12)

| 名称 | 值 | 说明 |
|------|-----|------|
| BACK_MODE | back | 人脸活体检测完成后返回到上一页 |
| REPLACE_MODE | replace | 人脸活体检测完成后跳转到成功或失败页面 |

### InteractiveLivenessConfig — 活体检测配置

> 元服务 API: 从版本 5.0.0(12) 开始支持
> 起始版本: 5.0.0(12)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| isSilentMode | DetectionMode | 否 | 否 | 人脸活体检测模式，默认动作活体检测模式 (INTERACTIVE_MODE) |
| actionsNum | ActionsNumber | 否 | 是 | 动作数量，范围 3 或 4，默认 3 |
| successfulRouteUrl | string | 否 | 是 | 成功后跳转的页面路径（routeMode 为 replace 时生效）|
| failedRouteUrl | string | 否 | 是 | 失败后跳转的页面路径（routeMode 为 replace 时生效）|
| routeMode | RouteRedirectionMode | 否 | 是 | 跳转模式，默认 REPLACE_MODE |
| challenge | string | 否 | 是 | 安全摄像头场景挑战值，长度范围 [16, 128]，需开通 Device Security 服务 |
| speechSwitch | boolean | 否 | 是 | 语音播报开关，默认 true（开启）|
| isPrivacyMode | boolean | 否 | 是 | 隐私模式开关，默认 false。开启时需额外申请 `ohos.permission.PRIVACY_WINDOW` 权限 |

**actionsNum 动作随机生成规则**:

- actionsNum = 3: [眨眼，注视] 组合不会同时存在且相邻动作不会相同
- actionsNum = 4: 眨眼动作有且仅有 1 次，注视动作最多 1 次，[眨眼，注视] 组合不相邻，相邻动作不会相同

**示例配置**:

```typescript
let routerOptions: interactiveLiveness.InteractiveLivenessConfig = {
  isSilentMode: interactiveLiveness.DetectionMode.INTERACTIVE_MODE,
  routeMode: interactiveLiveness.RouteRedirectionMode.REPLACE_MODE,
  actionsNum: interactiveLiveness.ActionsNumber.THREE_ACTION,
  failedRouteUrl: 'pages/FailPage',
  successfulRouteUrl: 'pages/SuccessPage'
};
```

### LivenessType — 活体类型枚举

> 元服务 API: 从版本 5.0.0(12) 开始支持
> 起始版本: 5.0.0(12)

| 名称 | 值 | 说明 |
|------|-----|------|
| INTERACTIVE_LIVENESS | 0 | 动作活体检测 |
| SILENT_LIVENESS | 1 | 静默活体检测，暂未支持 |
| NOT_LIVENESS | 2 | 非活体（检测失败），跳转失败页面，不会返回错误信息 |

### InteractiveLivenessResult — 检测结果

> 元服务 API: 从版本 5.0.0(12) 开始支持
> 起始版本: 5.0.0(12)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| livenessType | LivenessType | 否 | 否 | 活体检测模式 |
| mPixelMap | image.PixelMap | 否 | 是 | 检测成功后返回最具有活体特征的图片 |
| securedImageBuffer | ArrayBuffer | 否 | 是 | 安全摄像头场景返回的安全流 |
| certificate | Array\<string\> | 否 | 是 | 安全摄像头场景返回的证书链 |

### 动作说明

| 动作 ID | 动作 | 描述 |
|---------|------|------|
| 1 | 点头 | 上下点头 |
| 2 | 张嘴 | 张开嘴巴 |
| 3 | 眨眼 | 眨眼 |
| 4 | 左摇头 | 向左摇头 |
| 5 | 右摇头 | 向右摇头 |
| 6 | 注视 | 注视屏幕中心 |

---

## 方法

### startLivenessDetection (无 callback)

> 元服务 API: 从版本 5.0.0(12) 开始支持
> 起始版本: 5.0.0(12)

> **需要权限**: `ohos.permission.CAMERA`

```typescript
startLivenessDetection(config: InteractiveLivenessConfig): Promise<boolean>
```

跳转到人脸活体检测页面（路由模式），使用 Promise 异步回调获取跳转结果。检测结果通过 `getInteractiveLivenessResult()` 在目标页面获取。

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| config | InteractiveLivenessConfig | 是 | 活体检测配置项 |

| 返回值类型 | 说明 |
|------------|------|
| Promise\<boolean\> | true: 跳转成功<br>false: 跳转失败 |

**错误码**:

| 错误码 ID | 错误信息 |
|-----------|----------|
| 201 | Permission denied. |
| 1008301002 | Route switching failed. |

**示例**:

```typescript
import { interactiveLiveness } from '@kit.VisionKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

let routerOptions: interactiveLiveness.InteractiveLivenessConfig = {
  actionsNum: interactiveLiveness.ActionsNumber.THREE_ACTION,
  isSilentMode: interactiveLiveness.DetectionMode.INTERACTIVE_MODE
};

interactiveLiveness.startLivenessDetection(routerOptions).then((isSuccess: boolean) => {
  if (isSuccess) {
    hilog.info(0x0001, 'LivenessCollectionIndex', 'Succeeded in jumping.');
  } else {
    hilog.info(0x0001, 'LivenessCollectionIndex', 'Redirection failed.');
  }
}).catch((err: BusinessError) => {
  hilog.error(0x0001, 'LivenessCollectionIndex', `Error: ${err.code}, ${err.message}`);
});
```

### startLivenessDetection (带 callback)

> 元服务 API: 从版本 5.0.0(12) 开始支持
> 起始版本: 5.0.0(12)

> **需要权限**: `ohos.permission.CAMERA`

```typescript
startLivenessDetection(
  config: InteractiveLivenessConfig,
  callback: AsyncCallback<InteractiveLivenessResult | undefined>
): Promise<boolean>
```

跳转到人脸活体检测页面，使用 Promise 异步回调获取跳转结果，使用 callback 回调获取检测结果。**当前只适用于 BACK_MODE 跳转模式**。

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| config | InteractiveLivenessConfig | 是 | 活体检测配置项 |
| callback | AsyncCallback\<InteractiveLivenessResult \| undefined\> | 是 | 回调函数，检测成功时 err 为 undefined，data 为结果；检测失败时 result 返回 undefined |

| 返回值类型 | 说明 |
|------------|------|
| Promise\<boolean\> | true: 跳转成功<br>false: 跳转失败 |

**错误码**:

| 错误码 ID | 错误信息 |
|-----------|----------|
| 201 | Permission denied. |
| 401 | Parameter error. |
| 1008301002 | Route switching failed. |
| 1008302000 | Detection algorithm initialization. |
| 1008302001 | Detection timeout. |
| 1008302002 | Action mutual exclusion error. |
| 1008302003 | Continuity Check Failure. |
| 1008302004 | The test is not complete. |

**示例**:

```typescript
import { interactiveLiveness } from '@kit.VisionKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

let routerOptions: interactiveLiveness.InteractiveLivenessConfig = {
  actionsNum: interactiveLiveness.ActionsNumber.THREE_ACTION,
  isSilentMode: interactiveLiveness.DetectionMode.INTERACTIVE_MODE,
  routeMode: interactiveLiveness.RouteRedirectionMode.BACK_MODE
};

interactiveLiveness.startLivenessDetection(routerOptions, (err: BusinessError,
  result: interactiveLiveness.InteractiveLivenessResult | undefined) => {
  if (err.code !== 0 && !result) {
    hilog.error(0x0001, 'LivenessCollectionIndex',
      `Failed to detect. Code: ${err.code}, message: ${err.message}`);
    return;
  }
  hilog.info(0x0001, 'LivenessCollectionIndex', `Succeeded in detecting result: ${result}`);
});
```

### getInteractiveLivenessResult

> 元服务 API: 从版本 5.0.0(12) 开始支持
> 起始版本: 5.0.0(12)

```typescript
getInteractiveLivenessResult(): Promise<InteractiveLivenessResult>
```

获取人脸活体检测的结果。使用 Promise 异步回调。**在 REPLACE_MODE 的成功页面中调用此方法获取检测结果**。

| 返回值类型 | 说明 |
|------------|------|
| Promise\<InteractiveLivenessResult\> | Promise 对象，返回人脸活体检测的结果 |

**错误码**:

| 错误码 ID | 错误信息 |
|-----------|----------|
| 1008302000 | Detection algorithm initialization. |
| 1008302001 | Detection timeout. |
| 1008302002 | Action mutual exclusion error. |
| 1008302003 | Continuity Check Failure. |
| 1008302004 | The test is not complete. |

**示例**:

```typescript
import { interactiveLiveness } from '@kit.VisionKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

interactiveLiveness.getInteractiveLivenessResult().then((data) => {
  hilog.info(0x0001, 'LivenessCollectionIndex', 'Succeeded in detecting.');
}).catch((err) => {
  hilog.error(0x0001, 'LivenessCollectionIndex', `Failed: ${err.code}`);
});
```
