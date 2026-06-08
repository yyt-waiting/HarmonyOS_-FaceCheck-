# Core Vision Kit 基类 (visionBase)

visionBase 封装了视觉能力场景中的基本资源对象、数据结构、常用方法和生命周期管理。开发者可将其理解为 VisionKit 家族的"工具箱"，利用它可以更高效、更标准地实现各类视觉功能。

> 起始版本: 5.0.0(12)

## 导入模块

```typescript
import { visionBase } from '@kit.CoreVisionKit';
```

---

## 数据结构

### SceneMode — 场景模式

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.0(12)

| 名称 | 值 | 说明 |
|------|-----|------|
| FOREGROUND | 1 | (默认) 前台模式 |
| BACKGROUND | 2 | 后台模式 |

### ImageData — 视觉信息对象

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.0(12)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| pixelMap | image.PixelMap | 否 | 否 | 待识别的图片 |

### InputData — 输入数据类型

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.0(12)

```typescript
type InputData = ImageData | ImageData[];
```

多个图像数据组成的数组，可输入一个或多个图片。

### BoundingBox — 边界框

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.0(12)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| left | number | 否 | 否 | 边界框左上角的 x 坐标 |
| top | number | 否 | 否 | 边界框左上角的 y 坐标 |
| height | number | 否 | 否 | 边界框高度，单位为像素 |
| width | number | 否 | 否 | 边界框宽度，单位为像素 |

### Point — 二维点

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.0(12)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| x | number | 否 | 否 | 点的横坐标 |
| y | number | 否 | 否 | 点的纵坐标 |

### Orientation — 三维朝向

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.0(12)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| yaw | number | 否 | 否 | 绕 Y 轴旋转的角度（偏航角），取值范围 [-180, 180] |
| pitch | number | 否 | 否 | 绕 X 轴旋转的角度（俯仰角），取值范围 [-180, 180] |
| roll | number | 否 | 否 | 绕 Z 轴旋转的角度（翻滚角），取值范围 [-180, 180] |

---

## 模型下载事件 (预留接口，当前版本暂不支持)

### DownloadStartData — 下载开始事件

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.2(14)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| resId | string | 否 | 否 | 资源标识符，用于标识正在下载的模型 |

### DownloadCompleteData — 下载完成事件

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.2(14)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| resId | string | 否 | 否 | 资源标识符 |
| resVersion | string | 否 | 否 | 资源版本号 |

### DownloadCancelData — 下载取消事件

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.2(14)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| resId | string | 否 | 否 | 资源标识符 |

### DownloadStatusData — 下载状态事件

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.2(14)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| resId | string | 否 | 否 | 资源标识符 |
| statusCode | downloadStatusCode | 否 | 否 | 状态码 |
| message | string | 否 | 否 | 状态描述信息 |

### DownloadProgressData — 下载进度事件

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.2(14)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| resId | string | 否 | 否 | 资源标识符 |
| progressInfo | string | 否 | 否 | 进度信息 |

### downloadStatusCode — 下载状态码枚举

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 6.0.0(20)

| 名称 | 值 | 说明 |
|------|-----|------|
| PARAMETER_INVALID | 0 | 传入的下载参数有误 |
| NO_NETWORK_STATUS | 1 | 设备离线或网络不可用 |
| NO_MODEL | 2 | 服务器上找不到对应的模型文件 |
| COPY_FILE_FAILED | 3 | 下载后无法将模型文件复制到指定位置 |
| DOWNLOAD_NOT_ALLOWED | 4 | 用户已选择拒绝 |
| DOWNLOAD_TIME_OUT | 5 | 网络较慢或服务器响应延迟 |
| DOWNLOAD_EXCEPTION | 6 | 下载过程中出现错误 |
| DOWNLOAD_BACK_TO_DESKTOP | 7 | 用户在下载过程中切换出应用 |
| TASK_BUSY | 8 | 系统繁忙，正在执行另一个任务 |

---

## Request — 入参基类

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.0(12)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| inputData | InputData | 否 | 否 | 待识别的图片，可以是单个对象或多个对象的数组 |
| scene | SceneMode | 否 | 是 | 请求的场景模式，默认值为 `SceneMode.FOREGROUND`（预留字段，暂未实现）|
| requestId | string | 否 | 是 | 请求的标识，用于开发者跟踪和管理自己的请求（预留字段，暂未实现）|

## Response — 响应基类

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.0(12)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| requestId | string | 否 | 是 | 请求的唯一标识，默认值为空字符串 |

---

## Analyzer — 能力引擎基类

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.0(12)

Analyzer 基类充当多种视觉能力引擎的基类，提供统一的生命周期管理接口。

### destroy

> 起始版本: 5.0.0(12)

```typescript
destroy(): Promise<void>
```

用于销毁多种视觉能力的进程。使用 Promise 异步回调。

| 返回值类型 | 说明 |
|------------|------|
| Promise\<void\> | Promise 对象，无返回结果 |

**示例**: 参见 ObjectDetection.destroy

---

## 模型下载事件监听

### on('downloadStart')

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.2(14)
> 预留接口，当前版本暂不支持

```typescript
on(type: 'downloadStart', callback: Callback<DownloadStartData>): void
```

订阅模型下载开始事件。

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| type | string | 是 | 固定字符串 `'downloadStart'` |
| callback | Callback\<DownloadStartData\> | 是 | 回调函数 |

### on('downloadComplete')

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.2(14)
> 预留接口，当前版本暂不支持

```typescript
on(type: 'downloadComplete', callback: Callback<DownloadCompleteData>): void
```

订阅模型下载完成事件。

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| type | string | 是 | 固定字符串 `'downloadComplete'` |
| callback | Callback\<DownloadCompleteData\> | 是 | 回调函数 |

### on('downloadCancel')

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.2(14)
> 预留接口，当前版本暂不支持

```typescript
on(type: 'downloadCancel', callback: Callback<DownloadCancelData>): void
```

订阅模型下载取消事件。

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| type | string | 是 | 固定字符串 `'downloadCancel'` |
| callback | Callback\<DownloadCancelData\> | 是 | 回调函数 |

### on('downloadStatus')

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.2(14)
> 预留接口，当前版本暂不支持

```typescript
on(type: 'downloadStatus', callback: Callback<DownloadStatusData>): void
```

订阅模型下载状态事件。

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| type | string | 是 | 固定字符串 `'downloadStatus'` |
| callback | Callback\<DownloadStatusData\> | 是 | 回调函数 |

### on('downloadProgress')

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.2(14)
> 预留接口，当前版本暂不支持

```typescript
on(type: 'downloadProgress', callback: Callback<DownloadProgressData>): void
```

订阅模型下载进度事件。

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| type | string | 是 | 固定字符串 `'downloadProgress'` |
| callback | Callback\<DownloadProgressData\> | 是 | 回调函数 |

---

## 取消订阅事件

### off('downloadStart')

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.2(14)
> 预留接口，当前版本暂不支持

```typescript
off(type: 'downloadStart', callback?: Callback<DownloadStartData>): void
```

取消订阅模型下载开始事件。若无 callback 参数，则取消注册所有回调函数。

### off('downloadComplete')

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.2(14)
> 预留接口，当前版本暂不支持

```typescript
off(type: 'downloadComplete', callback?: Callback<DownloadCompleteData>): void
```

取消订阅模型下载完成事件。

### off('downloadCancel')

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.2(14)
> 预留接口，当前版本暂不支持

```typescript
off(type: 'downloadCancel', callback?: Callback<DownloadCancelData>): void
```

取消订阅模型下载取消事件。

### off('downloadStatus')

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.2(14)
> 预留接口，当前版本暂不支持

```typescript
off(type: 'downloadStatus', callback?: Callback<DownloadStatusData>): void
```

取消订阅模型下载状态事件。

### off('downloadProgress')

> 系统能力: `SystemCapability.AI.Vision.VisionBase`
> 起始版本: 5.0.2(14)
> 预留接口，当前版本暂不支持

```typescript
off(type: 'downloadProgress', callback?: Callback<DownloadProgressData>): void
```

取消订阅模型下载进度事件。
