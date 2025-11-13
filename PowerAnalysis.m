clc;
clear;

Runs={'PLACEHOLDER.rhc';
      };

RunsEvents={'PLACEHOLDER_FOLDER';
};

%%%%%%%%%%% Save Address %%%%%%%%%%%
Save_Address='C:\LFPAnalysis';
Save_Name='RF';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% Settings %%%%%%%%%%%
Pre=8;%3; %%% pre-stimlus
Post=8;%4; %%% post-stimlus
Resample=1000; %%% downsampling frequency
HPFCutOff=1; %%% high pass cut-off frequency
FreqSteps=1:1:500; %%% time-frequency analysis frequency
BaselineCorrectionApproach='normchange';%% 'z-score', 'absolute', 'relative', 'relchange', 'normchange' or 'db'
BaselineWindow=[-1 -0.2];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
OnsetEvent=5; %%% 5: flash start/end %%% 


mkdir([Save_Address filesep Save_Name]);
cd([Save_Address filesep Save_Name]);
Data=[];
Data_Events=[];
RunIndexes=[];
n=1;
for r=10:13
    %%%%%%%%% load the elec data %%%%%%%%%%%%
    read_Intan_RHD2000_file_faster(Runs{r});
    Data_Amp=amplifier_data;
    fsample=frequency_parameters.amplifier_sample_rate;
    clear amplifier_data

    %%%%%%%%% low pass and notch filter %%%%%%%%%%
    if(1)
        Data_ThisRun=[];
        Data_ThisRun.trial{1}=Data_Amp;
        Data_ThisRun.time{1}=0:1/fsample:(size(Data_Amp,2)-1)/fsample;
        Data_ThisRun.sampleinfo(1,:)=[0,(size(Data_Amp,2)-1)/fsample];
        CC=1;
        for i=1:length(amplifier_channels)
            Data_ThisRun.label{CC,1}=amplifier_channels(i).custom_channel_name;
            CC=CC+1;
        end
        Data_ThisRun.fsample=fsample;
%     
%         cfg = [];
%         cfg.bsfilter = 'yes';
%         cfg.bsfilttype = 'but';
%         cfg.bsfiltdir = 'twopass';
%         cfg.bsfiltord = 2;
%         cfg.bsinstabilityfix = 'reduce';
%         cfg.bsfreq = [48 52; 98 102; 148 152; 198 202; 248 252];
%         Data_ThisRun=ft_preprocessing(cfg, Data_ThisRun);
    
        cfg=[];
        cfg.lpfilter='yes';
        cfg.lpfreq=Resample/2;
        Data_ThisRun=ft_preprocessing(cfg, Data_ThisRun);
        Data_Amp=Data_ThisRun.trial{1};
    end

    %%%%%%%%% epochs %%%%%%%%%%
    run_start_elec=find(diff(board_dig_in_data(1,:))==1);
    % flash events
    D=diff(board_dig_in_data(OnsetEvent,:));
    S_M=find(D==1);
    E_M=find(D==-1);
    % epochs
    S=find(D==1)+1-Pre*fsample;
    E=S+(Pre+Post)*fsample;
    
    %%%%%%% Load the events %%%%%%%
    folderPath = RunsEvents{r};

    load([RunsEvents{r} filesep 'All.mat'],'experimentStartMouseClicked');
    run_start_beh=experimentStartMouseClicked;

    fileList = dir(fullfile(folderPath, '*.csv'));
    % Loop through files and read them
    beh_data_label=[];
    beh_data_startend_time=[];
    beh_data_trialstartend_time=[];
    beh_data_rewardstartend_time=[];
    for k = 1:numel(fileList)
        filename = fullfile(folderPath, fileList(k).name);
        % read csv %
        opts=detectImportOptions(filename);
        opts=setvartype(opts,'string'); 
        T=readtable(filename,opts); 
        events_start_idx=find(ismember(table2array(T(:,1)),'timestamp'),1);
        for i=(events_start_idx+1):size(T,1)
            if(strcmp(table2array(T(i,2)),'fixation_successful'))
                beh_data_label=[beh_data_label;table2array(T(i,3))];
                beh_data_startend_time=[beh_data_startend_time; str2num(table2array(T(i+1,1))) str2num(table2array(T(i+2,1)))];
            end
            if(strcmp(table2array(T(i,2)),'reward_started'))
                beh_data_rewardstartend_time=[beh_data_rewardstartend_time; str2num(table2array(T(i,1))) str2num(table2array(T(i+1,1)))];
            end
        end
        beh_data_trialstartend_time=[beh_data_trialstartend_time;str2num(table2array(T(16,2))) str2num(table2array(T(17,2)))];   
    end

    % compare events from elec with beh %
    figure('Position', [0 0 1920 1080]);
    time_stamps_beh=beh_data_startend_time(:,1)-run_start_beh;
    time_stamps_elec=(S_M-run_start_elec)/fsample;
    plot(time_stamps_beh,'o');
    hold on
    plot(time_stamps_elec,'*');
    print(gcf,['Check_Events_r' num2str(r) '.png'],'-dpng','-r300');
    if(length(time_stamps_beh)~=length(time_stamps_elec))
        %error('a mistmach');
    end
    close all;

    %%%% Use behvaioral instead %%%%
    %time_stamps_beh=beh_data_trialstartend_time(:,1)-run_start_beh;
    %S=round((time_stamps_beh-Pre)*fsample)+run_start_elec;
    %E=S+(Pre+Post)*fsample;

    %%%%%%%%% fieldtrip data %%%%%%%%%%%
    Data_ThisRun=[]; 
    Data_Events_ThisRun=[];
    k=1;
    for i=1:length(S)
        try
            if(~any(max(abs(Data_Amp(:,S(i):E(i)))')>500)) % remove obviously bad trials %
                Data_ThisRun.trial{k}=Data_Amp(:,S(i):E(i));
                Data_ThisRun.time{k}=-Pre:1/fsample:Post;
                Data_ThisRun.sampleinfo(k,:)=[S(i),E(i)];
                Data_Events_ThisRun{k,1}=beh_data_label{i};
                k=k+1;
            else
                disp('Exclude a bad trial');
                beep
            end
        catch

        end
    end
    disp(['NTrials: ' num2str(length(Data_ThisRun.trial))])

    RunIndexes=[RunIndexes;r*ones(length(Data_ThisRun.trial),1)];

    CC=1;
    for i=1:length(amplifier_channels)
        Data_ThisRun.label{CC,1}=amplifier_channels(i).custom_channel_name;
        CC=CC+1;
    end
    Data_ThisRun.fsample=fsample;

    %%%%%%%% downsample %%%%%%%%%%%%%
    cfg=[];
    cfg.resamplefs=Resample;
    Data_ThisRun_d=ft_resampledata(cfg,Data_ThisRun);

    %%% attach the sampleinfo %%%
    Data_ThisRun_d.sampleinfo=round(Data_ThisRun.sampleinfo*(Resample/fsample));
    Data_ThisRun=Data_ThisRun_d;
    clear Data_ThisRun_d;

    %%%%%%%%%%%% HP Filtering %%%%%%%%%%%%%
    cfg=[];
    cfg.hpfilter='yes';
    cfg.hpfreq=HPFCutOff;
    Data_ThisRun=ft_preprocessing(cfg, Data_ThisRun);

    Data{n}=Data_ThisRun;
    Data_Events{n}=Data_Events_ThisRun;
    
    clear Header;
    clear Data_ThisRun;
    clear Data_Events_ThisRun;
    clear Data_Amp;
    clear board_dig_in_data;
    clear fsample;
    clear amplifier_channels;

    n=n+1;
end
%%%% Concatenate all runs %%%%%%
Data_All_Events=[];
Data_All=[];
Data_All.fsample=Resample;
Data_All.label=Data{1}.label;
Data_All.sampleinfo=[];
k=1;
for r=1:length(Data)
    for i=1:length(Data{r}.trial)
        Data_All.trial{k}=Data{r}.trial{i};
        Data_All.time{k}=Data{r}.time{i};
        k=k+1;
    end
    if(r==1)
        Data_All.sampleinfo=[Data_All.sampleinfo;Data{r}.sampleinfo];
    else
        Data_All.sampleinfo=[Data_All.sampleinfo;Data{r}.sampleinfo+Data{r-1}.sampleinfo(end,end)];
    end
    Data_All_Events=[Data_All_Events;Data_Events{r}];
end    
Data=Data_All;
Data_Events=Data_All_Events;
Data.events=Data_Events;
Data.runindex=RunIndexes;
clear Data_All
clear Data_All_Events

%%% TF analysis %%%
cfg=[];
cfg.method='mtmconvol';
cfg.taper='hanning';
cfg.output='pow';
cfg.keeptrials='yes';
cfg.pad='nextpow2';
cfg.foi=FreqSteps;
cfg.t_ftimwin=ones(1,length(FreqSteps)).*6./FreqSteps;
cfg.toi=Data.time{1}(1):0.01:Data.time{1}(end);
TF=ft_freqanalysis(cfg, Data);
TF.runindex=Data.runindex;
TF.events=Data.events;

cfg=[];
cfg.baseline=BaselineWindow;
cfg.baselinetype='normchange';%% 'z-score', 'absolute', 'relative', 'relchange', 'normchange' or 'db'
TF_N=ft_freqbaseline(cfg, TF);

%%%%%%%%%%%%%  Plot %%%%%%%%%%%%%
Freq=[8 FreqSteps(end)];
Time=[-Pre Post];
%%%%%%%%%%%%%%%%%%%%%%%

Tend=find(TF_N.time<=Time(2));
Tend=Tend(end);
Tstart=find(TF_N.time>=Time(1));
Tstart=Tstart(1);

Fend=find(TF_N.freq<=Freq(2));
Fend=Fend(end);
Fstart=find(TF_N.freq>=Freq(1));
Fstart=Fstart(1);

%%%%% Shift the time Sample %%%%%
PossibleShift=0;%quantile(TF.cfg.t_ftimwin(Fstart:Fend),0.75)/2+TimingMisAlignment;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

POW_MAP=[];
k=1;
figure('Position', [0 0 1920 1080]);
for electrode=1:size(TF_N.powspctrm,2)
    
    POW_MAP=squeeze(mean(TF_N.powspctrm(:,electrode,:,:),1));
    %POW_MAP=squeeze(TF_N.powspctrm(electrode,:,:));
    POW_MAP(isnan(POW_MAP))=0;
    subplot(4,8,k);
    imagesc(TF_N.time(Tstart:Tend)+PossibleShift,TF_N.freq(Fstart:Fend),POW_MAP(Fstart:Fend,Tstart:Tend));
    set(gca,'YDir','normal');
    l=line([0 0],[TF_N.freq(1) TF_N.freq(end)]);
    set(l,'linestyle',':','color',[0 0 0],'LineWidth',2);
    %axis off;
    set(gca,'FontSize',12);
    %colorbar;
    colormap(jet(256));
    k=k+1;
end










