// Path: entry/src/main/ets/pages/LivenessFailPage.ets
// 活体检测失败回调页：LivenessType = NOT_LIVENESS 时系统自动跳转此页

import { router } from '@kit.ArkUI';

@Entry
@Component
struct LivenessFailPage {
  build() {
    Column() {
      Text('活体检测未通过')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ff4d4f')
        .margin({ top: 40 })

      Text('未能通过活体验证，请确保：')
        .fontSize(14)
        .fontColor('#666')
        .margin({ top: 20 })

      Column({ space: 8 }) {
        Text('• 在光线充足的环境下检测')
        Text('• 正对屏幕，按提示完成动作')
        Text('• 检测时请摘下口罩、眼镜等遮挡物')
        Text('• 仅限本人检测，勿使用照片或视频')
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 16 })
      .padding(16)
      .backgroundColor('#f5f5f5')
      .borderRadius(8)
      .width('90%')

      Button('重新检测')
        .width('80%')
        .height(48)
        .fontSize(16)
        .backgroundColor('#1890ff')
        .borderRadius(24)
        .margin({ top: 32 })
        .onClick(() => {
          router.back();
        })

      Button('返回注册页')
        .width('80%')
        .height(40)
        .fontSize(14)
        .fontColor('#666')
        .backgroundColor(Color.Transparent)
        .margin({ top: 12 })
        .onClick(() => {
          router.back();
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20 })
  }
}
