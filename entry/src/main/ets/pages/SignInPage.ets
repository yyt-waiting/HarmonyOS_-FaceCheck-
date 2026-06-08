// Path: entry/src/main/ets/pages/SignInPage.ets
// 刷脸签到页：输入学号 → 活体检测 → 查注册照 → 人脸比对 → 写签到记录

import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { requestCameraPermission } from '../utils/PermissionUtil';
import { startLivenessWithRoute } from '../service/LivenessService';
import { queryUser } from '../database/UserTable';
import { queryTodayRecord } from '../database/SignRecordTable';

const TAG = 'SignInPage';
const DOMAIN = 0x0001;

@Entry
@Component
struct SignInPage {
  @State studentId: string = '';
  @State isLoading: boolean = false;
  @State signStatus: string = '';

  build() {
    Column({ space: 16 }) {
      // 页面标题
      Text('刷脸签到')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ top: 8 })

      // 学号输入区域
      TextInput({ placeholder: '请输入学号', text: this.studentId })
        .width('90%')
        .height(48)
        .fontSize(16)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .inputFilter('[a-zA-Z0-9]')
        .onChange((value: string) => {
          this.studentId = value;
        })

      // 开始签到按钮
      Button('开始签到')
        .width('80%')
        .height(48)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.isLoading ? '#CCCCCC' : '#1890FF')
        .borderRadius(24)
        .enabled(!this.isLoading)
        .onClick(() => {
          this.doSignIn();
        })

      // 加载中状态展示
      if (this.isLoading) {
        LoadingProgress().width(32).height(32)
        Text('处理中...').fontSize(14).fontColor('#999999').margin({ top: 8 })
      }

      // 结果展示区域
      if (this.signStatus !== '') {
        Text(this.signStatus)
          .fontSize(14)
          .fontColor(this.signStatus.includes('成功') ? '#52C41A' : '#FF4D4F')
          .textAlign(TextAlign.Center)
          .margin({ top: 12 })
      }

      // 底部占位，保持布局美观
      Blank()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
  }

  /**
   * 执行签到流程
   * 流程：权限申请 → 查询用户 → 检查重复签到 → 存储上下文 → 拉起活体检测
   */
  private async doSignIn(): Promise<void> {
    // 校验学号输入
    if (this.studentId.trim() === '') {
      this.showToast('请输入学号');
      return;
    }

    this.isLoading = true;
    this.signStatus = '';

    try {
      // Step 1: 申请相机权限（活体检测必需）
      const hasPermission = await requestCameraPermission(getContext(this));
      if (!hasPermission) {
        this.signStatus = '请授权相机权限';
        hilog.error(DOMAIN, TAG, 'Camera permission denied');
        return;
      }

      // Step 2: 根据学号查询用户是否存在
      const user = await queryUser(this.studentId.trim());
      if (!user) {
        this.signStatus = '该学号未注册，请先注册';
        hilog.warn(DOMAIN, TAG, 'User not found: %{public}s', this.studentId.trim());
        return;
      }

      // Step 3: 检查今日是否已签到（防止重复签到）
      const todayRecord = await queryTodayRecord(this.studentId.trim());
      if (todayRecord) {
        this.signStatus = '今日已签到，请勿重复签到';
        hilog.warn(DOMAIN, TAG, 'Duplicate sign-in detected for: %{public}s', this.studentId.trim());
        return;
      }

      // Step 4: 存储签到上下文，供 SignInResultPage 获取用户信息和注册照路径
      AppStorage.set('sign_studentId', this.studentId.trim());
      AppStorage.set('sign_registeredFaceUri', user.faceUri);
      AppStorage.set('sign_registeredUserName', user.userName);
      hilog.info(DOMAIN, TAG, 'Sign-in context prepared for: %{public}s', this.studentId.trim());

      // Step 5: 拉起活体检测（签到模式）
      // 活体成功 → 跳转 SignInResultPage 进行人脸比对
      // 活体失败 → 跳转 LivenessFailPage
      const jumpOk = await startLivenessWithRoute(
        'pages/SignInResultPage',
        'pages/LivenessFailPage'
      );
      if (!jumpOk) {
        this.signStatus = '活体检测启动失败';
        hilog.error(DOMAIN, TAG, 'Failed to start liveness detection');
        return;
      }
      // 页面跳转后，活体结果将在 SignInResultPage 中获取并处理
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Sign-in flow failed: code=%{public}d, message=%{public}s',
        error.code, error.message);
      this.signStatus = `签到失败: ${error.message}`;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 显示轻提示
   * @param message 提示文本内容
   */
  private showToast(message: string): void {
    promptAction.showToast({ message: message, duration: 2000 });
  }
}
