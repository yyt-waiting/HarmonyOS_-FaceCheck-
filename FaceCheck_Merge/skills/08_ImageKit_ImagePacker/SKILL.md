---
metadata:
  id: "SKILL-HM-008"
  name: "ImageKit-ImagePacker"
  version: "1.0"
  target_api: "HarmonyOS NEXT (API 12)"
  category: "IO"
  dependencies: ["@kit.ImageKit", "@kit.CoreFileKit", "@kit.PerformanceAnalysisKit", "SKILL-HM-001"]
  trigger_keywords: ["ImagePacker", "PixelMap压缩", "图片保存", "JPG", "PNG", "沙箱存储", "文件写入", "getContext.filesDir", "uriToPixelMap"]
  strictness: "High"
---

# ImageKit — ImagePacker 沙箱图片存储

## <purpose>
本技能定义了使用 `@kit.ImageKit` 的 `ImagePacker` 将 `PixelMap` 压缩为图片文件并保存到应用沙箱目录的标准流程。由于 `PixelMap` 无法直接存入 SQLite，本技能是人脸图像持久化的关键环节——将 `PixelMap` 保存为 `.jpg` 文件，仅将文件名存入数据库。
:::

## <constraints>
### [强制约束]

- **IP-01**: 保存路径必须基于 `getContext().filesDir`，禁止硬编码绝对路径。
- **IP-02**: 文件名必须唯一，推荐使用 `studentId` + 时间戳或 UUID 防止覆盖。
- **IP-03**: 压缩后的图片必须经 `image.createImageSource` 验证可读取，防止保存损坏文件。
- **IP-04**: 文件写入后必须 `await fileIo.close(fd)`，否则 fd 泄漏。
- **IP-05**: 读取图片重建 `PixelMap` 后，原 `ImageSource` 必须 `.release()`。
- **IP-06**: 本技能生成的 PixelMap 均为**临时用途**，使用完毕后必须在 `finally` 块中释放。
- **IP-07**: 人脸图片建议使用 **JPG 格式**（质量 85~95，压缩率高），PNG 仅在需要透明通道时使用。
- **IP-08**: 保存文件前检查目标目录是否存在，不存在则创建。
:::

## <logic_flow>
### [保存 PixelMap → 沙箱文件]

```
1. [生成文件名] studentId + '_' + timestamp + '.jpg'
2. [构造路径] getContext().filesDir + '/' + fileName
3. [创建目录] fileIo.mkdir 确保目录存在
4. [打开文件] fileIo.open(filePath, WR_ONLY | CREATE)
5. [配置 ImagePacker] outputOption { format: 'image/jpeg', quality: 90 }
6. [压缩写入] imagePacker.packToFile(pixelMap, fd)
7. [关闭文件] fileIo.close(fd)
8. [验证] image.createImageSource(filePath).createPixelMap()
9. [返回] fileName（仅文件名，非完整路径）
```

### [读取沙箱文件 → PixelMap]

```
1. [构造路径] getContext().filesDir + '/' + fileName
2. [打开文件] fileIo.open(filePath, READ_ONLY)
3. [创建源] image.createImageSource(fd)
4. [生成 PixelMap] imageSource.createPixelMap()
5. [释放] imageSource.release(); fileIo.close(fd)
6. [返回] PixelMap（供 VisionKit 使用）
```

### [与数据库的协同关系]

```
注册时: PixelMap → [ImagePacker 保存] → 文件(face_1001.jpg)
                                           │
                                           ▼ 存入 UserTable.face_uri = "face_1001.jpg"

比对时: UserTable.face_uri = "face_1001.jpg"
           │
           ▼ [读取] → PixelMap → faceComparator.compareFaces()
```
:::

## <data_structures>

### [ImagePacker 配置]

```typescript
// Standard Template: 图片压缩配置
// 用途: packToFile / packToData 的输出配置
interface PackerOptions {
  format: 'image/jpeg' | 'image/png'; // MIME 类型
  quality: number;                     // 压缩质量 0~100，JPG 建议 85~95
}
```

### [沙箱路径工具接口]

```typescript
// Standard Template: 沙箱路径封装
// 用途: 统一管理文件路径拼接
interface FileUtil {
  getFaceDir(): string;              // 返回 filesDir/faces/
  getFacePath(fileName: string): string; // 返回完整路径
  ensureDir(dir: string): Promise<void>; // 确保目录存在
}
```
:::

## <best_practices>
### [PixelMap 保存模板 — 人脸注册]

```typescript
// Standard Template: PixelMap 保存到沙箱
// 文件路径参考: entry/src/main/ets/utils/ImageFileUtil.ets
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG = 'ImageFileUtil';
const FACE_DIR = 'faces';

interface SaveResult {
  success: boolean;
  fileName: string;
  message: string;
}

async function savePixelMapToFile(
  context: Context,
  pixelMap: image.PixelMap,
  studentId: string
): Promise<SaveResult> {
  const timestamp = Date.now();
  const fileName = `face_${studentId}_${timestamp}.jpg`;
  const fileDir = context.filesDir + '/' + FACE_DIR;
  const filePath = fileDir + '/' + fileName;
  let fd: number = -1;

  try {
    // Step 1: 确保目录存在
    await ensureDir(fileDir);

    // Step 2: 打开文件（写入模式）
    fd = await fileIo.open(filePath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);

    // Step 3: 配置 ImagePacker
    const packer = image.createImagePacker();
    const packOptions: image.PackingOption = {
      format: 'image/jpeg',
      quality: 90
    };

    // Step 4: 压缩并写入
    await packer.packToFile(pixelMap, fd, packOptions);
    await packer.release();

    hilog.info(0x0000, TAG, 'Image saved: %{public}s', filePath);

    // Step 5: 验证文件可读
    const verifySource = image.createImageSource(filePath);
    const verifyMap = await verifySource.createPixelMap();
    verifySource.release();
    verifyMap.release();

    return { success: true, fileName: fileName, message: '图片保存成功' };
  } catch (err) {
    const error = err as BusinessError;
    hilog.error(0x0000, TAG, 'Save image failed: %{public}s', error.message);
    return { success: false, fileName: '', message: `保存失败: ${error.message}` };
  } finally {
    if (fd !== -1) {
      await fileIo.close(fd);
    }
  }
}

async function ensureDir(dir: string): Promise<void> {
  try {
    await fileIo.mkdir(dir);
  } catch (err) {
    // EEXIST 是预期的，忽略即可
    const error = err as BusinessError;
    if (error.code !== 13900002) { // EEXIST
      throw err;
    }
  }
}
```

### [读取沙箱文件模板 — 人脸比对]

```typescript
// Standard Template: 从沙箱读取图片为 PixelMap
// 文件路径参考: entry/src/main/ets/utils/ImageFileUtil.ets
// 用途: 根据数据库中存储的 fileName 加载 PixelMap 供 faceComparator 使用

async function loadPixelMapFromFile(
  context: Context,
  fileName: string
): Promise<image.PixelMap | undefined> {
  const filePath = context.filesDir + '/' + FACE_DIR + '/' + fileName;
  let fd: fileIo.File | undefined = undefined;
  let imageSource: image.ImageSource | undefined = undefined;
  let pixelMap: image.PixelMap | undefined = undefined;

  try {
    fd = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY);
    imageSource = image.createImageSource(fd);
    pixelMap = await imageSource.createPixelMap();
    hilog.info(0x0000, TAG, 'PixelMap loaded from: %{public}s', fileName);
    return pixelMap;
  } catch (err) {
    hilog.error(0x0000, TAG, 'Load PixelMap failed: %{public}s',
      (err as BusinessError).message);
    return undefined;
  } finally {
    imageSource?.release();
    if (fd) { await fileIo.close(fd); }
  }
}
```

### [删除沙箱文件模板]

```typescript
// Standard Template: 删除沙箱文件
// 用途: 用户注销时删除其人脸图片
async function deleteFaceFile(context: Context, fileName: string): Promise<boolean> {
  const filePath = context.filesDir + '/' + FACE_DIR + '/' + fileName;
  try {
    await fileIo.unlink(filePath);
    hilog.info(0x0000, TAG, 'Face file deleted: %{public}s', fileName);
    return true;
  } catch (err) {
    hilog.warn(0x0000, TAG, 'Delete face file failed: %{public}s',
      (err as BusinessError).message);
    return false;
  }
}
```

### [完整注册流程模板 — 整合 DB + ImagePacker]

```typescript
// Standard Template: 人脸注册完整流程
// 文件路径参考: entry/src/main/ets/service/FaceRegisterService.ets
// 整合 SKILL-HM-007 + SKILL-HM-008

import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

async function registerFace(
  context: Context,
  pixelMap: image.PixelMap,
  studentId: string,
  userName: string
): Promise<{ success: boolean; message: string }> {
  // Step 1: 保存图片到沙箱
  const saveResult = await savePixelMapToFile(context, pixelMap, studentId);
  if (!saveResult.success) {
    return { success: false, message: saveResult.message };
  }

  // Step 2: 写入数据库
  const userRecord: UserRecord = {
    id: 0,
    studentId: studentId,
    userName: userName,
    faceUri: saveResult.fileName,
    gmtCreate: Date.now()
  };
  const dbResult = await insertUser(userRecord);

  // Step 3: 如果数据库失败，清理已保存的图片
  if (!dbResult.success) {
    await deleteFaceFile(context, saveResult.fileName);
    return { success: false, message: dbResult.message };
  }

  hilog.info(0x0000, 'RegisterService', 'Face registered: %{public}s', studentId);
  return { success: true, message: '注册成功' };
}
```

### [错误码速查]

| 场景 | 错误码 | 说明 | 处理 |
|------|--------|------|------|
| mkdir | 13900002 | 目录已存在 | 忽略，继续执行 |
| mkdir | 13900013 | 路径无效 | 检查 path |
| open | 13900002 | 文件不存在（读模式）| 提示文件丢失 |
| open | 13900013 | 权限不足 | 检查权限 |
| ImagePacker | 系统错误 | 压缩失败 | 重试 |
:::

## <verification_checklist>
- [ ] `savePixelMapToFile` 使用 `filesDir` 而非硬编码路径
- [ ] 文件名包含 `studentId` + 时间戳防止覆盖
- [ ] `ImagePacker.packToFile` 后有 `packer.release()`
- [ ] `fileIo.open` 后的 fd 在 `finally` 中 `fileIo.close(fd)`
- [ ] `loadPixelMapFromFile` 读取后 `imageSource.release()` 在 `finally` 中
- [ ] 保存后有文件可读性验证步骤
- [ ] 删除用户时同步删除沙箱文件
- [ ] JPG 格式 `quality` 设置在 85~95 范围
- [ ] `ensureDir` 正确处理 `EEXIST` 错误码 13900002
</verification_checklist>
