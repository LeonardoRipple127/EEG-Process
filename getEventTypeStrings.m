function eventTypes = getEventTypeStrings(EEG)
% Normalize numeric and string event types to a string array.

    eventTypes = strings(1, numel(EEG.event));

    for k = 1:numel(EEG.event)
        eventTypes(k) = string(EEG.event(k).type);
    end
end
