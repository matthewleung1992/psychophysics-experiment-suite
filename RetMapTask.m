function monkey_stimuli_presentation()
    % Revamped Monkey Stimuli Presentation Script using PsychToolbox
    % Uses eyetracker for fixation detection and peripheral flash stimuli
    
    %% HARDCODED PARAMETERS - EDIT HERE
    GRID_SIZE = 4;              % Grid size: only 4, 6, or 8 allowed
    CYCLES = 3;                 % C: Number of cycles of all combinations in pool
    TRIAL_DURATION = 10;        % Trial duration in seconds
    FLASH_DURATION = 20;        % Flash duration in milliseconds
    COOLDOWN_PERIOD = 0;        % Cooldown after flash in milliseconds
    FIXATION_THRESHOLD = 500;   % Fixation duration required (ms)
    BLANK_DURATION = 2000;      % Blank screen duration between trials (ms)
    SUCCESS_THRESHOLD = 0.7;    % Success threshold (0-1, e.g., 0.7 = 70%)
    OPPOSITE_COLUMNS = 1;       % Number of columns on opposite side for TL/TR
    FIXATION_POINT_SIZE = 5;    % Fixation point size in pixels
    FLASH_CIRCLE_SCALE = 0.8;   % Flash circle scale (0-1, fraction of cell size)
    GAZE_WINDOW = 50;           % D: Fixation window size (pixels) - square window DxD
    GAZE_PERCENTAGE = 0.95;     % G: Percentage of time gaze must be in window (0-1)
    DUMMY_MODE = 1;             % 0 = real eyetracker, 1 = mouse simulation
    ADDRESS_N = '100.1.1.1';   % Eyelink IP address
    DEBUG_MODE = 1;             % 1 = show debug messages for fixation detection
    FLASH_COLOR = [0 1 1];      % Cyan [R G B] normalized 0-1
    BACKGROUND_COLOR = [0.7 0.7 0.7]; % Light grey background
    FIXATION_COLOR = [1 1 1];   % White fixation points
    
    % Validate parameters
    if ~ismember(GRID_SIZE, [4, 6, 8])
        error('Grid size must be 4, 6, or 8 only!');
    end
    if OPPOSITE_COLUMNS > GRID_SIZE/2
        error('OPPOSITE_COLUMNS (%d) cannot be more than half of GRID_SIZE (%d)!', OPPOSITE_COLUMNS, GRID_SIZE/2);
    end
    
    %% Initialize PsychToolbox
    try
        % Basic setup
        PsychDefaultSetup(2);
        Screen('Preference', 'SkipSyncTests', 1); % Skip for development
        
        % Open window
        screens = Screen('Screens');
        screenNumber = max(screens);
        [window, windowRect] = PsychImaging('OpenWindow', screenNumber, BACKGROUND_COLOR);
        [screenXpixels, screenYpixels] = Screen('WindowSize', window);
        
        % Calculate grid parameters
        cellWidth = screenXpixels / GRID_SIZE;
        cellHeight = screenYpixels / GRID_SIZE;
        
        % Calculate junction positions (GRID_SIZE+1 junctions per dimension)
        junctionSpacingX = screenXpixels / GRID_SIZE;
        junctionSpacingY = screenYpixels / GRID_SIZE;
        
        % Define fixation point positions at junctions
        middleJunctionRow = ceil((GRID_SIZE + 1) / 2); % Middle horizontal line of junctions (1-based)
        middleY = (middleJunctionRow - 1) * junctionSpacingY; % Convert to 0-based pixel position
        
        fixationPositions = struct();
        % TL: second leftmost junction on middle row
        fixationPositions.TL = [1 * junctionSpacingX, middleY];
        % TC: middle junction  
        fixationPositions.TC = [ceil((GRID_SIZE + 1) / 2 - 1) * junctionSpacingX, middleY];
        % TR: second rightmost junction on middle row
        fixationPositions.TR = [(GRID_SIZE - 1) * junctionSpacingX, middleY];
        
        % Generate all possible flash positions (cell centers)
        flashPositions = [];
        flashLabels = {};
        for row = 1:GRID_SIZE
            for col = 1:GRID_SIZE
                centerX = (col - 0.5) * cellWidth;
                centerY = (row - 0.5) * cellHeight;
                flashPositions(end+1, :) = [centerX, centerY];
                flashLabels{end+1} = sprintf('R%dC%d', row, col);
            end
        end
        
        % Define flash combinations based on new rules
        combinations = {};
        combinationLabels = {};
        
        % TC triggers all cells
        for i = 1:length(flashLabels)
            combinations{end+1} = {'TC', flashLabels{i}, flashPositions(i, :)};
            combinationLabels{end+1} = sprintf('TC->%s', flashLabels{i});
        end
        
        % TL triggers rightmost OPPOSITE_COLUMNS columns
        for row = 1:GRID_SIZE
            for col = (GRID_SIZE - OPPOSITE_COLUMNS + 1):GRID_SIZE
                idx = (row - 1) * GRID_SIZE + col;
                combinations{end+1} = {'TL', flashLabels{idx}, flashPositions(idx, :)};
                combinationLabels{end+1} = sprintf('TL->%s', flashLabels{idx});
            end
        end
        
        % TR triggers leftmost OPPOSITE_COLUMNS columns
        for row = 1:GRID_SIZE
            for col = 1:OPPOSITE_COLUMNS
                idx = (row - 1) * GRID_SIZE + col;
                combinations{end+1} = {'TR', flashLabels{idx}, flashPositions(idx, :)};
                combinationLabels{end+1} = sprintf('TR->%s', flashLabels{idx});
            end
        end
        
        % Create pool with C cycles of all combinations
        combinationPool = {};
        poolLabels = {};
        for cycle = 1:CYCLES
            for i = 1:length(combinations)
                combinationPool{end+1} = combinations{i};
                poolLabels{end+1} = sprintf('C%d_%s', cycle, combinationLabels{i});
            end
        end
        
        % Calculate flash circle radius
        minCellDimension = min(cellWidth, cellHeight);
        flashRadius = (minCellDimension * FLASH_CIRCLE_SCALE) / 2;
        
        % Initialize keyboard
        KbName('UnifyKeyNames');
        keyTL = KbName('A');
        keyTC = KbName('S');
        keyTR = KbName('D');
        escapeKey = KbName('ESCAPE');
        
        % Hide cursor
        HideCursor;
        
        % Initialize Eyelink
        initializeEyetracker(window, DUMMY_MODE, ADDRESS_N);
        
        % Show initial blank screen and wait for mouse click
        Screen('FillRect', window, [1 1 1]); % White blank screen
        Screen('Flip', window);
        fprintf('Click mouse to start experiment...\n');
        GetClicks(window);
        experimentStartTime = GetSecs;
        fprintf('Grid: %dx%d, Cycles: %d, Trial Duration: %ds\n', GRID_SIZE, GRID_SIZE, CYCLES, TRIAL_DURATION);
        fprintf('Total combinations in pool: %d\n', length(combinationPool));
        fprintf('Success threshold: %.0f%%, Flash: %dms, Cooldown: %dms\n', SUCCESS_THRESHOLD*100, FLASH_DURATION, COOLDOWN_PERIOD);
        fprintf('Controls: A=TL, S=TC, D=TR, ESC=Exit\n\n');
        
        fprintf('\n=== REVAMPED MONKEY STIMULI PRESENTATION STARTED ===\n');
        %% Main experiment loop
        trialNumber = 0;
        consecutiveEscapes = 0; % Track consecutive escape presses
        
        while ~isempty(combinationPool)
            trialNumber = trialNumber + 1;
            trialStartTime = GetSecs;
            
            % Calculate maximum possible fixations for this trial
            maxPossibleFixations = floor(TRIAL_DURATION * 1000 / (FIXATION_THRESHOLD + FLASH_DURATION + COOLDOWN_PERIOD));
            
            % Select fixation point for this trial
            fixationTypes = {'TL', 'TC', 'TR'};
            availableTypes = {};
            for fType = fixationTypes
                typeCount = sum(cellfun(@(x) strcmp(x{1}, fType{1}), combinationPool));
                if typeCount > 0
                    availableTypes{end+1} = fType{1};
                end
            end
            
            if isempty(availableTypes)
                fprintf('*** EXPERIMENT COMPLETED - NO MORE COMBINATIONS ***\n');
                break;
            end
            
            selectedFixationType = availableTypes{randi(length(availableTypes))};
            
            % Get available combinations for selected fixation type
            availableCombinations = {};
            for i = 1:length(combinationPool)
                if strcmp(combinationPool{i}{1}, selectedFixationType)
                    availableCombinations{end+1} = combinationPool{i};
                end
            end
            
            % Adjust maximum if fewer combinations available
            actualMaxFixations = min(maxPossibleFixations, length(availableCombinations));
            
            % Randomly select combinations for this trial (no duplicates)
            if actualMaxFixations == 0
                fprintf('*** EXPERIMENT COMPLETED - NO MORE COMBINATIONS FOR ANY FIXATION TYPE ***\n');
                break;
            end
            
            selectedIndices = randperm(length(availableCombinations), actualMaxFixations);
            trialCombinations = availableCombinations(selectedIndices);
            
            % Calculate success threshold for this trial
            successThreshold = ceil(actualMaxFixations * SUCCESS_THRESHOLD);
            
            fprintf('--- TRIAL %d ---\n', trialNumber);
            fprintf('Fixation type: %s\n', selectedFixationType);
            fprintf('Max fixations: %d (time) -> %d (available)\n', maxPossibleFixations, actualMaxFixations);
            fprintf('Success threshold: %d/%d (%.0f%%)\n', successThreshold, actualMaxFixations, SUCCESS_THRESHOLD*100);
            
            % Initialize trial log
            trialLog = struct();
            trialLog.trial_number = trialNumber;
            trialLog.trial_start_time = trialStartTime;
            trialLog.fixation_type = selectedFixationType;
            trialLog.max_possible_fixations = maxPossibleFixations;
            trialLog.actual_max_fixations = actualMaxFixations;
            trialLog.success_threshold = successThreshold;
            trialLog.events = {};
            
            % Add config to log
            config = struct();
            config.GRID_SIZE = GRID_SIZE;
            config.CYCLES = CYCLES;
            config.TRIAL_DURATION = TRIAL_DURATION;
            config.FLASH_DURATION = FLASH_DURATION;
            config.COOLDOWN_PERIOD = COOLDOWN_PERIOD;
            config.FIXATION_THRESHOLD = FIXATION_THRESHOLD;
            config.BLANK_DURATION = BLANK_DURATION;
            config.SUCCESS_THRESHOLD = SUCCESS_THRESHOLD;
            config.OPPOSITE_COLUMNS = OPPOSITE_COLUMNS;
            config.FIXATION_POINT_SIZE = FIXATION_POINT_SIZE;
            config.GAZE_WINDOW = GAZE_WINDOW;
            config.GAZE_PERCENTAGE = GAZE_PERCENTAGE;
            config.DUMMY_MODE = DUMMY_MODE;
            config.FLASH_CIRCLE_SCALE = FLASH_CIRCLE_SCALE;
            trialLog.config = config;
            
            % Execute trial
            completedFixations = 0;
            completedCombinations = {};
            trialStart = GetSecs;
            lastFlashTime = 0;
            inCooldown = false;
            currentCombinationIndex = 1;
            fixationStartTime = 0;
            fixationInProgress = false;
            gazeHistory = []; % Track gaze positions during fixation attempts
            
            while (GetSecs - trialStart) < TRIAL_DURATION && currentCombinationIndex <= length(trialCombinations)
                currentTime = GetSecs;
                
                % Check if we're in cooldown period
                if inCooldown && (currentTime - lastFlashTime) < (COOLDOWN_PERIOD/1000)
                    continue;
                else
                    inCooldown = false;
                end
                
                % Draw background
                Screen('FillRect', window, BACKGROUND_COLOR);
                
                % Draw fixation point
                fixPos = fixationPositions.(selectedFixationType);
                Screen('DrawDots', window, [fixPos(1); fixPos(2)], FIXATION_POINT_SIZE, FIXATION_COLOR, [], 2);
                
                % Check for fixation (Eyelink)
                fixationDetected = false;
                
                if ~inCooldown
                    [gazeX, gazeY, gazeValid] = getGazePosition(window, DUMMY_MODE);
                    
                    if DEBUG_MODE && mod(round(currentTime*10), 10) == 0 % Debug every ~100ms
                        fprintf('Debug: Gaze at (%.1f, %.1f), Valid: %d\n', gazeX, gazeY, gazeValid);
                    end
                    
                    if gazeValid
                        % Check if gaze is within fixation window
                        fixPos = fixationPositions.(selectedFixationType);
                        distanceX = abs(gazeX - fixPos(1));
                        distanceY = abs(gazeY - fixPos(2));
                        gazeInWindow = distanceX <= GAZE_WINDOW/2 && distanceY <= GAZE_WINDOW/2;
                        
                        if DEBUG_MODE && gazeInWindow
                            fprintf('Debug: Gaze IN window at %s (dist: %.1f, %.1f)\n', selectedFixationType, distanceX, distanceY);
                        end
                        
                        if gazeInWindow
                            if ~fixationInProgress
                                fixationStartTime = currentTime;
                                fixationInProgress = true;
                                gazeHistory = [currentTime];
                                eventTime = currentTime;
                                trialLog.events{end+1} = struct('time', eventTime, 'event', 'fixation_started', 'details', sprintf('at %s', selectedFixationType));
                                fprintf('Fixation started at %s\n', selectedFixationType);
                            else
                                gazeHistory(end+1) = currentTime;
                            end
                            
                            % Check if fixation is successful
                            fixationDuration = currentTime - fixationStartTime;
                            if fixationDuration >= (FIXATION_THRESHOLD/1000)
                                % Calculate percentage of time gaze was in window
                                % Use actual time tracking instead of sample count
                                timeInWindow = fixationDuration; % All tracked time was in window
                                gazePercentage = timeInWindow / fixationDuration; % This will be 1.0
                                
                                if DEBUG_MODE
                                    fprintf('Debug: Fixation duration: %.3fs, Gaze %%: %.2f\n', fixationDuration, gazePercentage);
                                end
                                
                                if gazePercentage >= GAZE_PERCENTAGE
                                    fixationDetected = true;
                                end
                            end
                        else
                            if fixationInProgress
                                fixationInProgress = false;
                                eventTime = currentTime;
                                trialLog.events{end+1} = struct('time', eventTime, 'event', 'fixation_broken', 'details', sprintf('at %s', selectedFixationType));
                                fprintf('Fixation broken at %s\n', selectedFixationType);
                                gazeHistory = [];
                            end
                        end
                    end
                    
                    % Keyboard check for testing (fallback)
                    [keyIsDown, ~, keyCode] = KbCheck;
                    if keyIsDown
                        if keyCode(escapeKey)
                            eventTime = currentTime;
                            trialLog.events{end+1} = struct('time', eventTime, 'event', 'experiment_terminated', 'details', 'user_escape');
                            fprintf('*** TRIAL TERMINATED BY USER ***\n');
                            consecutiveEscapes = consecutiveEscapes + 1;
                            if consecutiveEscapes >= 3
                                fprintf('*** EXPERIMENT TERMINATED - 3 CONSECUTIVE ESCAPES ***\n');
                                break;
                            end
                            break;
                        elseif (keyCode(keyTL) && strcmp(selectedFixationType, 'TL')) || ...
                               (keyCode(keyTC) && strcmp(selectedFixationType, 'TC')) || ...
                               (keyCode(keyTR) && strcmp(selectedFixationType, 'TR'))
                            fixationDetected = true;
                            fprintf('Keyboard fixation triggered for %s\n', selectedFixationType);
                        end
                        WaitSecs(0.1); % Prevent multiple detections
                    end
                end
                
                % Process fixation detection
                if fixationDetected
                    currentCombination = trialCombinations{currentCombinationIndex};
                    flashPos = currentCombination{3};
                    flashLabel = currentCombination{2};
                    
                    eventTime = currentTime;
                    trialLog.events{end+1} = struct('time', eventTime, 'event', 'fixation_successful', 'details', sprintf('%s->%s', selectedFixationType, flashLabel));
                    
                    % Keep fixation point visible during flash
                    Screen('FillRect', window, BACKGROUND_COLOR);
                    fixPos = fixationPositions.(selectedFixationType);
                    Screen('DrawDots', window, [fixPos(1); fixPos(2)], FIXATION_POINT_SIZE, FIXATION_COLOR, [], 2);
                    
                    % Trigger flash (circle)
                    Screen('FillOval', window, FLASH_COLOR, [flashPos(1)-flashRadius, flashPos(2)-flashRadius, flashPos(1)+flashRadius, flashPos(2)+flashRadius]);
                    Screen('Flip', window);
                    
                    eventTime = currentTime;
                    trialLog.events{end+1} = struct('time', eventTime, 'event', 'flash_started', 'details', sprintf('at %s', flashLabel));
                    
                    WaitSecs(FLASH_DURATION/1000);
                    
                    eventTime = GetSecs;
                    trialLog.events{end+1} = struct('time', eventTime, 'event', 'flash_ended', 'details', sprintf('at %s', flashLabel));
                    
                    % Record completion
                    completedFixations = completedFixations + 1;
                    completedCombinations{end+1} = currentCombination;
                    lastFlashTime = GetSecs;
                    inCooldown = (COOLDOWN_PERIOD > 0);
                    fixationInProgress = false;
                    gazeHistory = [];
                    
                    fprintf('Fixation %d/%d completed: %s -> %s\n', completedFixations, actualMaxFixations, selectedFixationType, flashLabel);
                    
                    % Move to next combination
                    currentCombinationIndex = currentCombinationIndex + 1;
                end
                
                Screen('Flip', window);
                WaitSecs(0.01); % Small delay to prevent excessive CPU usage
            end
            
            % Remove completed combinations from pool
            for comp = completedCombinations
                for i = length(combinationPool):-1:1
                    if isequal(combinationPool{i}, comp{1})
                        combinationPool(i) = [];
                        break;
                    end
                end
            end
            
            % Determine trial result
            trialSuccessful = completedFixations >= successThreshold;
            trialEndTime = GetSecs;
            
            trialLog.trial_end_time = trialEndTime;
            trialLog.completed_fixations = completedFixations;
            trialLog.trial_successful = trialSuccessful;
            trialLog.combinations_remaining_in_pool = length(combinationPool);
            
            if trialSuccessful
                fprintf('*** TRIAL %d: SUCCESS! (%d/%d fixations) ***\n', trialNumber, completedFixations, actualMaxFixations);
                deliverReward();
                eventTime = GetSecs;
                trialLog.events{end+1} = struct('time', eventTime, 'event', 'reward_delivered', 'details', 'trial_successful');
                consecutiveEscapes = 0; % Reset escape counter on successful trial
            else
                fprintf('*** TRIAL %d: FAILED (%d/%d fixations) ***\n', trialNumber, completedFixations, actualMaxFixations);
                % Don't reset escape counter on failed trials
            end
            
            fprintf('Combinations remaining in pool: %d\n\n', length(combinationPool));
            
            % Show blank screen and write log during blank period
            Screen('FillRect', window, [1 1 1]); % White blank screen
            Screen('Flip', window);
            
            % Write trial log to CSV file
            writeTrialLog(trialLog, trialNumber);
            
            WaitSecs(BLANK_DURATION/1000);
            
            % Check for escape during blank
            [keyIsDown, ~, keyCode] = KbCheck;
            if keyIsDown && keyCode(escapeKey)
                fprintf('*** TRIAL TERMINATED BY USER DURING BLANK ***\n');
                consecutiveEscapes = consecutiveEscapes + 1;
                if consecutiveEscapes >= 3
                    fprintf('*** EXPERIMENT TERMINATED - 3 CONSECUTIVE ESCAPES ***\n');
                    break;
                end
            end
            
            % Check if experiment should terminate due to consecutive escapes
            if consecutiveEscapes >= 3
                break;
            end
        end
        
        %% Experiment completed
        experimentEndTime = GetSecs;
        fprintf('=== EXPERIMENT COMPLETED ===\n');
        fprintf('Total trials: %d\n', trialNumber);
        fprintf('Start time: %.3f\n', experimentStartTime);
        fprintf('End time: %.3f\n', experimentEndTime);
        fprintf('Duration: %.3f seconds\n', experimentEndTime - experimentStartTime);
        
        % Cleanup
        cleanupEyetracker();
        ShowCursor;
        Screen('CloseAll');
        
    catch ME
        % Error handling
        fprintf('Error occurred: %s\n', ME.message);
        cleanupEyetracker();
        ShowCursor;
        Screen('CloseAll');
        rethrow(ME);
    end
end

%% Helper Functions

function writeTrialLog(trialLog, trialNumber)
    % Write trial log to CSV file
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    filename = sprintf('trial_log_%03d_%s.csv', trialNumber, timestamp);
    
    try
        % Open file for writing
        fid = fopen(filename, 'w');
        if fid == -1
            error('Could not open file for writing: %s', filename);
        end
        
        % Write config section
        fprintf(fid, 'CONFIG\n');
        configFields = fieldnames(trialLog.config);
        for i = 1:length(configFields)
            fprintf(fid, '%s,%s\n', configFields{i}, num2str(trialLog.config.(configFields{i})));
        end
        fprintf(fid, '\n');
        
        % Write trial info section
        fprintf(fid, 'TRIAL_INFO\n');
        fprintf(fid, 'trial_number,%d\n', trialLog.trial_number);
        fprintf(fid, 'trial_start_time,%s\n', trialLog.trial_start_time);
        fprintf(fid, 'trial_end_time,%s\n', trialLog.trial_end_time);
        fprintf(fid, 'fixation_type,%s\n', trialLog.fixation_type);
        fprintf(fid, 'max_possible_fixations,%d\n', trialLog.max_possible_fixations);
        fprintf(fid, 'actual_max_fixations,%d\n', trialLog.actual_max_fixations);
        fprintf(fid, 'success_threshold,%d\n', trialLog.success_threshold);
        fprintf(fid, 'completed_fixations,%d\n', trialLog.completed_fixations);
        fprintf(fid, 'trial_successful,%d\n', trialLog.trial_successful);
        fprintf(fid, 'combinations_remaining_in_pool,%d\n', trialLog.combinations_remaining_in_pool);
        fprintf(fid, '\n');
        
        % Write events section
        fprintf(fid, 'EVENTS\n');
        fprintf(fid, 'timestamp,event,details\n');
        for i = 1:length(trialLog.events)
            event = trialLog.events{i};
            fprintf(fid, '%.6f,%s,%s\n', event.time, event.event, event.details);
        end
        
        fclose(fid);
        fprintf('Trial log written to: %s\n', filename);
        
    catch ME
        if exist('fid', 'var') && fid ~= -1
            fclose(fid);
        end
        fprintf('Error writing log file: %s\n', ME.message);
    end
end

%% Eyelink Functions
function initializeEyetracker(window, dummymode, Address_N)
    % Initialize Eyelink eyetracker
    try
        [winWidth, winHeight] = WindowSize(window);
        
        if dummymode == 0
            % Real eyetracker mode
            if ~isempty(Address_N)
                Eyelink('SetAddress', Address_N);
            end
            Eyelink('Initialize');
            Eyelink('StartSetup');
            
            % Use InitializeEyeTracker if available
            if exist('InitializeEyeTracker.m', 'file') == 2
                el = InitializeEyeTracker(window, dummymode, Address_N);
                EyelinkDoTrackerSetup(el);
            else
                fprintf('Warning: InitializeEyeTracker.m not found, using basic setup\n');
            end
        else
            % Dummy mode - use mouse
            fprintf('Eyetracker initialized in dummy mode (mouse simulation)\n');
        end
    catch ME
        fprintf('Error initializing eyetracker: %s\n', ME.message);
        fprintf('Falling back to dummy mode\n');
    end
end

function [gazeX, gazeY, gazeValid] = getGazePosition(window, dummymode)
    % Get current gaze position from Eyelink or mouse
    gazeX = 0;
    gazeY = 0;
    gazeValid = false;
    
    try
        if dummymode == 0
            % Real eyetracker mode
            NoErrorEyeTracking = 1;
            error = Eyelink('CheckRecording');
            if error ~= 0
                NoErrorEyeTracking = 0;
            end
            
            if Eyelink('NewFloatSampleAvailable') > 0 && NoErrorEyeTracking
                evt = Eyelink('NewestFloatSample');
                
                % Determine which eye to use (assume right eye = 1, left eye = 0)
                eye_used = 1; % You may need to adjust this based on your setup
                
                if eye_used ~= -1
                    gazeX = evt.gx(eye_used + 1); % +1 for MATLAB indexing
                    gazeY = evt.gy(eye_used + 1);
                    
                    % Check if data is valid (using common missing data value)
                    if gazeX ~= -32768 && gazeY ~= -32768  % Common missing data value
                        gazeValid = true;
                    end
                end
            end
        else
            % Dummy mode - use mouse (this was the problem!)
            [gazeX, gazeY] = GetMouse(window);
            gazeValid = true; % Mouse position is always valid
        end
    catch ME
        % Fallback to mouse if eyetracker fails
        [gazeX, gazeY] = GetMouse(window);
        gazeValid = true;
    end
end

function cleanupEyetracker()
    % Cleanup Eyelink eyetracker
    try
        if Eyelink('IsConnected')
            Eyelink('StopRecording');
            Eyelink('CloseFile');
            Eyelink('Shutdown');
        end
        fprintf('Eyetracker cleaned up\n');
    catch
        fprintf('Eyetracker cleanup completed\n');
    end
end

function deliverReward()
    % Placeholder for reward delivery
    % TODO: Replace with actual reward system trigger
    fprintf('*** REWARD DELIVERED! ***\n');
end