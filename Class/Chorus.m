
% batch for data analysis
classdef Chorus < handle
    %UNTITLED6 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        input
        path % just a list of all path
        neu % these are the inputs for class Experiment
        plx %
        wavfolder%
        sneu  % selected
        splx
        swavfolder
        nlist  % to show the list of neuron name
        
        neurons
        
        %test
        
    end
    
    
    methods
        function cho = Chorus(path_txt,path_plx,path_folder)
            
            if nargin== 0
                return
            end
            
            cho.path.path_txt = path_txt;
            cho.path.path_plx = path_plx;
            cho.path.path_folder = path_folder;
            cho.split;
            cho.nlist = cho.nlist';
            cho.select; % default, select all
            cho.input.pathtxt = path_txt;
            cho.input.pathplx = path_plx;
            cho.input.pathstm = path_folder;
        end
        
        function cho = split(cho) % split a recording file to neurons with different channel and unit names
            
            idx = 0;
            for k = 1:size(cho.path,1)
                spikes = Spike.split(cho.path(k).path_txt); % in this step, the unsorted spikes has been removed
                for m = 1: length(spikes)
                    idx = idx + 1;
                    cho.neu{idx} = spikes{m};
                    cho.plx{idx} = cho.path(k).path_plx;
                    cho.wavfolder{idx} = cho.path(k).path_folder;
                    if isa(cho.plx{idx},'Trigger')
                        [~,plxname,~] = fileparts(cho.plx{idx}.inputpath);
                    elseif isa(cho.plx{idx},'string')||isa(cho.plx{idx},'char')
                        [~,plxname,~] = fileparts(cho.plx{idx});
                    end
                    channelname = unique(cho.neu{idx}.channelname);
                    channelname = channelname{1};
                    unitname = unique(cho.neu{idx}.unit);
                    cho.nlist(idx).idx = idx;
                    cho.nlist(idx).neuronname = sprintf('%s_%s_%u',plxname,channelname,unitname);
                    
                end
            end
        end
        
        function cated = collectImages(cho)
            
            collect = {};
            
            for p = 1: length(cho.neurons) % for each single unit
                % generate struct
                collect{p} = cho.neurons{p}.collectImages;
            end
            cated = horzcat(collect{:});
        end
        
        function SimuThree(cho)
            catedcated = cho.collectImages;
            
            rows = unique({catedcated.channelunit}.');
            [columns,cindex] = unique(cellstr({catedcated.soundpath}.'));
            
            specrow = {};
            for ind = 1: length(cindex)
                specrow{1,ind} = catedcated(cindex(ind)).specimg;
            end
            
            size3 = size(catedcated(1).rasterimg);
            finalimg = repmat({uint8(255*ones(size3(1),size3(2),size3(3)))}, length(rows), length(columns));
            
            
            
            for dd = 1: length(catedcated)
                
                rownum = find(~cellfun(@isempty,regexp(rows,catedcated(dd).channelunit)));
                [columnnum,~] = find(ismember(columns,convertStringsToChars(catedcated(dd).soundpath)));
                finalimg{rownum,columnnum} = catedcated(dd).rasterimg;
            end
            
            finalimg = vertcat(specrow,finalimg);
            FINALIMG = cell2mat(finalimg);
            
            [~,plxname,~] = fileparts(path_plx);
            imwrite(FINALIMG,sprintf('SimuRecorded_Neurons_%s.tiff',plxname));
        end
        
        
         
    end
    methods(Hidden = true)
        
        
        
        function spikeinf = manspike(cho)
            for ii = 1: length(cho.neu)
                cho.select(ii);
                temp = cho.getn;
                thisn = temp{1};
                thisn.manspike;
            end
        end
        
        
        function avgn(cho) % write avgn mat files
            dbstop if error
            outdir = 'batch_avgn';
            mkdir(outdir);
            % 48 is jumped out
            for idx = 49: length(cho.neu) %!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                temp = Experiment(cho.neu{idx},cho.plx{idx},cho.wavfolder{idx});
                syllables = temp.avgn;
                %syllables = syllables';
                %[~,rawid,~] = fileparts(cho.plx{idx});
                fullid = temp.neuronname; %%%%%%%%%%%%%
                
                save(sprintf('%s\\%s.mat',outdir,fullid),'syllables');
                
            end
            
            
        end
        
        function select(cho,idx)
            if ~exist('idx','var')
                cho.sneu = cho.neu;
                cho.splx = cho.plx;
                cho.swavfolder = cho.wavfolder;
            else
                cho.sneu = cho.neu(idx);
                cho.splx = cho.plx(idx);
                cho.swavfolder = cho.wavfolder(idx);
            end
        end
        
        function neurons = getn_shift(cho,shift_value)
            
            parfor idx = 1: length(cho.sneu) % heer should be parfor , i edited here just tio chelc the bug
                NN = Experiment;
                neurons{idx} = NN.shiftNeuron(cho.sneu{idx},cho.splx{idx},cho.swavfolder{idx},shift_value);
            end
            
            parfor w = 1: length(neurons) % for each neuron, write the same_channel_spikes info
                
                
                same_channel_spikes = Spike.extract_specific_channel(cho.path.path_txt,neurons{w}.channelname);
                neurons{w}.sameChannelSpikes = same_channel_spikes;
                
            end
            
        end
        
        function neurons = getn(cho) % initiatialize neurons
            
            %neurons = {};
            for idx = 1: length(cho.sneu) % Here should be parfor
                neurons{idx} = Experiment(cho.sneu{idx},cho.splx{idx},cho.swavfolder{idx});
                
            end
            
            
            for w = 1: length(neurons) % for each neuron, write the same_channel_spikes info
                
                
                same_channel_spikes = Spike.extract_specific_channel(cho.path.path_txt,neurons{w}.channelname);
                neurons{w}.sameChannelSpikes = same_channel_spikes;
                
            end
            cho.neurons = neurons;
            
        end
        
        function featuretsne(cho)
            for idx = 11: length(cho.neu) %%%%%%%% modified here
                Experiment(cho.neu{idx},cho.plx{idx},cho.wavfolder{idx}).featuretsne;
            end
        end
        
       
        
      
        function sapscatter(cho)
            
            for idx = 1: length(cho.neu)
                
                cho.select(idx);
                neuron = cho.getn;
                neuron = neuron{1};
                try
                    neuron.sapscatter;
                catch Error
                end
            end
        end
        
        function Three(cho)
            
            IMG = {};
            
            neuronlist = cho.getn;
            
            for k = 1:length(neuronlist)
                IMG{k} = neuronlist{k}.OneRowThree;
            end
            
            final_IMG = vertcat(IMG{:});
            [~,plxname,~] = fileparts(cho.input.pathplx);
            imwrite(final_IMG,sprintf('Three_%s.png',plxname));
        end
        
    end
    
    methods(Static)
        
        function neuronlist = pipline(path_txt,path_plx,path_folder)
            dbstop if error
            addpath(genpath("C:\Users\Zhehao\Dropbox (OIST)\My_Matlab\TEA"))
            cho = Chorus(path_txt,path_plx,path_folder);
            cho.select;
            neuronlist = cho.getn;
            
            for k = 1: length(neuronlist)
                thisn = neuronlist{k};
                
                % A = Neuron(thisn);
                %save(thisn.neuronname,'A','-v7.3');
                %thisn.three;
                thisn.pltthree(1);
                %thisn.ResponseBasedOrderedThreePlots;
            end
        end
        
    end
end


