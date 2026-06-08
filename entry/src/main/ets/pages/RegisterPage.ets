// Path: entry/src/main/ets/pages/RegisterPage.ets
// 人脸注册页：输入学号+姓名，拉起活体检测，保存图片到沙箱，写入数据库

import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { requestCameraPermission } from '../utils/PermissionUtil';
import { startLivenessWithRoute } from '../service/LivenessService';

const TAG = 'RegisterPage';

@Entry
@Component
struct RegisterPage {
  @State studentId: string = '';
  @State userName: string = '';
  @State isLoading: boolean = false;
  @State resultMessage: string = '';

  build() {
    Column({ space: 20 }) {
      // 顶部说明
      Text('录入人脸信息，开启刷脸签到')
        .fontSize(14)
        .fontColor('#666')
        .textAlign(TextAlign.Center)
        .margin({ top: 16 })

      // 学号输入
      TextInput({ placeholder: '请输入学号', text: this.studentId })
        .width('90%')
        .height(48)
        .fontSize(16)
        .backgroundColor('#f5f5f5')
        .borderRadius(8)
        .inputFilter('[a-zA-Z0-9]')
        .onChange((value: string) => {
          this.studentId = value;
        })

      // 姓名输入
      TextInput({ placeholder: '请输入姓名', text: this.userName })
        .width('90%')
        .height(48)
        .fontSize(16)
        .backgroundColor('#f5f5f5')
        .borderRadius(8)
        .onChange((value: string) => {
          this.userName = value;
        })

      // 结果提示
      if (this.resultMessage !== '') {
        Text(this.resultMessage)
          .fontSize(14)
          .fontColor(this.resultMessage.includes('成功') ? '#52c41a' : '#ff4d4f')
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })
      }

      // 注册按钮
      Button('开始注册')
        .width('80%')
        .height(48)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.isLoading ? '#ccc' : '#1890ff')
        .borderRadius(24)
        .enabled(!this.isLoading)
        .onClick(() => {
          this.doRegister();
        })

      if (this.isLoading) {
        LoadingProgress()
          .width(32)
          .height(32)
          .margin({ top: 16 })
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
  }

  private async doRegister(): Promise<void> {
    // 输入校验
    if (this.studentId.trim() === '') {
      this.showToast('请输入学号');
      return;
    }
    if (this.userName.trim() === '') {
      this.showToast('请输入姓名');
      return;
    }

    this.isLoading = true;
    this.resultMessage = '';

    try {
      // Step 1: 申请相机权限
      const hasPermission = await requestCameraPermission(getContext(this));
      if (!hasPermission) {
        this.resultMessage = '请授权相机权限';
        return;
      }

      // Step 2: 存储注册表单数据到 AppStorage（供 LivenessResultPage 使用）
      AppStorage.set('reg_studentId', this.studentId.trim());
      AppStorage.set('reg_userName', this.userName.trim());

      // Step 3: 拉起活体检测（注册流程）
      const jumpOk = await startLivenessWithRoute(
        'pages/LivenessResultPage',
        'pages/LivenessFailPage'
      );
      if (!jumpOk) {
        this.resultMessage = '活体检测启动失败';
        return;
      }
      // REPLACE_MODE: 页面已跳转，活体结果在 LivenessResultPage 获取
    } catch (err) {
      const error = err as BusinessError;
      logger.error('Register flow failed: code=%{public}d, msg=%{public}s',
        error.code, error.message);
      this.resultMessage = `注册失败: ${error.message}`;
    } finally {
      this.isLoading = false;
    }
  }

  private showToast(message: string): void {
    promptAction.showToast({ message: message, duration: 2000 });
  }
}
