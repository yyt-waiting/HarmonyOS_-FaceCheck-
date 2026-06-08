// Path: entry/src/main/ets/database/SignRecordTable.ets
// 签到记录表增查操作

import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';
import { SignRecordModel } from '../model/SignRecordModel';
import { getRdbStore } from './DataManager';

const TAG = 'SignRecordTable';

/**
 * 插入签到记录
 */
async function insertSignRecord(record: SignRecordModel): Promise<number> {
  const store = getRdbStore();
  const bucket: relationalStore.ValuesBucket = {
    student_id: record.studentId,
    sign_time: record.signTime,
    status: record.status,
    similarity: record.similarity
  };

  try {
    const rowId = await store.insert('SignRecordTable', bucket);
    logger.info('Sign record inserted, rowId=%{public}d, studentId=%{public}s, status=%{public}d',
      rowId, record.studentId, record.status);
    return rowId;
  } catch (err) {
    logger.error('Insert sign record failed: %{public}s', (err as BusinessError).message);
    return -1;
  }
}

/**
 * 查询某学号的最近 N 条签到记录
 */
async function querySignRecords(studentId: string, limit: number = 50): Promise<SignRecordModel[]> {
  const store = getRdbStore();
  const predicates = new relationalStore.RdbPredicates('SignRecordTable');
  predicates.equalTo('student_id', studentId);
  predicates.orderByDesc('sign_time');
  predicates.limitAs(limit);

  let resultSet: relationalStore.ResultSet | undefined = undefined;
  const records: SignRecordModel[] = [];

  try {
    resultSet = await store.query(predicates,
      ['id', 'student_id', 'sign_time', 'status', 'similarity']);

    while (resultSet.goToNextRow()) {
      records.push(new SignRecordModel(
        resultSet.getString(resultSet.getColumnIndex('student_id')),
        resultSet.getLong(resultSet.getColumnIndex('sign_time')),
        resultSet.getLong(resultSet.getColumnIndex('status')),
        resultSet.getDouble(resultSet.getColumnIndex('similarity')),
        resultSet.getLong(resultSet.getColumnIndex('id'))
      ));
    }
    return records;
  } catch (err) {
    logger.error('Query sign records failed: %{public}s', (err as BusinessError).message);
    return [];
  } finally {
    resultSet?.close();
  }
}

/**
 * 查询全部签到记录（用于记录页）
 */
async function queryAllRecords(limit: number = 100): Promise<SignRecordModel[]> {
  const store = getRdbStore();
  const predicates = new relationalStore.RdbPredicates('SignRecordTable');
  predicates.orderByDesc('sign_time');
  predicates.limitAs(limit);

  let resultSet: relationalStore.ResultSet | undefined = undefined;
  const records: SignRecordModel[] = [];

  try {
    resultSet = await store.query(predicates,
      ['id', 'student_id', 'sign_time', 'status', 'similarity']);

    while (resultSet.goToNextRow()) {
      records.push(new SignRecordModel(
        resultSet.getString(resultSet.getColumnIndex('student_id')),
        resultSet.getLong(resultSet.getColumnIndex('sign_time')),
        resultSet.getLong(resultSet.getColumnIndex('status')),
        resultSet.getDouble(resultSet.getColumnIndex('similarity')),
        resultSet.getLong(resultSet.getColumnIndex('id'))
      ));
    }
    return records;
  } catch (err) {
    logger.error('Query all records failed: %{public}s', (err as BusinessError).message);
    return [];
  } finally {
    resultSet?.close();
  }
}

/**
 * 查询某学号今日是否已签到（用于防重复签到）
 */
async function queryTodayRecord(studentId: string): Promise<SignRecordModel | null> {
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const todayStartMs = todayStart.getTime();

  const store = getRdbStore();
  const predicates = new relationalStore.RdbPredicates('SignRecordTable');
  predicates.equalTo('student_id', studentId);
  predicates.greaterThan('sign_time', todayStartMs);
  predicates.orderByDesc('sign_time');
  predicates.limitAs(1);

  let resultSet: relationalStore.ResultSet | undefined = undefined;
  try {
    resultSet = await store.query(predicates,
      ['id', 'student_id', 'sign_time', 'status', 'similarity']);

    if (resultSet.goToFirstRow()) {
      return new SignRecordModel(
        resultSet.getString(resultSet.getColumnIndex('student_id')),
        resultSet.getLong(resultSet.getColumnIndex('sign_time')),
        resultSet.getLong(resultSet.getColumnIndex('status')),
        resultSet.getDouble(resultSet.getColumnIndex('similarity')),
        resultSet.getLong(resultSet.getColumnIndex('id'))
      );
    }
    return null;
  } catch (err) {
    logger.error('Query today record failed: %{public}s', (err as BusinessError).message);
    return null;
  } finally {
    resultSet?.close();
  }
}

export { insertSignRecord, querySignRecords, queryAllRecords, queryTodayRecord };
