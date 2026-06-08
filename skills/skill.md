# FaceCheck AI Skills 索引

本文档是 FaceCheck 项目所有 AI Skill 的总目录，说明每个 Skill 的**用途**、**何时使用**和**使用方法**。所有 Skill 共同服务于 FaceCheck 鸿蒙 AI 刷脸签到应用的开发。

## 快速导航

| ID | Skill 名称 | 用途 | 优先级 |
|----|-----------|------|--------|
| [SKILL-HM-001](#skill-hm-001) | HarmonyOS 基础规范 | 强制前置，所有代码的基础 | **必须** |
| [SKILL-HM-002](#skill-hm-002) | VisionKit 概览 | VisionKit 家族的通用知识 | **必须** |
| [SKILL-HM-003](#skill-hm-003) | 人脸比对 | 注册照与现场照 1:1 比对 | 签到核心 |
| [SKILL-HM-004](#skill-hm-004) | 人脸检测 | 静态图片人脸框/五官提取 | 注册前置 |
| [SKILL-HM-005](#skill-hm-005) | 活体检测 | 防照片/视频攻击的身份验证 | 签到核心 |
| [SKILL-HM-006](#skill-hm-006) | 多目标识别 | 图像内容分析与质量校验 | 可选辅助 |
| [SKILL-HM-007](#skill-hm-007) | RDB 数据库 | 用户/签到记录的持久化存储 | **必须** |
| [SKILL-HM-008](#skill-hm-008) | 图片存储 | PixelMap 压缩保存到沙箱 | 注册核心 |

---

## SKILL-HM-001

### HarmonyOS-Next-Stage-Baseline

**文件路径**: `skills/01_HarmonyOS_Base/SKILL.md`

### 用途

所有 FaceCheck ArkTS 代码必须遵守的底层约束规范。涵盖开发模型、权限申请、图像处理、类型安全、架构分层、异常处理和日志规范。

### 何时使用

- 编写任何 ArkTS 代码之前
- 调用相机、存储等系统 API 之前
- 定义接口、异常处理、日志输出时
- 任何其他 Skill 生成的代码，都必须满足本规范的约束

### 如何使用

1. **前置必读**: 生成任何代码前，先确认本规范中的 `M-01` ~ `M-10` 强制约束
2. **权限流程**: 调用相机前，生成 `requestPermissionsFromUser` 代码
3. **资源释放**: 所有 `PixelMap` 使用后，必须在 `finally` 中 `.release()`
4. **类型检查**: 所有 API 返回值必须显式类型标注，禁止隐式 `any`

### 核心依赖关系

本规范是**所有其他 Skill 的前置依赖**，其他 Skill 的 `dependencies` 中均引用本规范。

---

## SKILL-HM-002

### VisionKit-Overview

**文件路径**: `skills/02_VisionKit_Overview/SKILL.md`

### 用途

VisionKit 家族的通用知识库。定义所有视觉能力模块统一的输入格式（`PixelMap`）、生命周期模式和 `Core Vision Kit` 基类数据结构。

### 何时使用

- 生成任何 VisionKit 相关代码（FaceDetector / faceComparator / ObjectDetection / InteractiveLiveness）之前
- 需要了解 `VisionInfo`、`visionBase.Request`、`SceneMode` 等通用结构时
- 需要理解 VisionKit 四模块（FaceDetector / faceComparator / ObjectDetection / InteractiveLiveness）的整体关系时

### 如何使用

1. **快速查阅**: 使用 `<quick_reference>` 中的速查表定位目标能力
2. **确认输入格式**: 所有 VisionKit 输入必须是 `image.PixelMap`，不是 Uri 或 ArrayBuffer
3. **选择生命周期模式**: FaceDetector/faceComparator 使用 `init()/release()` 全局模式；ObjectDetector 使用 `create()/destroy()` 实例模式；InteractiveLiveness 使用路由模式

---

## SKILL-HM-003

### VisionKit-FaceComparator

**文件路径**: `skills/03_FaceComparator/SKILL.md`

### 用途

使用 `faceComparator` 模块进行人脸 1:1 比对。输入两张图片的 `PixelMap`，返回相似度分数（0~1）和是否为同一人的判断。

### 何时使用

- 用户发起刷脸签到，需要将现场活体照片与注册照进行比对时
- 判断两张人脸是否为同一人时

### 如何使用

```
1. faceComparator.init() → boolean
2. { pixelMap: registeredPixelMap } + { pixelMap: livePixelMap }
3. faceComparator.compareFaces(visionInfo1, visionInfo2)
   └── 返回 { isSamePerson: boolean, similarity: number(0~1) }
4. finally { faceComparator.release(); pixelMapA.release(); pixelMapB.release() }
```

### 业务阈值

- 相似度 ≥ 0.6 视为同一人（可调整）
- 必须配合 [SKILL-HM-005](#skill-hm-005) 活体检测结果使用

### 依赖关系

依赖 `SKILL-HM-001`（权限/资源释放）和 `SKILL-HM-002`（PixelMap 输入规范）

---

## SKILL-HM-004

### VisionKit-FaceDetector

**文件路径**: `skills/04_FaceDetector/SKILL.md`

### 用途

使用 `faceDetector` 模块进行静态图片人脸检测。返回检测到的人脸数量、位置框（`FaceRectangle`）、三维姿态（`FacePose`）和五官关键点（`FacePoint` 数组）。

### 何时使用

- 用户注册前，需要检测图库图片是否包含人脸时
- 签到前，需要校验拍摄图片质量（光线、角度）时
- 需要提取人脸五官关键点进行额外分析时

### 如何使用

```
1. faceDetector.init() → boolean
2. { pixelMap: imagePixelMap }
3. faceDetector.detect(visionInfo)
   └── 返回 Array<Face>（按人脸框大小排序）
4. 解析 Face.probability / rect / pose / points
5. finally { faceDetector.release(); pixelMap.release() }
```

### 与活体检测的区别

| 能力 | 输入 | 场景 |
|------|------|------|
| FaceDetector | 静态图片 | 图片质量预检、五官提取 |
| InteractiveLiveness | 视频流（系统相机）| 防伪认证 |

### 依赖关系

依赖 `SKILL-HM-001` 和 `SKILL-HM-002`

---

## SKILL-HM-005

### VisionKit-InteractiveLiveness

**文件路径**: `skills/05_InteractiveLiveness/SKILL.md`

### 用途

使用 `interactiveLiveness` 模块进行人脸活体检测。通过系统拉起的相机 UI 要求用户完成随机动作（点头/张嘴/眨眼/摇头/注视），验证用户为真实活体。成功返回最清晰的人脸 `PixelMap`。

### 何时使用

- 用户发起刷脸签到，需要验证"真人"而非"照片/视频"时
- 人脸注册时，需要确保录入的是真实人脸时

### 如何使用

**模式 A — REPLACE_MODE（推荐）**：

```
1. startLivenessDetection(config) → Promise<boolean>
   └── true = 跳转成功，跳转到成功/失败页面
2. 成功页面调用 getInteractiveLivenessResult()
   └── 返回 { livenessType, mPixelMap }
3. finally { mPixelMap.release() }
```

**模式 B — BACK_MODE**：

```
1. startLivenessDetection(config, callback)
   └── Promise<boolean> 跳转结果
   └── callback 接收 InteractiveLivenessResult
```

### 关键配置

- `actionsNum`: 3 或 4 个随机动作，默认 3
- `isSilentMode`: 必须为 `INTERACTIVE_MODE`
- 必须先申请 `ohos.permission.CAMERA` 权限

### 依赖关系

依赖 `SKILL-HM-001`（CAMERA 权限），可独立使用

---

## SKILL-HM-006

### VisionKit-ObjectDetection

**文件路径**: `skills/06_ObjectDetection/SKILL.md`

### 用途

使用 `objectDetection` 模块检测图像中多个目标（人脸、风景、动物、植物等），返回类别标签、置信度和边界框。

### 何时使用

- 需要分析图库图片内容时
- 签到前需要校验图片质量（是否为人脸特写、是否为证件卡证等）时
- 批量处理图像进行内容分类时

### 如何使用

```
1. ObjectDetector.create() → detector 实例
2. { inputData: { pixelMap }, scene: FOREGROUND }
3. detector.process(request)
   └── 返回 { objects: Array<VisionObject> }
4. 解析 objects[].labels / boundingBox / score
5. finally { detector.destroy(); pixelMap.release(); imageSource.release(); file.close() }
```

### 目标标签速查

标签 ID: 0=风景, 1=动物, 2=植物, 3=建筑, **5=人脸**, 6=表格, 7=文本, 8=人头, 9=猫头, 10=狗头, 11=食物, 12=汽车, 13=人体, 21=文档, 22=卡证

### 依赖关系

依赖 `SKILL-HM-001` 和 `SKILL-HM-002`

---

## SKILL-HM-007

### Database-RDB-Persistence

**文件路径**: `skills/07_Database_Standard/SKILL.md`

### 用途

使用 `relationalStore`（RDB）进行结构化数据持久化。管理 UserTable（用户注册表）和 SignRecordTable（签到记录表）的 CRUD 操作。

### 何时使用

- 用户注册时，保存学生信息（学号、姓名、人脸文件名）时
- 用户签到时，记录签到流水（学号、时间、状态、相似度）时
- 查询签到记录、统计签到成功率时

### 如何使用

```
注册流程:
  1. DataManager.initDatabase(context) 初始化数据库
  2. insertUser({ studentId, userName, faceUri, gmtCreate })
     └── 返回 { success, message }
     └── 捕获错误码 1501307（学号冲突）
  3. finally { resultSet.close() }

签到流程:
  1. queryUser(studentId) → UserRecord | null
  2. insertSignRecord({ studentId, signTime, status, similarity })
  3. querySignRecords(studentId, limit)
     └── 遍历 ResultSet → while(resultSet.goToNextRow())
     └── finally { resultSet.close() }
```

### 核心红线

- **严禁**将 `PixelMap` 存入数据库，只存文件名
- `resultSet.close()` 必须在 `finally` 中调用

### 依赖关系

依赖 `SKILL-HM-001`（async/await 规范）和 `SKILL-HM-008`（文件名存储策略）

---

## SKILL-HM-008

### ImageKit-ImagePacker

**文件路径**: `skills/08_ImageKit_ImagePacker/SKILL.md`

### 用途

使用 `ImagePacker` 将 `PixelMap` 压缩为 `.jpg` 文件保存到应用沙箱目录，或从沙箱读取文件重建 `PixelMap`。这是将人脸图像持久化的关键环节。

### 何时使用

- 用户注册人脸时，将相机拍摄的 `PixelMap` 保存为图片文件时
- 签到比对时，根据数据库中的文件名加载 `PixelMap` 时
- 用户注销时，删除对应的人脸图片文件时

### 如何使用

**保存流程**：

```
1. savePixelMapToFile(context, pixelMap, studentId)
   └── 生成文件名: face_{studentId}_{timestamp}.jpg
   └── ImagePacker.packToFile(pixelMap, fd, { format: 'image/jpeg', quality: 90 })
   └── 验证文件可读性
   └── 返回 fileName（存入数据库）
```

**读取流程**：

```
1. loadPixelMapFromFile(context, fileName)
   └── getContext().filesDir + '/faces/' + fileName
   └── image.createImageSource(fd) → createPixelMap()
   └── finally { imageSource.release(); fileIo.close(fd) }
   └── 返回 PixelMap（供 faceComparator 使用）
```

### 协同关系

```
注册时: PixelMap → [SKILL-HM-008 保存] → 文件
                                    ↓
                              face_uri 存入 [SKILL-HM-007]

比对时: face_uri 从 [SKILL-HM-007] 查询
              ↓
        [SKILL-HM-008 读取] → PixelMap → [SKILL-HM-003 比对]
```

### 依赖关系

依赖 `SKILL-HM-001`（资源释放规范）

---

## 技能依赖关系图

```
SKILL-HM-001 (基础规范)
├── SKILL-HM-002 (VisionKit 概览)
│   ├── SKILL-HM-003 (人脸比对)
│   ├── SKILL-HM-004 (人脸检测)
│   └── SKILL-HM-006 (多目标识别)
├── SKILL-HM-005 (活体检测) ──────────→ [产出 mPixelMap]
│                                        ↓
├── SKILL-HM-008 (图片存储) ──────────→ [产出 faceUri]
│       ↓                                   ↓
└── SKILL-HM-007 (数据库) ←────────────────┘
                    ↓
            [产出 userRecord / signRecord]
```

## 典型业务流对应的 Skill 组合

### 场景一：用户注册人脸

```
SKILL-HM-005 (活体检测) → 拍摄真实人脸 mPixelMap
    ↓
SKILL-HM-008 (图片存储) → 保存 mPixelMap 为 face_{id}.jpg
    ↓
SKILL-HM-007 (数据库) → 插入 UserTable{..., face_uri: "face_{id}.jpg"}
```

### 场景二：用户刷脸签到

```
SKILL-HM-005 (活体检测) → 获取现场真实人脸 mPixelMap
    ↓
SKILL-HM-007 (数据库) → 查询 UserTable 获取 face_uri
    ↓
SKILL-HM-008 (图片存储) → 加载 face_{id}.jpg 为注册 PixelMap
    ↓
SKILL-HM-003 (人脸比对) → compareFaces(注册PixelMap, 现场PixelMap)
    ↓
SKILL-HM-007 (数据库) → 插入 SignRecordTable{..., similarity, status}
```

### 场景三：注册前图片质量校验（可选）

```
SKILL-HM-004 (人脸检测) → 检测图库图片人脸数量 / probability / pose
SKILL-HM-006 (多目标识别) → 检测是否为单一清晰人脸图
```
