# 人脸检测 (faceDetector)

人脸检测支持 2D 人脸检测框的检测能力。检测给定图片中的人脸数量、人脸位置、特征点（左右眼中心、鼻子、左右嘴角）和姿态（pitch、roll、yaw）信息。人脸检测框按照大小排序。

> 与 VisionKit 的活体检测的区别是：活体检测用于视频，人脸检测用于图片。

> 起始版本: 5.0.0(12)

## 导入模块

```typescript
import { faceDetector } from '@kit.CoreVisionKit';
```

> 系统能力: `SystemCapability.AI.Face.Detector`

---

## 数据结构

### VisionInfo — 待识别视觉信息

> 元服务 API: 从版本 5.0.2(14) 开始支持
> 起始版本: 5.0.0(12)

待识别的视觉信息，目前仅支持颜色数据格式为 RGBA_8888 的 PixelMap 类型的视觉信息。

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| pixelMap | image.PixelMap | 是 | 否 | 待识别的图片 |

### FaceRecognitionConfiguration — 遮挡检测配置

> 起始版本: 5.0.2(14)

人脸遮挡检测的配置项。

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| faceBlock | boolean | 是 | 否 | 是否开启人脸遮挡检测。<br>true: 开启<br>false: 不开启（默认）|

### FaceBlock — 遮挡检测结果枚举

> 起始版本: 5.0.2(14)

| 名称 | 值 | 说明 |
|------|-----|------|
| UNINITIALIZED | -1 | 人脸遮挡检测未开启 |
| UNBLOCKED | 0 | 人脸无遮挡 |
| BLOCKED | 1 | 人脸有遮挡 |

### FacePoint — 五官关键点

> 元服务 API: 从版本 5.0.2(14) 开始支持
> 起始版本: 5.0.0(12)

指示像素点的位置。

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| x | number | 是 | 否 | 像素点横向 x 坐标 |
| y | number | 是 | 否 | 像素点纵向 y 坐标 |

### FacePose — 三维头部姿态

> 元服务 API: 从版本 5.0.2(14) 开始支持
> 起始版本: 5.0.0(12)

描述人脸在三维空间中的方向，坐标系可参考世界坐标系。

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| yaw | number | 是 | 否 | 头型航向，绕 Y 轴旋转（localRotationY），取值范围 [-180, 180] |
| pitch | number | 是 | 否 | 头型俯仰，绕 X 轴旋转（localRotationX），取值范围 [-180, 180] |
| roll | number | 是 | 否 | 头型横滚，绕 Z 轴旋转（localRotationZ），取值范围 [-180, 180] |

### FaceRectangle — 人脸矩形框

> 元服务 API: 从版本 5.0.2(14) 开始支持
> 起始版本: 5.0.0(12)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| left | number | 是 | 否 | 人脸矩形框左上角 x 坐标 |
| top | number | 是 | 否 | 人脸矩形框左上角 y 坐标 |
| width | number | 是 | 否 | 人脸框宽，单位: pixel |
| height | number | 是 | 否 | 人脸框高，单位: pixel |

### Face — 人脸信息

> 元服务 API: 从版本 5.0.2(14) 开始支持
> 起始版本: 5.0.0(12)

表示人脸的信息列表。

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| probability | number | 是 | 否 | 人脸检测结果的置信度，取值范围 0~1 的浮点数，数值越大代表置信度越高 |
| block | FaceBlock | 是 | 是 | 人脸遮挡结果，默认值为 `FaceBlock.UNINITIALIZED`；若开启了遮挡检测，则返回 `UNBLOCKED`（无遮挡）或 `BLOCKED`（有遮挡）|
| pose | FacePose | 是 | 否 | 人脸头型航向 |
| rect | FaceRectangle | 是 | 否 | 人脸框列表 |
| points | Array\<FacePoint\> | 是 | 否 | 人脸五官位置数组，顺序为: 左眼中心、右眼中心、鼻子、左嘴角、右嘴角 |

---

## 方法

### faceDetector.init — 基础初始化

> 元服务 API: 从版本 5.0.2(14) 开始支持
> 起始版本: 5.0.0(12)

```typescript
init(): Promise<boolean>
```

初始化人脸检测分析器服务，使用 Promise 异步回调。

| 返回值类型 | 说明 |
|------------|------|
| Promise\<boolean\> | true: 初始化成功<br>false: 初始化失败 |

**示例**:

```typescript
import { faceDetector } from '@kit.CoreVisionKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

async function initAndReleaseFaceDetector(): Promise<void> {
  const initResult = await faceDetector.init();
  hilog.info(0x0000, 'faceDetectorSample', `Face detector initialization result: ${initResult}`);

  if (initResult) {
    hilog.info(0x0000, 'faceDetectorSample', 'Face detector initialized successfully');
    // 这里可以添加使用人脸检测服务的代码
    await faceDetector.release();
    hilog.info(0x0000, 'faceDetectorSample', 'Face detector released successfully');
  } else {
    hilog.error(0x0000, 'faceDetectorSample', 'Failed to initialize face detector');
  }
}
```

### faceDetector.init — 遮挡检测初始化

> 起始版本: 5.0.2(14)

```typescript
init(faceRecognitionConfiguration: FaceRecognitionConfiguration): Promise<boolean>
```

初始化人脸遮挡检测分析器服务。同一个进程内只要有人脸检测服务开启了遮挡检测，在该人脸检测服务未 release 这段时间内，这个进程内的其他所有人脸检测服务都等同于开启了遮挡检测。

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| faceRecognitionConfiguration | FaceRecognitionConfiguration | 是 | 人脸遮挡检测配置参数 |

| 返回值类型 | 说明 |
|------------|------|
| Promise\<boolean\> | true: 初始化成功<br>false: 初始化失败 |

**错误码**:

| 错误码 ID | 错误信息 |
|-----------|----------|
| 401 | The parameter check failed. |

**示例**:

```typescript
import { faceDetector } from '@kit.CoreVisionKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

async function initWithBlockDetection(): Promise<void> {
  let config: faceDetector.FaceRecognitionConfiguration = { faceBlock: true };
  const initResult = await faceDetector.init(config);
  hilog.info(0x0000, 'faceDetectorSample', `Face detector initialization result: ${initResult}`);

  if (initResult) {
    hilog.info(0x0000, 'faceDetectorSample', 'Face detector initialized successfully');
    await faceDetector.release();
    hilog.info(0x0000, 'faceDetectorSample', 'Face detector released successfully');
  } else {
    hilog.error(0x0000, 'faceDetectorSample', 'Failed to initialize face detector');
  }
}
```

### faceDetector.release

> 元服务 API: 从版本 5.0.2(14) 开始支持
> 起始版本: 5.0.0(12)

```typescript
release(): Promise<void>
```

释放人脸检测分析器服务，使用 Promise 异步回调。

| 返回值类型 | 说明 |
|------------|------|
| Promise\<void\> | Promise 对象，无返回结果 |

### faceDetector.detect

> 元服务 API: 从版本 5.0.2(14) 开始支持
> 起始版本: 5.0.0(12)

```typescript
detect(visionInfo: VisionInfo): Promise<Array<Face>>
```

检测一张图片中的人脸信息，使用 Promise 异步回调。

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| visionInfo | VisionInfo | 是 | 图片实例（包含人脸）|

| 返回值类型 | 说明 |
|------------|------|
| Promise\<Array\<Face\>\> | Promise 对象，返回人脸检测的结果 |

**错误码**:

| 错误码 ID | 错误信息 |
|-----------|----------|
| 200 | Run timed out, please try again later. |
| 401 | The parameter check failed. |
| 1008800001 | Failed to run, please try again. |
| 1008800002 | The service is abnormal. |

**示例**:

```typescript
import { faceDetector } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

async function faceDetectTest(): Promise<void> {
  let imageSource: image.ImageSource | undefined = undefined;
  let chooseImage: image.PixelMap | undefined = undefined;
  let file: fileIo.File | undefined = undefined;

  // 通过图库选择一张图片
  let photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
  photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
  photoSelectOptions.maxSelectNumber = 1;
  let photoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
  let photoSelectResult = await photoPicker.select(photoSelectOptions);
  let uri = photoSelectResult.photoUris[0];
  if (uri === undefined) {
    hilog.info(0x0000, 'faceDetectorSample', 'uri is undefined');
    return;
  }

  // 将图片转换为 PixelMap
  file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
  imageSource = image.createImageSource(file.fd);
  chooseImage = await imageSource.createPixelMap();
  hilog.info(0x0000, 'faceDetectorSample', 'chooseImage: %{public}s', chooseImage);
  if (!chooseImage) {
    return;
  }

  // 调用人脸检测接口
  let visionInfo: faceDetector.VisionInfo = { pixelMap: chooseImage };
  let data: faceDetector.Face[] = await faceDetector.detect(visionInfo);
  if (data.length === 0) {
    hilog.info(0x0000, 'faceDetectorSample', 'No face is detected in the image.');
  } else {
    let faceString = JSON.stringify(data);
    hilog.info(0x0000, 'faceDetectorSample', `faceString data is ${faceString}`);
  }

  // 释放资源
  chooseImage.release();
  imageSource.release();
  if (file) { await fileIo.close(file); }
  await faceDetector.release();
}
```
