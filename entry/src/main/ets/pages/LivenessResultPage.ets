// Path: entry/src/main/ets/pages/LivenessResultPage.ets
// 活体检测成功回调页：获取 mPixelMap，完成注册流程（保存图片+写DB）
// 在 AppStorage 中存取注册表单数据（studentId / userName）
// 严格遵循规范：mPixelMap 必须在 finally 中 release()，所有异步必须包裹 try-catch

import { promptAction } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { savePixelMapToFile } from '../utils/ImageFileUtil';
import { getLivenessResult } from '../service/LivenessService';
import { insertUser } from '../database/UserTable';
import { UserModel } from '../model/UserModel';

const TAG = 'LivenessResultPage';

@Entry
@Component
struct LivenessResultPage {
  @State isLoading: boolean = true;
  @State message: string = '';
  @State messageColor: string = '#333333';

  async aboutToAppear() {
    logger.info('LivenessResultPage aboutToAppear');
    await this.processRegistration();
  }

  private async processRegistration(): Promise<void> {
    let livenessPixelMap: image.PixelMap | undefined = undefined;

    try {
      // Step 1: 获取活体检测结果
      livenessPixelMap = await getLivenessResult();
      if (!livenessPixelMap) {
        this.message = '活体检测未通过，请重试';
        this.messageColor = '#ff4d4f';
        this.isLoading = false;
        setTimeout(() => router.back(), 2000);
        return;
      }

      // Step 2: 从 AppStorage 获取注册表单数据
      const studentId = AppStorage.get<string>('reg_studentId') ?? '';
      const userName = AppStorage.get<string>('reg_userName') ?? '';

      if (!studentId || !userName) {
        this.message = '注册信息缺失，请重试';
        this.messageColor = '#ff4d4f';
        this.isLoading = false;
        setTimeout(() => router.back(), 2000);
        return;
      }

      // Step 3: 保存 PixelMap 到沙箱
      const context = getContext(this);
      const saveResult = await savePixelMapToFile(context, livenessPixelMap, studentId);
      if (!saveResult.success) {
        this.message = saveResult.message;
        this.messageColor = '#ff4d4f';
        this.isLoading = false;
        setTimeout(() => router.back(), 2000);
        return;
      }

      // Step 4: 写入数据库
      const user = new UserModel(studentId, userName, saveResult.fileName, Date.now());
      const dbResult = await insertUser(user);

      if (dbResult.success) {
        this.message = '注册成功！';
        this.messageColor = '#52c41a';
        logger.info('Registration complete: %{public}s', studentId);
        setTimeout(() => {
          AppStorage.set('reg_studentId', '');
          AppStorage.set('reg_userName', '');
          router.back();
        }, 1500);
      } else {
        this.message = dbResult.message;
        this.messageColor = '#ff4d4f';
        setTimeout(() => router.back(), 2000);
      }
    } catch (err) {
      const error = err as BusinessError;
      logger.error('Process registration failed: code=%{public}d, msg=%{public}s',
        error.code, error.message);
      this.message = '注册失败，请重试';
      this.messageColor = '#ff4d4f';
      setTimeout(() => router.back(), 2000);
    } finally {
      if (livenessPixelMap) {
        livenessPixelMap.release();
        logger.info('Liveness PixelMap released in finally block');
      }
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      if (this.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color('#1890ff')

        Text('正在处理...')
          .fontSize(16)
          .fontColor('#595959')
          .margin({ top: 16 })
      } else {
        Text(this.message)
          .fontSize(18)
          .fontColor(this.messageColor)
          .textAlign(TextAlign.Center)
          .padding({ left: 32, right: 32 })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#fafafa')
  }
}
