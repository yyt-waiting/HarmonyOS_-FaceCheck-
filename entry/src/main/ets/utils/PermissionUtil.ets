// Path: entry/src/main/ets/utils/PermissionUtil.ets
// 动态权限申请：相机权限是活体检测的前置条件

import { abilityAccessCtrl, bundleManager } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';

const TAG = 'PermissionUtil';
const CAMERA_PERMISSION = 'ohos.permission.CAMERA';

/**
 * 申请相机权限
 * @returns true = 授权成功，false = 授权失败
 */
async function requestCameraPermission(context: Context): Promise<boolean> {
  const atManager = abilityAccessCtrl.createAtManager();

  // 先检查权限授权状态
  try {
    const grantStatus = await atManager.checkAccessToken(
      context.applicationInfo.accessTokenId,
      CAMERA_PERMISSION
    );

    if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
      logger.info('Camera permission already granted');
      return true;
    }
  } catch (err) {
    // 未授权，走申请流程
    logger.warn('Camera permission not granted, requesting...');
  }

  // 申请权限
  try {
    const result = await atManager.requestPermissionsFromUser(context, [CAMERA_PERMISSION]);
    const grantResults = result.authResults;
    if (grantResults.length > 0 && grantResults[0] === 0) {
      logger.info('Camera permission granted by user');
      return true;
    }
    logger.warn('Camera permission denied by user');
    return false;
  } catch (err) {
    const error = err as BusinessError;
    logger.error('Request camera permission failed: code=%{public}d, msg=%{public}s',
      error.code, error.message);
    return false;
  }
}

export { requestCameraPermission };
