// Path: entry/src/main/ets/service/LivenessService.ets
// 活体检测服务封装：拉起系统活体检测 UI，完成后跳转指定结果页
// 严格遵循规范：mPixelMap 必须在 finally 中 release()

import { interactiveLiveness } from '@kit.VisionKit';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';

const TAG = 'LivenessService';

/**
 * 统一拉起活体检测，根据场景跳转到不同结果页
 * @param successRoute 成功跳转的页面路径（如 'pages/LivenessResultPage'）
 * @param failRoute 失败跳转的页面路径（如 'pages/LivenessFailPage'）
 */
async function startLivenessWithRoute(
  successRoute: string,
  failRoute: string
): Promise<boolean> {
  const config: interactiveLiveness.InteractiveLivenessConfig = {
    isSilentMode: interactiveLiveness.DetectionMode.INTERACTIVE_MODE,
    actionsNum: Constants.LIVENESS_ACTIONS_NUM === 3
      ? interactiveLiveness.ActionsNumber.THREE_ACTION
      : interactiveLiveness.ActionsNumber.FOUR_ACTION,
    routeMode: interactiveLiveness.RouteRedirectionMode.REPLACE_MODE,
    successfulRouteUrl: successRoute,
    failedRouteUrl: failRoute
  };

  try {
    const jumpResult = await interactiveLiveness.startLivenessDetection(config);
    logger.info('Liveness jump result: %{public}s', jumpResult.toString());
    return jumpResult;
  } catch (err) {
    const error = err as BusinessError;
    logger.error('Start liveness detection failed: code=%{public}d, msg=%{public}s',
      error.code, error.message);
    return false;
  }
}

/**
 * 获取活体检测结果（仅在结果页面中调用）
 * @returns mPixelMap = 最清晰人脸帧（RGBA_8888），使用完毕后必须在 finally 中 release()
 */
async function getLivenessResult(): Promise<image.PixelMap | undefined> {
  try {
    const result = await interactiveLiveness.getInteractiveLivenessResult();
    if (result.livenessType === interactiveLiveness.LivenessType.INTERACTIVE_LIVENESS) {
      logger.info('Liveness detected successfully, pixelMap available');
      return result.mPixelMap;
    }
    logger.warn('Liveness type is NOT_LIVENESS: %{public}d', result.livenessType);
    return undefined;
  } catch (err) {
    logger.error('Get liveness result failed: %{public}s', (err as BusinessError).message);
    return undefined;
  }
}

export { startLivenessWithRoute, getLivenessResult };
