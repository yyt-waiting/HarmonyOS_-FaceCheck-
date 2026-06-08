// Path: entry/src/main/ets/service/FaceCompareService.ets
// 人脸比对服务：传入两张 PixelMap，返回相似度和是否为同一人
// 严格遵循规范：init() → compareFaces() → release() + finally 释放资源

import { faceComparator } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';

const TAG = 'FaceCompareService';

/**
 * 人脸比对结果封装
 */
interface CompareResult {
  /** 是否为同一人 */
  isSamePerson: boolean;
  /** 原始相似度值 [0, 1] */
  similarity: number;
  /** 百分比形式相似度 [0, 100] */
  similarityPercent: number;
  /** similarity >= 阈值(0.6) 视为通过 */
  pass: boolean;
}

/**
 * 人脸 1:1 比对核心方法
 * 生命周期：init() → compareFaces() → release()
 * @param pixelMapA 基准人脸 PixelMap（注册照）
 * @param pixelMapB 比对人脸 PixelMap（活体检测结果）
 * @returns Promise<CompareResult> 比对结果
 */
async function compareFace(
  pixelMapA: image.PixelMap,
  pixelMapB: image.PixelMap
): Promise<CompareResult> {
  // Step 1: 初始化人脸比对器
  const initResult = await faceComparator.init();
  if (!initResult) {
    logger.error('Face comparator init failed');
    throw new Error('Face comparator initialization failed');
  }

  // 初始化默认值（避免路径失败时返回 undefined）
  const result: CompareResult = {
    isSamePerson: false,
    similarity: 0,
    similarityPercent: 0,
    pass: false
  };

  try {
    // Step 2: 封装 VisionInfo（必须是 RGBA_8888 格式的 PixelMap）
    const visionInfo1: faceComparator.VisionInfo = { pixelMap: pixelMapA };
    const visionInfo2: faceComparator.VisionInfo = { pixelMap: pixelMapB };

    // Step 3: 执行人脸比对
    const data = await faceComparator.compareFaces(visionInfo1, visionInfo2);

    // Step 4: 计算百分比形式和是否通过阈值
    const similarityPercent = Number((data.similarity * 100).toFixed(2));
    const pass = data.similarity >= Constants.SIMILARITY_THRESHOLD;

    logger.info('Compare result: similarity=%{public}f, similarityPercent=%{public}f, isSamePerson=%{public}s, pass=%{public}s',
      data.similarity, similarityPercent, data.isSamePerson.toString(), pass.toString());

    result.isSamePerson = data.isSamePerson;
    result.similarity = data.similarity;
    result.similarityPercent = similarityPercent;
    result.pass = pass;
  } catch (err) {
    // 捕获 BusinessError 并记录错误码和消息
    const error = err as BusinessError;
    logger.error('Compare faces failed: code=%{public}d, msg=%{public}s',
      error.code, error.message);
    throw err;
  } finally {
    // Step 5: 必须在 finally 中释放所有资源，防止 PixelMap 泄漏导致 OOM
    await faceComparator.release();
    pixelMapA.release();
    pixelMapB.release();
    logger.debug('FaceCompareService resources released');
  }

  return result;
}

export { compareFace, CompareResult };
