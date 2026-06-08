// Path: entry/src/main/ets/utils/ImageFileUtil.ets
// 沙箱文件管理：PixelMap 保存为 JPG，文件读取为 PixelMap
// 严格遵循规范：绝对禁止将 PixelMap 存入数据库

import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from './Logger';
import { Constants } from './Constants';

const TAG = 'ImageFileUtil';

interface SaveResult {
  success: boolean;
  fileName: string;
  message: string;
}

/**
 * 确保目录存在（忽略 EEXIST 错误）
 */
async function ensureDir(dirPath: string): Promise<void> {
  try {
    await fileIo.mkdir(dirPath);
    logger.info('Directory created: %{public}s', dirPath);
  } catch (err) {
    const error = err as BusinessError;
    if (error.code !== Constants.ERR_FILE_EXIST) {
      throw err;
    }
    // EEXIST: 目录已存在，正常忽略
  }
}

/**
 * 将 PixelMap 保存为 JPG 文件到沙箱目录
 * @param context 应用上下文
 * @param pixelMap 人脸 PixelMap
 * @param studentId 学号（用于生成唯一文件名）
 * @returns 保存结果，含文件名（不含完整路径）
 */
async function savePixelMapToFile(
  context: Context,
  pixelMap: image.PixelMap,
  studentId: string
): Promise<SaveResult> {
  const timestamp = Date.now();
  const fileName = `face_${studentId}_${timestamp}.jpg`;
  const faceDir = context.filesDir + '/' + Constants.FACE_IMAGES_DIR;
  const filePath = faceDir + '/' + fileName;
  let fd: number = -1;

  try {
    await ensureDir(faceDir);

    fd = await fileIo.open(filePath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);

    const packer = image.createImagePacker();
    const packOptions: image.PackingOption = {
      format: 'image/jpeg',
      quality: 90
    };

    await packer.packToFile(pixelMap, fd, packOptions);
    await packer.release();

    // 验证文件可读性
    const verifySource = image.createImageSource(filePath);
    const verifyMap = await verifySource.createPixelMap();
    verifySource.release();
    verifyMap.release();

    logger.info('PixelMap saved: %{public}s', fileName);
    return { success: true, fileName: fileName, message: '图片保存成功' };
  } catch (err) {
    const error = err as BusinessError;
    logger.error('Save PixelMap failed: code=%{public}d, msg=%{public}s',
      error.code, error.message);
    return { success: false, fileName: '', message: `保存失败: ${error.message}` };
  } finally {
    if (fd !== -1) {
      await fileIo.close(fd);
    }
  }
}

/**
 * 从沙箱文件读取图片为 PixelMap（供 faceComparator 比对使用）
 * @param context 应用上下文
 * @param fileName 数据库中存储的文件名（非完整路径）
 */
async function loadPixelMapFromFile(
  context: Context,
  fileName: string
): Promise<image.PixelMap | undefined> {
  const filePath = context.filesDir + '/' + Constants.FACE_IMAGES_DIR + '/' + fileName;
  let fd: fileIo.File | undefined = undefined;
  let imageSource: image.ImageSource | undefined = undefined;
  let pixelMap: image.PixelMap | undefined = undefined;

  try {
    fd = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY);
    imageSource = image.createImageSource(fd);
    pixelMap = await imageSource.createPixelMap();
    logger.info('PixelMap loaded: %{public}s', fileName);
    return pixelMap;
  } catch (err) {
    logger.error('Load PixelMap failed: %{public}s', (err as BusinessError).message);
    return undefined;
  } finally {
    imageSource?.release();
    if (fd) {
      await fileIo.close(fd);
    }
  }
}

/**
 * 删除沙箱人脸文件（用户注销时调用）
 */
async function deleteFaceFile(context: Context, fileName: string): Promise<boolean> {
  const filePath = context.filesDir + '/' + Constants.FACE_IMAGES_DIR + '/' + fileName;
  try {
    await fileIo.unlink(filePath);
    logger.info('Face file deleted: %{public}s', fileName);
    return true;
  } catch (err) {
    logger.warn('Delete face file failed: %{public}s', (err as BusinessError).message);
    return false;
  }
}

export { savePixelMapToFile, loadPixelMapFromFile, deleteFaceFile };
