%% Training task for FMM
%
%   Includes communication with display computer for visual displays.
%
% B. Caziot, July 2020
%  - 08/11/20 added different rewards
%  - 09/03/20 added switch to blue for errors
%  - 10/03/20 added conflicts
%  - 10/06/20 update schedule at all presses
%  - 12/03/20 added option not to plot data and run local for debugging
% P. Alefantis
%  - 13/03/21 Adapted Code to Vicon DataStream SDK 1.11.0
%  - 14/03/21 marker data added

clearvars
close all
clc


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                     %
%    BELOW ARE PARAMETERS TO CHANGE ON EVERY BLOCK    %
%                                                     %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% START DISPLAY COMPUTER FIRST

% Reward rates at each box:
% A: 10 20 30
% B: 20 30 10
% C: 30 10 20
% D: 10 30 20
% E: 20 10 30
% F: 30 20 10

% Schedules:
% When only 2 types of blocks, permute ABC for high noise blocks and DEF
% for low noise blocks. All possible permutations below:
% ABC, ACB, BAC, BCA, CAB, CBA
% DEF, DFE, EDF, DFE, FED, FDE
% Possible values for Kappa:
% Alternate High noise / Low noise (0.01/0.1).



scheduleMeans = [10;20;30];             % schedules for all blocks (column vector)
boxKappa = 1;                         	% noise level (stim concentration)
rewardDur = 300;                    	% reward duration in ms
rewardFactor = [1.2;1.0;1.0];         	% different durations
rewardGap = 0;                        % time between button press and reward in ms

conflictsRatio = 0;                	% Fraction of conflicting schedules(Fraction of trials)
conflictsStd = 0;                    	% Std of conflicts


% Tags
plotDevices = 0;            % Plot Vicon devices data, makes loop very slow
local = 1;                  % does not establish connection with display computer
verbose = 0;                % display received and sent messages
displayAvail = 0;           % 0=probability, 1=availability
unloadVicon = 0;            % unload vicon SDK when quiting

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                     %
% THAT'S IT, NO NEED TO CHANGE THE REST OF THE SCRIPT %
%                                                     %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Other parameters
dataRoot = 'D:/behavior/';

buttonThreshold = 5;        % 5V
buttonRebound = 0.25;       % 0.25 sec
skipCycles = 10;          	% number of cycles to skip when starting

boxAlpha = [1;1;1];     	% temporal weighting

serialPort = 'COM3';
serialBaudrate = 19200;

ipVicon = '128.128.1.10';
ipDisplay = '128.128.1.11';
portViconDisplay = 19690;
portDisplayVicon = 19790;
paramTxtFormat = 'Box %i: lambda=%f, kappa=%f, alpha=%f';
packetTxtFormat = 'Box %i: request packet %i';
startTxtFormat = 'Start';
sleepTxtFormat = 'Sleep';

%% Vicon parameters
% Devices list
DeviceNumber = 1;           % number of devices
DeviceOuputsList = [10];    % number of outputs per device
DeviceOuputSamples = 10;
deviceColors = lines(DeviceOuputsList);
plotDuration = 60;
% Program options
HostName = 'localhost:801';


%% Set variables
buttonSchedule = zeros(3,1);
lastPress = zeros(3,1);
lastReward = zeros(3,1);
isPressed = zeros(3,1);
wasPressed = zeros(3,1);
rewardsNumber = zeros(3,1);

% check variablew sizes
if size(scheduleMeans,1)<3
    scheduleMeans = scheduleMeans';
end
if length(boxKappa)==1
    boxKappa = boxKappa*ones(3,1);
end
if length(boxAlpha)==1
    boxAlpha = boxAlpha*ones(3,1);
end

fprintf('Randomized schedules: %2.2f, %2.2f, %2.2f\n',...
    scheduleMeans(1),scheduleMeans(2),scheduleMeans(3));    % Display schedules
fprintf('Stimulus kappa: %2.2f\n',...
    boxKappa); 	% Stim concentration
fprintf('Stimulus alpha: %2.2f\n',...
    boxAlpha); 	% Stim temporal weighting



%% Set data file
fprintf('\nOpen data file .. ');
monkey = input('Monkey? ','s');

timeBegin = clock;
fileName = sprintf('%s%s_%.4i-%.2i-%.2i_%.2i-%.2i-%.2i',dataRoot,monkey,timeBegin(1),timeBegin(2),timeBegin(3),timeBegin(4),timeBegin(5),round(timeBegin(6)));
if ~exist(sprintf('%s.beh',fileName),'file')
    fidLog = fopen(sprintf('%s.beh',fileName),'w');
    fidDat = fopen(sprintf('%s.dat',fileName),'w');
    if ~(fidLog>0) || ~(fidDat>0)
        error('Invalid file name');
    end
else
    error('File already exists');
end
fprintf(fidLog,'Script name: %s\n',mfilename);                          % Print script name
fprintf(fidLog,'Monkey name: %s\n',monkey);                             % Print monkey name
fprintf(fidLog,'Date: %s\n',datestr(timeBegin),'yyyy-mm-dd_HH-MM-SS');	% Print date
fprintf(fidLog,'Schedules: %f, %f, %f\n',...
    scheduleMeans(1), scheduleMeans(2), scheduleMeans(3));          	% Print schedules
fprintf(fidLog,'Stimulus kappa: %2.2f\n',...
    boxKappa(1), boxKappa(2),boxKappa(3));                              % Stim concentration
fprintf(fidLog,'Stimulus alpha: %2.2f\n',...
    boxAlpha(1), boxAlpha(2), boxAlpha(3));                          	% Stim temporal weighting
fprintf(fidLog,'################\n');
fprintf('done\n');


%% Close previous connections
fprintf('\nCleaning up connections\n');
instrList = instrfindall;
for ii=1:length(instrList)
    if strcmp(instrList(ii).Status,'open')
        fprintf('Closing connection with %s\n', instrList(ii).Name);
        fclose(instrList(ii));
    end
    fprintf('Deleting %s\n', instrList(ii).Name);
    delete(instrList(ii));
end
instrreset;


%% Initialize connection with display computer
if ~local
    fprintf('\nInitiating connection with display computer\n');
    udpViconDisplay = udp(ipDisplay,portViconDisplay,'LocalHost',ipVicon,'LocalPort',portViconDisplay);
    udpDisplayVicon = udp(ipDisplay,portDisplayVicon,'LocalHost',ipVicon,'LocalPort',portDisplayVicon);
    while 1
        try
            fopen(udpViconDisplay);
            fopen(udpDisplayVicon);
            break;
        catch
            fprintf('Failed to open port, will try to kill processes using it\n');
            PID = FMM_killUDP(ipVicon);
            fprintf('Killed process ID: %i\n',PID);
        end
    end
    
    if ~local
        while udpDisplayVicon.BytesAvailable
            tmp = fread(udpDisplayVicon);
            fprintf('Purging UDP buffer: %s',char(tmp'));
        end
        flushinput(udpDisplayVicon);
        fprintf('Waiting for handshake');
        handshake = 'Initiate connection';
        sentHandshake = 0;
        while 1
            if (GetSecs-sentHandshake)>1
                fprintf(' .');
                fprintf(udpViconDisplay,handshake);
                sentHandshake = GetSecs;
            end
            if udpDisplayVicon.BytesAvailable
                line = char(fread(udpDisplayVicon)');
                if contains(line,handshake)
                    fprintf('\n');
                    fprintf(line);
                    break
                else
                    fprintf('Wrong handshake received: %s\n',line);
                end
            end
        end
        fprintf(udpViconDisplay,sprintf('%s\n',startTxtFormat));
    end
    for bb=1:3
        line = sprintf(paramTxtFormat,bb,0,boxKappa,boxAlpha);
        fprintf(udpViconDisplay,line);
    end
end


%% Initialize connection with arduino
% Open port
fprintf('Initialize connection with Arduino\n');
fprintf('Opening serial port . . . ');
sid = serial(serialPort,'BaudRate',serialBaudrate);
fopen(sid);
if ~strcmp(sid.Status,'open')
    error('Failed to establish connection with arduino');
end
pause(0.1);
fprintf('done\n');

% Flush the buffer
while sid.BytesAvailable>0
    fprintf('Flushing: %s\n',fread(sid));
end



%% Initialize connection with Vicon
fprintf('\nInitialize connection with Vicon\n');


if ~exist( 'HostName' )
    HostName = 'localhost:801';
end

if exist('undefVar')
    fprintf('Undefined Variable: %s\n', mat2str( undefVar ) );
end


% Load the SDK
fprintf( 'Loading SDK...' );
addpath( 'C:\Program Files\Vicon\DataStream SDK\Win64\dotNET' );
dssdkAssembly = which('ViconDataStreamSDK_DotNET.dll');
if dssdkAssembly == ""
    [ file, path ] = uigetfile( '*.dll' );
    if isequal( file, 0 )
        fprintf( 'User canceled' );
        return;
    else
        dssdkAssembly = fullfile( path, file );
    end
end

NET.addAssembly(dssdkAssembly);


% Make a new client
MyClient = ViconDataStreamSDK.DotNET.Client();

% Connect to a server
fprintf( 'Connecting to %s ...\n', HostName );
while ~MyClient.IsConnected().Connected
    MyClient.Connect( HostName );
end


% Enable some different data types
MyClient.EnableSegmentData();
MyClient.EnableMarkerData();
MyClient.EnableUnlabeledMarkerData();
MyClient.EnableDeviceData();


fprintf( 'Segment Data Enabled: %s\n',          AdaptBool( MyClient.IsSegmentDataEnabled().Enabled ) );
fprintf( 'Marker Data Enabled: %s\n',           AdaptBool( MyClient.IsMarkerDataEnabled().Enabled ) );
fprintf( 'Unlabeled Marker Data Enabled: %s\n', AdaptBool( MyClient.IsUnlabeledMarkerDataEnabled().Enabled ) );
fprintf( 'Device Data Enabled: %s\n',           AdaptBool( MyClient.IsDeviceDataEnabled().Enabled ) );

MyClient.SetBufferSize(1)
% Set the streaming mode
MyClient.SetStreamMode( ViconDataStreamSDK.DotNET.StreamMode.ClientPull  );

% Set the global up axis
MyClient.SetAxisMapping(  ViconDataStreamSDK.DotNET.Direction.Forward, ...
    ViconDataStreamSDK.DotNET.Direction.Left,    ...
    ViconDataStreamSDK.DotNET.Direction.Up );    % Z-up


% Open figure to plot data
if plotDevices
    fhViconDevices = figure('Name','Vicon devices');
    devicesNames = cell(length(DeviceNumber));
    for DeviceIndex = 1:DeviceNumber
        devicesNames{DeviceIndex} = cell(DeviceOuputsList(DeviceIndex));
        Output_GetDeviceName = MyClient.GetDeviceName(DeviceIndex);
        for DeviceOutputIndex = 1:DeviceOuputsList(DeviceIndex)
            Output_GetDeviceOutputName = MyClient.GetDeviceOutputName( Output_GetDeviceName.DeviceName, DeviceOutputIndex );
            devicesNames{DeviceIndex}{DeviceOutputIndex} = Output_GetDeviceOutputName
        end
    end
    channelsName = {'But1','But2','But3','Rew1','Rew2','Rew3','Eye1','Eye2','Eye3','Pulse'};
end


%% Unify keynames
KbName('UnifyKeyNames');


%% Main loop
fprintf('Starting experiment\n');
timeStart = clock;      % Starting time including date
timeStartSec = GetSecs; % Starting time in seconds
currentSchedules = scheduleMeans;
Counter = 0;
stop = 0;
requestedPackets = zeros(3,1);
sentPackets = zeros(3,1);
for box=1:3
    lastPress(box) = GetSecs;
    buttonSchedule(box) = min(exprnd(scheduleMeans(box)),scheduleMeans(box)*2);
end



while ~stop
    Counter = Counter + 1;
    cycleTimes(Counter) = GetSecs;
    
    %% Get Data From Vicon
    %Get Frame
    while MyClient.GetFrame().Result ~= ViconDataStreamSDK.DotNET.Result.Success
    end
    
    % Get the frame number
    Output_GetFrameNumber = MyClient.GetFrameNumber();
    lastFrameTime = MyClient.GetTimecode();
    
    %If doesn't find device, get a new frame and try again
    while MyClient.GetDeviceCount().DeviceCount == 0
        while MyClient.GetFrame().Result ~= ViconDataStreamSDK.DotNET.Result.Success
        end
    end
    
    DeviceCount = MyClient.GetDeviceCount().DeviceCount;
    
    for DeviceIndex = 0:typecast( DeviceCount, 'int32' ) - 1
        % Get the device name and type
        Output_GetDeviceName = MyClient.GetDeviceName( typecast( DeviceIndex, 'uint32' ) );
        
        % Count the number of device outputs
        DeviceOutputCount = MyClient.GetDeviceOutputCount( Output_GetDeviceName.DeviceName ).DeviceOutputCount;
        
        deviceValues = NaN(numel(0:typecast( DeviceOutputCount, 'int32' )-1),1);
        for DeviceOutputIndex = 0:typecast( DeviceOutputCount, 'int32' ) - 1
            % Get the device output name and unit
            Output_GetDeviceOutputComponentName = MyClient.GetDeviceOutputComponentName( Output_GetDeviceName.DeviceName, typecast( DeviceOutputIndex, 'uint32') );
            
            % Get the number of subsamples associated with this device.
            Output_GetDeviceOutputSubsamples = MyClient.GetDeviceOutputSubsamples( Output_GetDeviceName.DeviceName, Output_GetDeviceOutputComponentName.DeviceOutputName, Output_GetDeviceOutputComponentName.DeviceOutputComponentName ).DeviceOutputSubsamples;
            
            subSamples = NaN(1,numel(0:typecast( Output_GetDeviceOutputSubsamples, 'int32' )-1));
            for DeviceOutputSubsample = 0:typecast( Output_GetDeviceOutputSubsamples, 'int32' )-1
                % Get the device output value
                Output_GetDeviceOutputValue = MyClient.GetDeviceOutputValue( Output_GetDeviceName.DeviceName, Output_GetDeviceOutputComponentName.DeviceOutputName, Output_GetDeviceOutputComponentName.DeviceOutputComponentName, typecast( DeviceOutputSubsample, 'uint32' ) );
                subSamples(DeviceOutputSubsample+1) = Output_GetDeviceOutputValue.Value;
            end
            deviceValues(DeviceOutputIndex+1,1) = mean(subSamples);
        end
    end
    
    %Get Marker Position
    SubjectCount = MyClient.GetSubjectCount().SubjectCount;
    for SubjectIndex = 0:typecast( SubjectCount, 'int32' ) -1
        SubjectName = MyClient.GetSubjectName( typecast( SubjectIndex, 'uint32') ).SubjectName;
        MarkerCount = MyClient.GetMarkerCount( SubjectName ).MarkerCount;
        
        tempMarkerPosition = NaN(MarkerCount,3);
        for MarkerIndex = 0:typecast( MarkerCount, 'int32' )-1
            
            % Get the marker name
            MarkerName = MyClient.GetMarkerName( SubjectName, typecast( MarkerIndex,'uint32') ).MarkerName;
            markerNames(MarkerIndex+1) = string(MarkerName);
            % Get the global marker translation
            Output_GetMarkerGlobalTranslation = MyClient.GetMarkerGlobalTranslation( SubjectName, MarkerName );
            % Get the marker name
            
            if strcmp(AdaptBool( Output_GetMarkerGlobalTranslation.Occluded),'False')
                tempMarkerPosition(MarkerIndex+1,:) = [ Output_GetMarkerGlobalTranslation.Translation(1) ...
                    Output_GetMarkerGlobalTranslation.Translation(2) ...
                    Output_GetMarkerGlobalTranslation.Translation(3) ];
            end
            
        end
    end
    
    
    % Get Labeled Marker Position
    LabeledMarkerCount = MyClient.GetLabeledMarkerCount().MarkerCount;
    tempLabeledMarkerPosition = NaN(LabeledMarkerCount,3);
    for LabeledMarkerIndex = 0:typecast( LabeledMarkerCount, 'int32' ) -1
        % Get the global marker translation
        Output_GetLabeledMarkerGlobalTranslation = MyClient.GetLabeledMarkerGlobalTranslation( typecast( LabeledMarkerIndex,'uint32') );
        
        tempLabeledMarkerPosition(LabeledMarkerIndex+1,:) = [ Output_GetLabeledMarkerGlobalTranslation.Translation(1) ...
            Output_GetLabeledMarkerGlobalTranslation.Translation(2) ...
            Output_GetLabeledMarkerGlobalTranslation.Translation(3) ];
        
    end
    
    % Get Unlabeled Marker Position
    UnlabeledMarkerCount = MyClient.GetUnlabeledMarkerCount().MarkerCount;
    tempUnlabeledMarkerPosition = NaN(UnlabeledMarkerCount,3);
    for UnlabeledMarkerIndex = 0:typecast( UnlabeledMarkerCount , 'int32' )- 1
        % Get the global marker translation
        Output_GetUnlabeledMarkerGlobalTranslation = MyClient.GetUnlabeledMarkerGlobalTranslation( typecast(UnlabeledMarkerIndex,'uint32'));
        
        tempUnlabeledMarkerPosition(UnlabeledMarkerIndex+1,:) = [ Output_GetUnlabeledMarkerGlobalTranslation.Translation(1) ...
            Output_GetUnlabeledMarkerGlobalTranslation.Translation(2) ...
            Output_GetUnlabeledMarkerGlobalTranslation.Translation(3) ];
    end
    
    
    
    % Save data per frame
    
    allFrameTimes(Counter) = GetSecs;
    markerPosition(:,:,Counter )= tempMarkerPosition;
    labeledMarkerPosition(Counter )= {tempLabeledMarkerPosition};
    unlabeledMarkerPosition(Counter )= {tempUnlabeledMarkerPosition};
    allDeviceValues(:,Counter) = deviceValues;
    availValues(:,Counter) = (allFrameTimes(end)-lastReward)>buttonSchedule;
    lambdaTrueValues(:,Counter) = 1-exp(-(cycleTimes(Counter)-lastPress)./scheduleMeans);
    lambdaVisualValues(:,Counter) = 1-exp(-(cycleTimes(Counter)-lastPress)./currentSchedules);
    kappaValues(:,Counter) = boxKappa;
    alphaValues(:,Counter) = boxAlpha;
    
    for bb=1:3
        fprintf(fidDat,'%f - box%i - button %f, lambdaT %f, lambdaV %f, kappa %f, alpha %f, avail %i\n',allFrameTimes(Counter),bb,allDeviceValues(bb,Counter),lambdaTrueValues(bb,Counter),lambdaVisualValues(bb,Counter),kappaValues(bb,Counter),alphaValues(bb,Counter),availValues(bb,Counter));
    end
    
    %% check button press
    for box=1:3
        if (allDeviceValues(box,end)<buttonThreshold) && (Counter>skipCycles)
            if ~isPressed(box)
                if (allFrameTimes(end)-lastPress(box))>buttonRebound
                    fprintf(fidLog,'Box %i, time %.3f, ',box, allFrameTimes(end));
                    fprintf('Box %i, time %.3f, ',box, allFrameTimes(end));
                    if (allFrameTimes(end)-lastPress(box))>buttonSchedule(box)
                        if ~local
                            fprintf(udpViconDisplay,'Feedback 1\n');
                        end
                        fprintf(fidLog,'correct\n');
                        fprintf('correct\n');
                        
                        rewardsNumber(box) = rewardsNumber(box)+1;
                        fprintf('Rewards: %i (%i,%i,%i)\n',sum(rewardsNumber),rewardsNumber(1),rewardsNumber(2),rewardsNumber(3));
                        
                        command = sprintf('%i-%.5i-%.5i\n',box,rewardDur*rewardFactor(box),rewardGap);
                        fprintf(fidLog,'Sending: %s',command);
                        if (verbose==1)
                            fprintf('Sending: %s',command);
                        end
                        fprintf(sid,command);
                        
                        buttonSchedule(box) = min(exprnd(scheduleMeans(box)),scheduleMeans(box)*4);
                        lastReward = allFrameTimes(end);
                    else
                        if ~local
                            fprintf(udpViconDisplay,'Feedback 0\n');
                        end
                        fprintf(fidLog,'incorrect\n');
                        fprintf('incorrect\n');
                    end
                    
                    lastPress(box) = allFrameTimes(end);
                    if rand<conflictsRatio
                        currentSchedules(box) = scheduleMeans(box)+sign(rand-0.5)*conflictsStd;
                    else
                        currentSchedules(box) = scheduleMeans(box);
                    end
                    
                    fprintf(fidLog,'Box %i, time %.3f, scheduleV %2.3f, next reward %2.3f\n', box, allFrameTimes(end), currentSchedules(box), buttonSchedule(box));
                    fprintf('Box %i, time %.3f, scheduleV %2.3f, next reward %2.3f\n', box, allFrameTimes(end), currentSchedules(box), buttonSchedule(box));
                end
                isPressed(box) = 1;
            end
        else
            isPressed(box) = 0;
        end
    end
    
    
    %%  Check Arduino
    cc=0;
    if sid.BytesAvailable>0
        while sid.BytesAvailable>0
            cc=cc+1;
            data(cc) = fread(sid,1);
        end
        fprintf(fidLog,'Received: %s\n',data);
        if (verbose==1)
            fprintf('Received: %s\n',data);
        end
        vec = sscanf(char(data),'%d-%d-%d');
        fprintf('Reward delivered: %ims at box %i\n',vec(2),vec(1));
    end
    
    if plotDevices
        figure(fhViconDevices)
        plot(allFrameTimes(end)-[plotDuration,0]-timeStartSec,repmat((0:(DeviceOuputsList-1))*20+10,2,1),'k:',...
            allFrameTimes(allFrameTimes>(allFrameTimes(end)-plotDuration))-timeStartSec,allDeviceValues(1:DeviceOuputsList,allFrameTimes>(allFrameTimes(end)-plotDuration))+repmat(20*(0:DeviceOuputsList-1)'+10,1,sum(allFrameTimes>(allFrameTimes(end)-plotDuration)))                );
        axis([allFrameTimes(end)-plotDuration-timeStartSec,allFrameTimes(end)-timeStartSec,-1,+20*DeviceOuputsList+1]);
        xlabel('Time since start (sec)')
        xticks(0:10:plotDuration);
        yticks(10+20*(0:DeviceOuputsList-1));
        yticklabels(channelsName)
    end
    
    %% Send parameters to display computer
    if ~local
        while udpDisplayVicon.BytesAvailable
            try
                lineReceived = char(fread(udpDisplayVicon)');
                vec = sscanf(lineReceived,packetTxtFormat);
                if ~displayAvail
                    lineSent = sprintf(paramTxtFormat,vec(1),lambdaVisualValues(vec(1),Counter),kappaValues(vec(1),Counter),alphaValues(vec(1),Counter));
                else
                    lineSent = sprintf(paramTxtFormat,vec(1),availValues(vec(1),Counter),kappaValues(vec(1),Counter),alphaValues(vec(1),Counter));
                end
                fprintf(udpViconDisplay,lineSent);
                requestedPackets(vec(1)) = vec(2);
                sentPackets(vec(1)) = sentPackets(vec(1))+1;
                if (verbose==1)
                    fprintf('Packets sent/requested: ');
                    for bb=1:3
                        fprintf('%i/%i', sentPackets(vec(1)) , requestedPackets(vec(1)));
                        if (bb<3); fprintf(' , '); else; fprintf('\n'); end
                    end
                end
            catch
                fprintf('Did not parse packet correctly: %s\n',lineReceived);
            end
        end
    end
    
    
    
    [kp,~,kc] = KbCheck;
    if kc(KbName('ESCAPE'))
        stop = 1;
    end
    
    if (verbose==1) && (length(allFrameTimes)>1)
        fprintf('Time since last cycle: %2.2fms\n',1000*(allFrameTimes(end)-allFrameTimes(end-1)));
    end
end

timeStop = clock;
timeStopSec = GetSecs;

save(fileName);


fprintf('\nExperiment ended at %i:%i:%i\n', timeStop(4),timeStop(5),round(timeStop(6)));
fprintf('Total duration %s\n', datetime(timeStop)-datetime(timeBegin));
fprintf('Data saved as %s\n', fileName);

fclose(fidLog);
fclose(fidDat);
fclose(sid);

if (stop==1)
    if ~local
        fprintf(udpViconDisplay,sleepTxtFormat);
        fprintf('Sent sleeping command\n');
        fprintf('Waiting for handshake .');
        lastSent = GetSecs;
        while 1
            if udpDisplayVicon.BytesAvailable
                line = char(fread(udpDisplayVicon)');
                if contains(line,sleepTxtFormat)
                    break
                end
            elseif (GetSecs-lastSent)>1
                fprintf(udpViconDisplay,sleepTxtFormat);
                fprintf(' .');
                lastSent = GetSecs;
            end
        end
        fprintf(' done\n');
    end
end
fprintf('Dipslay computer sleeping\n');

if ~local
    fprintf('Close UDP connections . . . ');
    fclose(udpViconDisplay);
    delete(udpViconDisplay);
    fclose(udpDisplayVicon);
    delete(udpDisplayVicon);
    fprintf('done\n');
end

fprintf('End Vicon connection . . . ');
MyClient.Disconnect();
if unloadVicon
    MyClient.UnloadViconDataStreamSDK();
end
fprintf('done\n');

close all
% clearvars
% clc