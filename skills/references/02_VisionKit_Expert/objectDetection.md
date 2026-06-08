# 多目标识别 (objectDetection)

多目标识别服务提供了从图像中识别多个目标的能力。通过拍照、录像等光学输入方式，把各种场景下的图像转化为数字图像信息，再利用 AI 底层能力对图像进行分析，从中定位并识别出多个感兴趣的目标对象，如人脸、动物、植物等，便于用户提取目标的类别、边框位置、置信度等信息。

> 起始版本: 5.0.0(12)

## 导入模块

```typescript
import { visionBase, objectDetection } from '@kit.CoreVisionKit';
```

> 系统能力: `SystemCapability.AI.Vision.ObjectDetection`

---

## 支持的目标类型

风景、动物、植物、建筑、人脸、表格、文本、人头、猫头、狗头、食物、汽车、人体、文档、卡证。

## 数据结构

### VisionObject — 视觉信息对象

> 起始版本: 5.0.0(12)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| boundingBox | visionBase.BoundingBox | 否 | 否 | visionObject 的边界框 |
| score | number | 否 | 否 | 置信度，范围 (0, 1)，0 表示置信度最低，1 表示置信度最高 |
| labels | Array\<number\> | 否 | 否 | 识别物体的类型标签 ID 数组 |
| id | number | 否 | 否 | visionObject 的唯一标识符（从 0 开始递增的整数编号）|

**标签 ID 对照表**:

| 标签 ID | 类别 | | 标签 ID | 类别 |
|---------|------|--|---------|------|
| 0 | 风景 | | 9 | 猫头 |
| 1 | 动物 | | 10 | 狗头 |
| 2 | 植物 | | 11 | 食物 |
| 3 | 建筑 | | 12 | 汽车 |
| 5 | 人脸 | | 13 | 人体 |
| 6 | 表格 | | 21 | 文档 |
| 7 | 文本 | | 22 | 卡证 |
| 8 | 人头 | | | |

### ObjectDetectionResponse — 检测响应

> 起始版本: 5.0.0(12)

多目标检测的结果类，继承自 visionBase 基类的 Response。

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| objects | Array\<VisionObject\> | 否 | 否 | 多目标检测结果，可以是单个对象或多个对象的数组 |

### ObjectDetector — 检测器类

> 起始版本: 5.0.0(12)

定义多目标识别的接口和基本结构，继承自 visionBase.Analyzer 类。

**构造函数**: 私有构造函数，必须通过 `static create()` 方法创建实例。

| 方法 | 说明 |
|------|------|
| `static create(): Promise<ObjectDetector>` | 初始化多目标识别接口，返回 ObjectDetector 实例 |
| `process(request: visionBase.Request): Promise<ObjectDetectionResponse>` | 处理多目标识别请求，返回检测结果 |
| `destroy(): Promise<void>` | 销毁多目标识别的进程 |

---

## 方法

### ObjectDetector.create

> 起始版本: 5.0.0(12)

```typescript
static create(): Promise<ObjectDetector>
```

多目标识别的初始化接口，使用 Promise 异步回调。

| 返回值类型 | 说明 |
|------------|------|
| Promise\<ObjectDetector\> | Promise 对象，返回 ObjectDetector 实例 |

**错误码**:

| 错误码 ID | 错误信息 |
|-----------|----------|
| 1011000001 | Failed to run, please try again. |
| 1011000002 | The service is abnormal. |

**示例**:

```typescript
import { objectDetection } from '@kit.CoreVisionKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

async function createAndDestroyDetector(): Promise<void> {
  const detector = await objectDetection.ObjectDetector.create();
  if (detector) {
    hilog.info(0x0000, 'objectDetectionSample', 'Object detector created successfully');
  } else {
    hilog.error(0x0000, 'objectDetectionSample', 'Failed to create object detector');
    return;
  }

  // 使用 detector 进行操作 ...

  // 完成后销毁 detector
  if (detector) {
    await detector.destroy();
    hilog.info(0x0000, 'objectDetectionSample', 'Object detector destroyed successfully');
  } else {
    hilog.error(0x0000, 'objectDetectionSample', 'Failed to destroy object detector');
  }
}
```

### detector.destroy

> 起始版本: 5.0.0(12)

```typescript
destroy(): Promise<void>
```

销毁多目标识别的进程，使用 Promise 异步回调。

| 返回值类型 | 说明 |
|------------|------|
| Promise\<void\> | Promise 对象，无返回结果 |

### detector.process

> 起始版本: 5.0.0(12)

```typescript
process(request: visionBase.Request): Promise<ObjectDetectionResponse>
```

创建多目标识别实例并执行多目标识别，使用 Promise 异步回调。

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| request | visionBase.Request | 是 | 图片实例，多目标识别接口仅支持传入一张图片 |

| 返回值类型 | 说明 |
|------------|------|
| Promise\<ObjectDetectionResponse\> | Promise 对象，返回多目标识别的结果 |

**错误码**:

| 错误码 ID | 错误信息 |
|-----------|----------|
| 401 | The parameter check failed. |
| 1011000001 | Failed to run, please try again. |
| 1011000003 | Failed to run the model, please try again. |
| 1011000004 | Running the model timed out. Try again later. |

**示例**:

```typescript
import { objectDetection, visionBase } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

async function objectDetectTest(): Promise<void> {
  let imageSource: image.ImageSource | undefined = undefined;
  let chooseImage: image.PixelMap | undefined = undefined;
  let file: fileIo.File | undefined = undefined;
  let detector: objectDetection.ObjectDetector | undefined = undefined;

  // 通过图库选择一张图片
  let photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
  photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
  photoSelectOptions.maxSelectNumber = 1;
  let photoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
  let photoSelectResult = await photoPicker.select(photoSelectOptions);
  let uri = photoSelectResult.photoUris[0];
  if (uri === undefined) {
    hilog.info(0x0000, 'objectDetectionSample', 'uri is undefined');
    return;
  }

  // 将图片转换为 PixelMap
  file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
  imageSource = image.createImageSource(file.fd);
  chooseImage = await imageSource.createPixelMap();
  hilog.info(0x0000, 'objectDetectionSample', 'chooseImage: %{public}s', chooseImage);
  if (!chooseImage) {
    return;
  }

  // 创建检测器
  detector = await objectDetection.ObjectDetector.create();
  hilog.info(0x0000, 'objectDetectionSample', 'Object detector created successfully');

  // 调用对象检测接口
  let request: visionBase.Request = {
    inputData: { pixelMap: chooseImage },
    scene: visionBase.SceneMode.FOREGROUND
  };
  let response: objectDetection.ObjectDetectionResponse = await detector.process(request);

  if (response.objects.length === 0) {
    hilog.info(0x0000, 'objectDetectionSample', 'No objects detected in the image.');
  } else {
    let objectString = JSON.stringify(response.objects);
    hilog.info(0x0000, 'objectDetectionSample', `Detected objects: ${objectString}`);
  }

  // 清理资源
  chooseImage.release();
  imageSource.release();
  if (file) { await fileIo.close(file); }
  if (detector) {
    await detector.destroy();
    hilog.info(0x0000, 'objectDetectionSample', 'Object detector destroyed successfully');
  }
}
```
