function EEG = detectAndInterpolateBadChannels( ...
    EEG, powerSDThreshold, amplitudeThreshold, amplitudeFraction)
% Detect bad-channel candidates, let the user confirm them,
% then interpolate confirmed channels using spherical splines.

    data = double(EEG.data);
    nChannels = EEG.nbchan;

    channelPower = mean(data.^2, 2, 'omitnan');
    powerThreshold = mean(channelPower, 'omitnan') + ...
        powerSDThreshold * std(channelPower, 0, 'omitnan');

    powerCandidates = find(channelPower > powerThreshold);

    amplitudeCandidates = [];

    for ch = 1:nChannels
        fractionLarge = mean( ...
            abs(data(ch, :)) >= amplitudeThreshold, 'omitnan');

        if fractionLarge > amplitudeFraction
            amplitudeCandidates(end+1) = ch; %#ok<AGROW>
        end
    end

    candidateIdx = unique([powerCandidates(:); ...
        amplitudeCandidates(:)]);

    labels = upper(strtrim(string({EEG.chanlocs.labels})));

    fprintf('\nBad-channel screening:\n');

    if isempty(candidateIdx)
        fprintf('No channels exceeded the screening thresholds.\n');
    else
        for k = 1:numel(candidateIdx)
            ch = candidateIdx(k);

            fprintf('Channel %s: power=%.4g, large-amplitude fraction=%.3f\n', ...
                labels(ch), channelPower(ch), ...
                mean(abs(data(ch, :)) >= amplitudeThreshold));
        end
    end

    fprintf(['Enter channel labels to interpolate, separated by commas.\n' ...
        'Example: FP1,FZ. Press Enter to keep all channels.\n']);

    userInput = strtrim(input('Channels to interpolate: ', 's'));

    if isempty(userInput)
        fprintf('No channels selected for interpolation.\n');
        return;
    end

    selectedLabels = upper(strtrim( ...
        string(regexp(userInput, '[,\s;]+', 'split'))));

    selectedIdx = find(ismember(labels, selectedLabels));

    unknownLabels = setdiff(selectedLabels, labels);

    assert(isempty(unknownLabels), ...
        'Unknown channel labels: %s', ...
        strjoin(unknownLabels, ', '));

    if isempty(selectedIdx)
        return;
    end

    assert(numel(selectedIdx) < EEG.nbchan, ...
        'Cannot interpolate every channel.');

    % Save the complete montage, remove confirmed bad channels,
    % then reconstruct their signals using spherical interpolation.
    originalChanlocs = EEG.chanlocs;

    fprintf('Interpolating channels: %s\n', ...
        strjoin(labels(selectedIdx), ', '));

    EEG = pop_select(EEG, 'nochannel', selectedIdx);
    EEG = eeg_checkset(EEG);

    EEG = pop_interp(EEG, originalChanlocs, 'spherical');
    EEG = eeg_checkset(EEG);

    assert(EEG.nbchan == numel(originalChanlocs), ...
        'Channel count mismatch after interpolation.');
end
