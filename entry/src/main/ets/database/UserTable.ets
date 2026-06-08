// Path: entry/src/main/ets/database/UserTable.ets
// UserTable 增删查操作，含学号 UNIQUE 冲突处理

import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';
import { UserModel } from '../model/UserModel';
import { getRdbStore } from './DataManager';

const TAG = 'UserTable';

/**
 * 插入用户记录（含学号 UNIQUE 冲突处理）
 * 错误码 1501307 = UNIQUE constraint failed
 */
async function insertUser(user: UserModel): Promise<{ success: boolean; message: string }> {
  const store = getRdbStore();
  const bucket: relationalStore.ValuesBucket = {
    student_id: user.studentId,
    user_name: user.userName,
    face_uri: user.faceUri,
    gmt_create: user.gmtCreate
  };

  try {
    const rowId = await store.insert('UserTable', bucket);
    logger.info('User inserted, rowId=%{public}d, studentId=%{public}s',
      rowId, user.studentId);
    return { success: true, message: '注册成功' };
  } catch (err) {
    const error = err as BusinessError;
    if (error.code === Constants.ERR_UNIQUE_CONSTRAINT) {
      logger.warn('Duplicate student_id: %{public}s', user.studentId);
      return { success: false, message: '学号已注册，请勿重复注册' };
    }
    logger.error('Insert user failed: code=%{public}d, msg=%{public}s',
      error.code, error.message);
    return { success: false, message: `注册失败: ${error.message}` };
  }
}

/**
 * 按学号查询用户
 */
async function queryUser(studentId: string): Promise<UserModel | null> {
  const store = getRdbStore();
  const predicates = new relationalStore.RdbPredicates('UserTable');
  predicates.equalTo('student_id', studentId);

  let resultSet: relationalStore.ResultSet | undefined = undefined;
  try {
    resultSet = await store.query(predicates,
      ['id', 'student_id', 'user_name', 'face_uri', 'gmt_create']);

    if (resultSet.goToFirstRow()) {
      const user = new UserModel(
        resultSet.getString(resultSet.getColumnIndex('student_id')),
        resultSet.getString(resultSet.getColumnIndex('user_name')),
        resultSet.getString(resultSet.getColumnIndex('face_uri')),
        resultSet.getLong(resultSet.getColumnIndex('gmt_create')),
        resultSet.getLong(resultSet.getColumnIndex('id'))
      );
      logger.info('User found: %{public}s', user.studentId);
      return user;
    }
    return null;
  } catch (err) {
    logger.error('Query user failed: %{public}s', (err as BusinessError).message);
    return null;
  } finally {
    resultSet?.close();
  }
}

/**
 * 查询全部注册用户（用于签到页面展示已注册用户列表）
 */
async function queryAllUsers(): Promise<UserModel[]> {
  const store = getRdbStore();
  const predicates = new relationalStore.RdbPredicates('UserTable');
  predicates.orderByDesc('gmt_create');

  let resultSet: relationalStore.ResultSet | undefined = undefined;
  const users: UserModel[] = [];

  try {
    resultSet = await store.query(predicates,
      ['id', 'student_id', 'user_name', 'face_uri', 'gmt_create']);

    while (resultSet.goToNextRow()) {
      users.push(new UserModel(
        resultSet.getString(resultSet.getColumnIndex('student_id')),
        resultSet.getString(resultSet.getColumnIndex('user_name')),
        resultSet.getString(resultSet.getColumnIndex('face_uri')),
        resultSet.getLong(resultSet.getColumnIndex('gmt_create')),
        resultSet.getLong(resultSet.getColumnIndex('id'))
      ));
    }
    return users;
  } catch (err) {
    logger.error('Query all users failed: %{public}s', (err as BusinessError).message);
    return [];
  } finally {
    resultSet?.close();
  }
}

/**
 * 删除用户（同步删除沙箱文件由调用方负责）
 */
async function deleteUser(studentId: string): Promise<boolean> {
  const store = getRdbStore();
  const predicates = new relationalStore.RdbPredicates('UserTable');
  predicates.equalTo('student_id', studentId);

  try {
    const deletedRows = await store.delete(predicates);
    logger.info('User deleted: %{public}s, rows=%{public}d', studentId, deletedRows);
    return deletedRows > 0;
  } catch (err) {
    logger.error('Delete user failed: %{public}s', (err as BusinessError).message);
    return false;
  }
}

export { insertUser, queryUser, queryAllUsers, deleteUser };
