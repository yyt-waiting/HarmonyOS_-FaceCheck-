// Path: entry/src/main/ets/model/SignRecordModel.ets
// 签到记录数据模型，对应 SignRecordTable 表结构

export class SignRecordModel {
  id: number = 0;           // 主键自增
  studentId: string = '';    // 关联学号
  signTime: number = 0;      // 签到时间戳（毫秒）
  status: number = 1;        // 状态: 1成功/0活体失败/-1比对失败
  similarity: number = 0;    // 相似度 [0, 1]

  constructor(
    studentId: string,
    signTime: number = Date.now(),
    status: number = 1,
    similarity: number = 0,
    id: number = 0
  ) {
    this.id = id;
    this.studentId = studentId;
    this.signTime = signTime;
    this.status = status;
    this.similarity = similarity;
  }
}
