clear,clc
%% Initialize connection with Vicon
% Program options
% TransmitMulticast = false;
% EnableHapticFeedbackTest = false;
% HapticOnList = {'ViconAP_001';'ViconAP_002'};
% SubjectFilterApplied = false;
% bPrintSkippedFrame = false;

% Check whether these variables exist, as they can be set by the command line on launch
% If you run the script with Command Window in Matlab, these workspace vars could persist the value from previous runs even not set in the Command Window
% You could clear the value with "clearvars"
% if ~exist( 'bReadCentroids' )
%   bReadCentroids = false;
% end
%
% if ~exist( 'bReadRays' )
%   bReadRays = true;
% end
DeviceOuputsList = 10;
if ~exist( 'bTrajectoryIDs' )
    bTrajectoryIDs = false;
end

% if ~exist( 'axisMapping' )
%   axisMapping = 'ZUp';
% end

% example for running from commandline in the ComandWindow in Matlab
% e.g. bLightweightSegment = true;HostName = 'localhost:801';ViconDataStreamSDK_MATLABTest
% if ~exist('bLightweightSegment')
%   bLightweightSegment = false;
% end

% Pass the subjects to be filtered in
% e.g. Subject = {'Subject1'};HostName = 'localhost:801';ViconDataStreamSDK_MATLABTest
% EnableSubjectFilter  = exist('subjects');

% Program options
if ~exist( 'HostName' )
    HostName = 'localhost:801';
end

if exist('undefVar')
    fprintf('Undefined Variable: %s\n', mat2str( undefVar ) );
end

% fprintf( 'Centroids Enabled: %s\n', mat2str( bReadCentroids ) );
% fprintf( 'Rays Enabled: %s\n', mat2str( bReadRays ) );
fprintf( 'Trajectory IDs Enabled: %s\n', mat2str( bTrajectoryIDs ) );
% fprintf( 'Lightweight Segment Data Enabled: %s\n', mat2str( bLightweightSegment ) );
% fprintf( 'Axis Mapping: %s\n', axisMapping )

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
fprintf( 'done\n' );

% A dialog to stop the loop
% MessageBox = msgbox( 'Stop DataStream Client', 'Vicon DataStream SDK' );

% Make a new client
MyClient = ViconDataStreamSDK.DotNET.Client();

% Connect to a server
fprintf( 'Connecting to %s ...', HostName );
while ~MyClient.IsConnected().Connected
    % Direct connection
    MyClient.Connect( HostName );
    
    % Multicast connection
    % MyClient.ConnectToMulticast( HostName, '224.0.0.0' );
    
    fprintf( '.' );
end
fprintf( '\n' );

% Enable some different data types
MyClient.EnableSegmentData();
MyClient.EnableMarkerData();
MyClient.EnableUnlabeledMarkerData();
MyClient.EnableDeviceData();
% if bReadCentroids
%   MyClient.EnableCentroidData();
% end
% if bReadRays
%   MyClient.EnableMarkerRayData();
% end

% if bLightweightSegment
%   MyClient.DisableLightweightSegmentData();
%   Output_EnableLightweightSegment = MyClient.EnableLightweightSegmentData();
%   if Output_EnableLightweightSegment.Result ~= ViconDataStreamSDK.DotNET.Result.Success
%     fprintf( 'Server does not support lightweight segment data.\n' );
%   end
% end

fprintf( 'Segment Data Enabled: %s\n',          AdaptBool( MyClient.IsSegmentDataEnabled().Enabled ) );
fprintf( 'Marker Data Enabled: %s\n',           AdaptBool( MyClient.IsMarkerDataEnabled().Enabled ) );
fprintf( 'Unlabeled Marker Data Enabled: %s\n', AdaptBool( MyClient.IsUnlabeledMarkerDataEnabled().Enabled ) );
fprintf( 'Device Data Enabled: %s\n',           AdaptBool( MyClient.IsDeviceDataEnabled().Enabled ) );
fprintf( 'Centroid Data Enabled: %s\n',         AdaptBool( MyClient.IsCentroidDataEnabled().Enabled ) );
fprintf( 'Marker Ray Data Enabled: %s\n',       AdaptBool( MyClient.IsMarkerRayDataEnabled().Enabled ) );

MyClient.SetBufferSize(1)
% % Set the streaming mode
MyClient.SetStreamMode( ViconDataStreamSDK.DotNET.StreamMode.ClientPull  );
% % MyClient.SetStreamMode( StreamMode.ClientPullPreFetch );
% % MyClient.SetStreamMode( StreamMode.ServerPush );

% % Set the global up axis
% if axisMapping == 'XUp'
%   MyClient.SetAxisMapping( ViconDataStreamSDK.DotNET.Direction.Up, ...
%                            ViconDataStreamSDK.DotNET.Direction.Forward,      ...
%                            ViconDataStreamSDK.DotNET.Direction.Left ); % X-up
% elseif axisMapping == 'YUp'
%   MyClient.SetAxisMapping(  ViconDataStreamSDK.DotNET.Direction.Forward, ...
%                           ViconDataStreamSDK.DotNET.Direction.Up,    ...
%                           ViconDataStreamSDK.DotNET.Direction.Right );    % Y-up
% else
MyClient.SetAxisMapping(  ViconDataStreamSDK.DotNET.Direction.Forward, ...
    ViconDataStreamSDK.DotNET.Direction.Left,    ...
    ViconDataStreamSDK.DotNET.Direction.Up );    % Z-up
% end

% Output_GetAxisMapping = MyClient.GetAxisMapping();
% fprintf( 'Axis Mapping: X-%s Y-%s Z-%s\n', char( Output_GetAxisMapping.XAxis.ToString() ), ...
%                                            char( Output_GetAxisMapping.YAxis.ToString() ), ...
%                                            char( Output_GetAxisMapping.ZAxis.ToString() ) );

% Discover the version number
Output_GetVersion = MyClient.GetVersion();
fprintf( 'Version: %d.%d.%d\n', Output_GetVersion.Major, ...
    Output_GetVersion.Minor, ...
    Output_GetVersion.Point );

% if TransmitMulticast
%   MyClient.StartTransmittingMulticast( 'localhost', '224.0.0.0' );
% end

Frame = -1;
SkippedFrames = [];
Counter = 1;

FrameCount = []; % Empty array that will be populated in the while loop

tStart = tic;


%Get Frame
while MyClient.GetFrame().Result ~= ViconDataStreamSDK.DotNET.Result.Success
end

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
deviceValues


LabeledMarkerCount = MyClient.GetLabeledMarkerCount().MarkerCount;
tempLabeledMarkerPosition = NaN(LabeledMarkerCount,3);
for LabeledMarkerIndex = 0:typecast( LabeledMarkerCount, 'int32' ) -1
    % Get the global marker translation
    Output_GetLabeledMarkerGlobalTranslation = MyClient.GetLabeledMarkerGlobalTranslation( typecast( LabeledMarkerIndex,'uint32'));
    
    tempLabeledMarkerPosition(LabeledMarkerIndex+1,:) = [ Output_GetLabeledMarkerGlobalTranslation.Translation(1) ...
        Output_GetLabeledMarkerGlobalTranslation.Translation(2) ...
        Output_GetLabeledMarkerGlobalTranslation.Translation(3) ];
    
    ID(LabeledMarkerIndex+1,:) = Output_GetLabeledMarkerGlobalTranslation.MarkerID;
end


UnlabeledMarkerCount = MyClient.GetUnlabeledMarkerCount().MarkerCount;


for UnlabeledMarkerIndex = 0:typecast( UnlabeledMarkerCount , 'int32' )- 1
    % Get the global marker translation
    Output_GetUnlabeledMarkerGlobalTranslation = MyClient.GetUnlabeledMarkerGlobalTranslation( typecast(UnlabeledMarkerIndex,'uint32'));
    
    tempUnlabeledMarkerPosition(UnlabeledMarkerIndex+1,:) = [ Output_GetUnlabeledMarkerGlobalTranslation.Translation(1) ...
        Output_GetUnlabeledMarkerGlobalTranslation.Translation(2) ...
        Output_GetUnlabeledMarkerGlobalTranslation.Translation(3) ];
end








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
    
    % Count the number of segments
    SegmentCount = MyClient.GetSegmentCount( SubjectName ).SegmentCount;
    % Initialize Temporary Matrices
    tempSegmentStatic = struct('translation',NaN(3,1),'rotHelical',NaN(3,1),'rotMatrix',NaN(9,1),'rotQuaternion',NaN(4,1),'rotEulerXYZ',NaN(3,1));
    tempSegmentGlobal = struct('translation',NaN(3,1),'rotHelical',NaN(3,1),'rotMatrix',NaN(9,1),'rotQuaternion',NaN(4,1),'rotEulerXYZ',NaN(3,1));
    tempSegmentLocal = struct('translation',NaN(3,1),'rotHelical',NaN(3,1),'rotMatrix',NaN(9,1),'rotQuaternion',NaN(4,1),'rotEulerXYZ',NaN(3,1));
    
    for SegmentIndex = 0:typecast( SegmentCount , 'int32' )-1
        % Get the segment name
        SegmentName = MyClient.GetSegmentName( SubjectName, typecast( SegmentIndex, 'uint32') ).SegmentName;
        
        % Get the static segment translation
        Output_GetSegmentStaticTranslation = MyClient.GetSegmentStaticTranslation( SubjectName, SegmentName );
        tempSegmentStatic.translation(:,SegmentIndex+1) = [Output_GetSegmentStaticTranslation.Translation( 1 ), ...
            Output_GetSegmentStaticTranslation.Translation( 2 ), ...
            Output_GetSegmentStaticTranslation.Translation( 3 ) ];
        
        % Get the static segment rotation in helical co-ordinates
        Output_GetSegmentStaticRotationHelical = MyClient.GetSegmentStaticRotationHelical( SubjectName, SegmentName );
        tempSegmentStatic.rotHelical(:,SegmentIndex+1) = [Output_GetSegmentStaticRotationHelical.Rotation( 1 ), ...
            Output_GetSegmentStaticRotationHelical.Rotation( 2 ), ...
            Output_GetSegmentStaticRotationHelical.Rotation( 3 ) ];
        
        % Get the static segment rotation as a matrix
        Output_GetSegmentStaticRotationMatrix = MyClient.GetSegmentStaticRotationMatrix( SubjectName, SegmentName );
        tempSegmentStatic.rotMatrix(:,SegmentIndex+1) = [Output_GetSegmentStaticRotationMatrix.Rotation( 1 ),            ...
            Output_GetSegmentStaticRotationMatrix.Rotation( 2 ),            ...
            Output_GetSegmentStaticRotationMatrix.Rotation( 3 ),            ...
            Output_GetSegmentStaticRotationMatrix.Rotation( 4 ),            ...
            Output_GetSegmentStaticRotationMatrix.Rotation( 5 ),            ...
            Output_GetSegmentStaticRotationMatrix.Rotation( 6 ),            ...
            Output_GetSegmentStaticRotationMatrix.Rotation( 7 ),            ...
            Output_GetSegmentStaticRotationMatrix.Rotation( 8 ),            ...
            Output_GetSegmentStaticRotationMatrix.Rotation( 9 ) ];
        
        % Get the static segment rotation in quaternion co-ordinates
        Output_GetSegmentStaticRotationQuaternion = MyClient.GetSegmentStaticRotationQuaternion( SubjectName, SegmentName );
        tempSegmentStatic.rotQuaternion(:,SegmentIndex+1) = [Output_GetSegmentStaticRotationQuaternion.Rotation( 1 ), ...
            Output_GetSegmentStaticRotationQuaternion.Rotation( 2 ), ...
            Output_GetSegmentStaticRotationQuaternion.Rotation( 3 ), ...
            Output_GetSegmentStaticRotationQuaternion.Rotation( 4 ) ];
        
        % Get the static segment rotation in EulerXYZ co-ordinates
        Output_GetSegmentStaticRotationEulerXYZ = MyClient.GetSegmentStaticRotationEulerXYZ( SubjectName, SegmentName );
        tempSegmentStatic.rotEulerXYZ(:,SegmentIndex+1) = [Output_GetSegmentStaticRotationEulerXYZ.Rotation( 1 ),  ...
            Output_GetSegmentStaticRotationEulerXYZ.Rotation( 2 ),  ...
            Output_GetSegmentStaticRotationEulerXYZ.Rotation( 3 ) ];
        
        
        
          % Get the global segment translation
      Output_GetSegmentGlobalTranslation = MyClient.GetSegmentGlobalTranslation( SubjectName, SegmentName );
      if strcmp( AdaptBool( Output_GetSegmentGlobalTranslation.Occluded ),'False')
      
      tempSegmentGlobal.translation(:,SegmentIndex+1) = [ Output_GetSegmentGlobalTranslation.Translation( 1 ), ...
                         Output_GetSegmentGlobalTranslation.Translation( 2 ), ...
                         Output_GetSegmentGlobalTranslation.Translation( 3 )];
      end
                     
      % Get the global segment rotation in helical co-ordinates
      Output_GetSegmentGlobalRotationHelical = MyClient.GetSegmentGlobalRotationHelical( SubjectName, SegmentName );
      if strcmp( AdaptBool( Output_GetSegmentGlobalRotationHelical.Occluded ),'False')
          
      tempSegmentGlobal.rotHelical(:,SegmentIndex+1) = [Output_GetSegmentGlobalRotationHelical.Rotation( 1 ), ...
                         Output_GetSegmentGlobalRotationHelical.Rotation( 2 ), ...
                         Output_GetSegmentGlobalRotationHelical.Rotation( 3 )];
      end
                     
      
      % Get the global segment rotation as a matrix
      Output_GetSegmentGlobalRotationMatrix = MyClient.GetSegmentGlobalRotationMatrix( SubjectName, SegmentName );
      
      if strcmp( AdaptBool( Output_GetSegmentGlobalRotationMatrix.Occluded ),'False')
      tempSegmentGlobal.rotMatrix(:,SegmentIndex+1) = [ Output_GetSegmentGlobalRotationMatrix.Rotation( 1 ),...
                         Output_GetSegmentGlobalRotationMatrix.Rotation( 2 ),               ...
                         Output_GetSegmentGlobalRotationMatrix.Rotation( 3 ),               ...
                         Output_GetSegmentGlobalRotationMatrix.Rotation( 4 ),               ...
                         Output_GetSegmentGlobalRotationMatrix.Rotation( 5 ),               ...
                         Output_GetSegmentGlobalRotationMatrix.Rotation( 6 ),               ...
                         Output_GetSegmentGlobalRotationMatrix.Rotation( 7 ),               ...
                         Output_GetSegmentGlobalRotationMatrix.Rotation( 8 ),               ...
                         Output_GetSegmentGlobalRotationMatrix.Rotation( 9 )];
      end
      
      % Get the global segment rotation in quaternion co-ordinates
      Output_GetSegmentGlobalRotationQuaternion = MyClient.GetSegmentGlobalRotationQuaternion( SubjectName, SegmentName );
       if strcmp( AdaptBool( Output_GetSegmentGlobalRotationQuaternion.Occluded ),'False')
           
      tempSegmentGlobal.rotQuaterion(:,SegmentIndex+1) = [ Output_GetSegmentGlobalRotationQuaternion.Rotation( 1 ),...
                         Output_GetSegmentGlobalRotationQuaternion.Rotation( 2 ),       ...
                         Output_GetSegmentGlobalRotationQuaternion.Rotation( 3 ),       ...
                         Output_GetSegmentGlobalRotationQuaternion.Rotation( 4 )];
       end

      % Get the global segment rotation in EulerXYZ co-ordinates
      Output_GetSegmentGlobalRotationEulerXYZ = MyClient.GetSegmentGlobalRotationEulerXYZ( SubjectName, SegmentName );
       if strcmp( AdaptBool( Output_GetSegmentGlobalRotationEulerXYZ.Occluded ),'False')
      
      tempSegmentGlobal.rotEulerXYZ(:,SegmentIndex+1) = [ Output_GetSegmentGlobalRotationEulerXYZ.Rotation( 1 ),...
                         Output_GetSegmentGlobalRotationEulerXYZ.Rotation( 2 ),...
                         Output_GetSegmentGlobalRotationEulerXYZ.Rotation( 3 )];
       end
       
       
      % Get the local segment translation
      Output_GetSegmentLocalTranslation = MyClient.GetSegmentLocalTranslation( SubjectName, SegmentName );
      if strcmp( AdaptBool( Output_GetSegmentLocalTranslation.Occluded ),'False') 
      tempSegmentGlobal.translaton(:,SegmentIndex+1) = [Output_GetSegmentLocalTranslation.Translation( 1 ), ...
                         Output_GetSegmentLocalTranslation.Translation( 2 ), ...
                         Output_GetSegmentLocalTranslation.Translation( 3 )];
      end
      
      % Get the local segment rotation in helical co-ordinates
      Output_GetSegmentLocalRotationHelical = MyClient.GetSegmentLocalRotationHelical( SubjectName, SegmentName );
      if strcmp( AdaptBool( Output_GetSegmentLocalRotationHelical.Occluded ),'False')
      tempSegmentGlobal.rotHelical(:,SegmentIndex+1) = [Output_GetSegmentLocalRotationHelical.Rotation( 1 ), ...
                         Output_GetSegmentLocalRotationHelical.Rotation( 2 ), ...
                         Output_GetSegmentLocalRotationHelical.Rotation( 3 ) ];
      end
                     
      % Get the local segment rotation as a matrix
      Output_GetSegmentLocalRotationMatrix = MyClient.GetSegmentLocalRotationMatrix( SubjectName, SegmentName );
       if strcmp( AdaptBool( Output_GetSegmentLocalRotationMatrix.Occluded ),'False')
      tempSegmentGlobal.rotMatrix(:,SegmentIndex+1) = [Output_GetSegmentLocalRotationMatrix.Rotation( 1 ),               ...
                         Output_GetSegmentLocalRotationMatrix.Rotation( 2 ),               ...
                         Output_GetSegmentLocalRotationMatrix.Rotation( 3 ),               ...
                         Output_GetSegmentLocalRotationMatrix.Rotation( 4 ),               ...
                         Output_GetSegmentLocalRotationMatrix.Rotation( 5 ),               ...
                         Output_GetSegmentLocalRotationMatrix.Rotation( 6 ),               ...
                         Output_GetSegmentLocalRotationMatrix.Rotation( 7 ),               ...
                         Output_GetSegmentLocalRotationMatrix.Rotation( 8 ),               ...
                         Output_GetSegmentLocalRotationMatrix.Rotation( 9 )];
       end
       
      % Get the local segment rotation in quaternion co-ordinates
      Output_GetSegmentLocalRotationQuaternion = MyClient.GetSegmentLocalRotationQuaternion( SubjectName, SegmentName );
       if strcmp( AdaptBool( Output_GetSegmentLocalRotationQuaternion.Occluded ),'False')
      tempSegmentGlobal.rotQuaternion(:,SegmentIndex+1) = [Output_GetSegmentLocalRotationQuaternion.Rotation( 1 ),       ...
                         Output_GetSegmentLocalRotationQuaternion.Rotation( 2 ),       ...
                         Output_GetSegmentLocalRotationQuaternion.Rotation( 3 ),       ...
                         Output_GetSegmentLocalRotationQuaternion.Rotation( 4 )];
       end
      % Get the local segment rotation in EulerXYZ co-ordinates
      Output_GetSegmentLocalRotationEulerXYZ = MyClient.GetSegmentLocalRotationEulerXYZ( SubjectName, SegmentName );
       if strcmp( AdaptBool( Output_GetSegmentLocalRotationEulerXYZ.Occluded ),'False')
      tempSegmentGlobal.rotEulerXYZ(:,SegmentIndex+1) = [Output_GetSegmentLocalRotationEulerXYZ.Rotation( 1 ),       ...
                         Output_GetSegmentLocalRotationEulerXYZ.Rotation( 2 ),       ...
                         Output_GetSegmentLocalRotationEulerXYZ.Rotation( 3 )];
       end
        
    end
    
    
end

