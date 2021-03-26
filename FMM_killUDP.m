%% Function FMM_killUDP
%
%   Use Windows netstat- tool to locate process connected top remote host
%   and kill them to f-ree ports.
%
%   RemoteHost: IP address of the remote host
%   PID: process ID of the process killed, 0 if any
%
% B Caziot, July 20cmd20



function PID = FMM_killUDP(RemoteHost)

	[~,cmdout] = system('netstat -ano');
    PID = 0;
    
    lf = find(cmdout==10);  
    for ll=4:length(lf)-1
        line = cmdout(lf(ll):lf(ll+1));
        if contains(line,'UDP')
            res = textscan(line,'%s','Delimiter',' ');
            field = 0;
            for rr=1:length(res{1})
                if ~isempty(res{1}{rr})
                    field = field+1;
                    res2{field} = res{1}{rr};
                end
            end
            if contains(res2{2},RemoteHost)
                PID = res2{4};
                system(sprintf('taskkill -pid %i /f',str2double(PID)));
            end
        end
    end


end