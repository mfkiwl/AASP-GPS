function [signal] = genSatSignal(currSat, settings,...
        points, CAtable, NAVtable, Ptable)
%receiver
% INPUTS:   sat         - is the current satellite;
%           options     - the settings data structure
%           CAtable     - CA look-up table for the satellite
%           NAVtable    - Navigation data look-up table for the satellite
%           Ptable      - P(y) code look-up table for the satellite
% OUTPUTS:  signal      - formed section of signal outputed from this satellite 

%% clocks/counters initial settings =======================================
% the carrier freq is about 1.5 GHz, the fastest clock; but there's no need
% to generate it and since it demands lots of memory; 
fprintf('. ')
%masterCont = 1; % global counter, "the Carrier clock" 
if(currSat.CodPhase < 19 && currSat.CodPhase > 9)
    chip = 1;
elseif currSat.CodPhase <= 9 && currSat.CodPhase > 0;
    chip = 1023;
else
    chip = round(currSat.CodPhase*settings.codeLength/...
    (settings.samplingFreq*(settings.codeLength/settings.codeFreqBasis)));
end
contP = (1024 - chip)*10; %10.23MHz P Code Clock Counter: 1 inc = 154 masterCont
contCA = 1024 - chip; %1.023MHz C/A Code Clock Counter: 1 inc = 10 ContP10_23Mhz
clockNAV50 = 1; %50Hz NavCode Clock: 1 inc = 10230 ContP10_23Mhz
contNAV = 1; % NavMessage Counter                             

%% Carriers generation ====================================================
% Frequency off-set
freq = (settings.satL1freq + currSat.FreqOffSet);
%freq = (set.IF + currSat.DoppErr);
carrSin = zeros(1,points);
carrCos = zeros(1,points);

time = 0:1/(settings.nyquistGapgen*freq):...
    (0.001*settings.nrMSgen - 1/(settings.nyquistGapgen*freq));

samptime = 0:1:(points-1);
%samptime = samptime/(set.nyquistGapgen*set.samplingFreq); %sampling points of generation
samptime = samptime/settings.samplingFreq;
sample = 1;

%% Doppler shift rate
%by now no rate, just difference

%% Signal Formation, as GNSS book Appendix B ==============================
fprintf('. |')
ref = 154*settings.nyquistGapgen; %Pcode basis = 154 clocks of carrier
% and 1000 beacause of the ms base
TIME = length(time);
marker250us = fix(TIME/(settings.nrMSgen*4));
marker1ms = 4*marker250us;

for now = 1:TIME
    % BPSK itself trough look-up tables
    if( time(now) >= samptime(sample) ) % comparision of generation time with sampling time
        % cossine signal formation
        carrCos(sample) = CAtable(contCA)*NAVtable(contNAV);
        % sine signal formation
        carrSin(sample) = Ptable(contP)*NAVtable(contNAV);
        if (sample < points) 
            sample = sample+1; %... it extrapolates index, so I ignored...
        else
            fprintf('|')
            break;
        end %if(sample < points)
     
    end %if( ~mod(now/tt(now)) )
    
    %look-up tables update; all is done by the falling-edge
    if(~mod(now,ref)) 
       
        if (contP < 10230)
            contP = contP + 1;        
        else
            contP = 1;
        end %(contP == 10230)
        
        if(~mod(now,ref*10)) %CA count runs 10 times slower then Pcode
            if (contCA < 1023)
                contCA = contCA + 1;
            else
                contCA = 1;
                fprintf('�')
                % marks each complete CA with "�"
                if(clockNAV50 < 50)
                    clockNAV50 = clockNAV50 + 1; 
                else
                    clockNAV50 = 1;
                
                    if(contNAV < 1500)
                        contNAV = contNAV + 1;
                    else
                        contNAV = 1;
                    end % if(contNAV < 1500)
                     
                end %if(clockNAV50 < 50)
            
            end %(contCA < 1023)
                   
        end %if(~mod(now,ref*10)
        
    end %if(~mod(now,ref))
       
    if(~mod(now,marker250us))
        fprintf('.')
        if(~mod(now,marker1ms))
            fprintf('|')
        end
    end
 


end % for now = 1:length(time)

%carriers addition

signal = carrCos.*cos(2*pi*freq.*samptime);
signal = signal + ...
    carrSin.*sin(2*pi*freq.*samptime)*db2mag(-3); %normal attenuation block
fprintf(' .')

end % end function
