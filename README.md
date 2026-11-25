# EEG-Process

用于课堂多人同步 EEG 数据的 MATLAB / EEGLAB 预处理脚本。支持从同步记录中提取单个被试，完成滤波、坏导人工确认与插值、试次外坏时间段删除、ICA 成分人工剔除和平均参考。

本仓库发布 `EEG_Process` 目录中的代码，不包含 `pre/` 文件夹、原始脑电数据、处理结果或第三方 EEGLAB 插件。源脚本保留原有处理逻辑和本地路径，使用前请按自己的数据位置修改配置。

## 文件说明

| 文件 | 用途 |
| --- | --- |
| `EEG_Preprocessing.m` | 主要预处理脚本；默认处理被试 1–5，支持调用脚本传入 `subjectIds` |
| `sub2preprocess.m` | 仅处理被试 2 的运行入口 |
| `extractSubjectEEG.m` | 根据通道名及被试数字后缀提取被试数据 |
| `cropClassroomInterval.m` | 保留第一个事件 3 前 5 秒至最后一个事件 4 后 5 秒的数据 |
| `detectAndInterpolateBadChannels.m` | 检测坏导候选，由用户输入通道名称后进行球面插值 |
| `removeArtifactsOutsideTrials.m` | 检测幅值异常，仅删除事件 3–4 保护区间以外的异常片段 |
| `getEventTypeStrings.m` | 将数字和字符事件类型统一为字符串 |
| `plotInteractiveICReview.m` | 可点击的全部 ICA 成分拓扑图及 ICLabel 分类提示；当前主流程未调用 |
| `readPreprocessedEEG.m` | 原有波形浏览脚本；当前版本的 MAT 读取方式需调整，见下文 |
| `RereferenceEEG.m` | 独立后处理脚本：读取已有 ICA SET 数据，剔除指定成分、平均参考，并生成 ERP 分段数据 |

## 依赖

- MATLAB，需支持脚本、字符串数组及相关统计函数。
- [EEGLAB](https://eeglab.org/)，并将其根目录加入 MATLAB 搜索路径。
- FIRfilt：提供 `pop_eegfiltnew` 滤波函数。
- ICLabel：提供 ICA 成分分类功能。
- Viewprops：提供 `pop_viewprops` 成分检查窗口。
- DIPFIT 的标准电极坐标文件 `standard_1005.elc`。
- 依处理过程使用的函数，可能需要 MATLAB Signal Processing Toolbox。

EEGLAB 及插件需要单独安装，本仓库不提供这些依赖。当前代码优先从以下位置加载 Viewprops：

```text
<EEGLAB root>/plugins/ICLabel/viewprops
```

如果你将 Viewprops 安装在其他位置，请修改 `EEG_Preprocessing.m` 中的 `viewpropsDir`。

## 输入数据与路径配置

默认输入为同一目录内的配套文件：

```text
5subject_sync_label_0630.set
5subject_sync_label_0630.fdt
```

在 `EEG_Preprocessing.m` 中设置：

```matlab
dataDir = 'E:\RIVERPROJECT\InterBrain\Dataset\Lecture_data';
setFile = '5subject_sync_label_0630.set';
outputDir = fullfile(dataDir, 'Preprocessed_Final');
```

EEGLAB 通过 SET 文件中的元数据读取配套 FDT 文件。数据应为连续记录，通道名需符合脚本中的 64 通道列表：被试 1 使用 `FP1` 等标准名称，被试 2 使用 `FP1-2`，其他被试依次使用 `-3`、`-4`、`-5` 后缀。

脚本将事件 `3` 作为试次开始、事件 `4` 作为试次结束。用于裁剪和保护试次的事件代码应与实际实验标记一致。幅值筛查参数默认假设数据单位为微伏。

## 快速开始

先在 MATLAB 中将 EEGLAB 加入路径，再进入本仓库目录：

```matlab
addpath('E:\matlab\toolbox\eeglab');
cd('E:\RIVERPROJECT\InterBrain\EEG_Process');
sub2preprocess;
```

`sub2preprocess.m` 设置 `subjectIds = 2` 后运行主脚本。也可以手动选择其他被试：

```matlab
subjectIds = [1 3];
EEG_Preprocessing;
```

未设置 `subjectIds` 时，主脚本默认处理 `1:5`。主脚本中的 `clearvars -except subjectIds` 用于保留调用者设置的被试编号。

运行过程中有两处人工操作：

1. 坏导插值：根据筛查结果输入通道名称，例如 `FP1,FZ`；直接回车跳过插值。候选通道不会自动插值。
2. ICA 成分剔除：查看成分属性后，输入成分编号，例如 `[3 4 8]`；输入 `[]` 保留全部成分。

当前主流程只显示前 `min(20, nIC)` 个成分，ICA 分解和 ICLabel 分类仍针对全部成分。需要检查其他成分时可在相应数据仍处于工作区时调用 `pop_viewprops`，例如：

```matlab
pop_viewprops(EEG, 0, 21:40, {'freqrange', [1 30]});
```

仅当上述编号未超过实际成分数时使用该示例。

## 主要处理流程

1. 读取同步 SET/FDT 数据并提取当前被试的 64 个通道。
2. 恢复标准通道名、匹配标准坐标，移除 `M1`、`M2`、`CB1`、`CB2`，保留 60 个通道。
3. 从第一个事件 3 前 5 秒裁剪至最后一个事件 4 后 5 秒，不分别切分各试次。
4. 依次进行 0.5–30 Hz 带通滤波和 49–51 Hz 陷波。
5. 检测通道功率超过通道功率均值加 3 SD，或绝对幅值 ≥40 的比例超过 10% 的候选坏导；由用户确认后插值。
6. 将各事件 3 至后续第一个事件 4 的区间设为保护区间。
7. 按各通道均值 ±5 SD 检测异常，向两侧扩展 40 ms；仅删除保护区间外的异常时间片段。
8. 降采样至 500 Hz。
9. 运行扩展 Infomax ICA（`runica`，`extended = 1`）和 ICLabel，显示前 20 个成分供人工选择，使用 `pop_subcomp` 剔除指定成分。
10. 全脑平均参考，将最终 EEG 结构体保存为 MAT 文件。

主预处理流程不进行 epoch 分段或基线校正。`RereferenceEEG.m` 是另一条独立后处理流程，会执行事件 3 周围的分段和基线校正，不是主脚本的自动后续步骤。

### 关于 boundary

`removeArtifactsOutsideTrials.m` 使用 `eeg_eegrej` 删除坏时间段。内部片段删除形成的数据拼接处会由 EEGLAB 记录为 `boundary`，当前主流程保留这些事件。ICA 成分剔除 `pop_subcomp` 本身不会通过删除时间点来新增这种断点。

各被试的坏时间段分别检测、分别删除；用于跨被试同步或脑间耦合分析时，需要重新核对事件及时间轴，不能假定处理后相同数组下标仍对应相同的原始时刻。

## 输出与读取

仅处理被试 2 时，默认输出：

```text
<dataDir>/Preprocessed_Final/Subject_2_Preprocessed.mat
```

MAT 文件通过 `save(outputPath, 'EEG', '-v7.3')` 保存，包含变量 `EEG`。`-v7.3` 使用支持大型变量的 HDF5 MAT 格式。

正确读取并绘图的示例：

```matlab
resultFile = fullfile(dataDir, 'Preprocessed_Final', ...
    'Subject_2_Preprocessed.mat');
result = load(resultFile, 'EEG');
EEG = eeg_checkset(result.EEG);

eegplot(EEG.data, ...
    'srate', EEG.srate, ...
    'eloc_file', EEG.chanlocs, ...
    'events', EEG.event, ...
    'winlength', 10, ...
    'dispchans', 20, ...
    'spacing', 50);
```

当前 `readPreprocessedEEG.m` 保留了使用 `pop_loadset` 读取 `.mat` 的旧写法，并引用了未在脚本中初始化的 `subjectId`。请使用上述 `load` 示例，或自行调整该浏览脚本后再运行。

## 独立后处理脚本

`RereferenceEEG.m` 的输入是已有 ICA 的 `Subject_N_ICA.set`，不是主流程输出的 MAT 文件。它包含针对既有分解手工指定的成分编号，需要根据自己的 ICA 结果更新 `artifactICs`。

该脚本保存平均参考后的连续 SET 数据，并以事件 3 为中心进行 `[-0.2, 1.0]` 秒分段及 `[-200, 0]` 毫秒基线校正，另存 ERP SET 数据。运行前需配置输入、输出路径。

## 发布范围与许可证

`pre/` 文件夹不发布。原始数据、处理结果和 MATLAB 临时文件由 `.gitignore` 排除。

本次发布暂不添加开源许可证。代码公开可见，但不代表授予了不受限制的复制、修改或再分发许可。第三方工具与插件遵循各自的许可证。
