function EEG = removeArtifactsOutsideTrials( ...
    EEG, startCode, endCode, thresholdSD, paddingMs)
% Detect amplitude outliers and expand each by +/-paddingMs.
% Keep artifacts inside event-defined trials marked but not deleted.
% Delete only artifact segments outside these trial intervals.

    nTime = EEG.pnts;
    nChannels = EEG.nbchan;
    fs = EEG.srate;

    eventTypes = getEventTypeStrings(EEG);
    eventLatency = round([EEG.event.latency]);

    [eventLatency, sortIdx] = sort(eventLatency);
    eventTypes = eventTypes(sortIdx);

    idxStart = find(eventTypes == startCode);
    idxEnd = find(eventTypes == endCode);

    assert(~isempty(idxStart) && ~isempty(idxEnd), ...
        'Cannot construct trial intervals: events %s/%s missing.', ...
        startCode, endCode);

    trialMask = false(1, nTime);

    for k = 1:numel(idxStart)

        currentStart = idxStart(k);
        nextEndPosition = find(idxEnd > currentStart, 1, 'first');

        if isempty(nextEndPosition)
            warning('Start event %d has no subsequent end event.', k);
            continue;
        end

        currentEnd = idxEnd(nextEndPosition);

        startPoint = max(1, eventLatency(currentStart));
        endPoint = min(nTime, eventLatency(currentEnd));

        if startPoint < endPoint
            trialMask(startPoint:endPoint) = true;
        end
    end

    assert(any(trialMask), ...
        'No valid event-3-to-event-4 trial intervals found.');

    paddingPoints = round(paddingMs / 1000 * fs);
    artifactMask = false(1, nTime);

    data = double(EEG.data);

    for ch = 1:nChannels

        x = data(ch, :);
        channelMean = mean(x, 'omitnan');
        channelSD = std(x, 0, 'omitnan');

        if ~isfinite(channelSD) || channelSD == 0
            continue;
        end

        outlierIdx = find( ...
            x > channelMean + thresholdSD * channelSD | ...
            x < channelMean - thresholdSD * channelSD);

        for k = 1:numel(outlierIdx)

            left = max(1, outlierIdx(k) - paddingPoints);
            right = min(nTime, outlierIdx(k) + paddingPoints);

            artifactMask(left:right) = true;
        end
    end

    markOnlyMask = artifactMask & trialMask;
    deleteMask = artifactMask & ~trialMask;

    fprintf('Artifact duration: %.2f s\n', ...
        nnz(artifactMask) / fs);

    fprintf('Artifact duration inside trials (kept): %.2f s\n', ...
        nnz(markOnlyMask) / fs);

    fprintf('Artifact duration outside trials (candidate deletion): %.2f s\n', ...
        nnz(deleteMask) / fs);

    % Convert the deletion mask into continuous sample segments.
    edges = diff([false, deleteMask, false]);

    segmentStart = find(edges == 1);
    segmentEnd = find(edges == -1) - 1;

    segments = [segmentStart(:), segmentEnd(:)];

    if isempty(segments)
        fprintf('No outside-trial artifact segments to delete.\n');
        return;
    end

    fprintf('Outside-trial segments to delete: %d\n', ...
        size(segments, 1));

    % Delete segments while allowing EEGLAB to update event latencies.
    EEG = eeg_eegrej(EEG, segments);
    EEG = eeg_checkset(EEG);

    fprintf('Outside-trial artifact segments deleted.\n');
end