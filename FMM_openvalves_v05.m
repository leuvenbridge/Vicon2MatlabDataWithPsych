  
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

% Load SDK
fprintf('Loading SDK...');
Client.LoadViconDataStreamSDK();
fprintf('Done\n');

% Program options
HostName = 'localhost:801';

% Make a new client
MyClient = Client();

% Connect to a server
fprintf('Connecting to %s ...', HostName);
while ~MyClient.IsConnected().Connected
  % Direct connection
  MyClient.Connect(HostName);
  fprintf( '.' );
end
fprintf( '\n' );

% Enable some different data types
MyClient.EnableDeviceData();
fprintf('Device Data Enabled: %s\n', AdaptBool(MyClient.IsDeviceDataEnabled().Enabled));

% Set the streaming mode
MyClient.SetStreamMode(StreamMode.ClientPull);

% Get the frame rate
Output_GetFrameRate = MyClient.GetFrameRate();
fprintf('Frame rate: %g\n', Output_GetFrameRate.FrameRateHz);

for FrameRateIndex = 1:MyClient.GetFrameRateCount().Count
    FrameRateName  = MyClient.GetFrameRateName(FrameRateIndex).Name;
    FrameRateValue = MyClient.GetFrameRateValue(FrameRateName).Value;

    fprintf('%s: %gHz\n', FrameRateName, FrameRateValue);
end
fprintf( '\n' );

% Get the timecode
Output_GetTimecode = MyClient.GetTimecode();
fprintf( 'Timecode: %dh %dm %ds %df %dsf %s %d %d %d\n\n',    ...
                 Output_GetTimecode.Hours,                  ...
                 Output_GetTimecode.Minutes,                ...
                 Output_GetTimecode.Seconds,                ...
                 Output_GetTimecode.Frames,                 ...
                 Output_GetTimecode.SubFrame,               ...
                 AdaptBool( Output_GetTimecode.FieldFlag ), ...
                 Output_GetTimecode.Standard.Value,         ...
                 Output_GetTimecode.SubFramesPerFrame,      ...
                 Output_GetTimecode.UserBits );

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
    
    
    % Get a frame
    while MyClient.GetFrame().Result.Value~=Result.Success
    end

    
    % Get the frame number
    Output_GetFrameNumber = MyClient.GetFrameNumber();
    lastFrameTime = MyClient.GetTimecode();
    
    for DeviceIndex = 1:DeviceNumber
        
        Output_GetDeviceName = MyClient.GetDeviceName(DeviceIndex);
         
        deviceValues = NaN(DeviceOuputsList(DeviceIndex),1);
        for DeviceOutputIndex = 1:DeviceOuputsList(DeviceIndex)
            
            Output_GetDeviceOutputName = MyClient.GetDeviceOutputName( Output_GetDeviceName.DeviceName, DeviceOutputIndex );
            Output_GetDeviceOutputSubsamples = MyClient.GetDeviceOutputSubsamples( Output_GetDeviceName.DeviceName, Output_GetDeviceOutputName.DeviceOutputName );
            DeviceOutputCount = MyClient.GetDeviceOutputCount( Output_GetDeviceName.DeviceName ).DeviceOutputCount;
            
            Output_GetDeviceOutputValue = MyClient.GetDeviceOutputValue(Output_GetDeviceName.DeviceName, Output_GetDeviceOutputName.DeviceOutputName, DeviceOuputSamples);
             
            deviceValues(DeviceOutputIndex) = Output_GetDeviceOutputValue.Value;
            
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
 
    end
    
    [kp,~,kc] = KbCheck;
    if kc(KbName('ESCAPE'))
        stop = 1;
    end
    
end

fclose(sid);




