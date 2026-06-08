// Path: entry/src/main/ets/pages/SignInResultPage.ets
// 活体成功后的签到结果处理页：获取活体 PixelMap → 加载注册照 → 比对 → 写记录
// 严格遵循规范：所有异步包裹 try-catch，两个 PixelMap 在 finally 中释放

import { router } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';
import { getLivenessResult } from '../service/LivenessService';
import { compareFace } from '../service/FaceCompareService';
import { insertSignRecord } from '../database/SignRecordTable';
import { loadPixelMapFromFile } from '../utils/ImageFileUtil';
import { SignRecordModel } from '../model/SignRecordModel';

const TAG = 'SignInResultPage';

@Entry
@Component
struct SignInResultPage {
  @State isLoading: boolean = true;
  @State resultMessage: string = '';
  @State isSuccess: boolean = false;

  async aboutToAppear() {
    await this.processSignIn();
  }

  /**
   * 签到流程主逻辑：
   * Step 1: 获取活体检测结果（最清晰人脸帧 PixelMap）
   * Step 2: 从 AppStorage 取出签到上下文（学号、注册照文件名、用户名）
   * Step 3: 根据注册照文件名从沙箱加载注册照 PixelMap
   * Step 4: 调用 FaceCompareService 进行 1:1 人脸比对（两 PixelMap 在内部 finally 中被 release）
   * Step 5: 构造 SignRecordModel 并写入签到记录表
   * 兜底：任何一步失败均跳转回上一页
   */
  private async processSignIn(): Promise<void> {
    // 两个 PixelMap 均声明在 try 外层，确保 finally 中可访问
    let livenessPixelMap: image.PixelMap | undefined = undefined;
    let registeredPixelMap: image.PixelMap | undefined = undefined;

    try {
      // ─────────────────────────────────────────────
      // Step 1: 获取活体检测结果
      // ─────────────────────────────────────────────
      livenessPixelMap = await getLivenessResult();
      if (!livenessPixelMap) {
        this.resultMessage = '活体检测未通过';
        this.isSuccess = false;
        this.isLoading = false;
        setTimeout(() => router.back(), 2000);
        return;
      }

      // ─────────────────────────────────────────────
      // Step 2: 获取签到上下文（由 SignInPage 写入）
      // ─────────────────────────────────────────────
      const studentId = AppStorage.get<string>('sign_studentId') ?? '';
      const faceUri = AppStorage.get<string>('sign_registeredFaceUri') ?? '';
      const userName = AppStorage.get<string>('sign_registeredUserName') ?? '';

      if (!studentId || !faceUri) {
        this.resultMessage = '签到信息缺失';
        this.isSuccess = false;
        this.isLoading = false;
        setTimeout(() => router.back(), 2000);
        return;
      }

      // ─────────────────────────────────────────────
      // Step 3: 从沙箱加载注册照 PixelMap
      // faceUri 在 UserTable 中仅存文件名（如 face_001_1699999999999.jpg）
      // loadPixelMapFromFile 会拼接 context.filesDir + '/faces/' + faceUri
      // ─────────────────────────────────────────────
      const context = getContext(this);
      registeredPixelMap = await loadPixelMapFromFile(context, faceUri);
      if (!registeredPixelMap) {
        this.resultMessage = '注册照片加载失败';
        this.isSuccess = false;
        this.isLoading = false;
        setTimeout(() => router.back(), 2000);
        return;
      }

      // ─────────────────────────────────────────────
      // Step 4: 人脸 1:1 比对
      // compareFace 内部在 finally 中 release 两个 PixelMap，调用方置空即可
      // ─────────────────────────────────────────────
      const compareResult = await compareFace(registeredPixelMap, livenessPixelMap);
      // compareFace 的 finally 已释放两个 PixelMap，置空防止误用
      registeredPixelMap = undefined;
      livenessPixelMap = undefined;

      // ─────────────────────────────────────────────
      // Step 5: 写入签到记录
      // ─────────────────────────────────────────────
      const now = Date.now();
      const record = new SignRecordModel(
        studentId,
        now,
        compareResult.pass ? Constants.STATUS_SIGN_SUCCESS : Constants.STATUS_MATCH_FAIL,
        compareResult.similarity
      );
      const rowId = await insertSignRecord(record);

      if (compareResult.pass) {
        this.resultMessage = `签到成功！${userName} 同学，欢迎回来！\n相似度: ${compareResult.similarityPercent.toFixed(2)}%`;
        this.isSuccess = true;
        logger.info('SignIn SUCCESS: %{public}s, similarity=%{public}f, rowId=%{public}d',
          studentId, compareResult.similarity, rowId);
      } else {
        this.resultMessage = `签到失败：相似度 ${compareResult.similarityPercent.toFixed(2)}% 未达标\n请确认是否为本人`;
        this.isSuccess = false;
        logger.warn('SignIn FAIL: %{public}s, similarity=%{public}f, threshold=%{public}f',
          studentId, compareResult.similarity, Constants.SIMILARITY_THRESHOLD);
      }

      // 清理签到上下文，防止页面回退后残留数据
      AppStorage.set('sign_studentId', '');
      AppStorage.set('sign_registeredFaceUri', '');
      AppStorage.set('sign_registeredUserName', '');

      // 成功后等待 3 秒自动返回，让用户看清结果
      setTimeout(() => router.back(), 3000);

    } catch (err) {
      // 捕获所有未预期异常，记录错误码和消息
      const error = err as BusinessError;
      logger.error('Process signIn failed: code=%{public}d, msg=%{public}s',
        error.code, error.message);
      this.resultMessage = '签到处理失败，请重试';
      this.isSuccess = false;
      setTimeout(() => router.back(), 2000);

    } finally {
      // 兜底释放：registeredPixelMap 在 compareFace 成功后已被释放，置空后这里会跳过；
      // 若 compareFace 抛出异常未执行 release，则此处兜底释放，防止 OOM
      if (registeredPixelMap) {
        registeredPixelMap.release();
      }
      if (livenessPixelMap) {
        livenessPixelMap.release();
      }
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      if (this.isLoading) {
        // 加载中状态：转圈 + 提示文字
        LoadingProgress()
          .width(48)
          .height(48)
          .color('#1890ff')
        Text('正在比对...')
          .fontSize(16)
          .fontColor('#666')
          .margin({ top: 16 })
      } else {
        // 结果展示：绿色=成功，红色=失败
        Text(this.resultMessage)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .fontColor(this.isSuccess ? '#52c41a' : '#ff4d4f')
          .padding(24)
          .borderRadius(12)
          .backgroundColor(this.isSuccess ? '#f6ffed' : '#fff2f0')
          .width('85%')
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#fafafa')
  }
}
