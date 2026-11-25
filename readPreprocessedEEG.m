%% 使用 EEGLAB 读取并绘制被试预处理后的脑电
% 请先将 EEGLAB 添加到 MATLAB 路径。
% 每名被试打开一个独立的交互式脑电浏览窗口。

eeglab('nogui');

dataDir = ...
    'E:\RIVERPROJECT\InterBrain\Dataset\Lecture_data\Preprocessed_Final';

%for subjectId = 1:5
    fileName = sprintf('Subject_2_Preprocessed.mat', subjectId);

    EEG = pop_loadset( ...
        'filename', fileName, ...
        'filepath', dataDir, ...
        'loadmode', 'all');

    EEG = eeg_checkset(EEG);

    eegplot(EEG.data, ...
        'srate', EEG.srate, ...
        'eloc_file', EEG.chanlocs, ...
        'events', EEG.event, ...
        'winlength', 10, ...       % 每页显示 10 秒
        'dispchans', 20, ...       % 每页显示 20 个导联，可上下滚动
        'spacing', 50, ...         % 导联间距，按实际幅值调整
        'title', sprintf('Subject %d — Preprocessed EEG', subjectId));
%end