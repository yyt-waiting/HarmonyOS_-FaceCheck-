# 人脸比对 (faceComparator)

识别人脸，对人像进行高精度比对，给出置信度分数，判断对象是否为同一个人。人脸比对技术可应用于对图库照片的智能分类管理等场景中。基于领先的端侧智能图像识别算法，对人脸识别准确度高。

> 起始版本: 5.0.0(12)

## 导入模块

```typescript
import { faceComparator } from '@kit.CoreVisionKit';
```

> 系统能力: `SystemCapability.AI.Face.Comparator`

---

## 数据结构

### VisionInfo — 待识别视觉信息

> 起始版本: 5.0.0(12)

待识别的视觉信息，目前仅支持颜色数据格式为 RGBA_8888 的 PixelMap 类型的视觉信息。

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| pixelMap | image.PixelMap | 是 | 否 | 待识别的图片 |

### FaceCompareResult — 比对结果

> 起始版本: 5.0.0(12)

| 名称 | 类型 | 只读 | 可选 | 说明 |
|------|------|------|------|------|
| isSamePerson | boolean | 是 | 否 | 是否是同一个人，true 代表为同一个人，false 代表不是同一个人 |
| similarity | number | 是 | 否 | 相似度，取值范围是 0~1 的浮点数，值越大说明相似程度越高 |

---

## 方法

### faceComparator.init

> 起始版本: 5.0.0(12)

```typescript
init(): Promise<boolean>
```

初始化人脸比对分析器服务。使用 Promise 异步回调。

| 返回值类型 | 说明 |
|------------|------|
| Promise\<boolean\> | Promise 对象，返回初始化是否成功。<br>true: 初始化成功<br>false: 初始化失败 |

**示例**:

```typescript
import { faceComparator } from '@kit.CoreVisionKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

async function initAndReleaseFaceComparator(): Promise<void> {
  const initResult = await faceComparator.init();
  hilog.info(0x0000, 'faceComparatorSample', `Face comparator initialization result: ${initResult}`);

  if (initResult) {
    hilog.info(0x0000, 'faceComparatorSample', 'Face comparator initialized successfully');

    // 这里可以添加使用人脸比较服务的代码

    await faceComparator.release();
    hilog.info(0x0000, 'faceComparatorSample', 'Face comparator released successfully');
  } else {
    hilog.error(0x0000, 'faceComparatorSample', 'Failed to initialize face comparator');
  }
}
```

### faceComparator.release

> 起始版本: 5.0.0(12)

```typescript
release(): Promise<void>
```

释放人脸比对分析器服务。使用 Promise 异步回调。

| 返回值类型 | 说明 |
|------------|------|
| Promise\<void\> | Promise 对象，无返回结果 |

### faceComparator.compareFaces

> 起始版本: 5.0.0(12)

```typescript
compareFaces(visionInfo1: VisionInfo, visionInfo2: VisionInfo): Promise<FaceCompareResult>
```

创建人脸比对实例并执行人脸比对，使用 Promise 异步回调。

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| visionInfo1 | VisionInfo | 是 | 第一张包含人脸的图片 |
| visionInfo2 | VisionInfo | 是 | 第二张包含人脸的图片 |

| 返回值类型 | 说明 |
|------------|------|
| Promise\<FaceCompareResult\> | Promise 对象，返回人脸比对的结果 |

**错误码**:

| 错误码 ID | 错误信息 |
|-----------|----------|
| 200 | Run timed out, please try again later. |
| 401 | The parameter check failed. |
| 1008400001 | Failed to run, please try again. |
| 1008400002 | The service is abnormal. |

**示例**:

```typescript
import { faceComparator } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

async function faceCompareTest(): Promise<void> {
  let chooseImage: image.PixelMap | undefined = undefined;
  let chooseImage1: image.PixelMap | undefined = undefined;

  // 从图库中选择两张图片
  let photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
  photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
  photoSelectOptions.maxSelectNumber = 2;
  let photoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
  let photoSelectResult = await photoPicker.select(photoSelectOptions);
  let uris = photoSelectResult.photoUris;

  if (uris.length !== 2) {
    hilog.info(0x0000, 'testTag', 'selected uris length is not 2');
    return;
  }

  // 将选择的图片转换为 PixelMap
  let fileSource = await fileIo.open(uris[0], fileIo.OpenMode.READ_ONLY);
  let imageSource = image.createImageSource(fileSource.fd);
  chooseImage = await imageSource.createPixelMap();
  await fileIo.close(fileSource);
  imageSource.release();

  fileSource = await fileIo.open(uris[1], fileIo.OpenMode.READ_ONLY);
  imageSource = image.createImageSource(fileSource.fd);
  chooseImage1 = await imageSource.createPixelMap();
  await fileIo.close(fileSource);
  imageSource.release();

  if (!chooseImage || !chooseImage1) {
    hilog.info(0x0000, 'testTag', 'chooseImage or chooseImage1 is undefined');
    return;
  }

  // 调用人脸比对接口
  let visionInfo: faceComparator.VisionInfo = { pixelMap: chooseImage };
  let visionInfo1: faceComparator.VisionInfo = { pixelMap: chooseImage1 };

  let data: faceComparator.FaceCompareResult = await faceComparator.compareFaces(visionInfo, visionInfo1);
  let similarity = (data.similarity * 100).toFixed(2);
  let isSamePerson = data.isSamePerson ? 'is' : 'is not';
  let faceString = `Similarity: ${similarity}%. ${isSamePerson} the same person`;
  hilog.info(0x0000, 'testTag', `faceString data is ${faceString}`);

  // 释放资源
  chooseImage.release();
  chooseImage1.release();
}
```
