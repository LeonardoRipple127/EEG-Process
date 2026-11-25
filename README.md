# EEG-Process

用于 EEG 数据的 MATLAB / EEGLAB 预处理脚本。支持从同步记录中提取单个被试，完成滤波、坏导人工确认与插值、试次外坏时间段删除、ICA 成分人工剔除和平均参考。

## 文件说明

| 文件 | 用途 |
| --- | --- |
| `EEG_Preprocessing.m` | 主要预处理脚本 |
| `extractSubjectEEG.m` | 根据通道名及被试数字后缀提取被试数据 |
| `cropClassroomInterval.m` | 保留第一个事件 3 前 5 秒至最后一个事件 4 后 5 秒的数据 |
| `detectAndInterpolateBadChannels.m` | 检测坏导候选，由用户输入通道名称后进行球面插值 |
| `removeArtifactsOutsideTrials.m` | 检测幅值异常，仅删除事件 3–4 保护区间以外的异常片段 |
| `getEventTypeStrings.m` | 将数字和字符事件类型统一为字符串 |
| `plotInteractiveICReview.m` | 可点击的全部 ICA 成分拓扑图及 ICLabel 分类提示 |
| `readPreprocessedEEG.m` | 原有波形浏览脚本 |
| `RereferenceEEG.m` | 独立后处理脚本：读取已有 ICA SET 数据，剔除指定成分、平均参考，并生成 ERP 分段数据 |

## 依赖

- MATLAB，需支持脚本、字符串数组及相关统计函数。
- [EEGLAB](https://eeglab.org/)，并将其根目录加入 MATLAB 搜索路径。
- FIRfilt：提供 `pop_eegfiltnew` 滤波函数。
- ICLabel：提供 ICA 成分分类功能。
- Viewprops：提供 `pop_viewprops` 成分检查窗口。
- DIPFIT 的标准电极坐标文件 `standard_1005.elc`。
- 依处理过程使用的函数，可能需要 MATLAB Signal Processing Toolbox。
 

## 输入数据与路径配置

在 `EEG_Preprocessing.m` 中设置：

```matlab
dataDir = 'dir...';
setFile = '____.set';
outputDir = fullfile(dataDir, 'name');
```

EEGLAB 通过 SET 文件中的元数据读取配套 FDT 文件。数据应为连续记录，通道名需符合脚本中的 64 通道列表。

脚本将事件 `3` 作为试次开始、事件 `4` 作为试次结束。用于裁剪和保护试次的事件代码应与实际实验标记一致。幅值筛查参数默认假设数据单位为微伏。

## 主要处理流程

1. 读取同步 SET/FDT 数据并提取当前通道。
2. 原始EEG内试次划分。
4. 依次进行 0.5–30 Hz 带通滤波和 49–51 Hz 陷波。
5. 检测通道功率超过通道功率均值加 3 SD，或绝对幅值 ≥40 的比例超过 10% 的候选坏导；由用户确认后插值。
6. 将各事件 3 至后续第一个事件 4 的区间设为保护区间。
7. 按各通道均值 ±5 SD 检测异常，向两侧扩展 40 ms；仅删除保护区间外的异常时间片段。
8. 降采样至 500 Hz。
9. ICA。
10. 全脑平均参考。
