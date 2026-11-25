function EEG = extractSubjectEEG(EEG_all, subjectId, montageLabels)
% Extract one subject using channel labels and numeric suffixes.

    labels = upper(strtrim(string({EEG_all.chanlocs.labels})));
    baseLabels = regexprep(labels, '-\d+$', '');

    subjectIds = ones(size(labels));
    tokens = regexp(cellstr(labels), ...
        '-(\d+)$', 'tokens', 'once');

    for k = 1:numel(labels)
        if ~isempty(tokens{k})
            subjectIds(k) = str2double(tokens{k}{1});
        end
    end

    channelIdx = find( ...
        subjectIds == subjectId & ...
        ismember(baseLabels, montageLabels));

    foundLabels = baseLabels(channelIdx);

    missingLabels = setdiff(montageLabels, foundLabels);

    assert(isempty(missingLabels), ...
        'Subject %d is missing channels: %s', ...
        subjectId, strjoin(missingLabels, ', '));

    EEG = pop_select(EEG_all, 'channel', channelIdx);
    EEG = eeg_checkset(EEG);

    % Restore standard unsuffixed labels for this subject.
    for k = 1:EEG.nbchan
        EEG.chanlocs(k).labels = char( ...
            regexprep(upper(strtrim( ...
            string(EEG.chanlocs(k).labels))), '-\d+$', ''));
    end
end
