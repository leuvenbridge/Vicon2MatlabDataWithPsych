%% Training task for FMM
%
% written by B. Caziot, February 2020


clearvars
close all
clc


Screen('Preference', 'Verbosity', 0);   % Sueppress all warnings
PsychDefaultSetup(1);                   % Unify keys


%% Set parameters
dataRoot = 'D:/behavior/';

serialPort = 'COM3';
serialBaudrate = 19200;
buttonThreshold = 5;
rewardDur = 0.1;


%% Set feedback sounds
sndSampFreq = 44100;
sndDur = 0.2;
sndFadeDur = 0.02;
sndFreq1 = 440;
sndFreq2 = 220;

sndSamples = sndDur*sndSampFreq;
sndFadeSamples = sndFadeDur*sndSampFreq;
sndPlateauSamples = sndSamples-2*sndFadeSamples;

sndSine1 = sin((1/sndSampFreq:1/sndSampFreq:sndDur)*2*pi*sndFreq1);
sndSine2 = sin((1/sndSampFreq:1/sndSampFreq:sndDur)*2*pi*sndFreq2);
sndWindow = [sin(linspace(0,pi/2,sndFadeSamples)).^2,ones(1,sndPlateauSamples),cos(linspace(0,pi/2,sndFadeSamples)).^2];


%% Initialize connection with arduino
% close unwanted serial connections
instrList = instrfind;
for ii=1:length(instrList)
    if strcmp(instrList(ii).Status,'open')
        fprintf('Closing connection with %s\n', instrList(ii).Name);
        fclose(instrList(ii));
        delete(instrList(ii));
    end
end

fprintf('Opening serial port .. ');
sid = serial(serialPort,'BaudRate',serialBaudrate);
fopen(sid);
if ~strcmp(sid.Status,'open')
    error('Failed to establish connection with arduino');
end
pause(1);
fprintf('done\n');

% Flush the buffer
while sid.BytesAvailable>0
    fprintf('Flushing: %s',fread(sid));
end



%% Initialize connection with Vicon
dataAcqFps = 10;

% Devices list
DeviceNumber = 1;
DeviceOuputsList = [3];
DeviceOuputSamples = 10;

deviceColors = lines(sum(DeviceOuputsList));

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

% Get the frame rate
Output_GetFrameRate = MyClient.GetFrameRate();
fprintf('Frame rate: %g\n', Output_GetFrameRate.FrameRateHz);

% for FrameRateIndex = 1:MyClient.GetFrameRateCount().Count
%     FrameRateName  = MyClient.GetFrameRateName(FrameRateIndex).Name;
%     FrameRateValue = MyClient.GetFrameRateValue(FrameRateName).Value;
%
%     fprintf('%s: %gHz\n', FrameRateName, FrameRateValue);
% end
% fprintf( '\n' );
%
% % Get the timecode
% Output_GetTimecode = MyClient.GetTimecode();
% fprintf( 'Timecode: %dh %dm %ds %df %dsf %s %d %d %d\n\n',    ...
%                  Output_GetTimecode.Hours,                  ...
%                  Output_GetTimecode.Minutes,                ...
%                  Output_GetTimecode.Seconds,                ...
%                  Output_GetTimecode.Frames,                 ...
%                  Output_GetTimecode.SubFrame,               ...
%                  AdaptBool( Output_GetTimecode.FieldFlag ), ...
%                  Output_GetTimecode.Standard.Value,         ...
%                  Output_GetTimecode.SubFramesPerFrame,      ...
%                  Output_GetTimecode.UserBits );

% Get the latency
fprintf( 'Latency: %gs\n', MyClient.GetLatencyTotal().Total );

for LatencySampleIndex = 1:MyClient.GetLatencySampleCount().Count
    SampleName  = MyClient.GetLatencySampleName( LatencySampleIndex ).Name;
    SampleValue = MyClient.GetLatencySampleValue( SampleName ).Value;
    
    fprintf( '  %s %gs\n', SampleName, SampleValue );
end
fprintf( '\n' );



Counter = 0;
stop = 0;
lastSent = zeros(3,1);
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
    
    allFrameTimes(Counter) = GetSecs;
    allDeviceValues(:,Counter) = deviceValues;
    
    % check button press
    for box=1:3
        if (allDeviceValues(box,end)<buttonThreshold) && ((GetSecs-lastSent(box))>0.9*rewardDur)
            
            command = sprintf('%i-%.5i-00000/',box,round(rewardDur*1000));
            fprintf(sid,command);
            fprintf("%2.2f - %s\n",GetSecs-lastSent(box),command);
            lastSent(box) = GetSecs;
            
        end
    end
    
    % Check arduino
    cc=0;
    if sid.BytesAvailable>0
        while sid.BytesAvailable>0
            cc=cc+1;
            data(cc) = fread(sid,1);
        end
        fprintf('Received: %s\n',data);
    end
    
    
    
    [kp,~,kc] = KbCheck;
    if kc(KbName('ESCAPE'))
        stop = 1;
    end
    
end

fclose(sid);