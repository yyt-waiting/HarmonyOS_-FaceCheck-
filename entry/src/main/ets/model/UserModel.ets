// Path: entry/src/main/ets/model/UserModel.ets
// 用户数据模型，对应 UserTable 表结构

export class UserModel {
  id: number = 0;           // 主键自增
  studentId: string = '';   // 学号/工号 (UNIQUE)
  userName: string = '';    // 姓名
  faceUri: string = '';     // 沙箱文件名（非完整路径）
  gmtCreate: number = 0;    // 注册时间戳（毫秒）

  constructor(
    studentId: string,
    userName: string,
    faceUri: string,
    gmtCreate: number = Date.now(),
    id: number = 0
  ) {
    this.id = id;
    this.studentId = studentId;
    this.userName = userName;
    this.faceUri = faceUri;
    this.gmtCreate = gmtCreate;
  }
}
