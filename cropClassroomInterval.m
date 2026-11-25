function EEG = cropClassroomInterval( ...
    EEG, startCode, endCode, paddingSeconds)
% Keep the interval from the first start event to the last end event,
% including the requested padding.

    eventTypes = getEventTypeStrings(EEG);
    latencies = round([EEG.event.latency]);

    startIdx = find(eventTypes == startCode, 1, 'first');
    endIdx = find(eventTypes == endCode, 1, 'last');

    assert(~isempty(startIdx) && ~isempty(endIdx), ...
        'Required event codes %s and %s were not found.', ...
        startCode, endCode);

    firstLatency = latencies(startIdx);
    lastLatency = latencies(endIdx);

    assert(firstLatency < lastLatency, ...
        'Classroom event boundaries are invalid.');

    startPoint = max(1, ...
        firstLatency - round(paddingSeconds * EEG.srate));

    endPoint = min(EEG.pnts, ...
        lastLatency + round(paddingSeconds * EEG.srate));

    fprintf('Cropping samples %d to %d.\n', ...
        startPoint, endPoint);

    EEG = pop_select(EEG, 'point', [startPoint endPoint]);
    EEG = eeg_checkset(EEG);
end
