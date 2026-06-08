// Path: entry/src/main/ets/service/FaceDetectService.ets
// 人脸检测服务：静态图片人脸框检测，用于注册前质量预检
// 严格遵循规范：init() → detect() → release() 生命周期

import { faceDetector } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG = 'FaceDetectService';
const MIN_PROBABILITY = 0.5;

/**
 * 人脸检测结果输出接口
 */
interface DetectOutput {
  /** 检测到的人脸总数 */
  faceCount: number;
  /** 置信度最高的有效人脸，若无符合条件的人脸则为 null */
  validFace: faceDetector.Face | null;
}

/**
 * 检测图片中的人脸
 * 适用于静态图片的质量预检场景（如注册人脸前的图片验证）
 *
 * @param pixelMap 输入图片的 PixelMap 对象（需为 RGBA_8888 格式）
 * @returns 检测结果：人脸数量和置信度最高的有效人脸
 * @throws 若检测器初始化失败或检测过程异常则抛出错误
 */
async function detectFace(pixelMap: image.PixelMap): Promise<DetectOutput> {
  // Step 1: 初始化检测器
  const initResult = await faceDetector.init();
  if (!initResult) {
    hilog.error(0x0000, TAG, 'Face detector init failed');
    throw new Error('Face detector initialization failed');
  }
  hilog.info(0x0000, TAG, 'Face detector initialized successfully');

  try {
    // Step 2: 封装 VisionInfo 并执行检测
    const visionInfo: faceDetector.VisionInfo = {
      pixelMap: pixelMap
    };
    const faces = await faceDetector.detect(visionInfo);

    // Step 3: 解析检测结果
    const faceCount = faces.length;
    hilog.info(0x0000, TAG, 'Detected %{public}d face(s)', faceCount);

    // 无检测结果
    if (faceCount === 0) {
      return { faceCount: 0, validFace: null };
    }

    // 按人脸框大小排序后，过滤低置信度人脸
    // 约束 FD-02: 检测结果数组按人脸框大小排序（最大人脸优先）
    // 约束 FD-07: 多张人脸时 probability 最高的为主脸
    const validFaces = faces.filter(f => f.probability >= MIN_PROBABILITY);
    const primaryFace = validFaces[0] ?? null;

    if (primaryFace) {
      hilog.info(0x0000, TAG,
        'Primary face: probability=%{public}f, rect=[%{public}d, %{public}d, %{public}d, %{public}d]',
        primaryFace.probability,
        primaryFace.rect.left, primaryFace.rect.top,
        primaryFace.rect.width, primaryFace.rect.height);
      hilog.info(0x0000, TAG,
        'Face pose: yaw=%{public}f, pitch=%{public}f, roll=%{public}f',
        primaryFace.pose.yaw, primaryFace.pose.pitch, primaryFace.pose.roll);
    } else {
      hilog.warn(0x0000, TAG,
        'No face with probability >= %{public}f found, all faces filtered out',
        MIN_PROBABILITY);
    }

    return { faceCount, validFace: primaryFace };
  } catch (err) {
    // Step 4: 捕获并记录异常
    const error = err as BusinessError;
    hilog.error(0x0000, TAG,
      'Face detection failed: code=%{public}d, message=%{public}s',
      error.code, error.message);
    throw err;
  } finally {
    // Step 5: 严格遵循 FD-03 生命周期，释放检测器资源
    await faceDetector.release();
    hilog.info(0x0000, TAG, 'Face detector released');
  }
}

/**
 * 开启遮挡检测的人脸检测
 * 适用于 API 14+ 需要检测人脸是否被遮挡的场景
 *
 * @param pixelMap 输入图片的 PixelMap 对象
 * @returns 检测结果，包含遮挡状态信息
 */
async function detectFaceWithBlock(pixelMap: image.PixelMap): Promise<DetectOutput & { blocked: boolean }> {
  // 使用遮挡检测配置初始化
  const config: faceDetector.FaceRecognitionConfiguration = {
    faceBlock: true
  };
  const initResult = await faceDetector.init(config);
  if (!initResult) {
    hilog.error(0x0000, TAG, 'Face detector with block detection init failed');
    throw new Error('Face detector initialization with block detection failed');
  }
  hilog.info(0x0000, TAG, 'Face detector with block detection initialized');

  try {
    const visionInfo: faceDetector.VisionInfo = {
      pixelMap: pixelMap
    };
    const faces = await faceDetector.detect(visionInfo);
    const faceCount = faces.length;

    hilog.info(0x0000, TAG, 'Detected %{public}d face(s) with block detection', faceCount);

    if (faceCount === 0) {
      return { faceCount: 0, validFace: null, blocked: false };
    }

    // 检查主脸遮挡状态
    const validFaces = faces.filter(f => f.probability >= MIN_PROBABILITY);
    const primaryFace = validFaces[0] ?? null;

    let blocked = false;
    if (primaryFace) {
      hilog.info(0x0000, TAG,
        'Primary face block status: %{public}d (0=UNBLOCKED, 1=BLOCKED)',
        primaryFace.block);
      blocked = primaryFace.block === faceDetector.FaceBlock.BLOCKED;

      if (blocked) {
        hilog.warn(0x0000, TAG, 'Face is blocked/occluded, please show clear face');
      }
    }

    return { faceCount, validFace: primaryFace, blocked };
  } catch (err) {
    const error = err as BusinessError;
    hilog.error(0x0000, TAG,
      'Face detection with block failed: code=%{public}d, message=%{public}s',
      error.code, error.message);
    throw err;
  } finally {
    await faceDetector.release();
    hilog.info(0x0000, TAG, 'Face detector with block detection released');
  }
}

export { detectFace, detectFaceWithBlock, DetectOutput };
