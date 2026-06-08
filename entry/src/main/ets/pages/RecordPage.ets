// Path: entry/src/main/ets/pages/RecordPage.ets
// 签到记录页：List 展示全部签到记录，支持按学号筛选

import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';
import { queryAllRecords, querySignRecords } from '../database/SignRecordTable';
import { SignRecordModel } from '../model/SignRecordModel';

const TAG = 'RecordPage';

@Entry
@Component
struct RecordPage {
  @State records: SignRecordModel[] = [];
  @State filterStudentId: string = '';
  @State isLoading: boolean = false;

  async aboutToAppear() {
    await this.loadRecords();
  }

  build() {
    Column({ space: 12 }) {
      // 筛选输入区域
      this.FilterRow()

      // 统计行
      Row() {
        Text(`共 ${this.records.length} 条记录`)
          .fontSize(12)
          .fontColor('#999')
      }
      .width('100%')
      .padding({ left: 16 })

      // 记录列表
      this.RecordList()
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 筛选输入行 Builder
   */
  @Builder
  FilterRow() {
    Row({ space: 8 }) {
      TextInput({ placeholder: '输入学号筛选', text: this.filterStudentId })
        .height(40)
        .fontSize(14)
        .backgroundColor('#f5f5f5')
        .borderRadius(8)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.filterStudentId = value;
        })

      Button('查询')
        .height(40)
        .fontSize(14)
        .backgroundColor('#1890ff')
        .borderRadius(8)
        .onClick(() => {
          this.loadRecords();
        })

      Button('全部')
        .height(40)
        .fontSize(14)
        .backgroundColor('#f5f5f5')
        .fontColor('#666')
        .borderRadius(8)
        .onClick(() => {
          this.filterStudentId = '';
          this.loadRecords();
        })
    }
    .width('100%')
    .padding({ left: 8, right: 8 })
  }

  /**
   * 记录列表 Builder（处理加载中/空数据/有数据三种状态）
   */
  @Builder
  RecordList() {
    if (this.isLoading) {
      // 加载中状态
      Column() {
        LoadingProgress()
          .width(32)
          .height(32)
          .margin({ top: 40 })
      }
      .width('100%')
    } else if (this.records.length === 0) {
      // 空数据状态
      Column() {
        Text('暂无签到记录')
          .fontSize(16)
          .fontColor('#999')
          .margin({ top: 60 })
      }
      .width('100%')
    } else {
      // 有数据状态
      List() {
        ForEach(this.records, (record: SignRecordModel, index: number) => {
          ListItem() {
            this.RecordItem(record)
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#eee' })
    }
  }

  /**
   * 单条记录项 Builder
   */
  @Builder
  RecordItem(record: SignRecordModel) {
    Row() {
      // 左侧：学号 + 时间
      Column({ space: 4 }) {
        Text(record.studentId)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333')

        Text(this.formatTime(record.signTime))
          .fontSize(12)
          .fontColor('#999')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 右侧：状态 + 相似度
      Column({ space: 4 }) {
        Text(this.getStatusText(record.status))
          .fontSize(14)
          .fontColor(record.status === 1 ? '#52c41a' : '#ff4d4f')
          .fontWeight(FontWeight.Medium)

        if (record.similarity > 0) {
          Text(`相似度: ${(record.similarity * 100).toFixed(1)}%`)
            .fontSize(11)
            .fontColor('#999')
        }
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#fff')
  }

  /**
   * 加载签到记录（支持按学号筛选）
   */
  private async loadRecords(): Promise<void> {
    this.isLoading = true;
    try {
      if (this.filterStudentId.trim() !== '') {
        // 按学号筛选查询
        this.records = await querySignRecords(this.filterStudentId.trim(), 50);
      } else {
        // 查询全部记录
        this.records = await queryAllRecords(100);
      }
    } catch (err) {
      const error = err as BusinessError;
      logger.error('Load records failed: code=%{public}d, msg=%{public}s',
        error.code, error.message);
      promptAction.showToast({ message: '加载记录失败', duration: 2000 });
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 格式化时间戳为 yyyy-MM-dd HH:mm
   */
  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
  }

  /**
   * 根据状态码获取显示文本
   */
  private getStatusText(status: number): string {
    switch (status) {
      case Constants.STATUS_SIGN_SUCCESS:
        return '签到成功';
      case Constants.STATUS_LIVENESS_FAIL:
        return '活体失败';
      case Constants.STATUS_MATCH_FAIL:
        return '比对失败';
      default:
        return '未知';
    }
  }
}
