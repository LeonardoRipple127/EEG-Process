clear;
clc;

eeglab('nogui');

%% Existing ICA datasets
inputDir = ...
    'E:\RIVERPROJECT\InterBrain\Dataset\Lecture_data\ICA_results';

%% Output directories
outputDir = ...
    'E:\RIVERPROJECT\InterBrain\Dataset\Lecture_data\EEG_Cleaned';

continuousDir = fullfile(outputDir, 'Continuous_AvgRef');
erpDir = fullfile(outputDir, 'ERP_Epoched_Baseline');

if ~exist(continuousDir, 'dir')
    mkdir(continuousDir);
end

if ~exist(erpDir, 'dir')
    mkdir(erpDir);
end

%% Artifact components to remove
artifactICs = {
    [3 4 8 37]   % Subject 1
    [5 19]       % Subject 2
    [1 2]        % Subject 3
    [2 17]       % Subject 4
    [26 38]      % Subject 5
};

%% ERP parameters
eventCode = '3';
epochWindow = [-0.2 1.0];  % -200 ms to +1000 ms
baselineWindow = [-200 0]; % milliseconds

%% Process all subjects
for subjectId = 1:5

    fprintf('\n========================================\n');
    fprintf('Processing Subject %d\n', subjectId);
    fprintf('========================================\n');

    fileName = sprintf('Subject_%d_ICA.set', subjectId);

    assert(isfile(fullfile(inputDir, fileName)), ...
        'ICA dataset not found: %s', fullfile(inputDir, fileName));

    %% Load existing ICA; do not rerun ICA
    EEG = pop_loadset( ...
        'filename', fileName, ...
        'filepath', inputDir);

    EEG = eeg_checkset(EEG);

    assert(EEG.trials == 1, ...
        'Subject %d is not continuous EEG.', subjectId);

    assert(~isempty(EEG.icaweights) && ...
           ~isempty(EEG.icawinv), ...
        'ICA decomposition missing for Subject %d.', subjectId);

    %% 1. Remove selected artifact components
    rejectICs = artifactICs{subjectId};
    nIC = size(EEG.icawinv, 2);

    assert(all(rejectICs >= 1 & rejectICs <= nIC), ...
        'Invalid IC indices for Subject %d.', subjectId);

    fprintf('Removing ICs: %s\n', mat2str(rejectICs));

    EEG_clean = pop_subcomp(EEG, rejectICs, 0);
    EEG_clean = eeg_checkset(EEG_clean);

    %% 2. Whole-scalp average reference
    % These Subject_N_ICA datasets are expected to contain
    % scalp EEG channels only.
    EEG_clean = pop_reref(EEG_clean, []);
    EEG_clean = eeg_checkset(EEG_clean);

    %% Save cleaned continuous EEG for IBC analysis
    EEG_clean.setname = sprintf( ...
        'Subject_%d_Cleaned_AvgRef', subjectId);

    continuousFile = sprintf( ...
        'Subject_%d_Cleaned_AvgRef.set', subjectId);

    pop_saveset( ...
        EEG_clean, ...
        'filename', continuousFile, ...
        'filepath', continuousDir, ...
        'savemode', 'onefile');

    fprintf('Saved continuous EEG:\n%s\n', ...
        fullfile(continuousDir, continuousFile));

    %% 3. Epoch around knowledge-point onset (event 3)
    eventTypes = string({EEG_clean.event.type});

    assert(any(eventTypes == string(eventCode)), ...
        'Event code %s not found for Subject %d.', ...
        eventCode, subjectId);

    EEG_epoched = pop_epoch( ...
        EEG_clean, ...
        {eventCode}, ...
        epochWindow, ...
        'epochinfo', 'yes');

    EEG_epoched = eeg_checkset(EEG_epoched);

    assert(EEG_epoched.trials > 0, ...
        'No valid epochs for Subject %d.', subjectId);

    fprintf('Valid epochs: %d\n', EEG_epoched.trials);

    %% 4. Baseline correction
    EEG_epoched = pop_rmbase( ...
        EEG_epoched, baselineWindow);

    EEG_epoched = eeg_checkset(EEG_epoched);

    EEG_epoched.setname = sprintf( ...
        'Subject_%d_KnowledgeERP_BaselineCorrected', ...
        subjectId);

    %% Save ERP dataset
    erpFile = sprintf( ...
        'Subject_%d_KnowledgeERP.set', subjectId);

    pop_saveset( ...
        EEG_epoched, ...
        'filename', erpFile, ...
        'filepath', erpDir, ...
        'savemode', 'onefile');

    fprintf('Saved ERP dataset:\n%s\n', ...
        fullfile(erpDir, erpFile));

end

fprintf('\n========================================\n');
fprintf('All subjects processed.\n');
fprintf('Continuous EEG: %s\n', continuousDir);
fprintf('ERP datasets: %s\n', erpDir);
fprintf('ICA was not rerun.\n');
fprintf('Original ICA datasets were not overwritten.\n');
fprintf('========================================\n');
