%clear;
clearvars -except subjectIds;
clc;
close all;

%% =========================================================
% EEG preprocessing.
%% =========================================================

%% 1. Configuration

if ~exist('subjectIds', 'var')
    subjectIds = 1:5;
end

validateattributes(subjectIds, {'numeric'}, ...
    {'vector', 'integer', '>=', 1, '<=', 5});

eeglab('nogui');

% Add the bundled Viewprops functions to the MATLAB search path.
viewpropsDir = fullfile( ...
    fileparts(which('eeglab')), ...
    'plugins', 'ICLabel', 'viewprops');

assert(isfolder(viewpropsDir), ...
    'Viewprops directory not found: %s', viewpropsDir);

addpath(viewpropsDir);

assert(exist('pop_viewprops', 'file') == 2, ...
    'pop_viewprops is still unavailable after adding its directory.');

dataDir = ...
    'E:\RIVERPROJECT\InterBrain\Dataset\Lecture_data';

setFile = '5subject_sync_label_0630.set';

outputDir = fullfile(dataDir, 'Preprocessed_Final');

if ~isfolder(outputDir)
    mkdir(outputDir);
end

% Filtering.
bandpassHz = [0.5 30];
notchHz = [49 51];
targetRate = 500;

% Event definitions.
trialStartCode = "3";
trialEndCode = "4";
cropPaddingSeconds = 5;

% Artifact detection.
powerSDThreshold = 3;
amplitudeSDThreshold = 5;
artifactPaddingMs = 40;

% These thresholds assume EEG amplitudes are in microvolts.
largeAmplitudeThreshold = 40;
largeAmplitudeFraction = 0.10;

% ICA component review.
icLabelFrequencyRange = [1 30];
maxDisplayedComponents = 20;

%% 2. Check required functions

requiredFunctions = {
    'pop_loadset'
    'pop_runica'
    'pop_iclabel'
    'pop_viewprops'
    'pop_subcomp'
    'extractSubjectEEG'
    'cropClassroomInterval'
    'detectAndInterpolateBadChannels'
    'removeArtifactsOutsideTrials'
    'getEventTypeStrings'
    };

for k = 1:numel(requiredFunctions)

    assert(exist(requiredFunctions{k}, 'file') == 2, ...
        'Required function unavailable: %s', ...
        requiredFunctions{k});

end

assert(isfile(fullfile(dataDir, setFile)), ...
    'Input SET file not found: %s', ...
    fullfile(dataDir, setFile));

%% 3. Locate standard electrode coordinates

eeglabRoot = fileparts(which('eeglab'));

lookupFile = fullfile(eeglabRoot, ...
    'plugins', 'dipfit', 'standard_BEM', ...
    'elec', 'standard_1005.elc');

if ~isfile(lookupFile)

    lookupCandidates = dir(fullfile( ...
        eeglabRoot, '**', 'standard_1005.elc'));

    assert(~isempty(lookupCandidates), ...
        'Cannot locate standard_1005.elc. Check DIPFIT.');

    lookupFile = fullfile( ...
        lookupCandidates(1).folder, ...
        lookupCandidates(1).name);

end

%% 4. Define the standard 64-channel montage

montageLabels = split( ...
    "FP1 FPZ FP2 AF3 AF4 F7 F5 F3 F1 FZ F2 F4 F6 F8 " + ...
    "FT7 FC5 FC3 FC1 FCZ FC2 FC4 FC6 FT8 T7 C5 C3 C1 " + ...
    "CZ C2 C4 C6 T8 M1 TP7 CP5 CP3 CP1 CPZ CP2 CP4 " + ...
    "CP6 TP8 M2 P7 P5 P3 P1 PZ P2 P4 P6 P8 PO7 PO5 " + ...
    "PO3 POZ PO4 PO6 PO8 CB1 O1 OZ O2 CB2");

auxiliaryLabels = ["M1", "M2", "CB1", "CB2"];

%% 5. Load the original synchronized dataset

EEG_all = pop_loadset( ...
    'filename', setFile, ...
    'filepath', dataDir, ...
    'loadmode', 'all');

EEG_all = eeg_checkset(EEG_all);

assert(EEG_all.trials == 1, ...
    'The source dataset must contain continuous EEG.');

fprintf('\n============================================\n');
fprintf('Classroom EEG preprocessing\n');
fprintf('Input: %s\n', fullfile(dataDir, setFile));
fprintf('Sampling rate: %.1f Hz\n', EEG_all.srate);
fprintf('Subjects: %s\n', mat2str(subjectIds));
fprintf('Output: %s\n', outputDir);
fprintf('============================================\n');

%% 6. Process each selected subject independently

for subjectId = subjectIds(:)'

    fprintf('\n\n############################################\n');
    fprintf('SUBJECT %d\n', subjectId);
    fprintf('############################################\n');

    %% Extract the subject's channels

    EEG = extractSubjectEEG( ...
        EEG_all, subjectId, montageLabels);

    fprintf('Extracted channels: %d\n', EEG.nbchan);

    %% Assign standard electrode coordinates

    for ch = 1:EEG.nbchan

        EEG.chanlocs(ch).labels = char( ...
            upper(strtrim(string(EEG.chanlocs(ch).labels))));

    end

    EEG = pop_chanedit(EEG, 'lookup', lookupFile);
    EEG = eeg_checkset(EEG);

    %% Remove auxiliary channels

    labels = upper(strtrim(string({EEG.chanlocs.labels})));

    auxIdx = find(ismember(labels, auxiliaryLabels));

    if ~isempty(auxIdx)

        EEG = pop_select(EEG, 'nochannel', auxIdx);
        EEG = eeg_checkset(EEG);

    end

    assert(EEG.nbchan == 60, ...
        'Expected 60 scalp channels for Subject %d; found %d.', ...
        subjectId, EEG.nbchan);

    fprintf('Remaining scalp channels: %d\n', EEG.nbchan);

    %% Crop the classroom interval

    EEG = cropClassroomInterval( ...
        EEG, trialStartCode, trialEndCode, ...
        cropPaddingSeconds);

    %% Apply band-pass and notch filters

    fprintf('Filtering %.1f-%.1f Hz...\n', ...
        bandpassHz(1), bandpassHz(2));

    EEG = pop_eegfiltnew(EEG, ...
        'locutoff', bandpassHz(1), ...
        'hicutoff', bandpassHz(2), ...
        'plotfreqz', 0);

    EEG = pop_eegfiltnew(EEG, ...
        'locutoff', notchHz(1), ...
        'hicutoff', notchHz(2), ...
        'revfilt', 1, ...
        'plotfreqz', 0);

    EEG = eeg_checkset(EEG);

    %% Detect bad-channel candidates and interpolate

    EEG = detectAndInterpolateBadChannels( ...
        EEG, powerSDThreshold, ...
        largeAmplitudeThreshold, largeAmplitudeFraction);

    %% Delete amplitude-artifact segments outside trials
    % Preserve the original temporal-rejection procedure.
    % Do not remove automatically generated boundary events.

    EEG = removeArtifactsOutsideTrials( ...
        EEG, trialStartCode, trialEndCode, ...
        amplitudeSDThreshold, artifactPaddingMs);

    %% Resample to 500 Hz

    fprintf('Resampling: %.1f -> %.1f Hz\n', ...
        EEG.srate, targetRate);

    EEG = pop_resample(EEG, targetRate);
    EEG = eeg_checkset(EEG);

    %% Compute the full ICA decomposition

    fprintf('\nRunning ICA for Subject %d...\n', subjectId);

    EEG = pop_runica(EEG, ...
        'icatype', 'runica', ...
        'extended', 1, ...
        'interrupt', 'on');

    EEG = eeg_checkset(EEG);

    assert(~isempty(EEG.icaweights) && ...
           ~isempty(EEG.icawinv), ...
        'ICA failed for Subject %d.', subjectId);

    %% Classify components using ICLabel

    fprintf('Running ICLabel...\n');

    EEG = pop_iclabel(EEG, 'default');

    nIC = size(EEG.icawinv, 2);

    fprintf('ICA components before removal: %d\n', nIC);

    %% Display only the first 20 components
    % This limits the display, not the ICA decomposition.

    num_comps = min(maxDisplayedComponents, nIC);

    spec_opt = {'freqrange', icLabelFrequencyRange};

    pop_viewprops(EEG, 0, 1:num_comps, spec_opt);

    fprintf('\nDisplaying ICs 1 through %d.\n', num_comps);

    rejectIC = input( ...
        'Enter IC indices to remove, e.g. [3 4 8], or []: ');

    if ~isempty(rejectIC)

        validateattributes(rejectIC, {'numeric'}, ...
            {'vector', 'integer', '>=', 1, '<=', nIC});

        rejectIC = unique(rejectIC(:)');

        EEG = pop_subcomp(EEG, rejectIC, 0);
        EEG = eeg_checkset(EEG);

    end

    fprintf('Removed %d of %d ICA components; %d remain.\n', ...
        numel(rejectIC), nIC, size(EEG.icawinv, 2));

    %% Apply whole-scalp average reference

    fprintf('Applying average reference...\n');

    EEG = pop_reref(EEG, []);
    EEG = eeg_checkset(EEG);

    %% Store processing information

    EEG.setname = sprintf( ...
        'Subject_%d_Preprocessed_500Hz', subjectId);

    EEG.subject = sprintf('Subject_%d', subjectId);

    EEG.etc.preprocessing = struct( ...
        'filterBandpassHz', bandpassHz, ...
        'notchHz', notchHz, ...
        'targetRate', targetRate, ...
        'trialStartCode', char(trialStartCode), ...
        'trialEndCode', char(trialEndCode), ...
        'artifactSDThreshold', amplitudeSDThreshold, ...
        'artifactPaddingMs', artifactPaddingMs, ...
        'rejectedICs', rejectIC);

    %% Save the final EEG structure as a MAT file

    outputFile = sprintf( ...
        'Subject_%d_Preprocessed.mat', subjectId);

    outputPath = fullfile(outputDir, outputFile);

    save(outputPath, 'EEG', '-v7.3');

    fprintf('\nSaved final dataset:\n%s\n', outputPath);
    fprintf('Subject %d completed.\n', subjectId);

    clear EEG;

end

fprintf('\n============================================\n');
fprintf('SELECTED SUBJECTS COMPLETED\n');
fprintf('Final output directory:\n%s\n', outputDir);
fprintf('No epoching or baseline correction was performed.\n');
fprintf('No intermediate EEG datasets were saved.\n');
fprintf('============================================\n');