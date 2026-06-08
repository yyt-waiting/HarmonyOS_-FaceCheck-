// Path: entry/src/main/ets/pages/Index.ets
// Tabs 主框架：包含注册页、签到页、记录页三个 Tab

// 导入页面组件（懒加载方式引入，降低首屏加载压力）
import { RegisterPage } from './RegisterPage';
import { SignInPage } from './SignInPage';
import { RecordPage } from './RecordPage';

// 导入性能分析日志模块，替换 console.log
import { hilog } from '@kit.PerformanceAnalysisKit';

// 声明日志 tag，便于在 DevEco Studio 中过滤日志
const TAG: string = 'Index';
const DOMAIN: number = 0x0000;

@Entry
@Component
struct Index {
  // 当前 Tab 页索引，@State 装饰器实现响应式更新
  @State currentIndex: number = 0;
  // Tabs 控制器，用于程序化控制 Tab 切换
  private tabController: TabsController = new TabsController();

  /**
   * TabBar 构建器
   * @param title Tab 标题文本
   * @param targetIndex 目标页索引
   * @param selectedIcon 选中状态图标资源
   * @param normalIcon 未选中状态图标资源
   */
  @Builder
  TabBuilder(title: string, targetIndex: number, selectedIcon: Resource, normalIcon: Resource) {
    Column() {
      // 根据当前索引决定显示选中或未选中图标
      Image(this.currentIndex === targetIndex ? selectedIcon : normalIcon)
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain);

      // Tab 标题文字，选中时高亮蓝色，未选中时灰色
      Text(title)
        .fontSize(12)
        .fontColor(this.currentIndex === targetIndex ? '#1890ff' : '#999999')
        .margin({ top: 4 });
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      // 点击 Tab 时更新索引并触发控制器切换
      this.currentIndex = targetIndex;
      this.tabController.changeIndex(targetIndex);
      hilog.info(DOMAIN, TAG, 'Tab changed to index: %{public}d', targetIndex);
    });
  }

  build() {
    Column() {
      Tabs({
        barPosition: BarPosition.END,
        controller: this.tabController
      }) {
        // Tab 1: 人脸注册页
        TabContent() {
          NavDestination() {
            RegisterPage();
          }
          .title('人脸注册');
        }
        .tabBar(this.TabBuilder(
          '注册',
          0,
          $r('sys.media.ic_public_save'),
          $r('sys.media.ic_public_save')
        ));

        // Tab 2: 刷脸签到页
        TabContent() {
          NavDestination() {
            SignInPage();
          }
          .title('刷脸签到');
        }
        .tabBar(this.TabBuilder(
          '签到',
          1,
          $r('sys.media.ic_public_input_method'),
          $r('sys.media.ic_public_input_method')
        ));

        // Tab 3: 签到记录页
        TabContent() {
          NavDestination() {
            RecordPage();
          }
          .title('签到记录');
        }
        .tabBar(this.TabBuilder(
          '记录',
          2,
          $r('sys.media.ic_public_view_list'),
          $r('sys.media.ic_public_view_list')
        ));
      }
      .barHeight(56)
      .barMode(BarMode.Fixed)
      .onChange((index: number) => {
        // Tab 切换回调，同步更新 currentIndex 状态
        this.currentIndex = index;
        hilog.info(DOMAIN, TAG, 'Tab onChange callback, index: %{public}d', index);
      })
      .layoutWeight(1)
      .width('100%');
    }
    .width('100%')
    .height('100%');
  }
}
