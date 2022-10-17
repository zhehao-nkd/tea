classdef Sultan
    % 批量对Analysis文件进行操作，以进行复杂的数据分析
    % So Sultan controls everything, more powerful than Consul
    
    properties
        anas % a cell collection of neurons
        ana_filelist
        anainfo
        con_anas
    end
    
    methods %计算方法
        
        function s = Sultan(dirs_of_analysis)
            
            s.ana_filelist = Extract.filename(dirs_of_analysis,'*.mat');
            s.anas = Extract.filename(dirs_of_analysis,'*.mat');
            
        end
        
        function errors = update_Analysis_Files(s,targetdir)
            
            wb = waitbar(0,'Start processing');
            num_files = length(s.anas);
            Utl.UpdateParforWaitbar(num_files, wb);
            D = parallel.pool.DataQueue;
            afterEach(D, @Utl.UpdateParforWaitbar);
            ana_pathes = s.anas;
            errors = struct;
            
            mkdir(targetdir)
            
            for k = 1: length(ana_pathes) % should be par-for
                try
                    loaded = load(ana_pathes{k});
                    A = loaded.A;
                    A.judgeConResp_FR;
                    A.judgeFragResp_FR;
                    %A.judgeConResp; % update con resp labels
                    % parsave(sprintf('%s.mat',A.formated_name),A);
                    
                    %save(A.formated_name,'A','-v7.3');
                    
                    [~,name,ext] = fileparts(ana_pathes{k});
                    
                    newpath = fullfile(targetdir,strcat(name,ext));
                    save(newpath,'A','-v7.3')
                    
                catch ME
                    
                    errors(k).ME = ME;
                    errors(k).filepath = ana_pathes{k};
                    errors(k).kvalue = k;
                    
                end
                send(D, 1);
                
            end
            
            close(wb);
            
        end
        
        
        function anainfo = getAnalysisInfo(s) % 获取每个analysis的信息，主要是他们是否含有 frag， repla 以及 deg 的 stimuli
            
            for k = 1: length(s.anas)
                
                load(s.anas{k});
                anainfo(k).uniqueid = A.uniqueid;
                anainfo(k).birdid = A.birdid;
                
                if ~isempty(A.normlist)
                    anainfo(k).songexist = 1;
                else
                    anainfo(k).songexist = 0;
                end
                
                
                if ~isempty(A.fragnames)
                    anainfo(k).fragexist = 1;
                else
                    anainfo(k).fragexist = 0;
                end
                
                if ~isempty(A.degnames)
                    anainfo(k).degexist = 1;
                else
                    anainfo(k).degexist = 0;
                end
                
                if ~isempty(A.replanames)
                    anainfo(k).replaexist = 1;
                else
                    anainfo(k).replaexist = 0;
                end
                
                if ~isempty(A.replanames)&&~isempty(A.degnames)&&~isempty(A.fragnames)&&~isempty(A.normlist)
                    anainfo(k).allexist = 1;
                else
                    anainfo(k).allexist = 0;
                end
                
                
            end
            
        end
        
        function s = selectConNeurons(s)
            
            
            selected_ids = [];
            for k = 1: length(s.neurons)
                
                if length(cellfun(@isempty, regexp('norm',{s.neurons{k}.slist.name}.')))> 12
                    selected_ids = [selected_ids,k];
                end
            end
            s.con_neurons = s.neurons{selected_ids};
        end % 需要修改
        
        function wl_info = calWavelength(s)
            wl_info = struct;
            
            for k = 1: length(s.anas)
                load(s.anas{k});
                wl_info(k).wl = A.calMeanWaveLength;
                wl_info(k).neuronname = A.formated_name;
            end
            
        end
        
        function frags_exist_names = markNeuronsWithFragsAsStimuli(s)
            
            frags_exist_names = {};
            counts = 0;
            for k = 1: length(s.anas)
                load(s.anas{k});
                if ~isempty(~arrayfun(@isempty, regexp([A.neuinfo.keywords],"frag")) )
                    counts = counts + 1;
                    frags_exist_names{counts} = A.unique_neuronname;
                end
            end
        end
        
        function neuronStimuliInfo = getStimuliInfo(s)
            
            neuronStimuliInfo = struct;
            
            for k = 1: length(s.anas)
                these_names = {s.anas{k}.slist.name}.';
                
                % initialize
                neuronStimuliInfo(k).neuronname = s.neurons{k}.neuronname;
                neuronStimuliInfo(k).norm = 0;
                neuronStimuliInfo(k).frag = 0;
                neuronStimuliInfo(k).repla = 0;
                
                if ~isempty(find(~cellfun(@isempty, regexp(these_names,'norm'))))
                    neuronStimuliInfo(k).norm = 1;
                end
                
                if ~isempty(find(~cellfun(@isempty, regexp(these_names,'frag|Frag|syl|Syl'))))
                    neuronStimuliInfo(k).frag = 1;
                end
                
                if ~isempty(find(~cellfun(@isempty, regexp(these_names,'Repla|repla|catego'))))
                    neuronStimuliInfo(k).repla = 1;
                end
                
            end
            
            sumnorm = sum([neuronStimuliInfo.norm].');
            sumfrag = sum([neuronStimuliInfo.frag].');
            sumrepla = sum([neuronStimuliInfo.repla].');
            
            %????????????????????????????????? something is wrong
            
        end
        
        function fr_info = multiRepeatsFiringRate(s)
            fr_info = struct;
            
            for k = 1: length(s.anas)
                % for each neuron
                load(s.anas{k});
                thisA = A;
                fr_info(k).neuronname = A.formated_name;
                
                sum_prelen = 0; % summed prey length
                concat_presptimes = []; % concatenated prey sptimes
                
                sum_pltlen = 0; %summed prey( stimuli y, not plty or rawy) length
                concat_pltsptimes = []; %  % concatenated y sptimes
                
                all_es = thisA.getAllEphysObject;
                for m = 1: length(all_es)
                    
                    
                    % for prey
                    fr_info(k).presptimes{m} = all_es{m}.presptimes
                    fr_info(k).preylen{m} = length(all_es{m}.y)/all_es{m}.fs;
                    fr_info(k).repnum{m} = size(all_es{m}.presptimes,2);
                    temp = all_es{m}.presptimes.';
                    concat_presptimes = [concat_presptimes;vertcat(vertcat(temp{:}))+ sum_prelen];
                    sum_prelen = sum_prelen +  fr_info(k).preylen{m};
                    
                    % for plty
                    fr_info(k).pltsptimes{m} = all_es{m}.pltsptimes
                    fr_info(k).pltlen{m} = length(all_es{m}.plty)/all_es{m}.fs;
                    temp = all_es{m}.pltsptimes.';
                    concat_pltsptimes = [concat_pltsptimes;vertcat(vertcat(temp{:}))+ sum_pltlen];
                    sum_pltlen = sum_pltlen +  fr_info(k).pltlen{m};
                    
                end
                
                
                % for norm songs, degressive songs, adn detailed
                % frags/replas, calculate the concatenated firing rate one
                % by one
                
                % for pre_y
                fr_info(k).concat_pre_sptimes = concat_presptimes;
                fr_info(k).concat_pre_len = sum_prelen;
                fr_info(k).mean_pre_fr = length(concat_presptimes)/sum_prelen;
                
                % for plt_y
                fr_info(k).concat_plt_sptimes = concat_pltsptimes;
                fr_info(k).concat_plt_len = sum_pltlen;
                fr_info(k).mean_plt_fr = length(concat_pltsptimes)/sum_pltlen;
                
                
            end
            
        end
        
        function [bstruct,originplot] = Whether_neurons_from_same_birds_respond_biasedly_to_songs(s)
            
            dbstop if error
            wb = waitbar(0,'Start processing');
            Utl.UpdateParforWaitbar(length(s.anas), wb);
            D = parallel.pool.DataQueue;
            afterEach(D, @Utl.UpdateParforWaitbar);
            
            
            conkeywords = {'B346','B512','B521','B554','B606','G429','G506','G518','G548','G573',...
                'G578','O331','O507','O509','O540','Y515','Y606','Y616'};
            
            songinf = struct;
            for k = 1:length(conkeywords)
                songinf(k).songname = conkeywords{k};
                songinf(k).neunum = 0;
                songinf(k).neuname = {};
            end
            
            bid = {};
            for k = 1:length(s.anas)
                [~,filename,~] = fileparts(s.anas{k});
                bid(k) = regexp(char(filename),'[OGBRY]\d{3}','match');
                
            end
            bnames = unique(bid);
            
            coresp_bnum = [];
            for k = 1:length(bnames)
                coresp_bnum(k) = length(find(~cellfun(@isempty,regexp(cellstr(s.anas),bnames{k}))));
            end
            
            figure
            X = categorical(bnames );
            Y = coresp_bnum;
            bar(X,Y);
            
            bstruct = struct;  %  初始化
            for k = 1:length(bnames)
                bstruct(k).bname = bnames{k};
                bstruct(k).songinf = songinf;
            end
            allbnames = cellstr({bstruct.bname}.');
            
            
            Collect = struct;
            parfor k = 1:length(s.anas) % 计算
                loaded = load(s.anas{k});
                A = loaded.A;
                A.judgeConResp_FR;
                Collect(k).list  = struct('stimuliname', {A.list(:).stimuliname}, 'label', {A.list(:).label});
                Collect(k).bid = A.birdid;
                Collect(k).formated_name = A.formated_name;
                send(D, 1);
            end
            
            for k = 1: length(Collect)
                bird_ids = find(~cellfun(@isempty,regexp(allbnames,Collect(k).bid)));
                for kk = 1:length(conkeywords)
                    alist_ids = find(~cellfun(@isempty,regexp(cellstr({Collect(k).list.stimuliname}.'),['norm','\S+',conkeywords{kk}])));
                    if length(alist_ids) > 1;alist_ids = alist_ids(1);end % 万一有多个同名norm songs，只用第一个
                    if Collect(k).list(alist_ids).label == 1
                        bstruct(bird_ids).songinf(kk).neunum = bstruct(bird_ids).songinf(kk).neunum + 1;
                        bstruct(bird_ids).songinf(kk).neuname = {bstruct(bird_ids).songinf(kk).neuname,Collect(k).formated_name};
                    end
                end
                send(D, 1);
                
            end
            
            % zuotu
            
            
            coors = [];
            for k = 1:length(bstruct)
                %birdname = bstruct(k).bname
                coors(:,k) = flip(cumsum([bstruct(k).songinf.neunum].'))
                
            end
            
            figure;
            hold on
            for k = 1:size(coors,1)
                area(coors(k,:))
            end
            
            xticks(linspace(0,length(bstruct) + 1,length(bstruct)+2 ));
            xticklabels([{''},{bstruct.bname},{''}]);
            hold off
            
            
            percen_coors = []; % draw percentage figure
            for k = 1:size(coors,2)
                percen_coors(:,k) = coors(:,k)/coors(1,k);
            end
            
            figure;
            hold on
            for k = 1:size(coors,1)
                area(percen_coors(k,:));
            end
            
            xticks(linspace(0,length(bstruct) + 1,length(bstruct)+2 ));
            xticklabels([{''},{bstruct.bname},{''}]);
            
            yticks(linspace(0,1,length(conkeywords)+2 ));
            yticklabels([{''}, conkeywords ]);
            set(gca,'TickLength',[0 0])
            hold off
            
            
            originplot.data_for_origin = [];
            for k = 1: length(bstruct)
                
                originplot.data_for_origin(k,:) =  [bstruct(k).songinf.neunum]
                
            end
            
            originplot.birdids = {bstruct.bname}.';
            
            originplot.songids = {bstruct(1).songinf.songname}.';
            
            
            
            
        end
        
        
        function ainf = clusterAllNeurons(s)
            
            dbstop if error
            wb = waitbar(0,'Start processing');
            Utl.UpdateParforWaitbar(length(s.anas), wb);
            D = parallel.pool.DataQueue;
            afterEach(D, @Utl.UpdateParforWaitbar);
            
            
            acollect = {};
            parfor k = 1: length(s.anas) % par-for
                loaded = load(s.anas{k});
                A = loaded.A;
                acollect{k} = A.calPropertiesForClustering;
                acollect{k}.filepath = s.anas{k};
                send(D,1);
            end
            
            ainf = vertcat(acollect{:});
            
            figure;
            scatter([ainf.mean_pre_fr].',[ainf.meanWL].')
            xlabel('Spon FR')
            ylabel('Spike Width')
            roi = drawfreehand;
            pause(0.1);
            xv = roi.Position(:,1);
            yv = roi.Position(:,2);
            for k = 1:length(ainf )
                ainf (k).isBS = inpolygon(ainf(k).mean_pre_fr,ainf(k).meanWL,xv,yv); % brushed is BS
            end
            
            %
            %             figure;
            %             scatter([ainf.sumsparseness].',[ainf.meanWL].')
            %             xlabel('Sparseness')
            %             ylabel('Spike Width')
            %             roi = drawfreehand;
            %             pause(0.1);
            %             xv = roi.Position(:,1);
            %             yv = roi.Position(:,2);
            %             for k = 1:length(ainf)
            %                 ainf (k).isSparse = inpolygon(ainf(k).sumsparseness,ainf(k).meanWL,xv,yv); % brushed is BS
            %             end
            
            
            isbs = find([ainf.isBS] == 1);
            notisbs = find([ainf.isBS] == 0);
            
            %             isspa = find([ainf.isSparse] == 1);
            %             notisspa = find([ainf.isSparse] == 0);
            
            
            
            xyzpoints = horzcat([ainf.sumsparseness].',[ainf.mean_pre_fr].',[ainf.meanWL].')
            Y = tsne(xyzpoints)
            
            figure
            
            %             subplot(1,2,1)
            hold on
            scatter(Y(:,1),Y(:,2),[],'k')
            scatter(Y(isbs,1),Y(isbs,2),[],'r')
            scatter(Y(notisbs,1),Y(notisbs,2),[],'b')
            
            %             subplot(1,2,2)
            %             hold on
            %             scatter(Y(:,1),Y(:,2),[],'k')
            %             scatter(Y(isspa,1),Y(isspa,2),[],'r')
            %             scatter(Y(notisspa,1),Y(notisspa,2),[],'b')
            %
            neuronnames = {ainf.neuronname}.';
            values = [];
            for k = 1:length(ainf)
                values(k,:) = ainf(k).forpca;
                %values(k,:) = ainf(k).eachsparseness;
                
            end
            [coeff,score,latent] = pca(values);
            figure;
            scatter(score(:,1),score(:,2));
            
            Y = tsne(values);
            
            figure
            %scatter(Y(:,1),Y(:,2))
            scatter([ainf.sumsparseness].',[ainf.sumCI].',[],'r','filled')
            xlabel('sparseness'); ylabel('Correlation index')
            text([ainf.sumsparseness].',[ainf.sumCI].',neuronnames);
            
            figure
            %scatter(Y(:,1),Y(:,2))
            scatter([ainf.sumsparseness].',[ainf.mean_judgeresp_fr].',[],'r','filled')
            xlabel('sparseness'); ylabel('mean_judgeresp_fr')
            text([ainf.sumsparseness].',[ainf.mean_judgeresp_fr].',neuronnames);
            
            
            figure;
            scatter3([ainf.sumsparseness].',[ainf.mean_judgeresp_fr].',[ainf.sumCI].',[],'r','filled')
            xlabel('sparseness'); ylabel('mean_judgeresp_fr'); zlabel('Correlation index')
            
            text([ainf.sumsparseness].',[ainf.mean_judgeresp_fr].',[ainf.sumCI].',neuronnames);
            
            
            %
            %             ptCloud = pointCloud(xyzpoints);
            %             figure
            %             pcshow(ptCloud)
            %             labels = pcsegdist(ptCloud,minDistance)
            %
            
        end
        
    end
    
    methods % 作图方法
        
        function drawCONResponse(s)
            % Extract binarized neuron's responses to CONs
            dbstop if error
            con_info = struct;
            counts = 0;
            
            common_cons = {};
            for k = 1: length(s.neurons)
                Conlist = Neuron(s.neurons{k}).evaluateConResponse;
                if length(Conlist) >= 18 % hard code here
                    counts = counts + 1;
                    con_match = regexp({Conlist.stimuliname}.','[BGYRO]\d{3}','match');
                    con_ids = find(~cellfun(@isempty,con_match));
                    spe_match = regexp({Conlist.stimuliname}.','TUT|BOS|Fcall|Mcall|WNS','match');
                    spe_ids = find(~cellfun(@isempty,spe_match));
                    % remove TUT and BOS
                    con_ids = setdiff(con_ids,spe_ids);
                    con_match = [con_match{con_ids}].';
                    % Extract con_label
                    con_info(counts).neuronname = s.neurons{counts}.neuronname;
                    con_info(counts).con_match = con_match;
                    con_info(counts).con_resp = [Conlist(con_ids).label].';
                    % find out Common Conspecific songs
                    if counts == 1
                        common_cons = con_info(counts).con_match;
                    else
                        temp = intersect(common_cons,con_info(counts).con_match);
                        
                        common_cons = temp; % weird bugs happened when temp was not used
                        
                        if length(common_cons)< 18
                            pause
                        end
                        
                    end
                end
            end
            
            
            % Extract binary resp map
            respmap = [];
            for m = 1: length(con_info)
                [~,loc] = ismember (common_cons,con_info(m).con_match);
                
                % new_con_info(m).name = {con_info(m).con_match{loc}}.';
                respmap(m,:) = con_info(m).con_resp(loc);
            end
            
            % Sort the matrix
            [~,new_rowids] = sort(sum(respmap,2),'descend');
            [~,new_columnids] = sort(sum(respmap,1),2,'descend');
            tempo =  respmap(new_rowids,:);
            new_respmap = tempo(:,new_columnids);
            new_cnames = {common_cons{new_columnids}}; %#ok<CCAT1>
            tempo = {con_info.neuronname};
            new_rnames = {tempo{new_rowids}};
            
            %             figure
            %             subplot(1,3,1)
            %             imagesc(respmap)
            %             subplot(1,3,2)
            %             imagesc( respmap(new_rowids,:));
            %             subplot(1,3,3)
            %             tempo =  respmap(new_rowids,:);
            %             imagesc( tempo(:,new_columnids));
            
            
            respT = array2table(respmap);
            respT.Properties.VariableNames = new_cnames;
            respT.Properties.RowNames = new_rnames;
            
            
        end
        
        function histWaveLength(s)
            dbstop if error
            %             figure
            %             imagesc(new_respmap);
            %             xticks(1:length(new_cnames));
            %             xticklabels(new_cnames);
            %             yticks(1:length(new_rnames));
            %             yticklabels(new_rnames);
            %             set(gca,'TickLabelInterpreter','none');
            
            wl_info = struct;
            
            for k = 1: length(s.anas)
                load(s.anas{k});
                wl_info(k).wl = A.calMeanWaveLength;
                wl_info(k).neuronname = A.unique_neuronname;
            end
            
            figure('Color','w');
            histogram([wl_info.wl].',30); % originally 15
            
            xlabel('Spike width (ms)');
            ylabel('Neurons per bin');
            
        end
        
        function Deprecated_drawCONSPEResponse(s)
            
            % Extract binarized neuron's responses to CONs
            dbstop if error
            con_info = struct;
            counts = 0;
            common_cons = {};
            common_spes = {};
            
            for k = 1: length(s.anas)
                load(s.anas{k});
                this_neuron = A.neurons{A.song_id};
                Conlist = Neuron(this_neuron).evaluateConResponse;
                if length(Conlist) >= 18 % hard code here
                    counts = counts + 1;
                    con_match = regexp(cellstr({Conlist.stimuliname}.'),'[BGYRO]\d{3}','match');
                    con_ids = find(~cellfun(@isempty,con_match));
                    spe_match = regexp(cellstr({Conlist.stimuliname}.'),'TUT|BOS|Fcall|Mcall|WNS','match');
                    spe_ids = find(~cellfun(@isempty,spe_match));
                    spe_match = [spe_match{spe_ids}].';
                    % remove TUT and BOS
                    con_ids = setdiff(con_ids,spe_ids);
                    con_match = [con_match{con_ids}].';
                    
                    
                    % add TUT-BOS-Fcall-Mcall-WNS (Special)
                    
                    % Extract con_label
                    con_info(counts).wav_len = A.calMeanWaveLength;
                    con_info(counts).neuronname = A.formated_name;
                    con_info(counts).con_match = con_match;
                    con_info(counts).con_resp = [Conlist(con_ids).label].';
                    con_info(counts).spe_match = spe_match;
                    con_info(counts).spe_resp = [Conlist(spe_ids).label].';
                    % find out Common Conspecific songs
                    if counts == 1
                        common_cons = con_info(counts).con_match;
                        %common_spes = con_info(counts).spe_match;
                    else
                        temp = intersect(common_cons,con_info(counts).con_match);
                        
                        common_cons = temp; % weird bugs happened when temp was not used
                        
                        %
                        %                         temp = intersect(common_spes,con_info(counts).spe_match);
                        %                         common_spes = temp;
                        
                        if length(common_cons)< 18
                            pause
                        end
                        
                    end
                end
            end
            
            
            % Extract binary con-resp map
            respmap = [];
            for m = 1: length(con_info)
                [~,loc] = ismember (common_cons,con_info(m).con_match);
                
                % new_con_info(m).name = {con_info(m).con_match{loc}}.';
                respmap(m,:) = con_info(m).con_resp(loc);
            end
            
            
            % Extract spe-resp map
            common_spes = {'TUT','BOS','Fcall','Mcall','WNS'};
            spemap = [];
            for m = 1: length(con_info)
                
                if ~isempty(con_info(m).spe_match)
                    [~,loc] = ismember (common_spes,con_info(m).spe_match);
                else
                    [~,loc] = ismember (common_spes,{});
                end
                
                % new_con_info(m).name = {con_info(m).con_match{loc}}.';
                for mm = 1: length(loc)
                    if loc(mm) == 0
                        spemap(m,mm) = nan;
                    else
                        spemap(m,mm) = con_info(m).spe_resp(loc(mm));
                    end
                end
            end
            
            
            % Sort the matrix
            [~,new_rowids] = sort(sum(respmap,2),'descend');
            [~,new_columnids] = sort(sum(respmap,1),2,'descend');
            tempo =  respmap(new_rowids,:);
            new_respmap = tempo(:,new_columnids);
            new_cnames = {common_cons{new_columnids}}; %#ok<CCAT1>
            tempo = {con_info.neuronname};
            new_rnames = {tempo{new_rowids}};
            
            respT = array2table(respmap);
            respT.Properties.VariableNames = new_cnames;
            respT.Properties.RowNames = new_rnames;
            
            % sort spe-map
            new_spemap = spemap(new_rowids,:);
            
            
            % reordered waveforms length
            
            WLs = [con_info.wav_len].';
            WLs = WLs(new_rowids);
            
            
            for k = 1: size(new_respmap,1)
                value_is_one_ids = find(new_respmap(k,:));
                new_respmap(k,value_is_one_ids) = WLs(k);
            end
            
            figure;
            colormap('summer');
            imagesc(new_respmap);
            
            colorbar;
            
            xticks(1:size(new_respmap,2));
            xticklabels(new_cnames);
            
            
            yticks(1:size(new_respmap,1));
            yticklabels(new_rnames);
            set(gca,'TickLabelInterpreter','none');
            set(gca,'TickLength',[0.001, 0.001]);
            
        end
        
        function Deprecated_drawCONOnlyResponse_NSBS(s)
            
            % Extract binarized neuron's responses to CONs
            dbstop if error
            con_info = struct;
            counts = 0;
            common_cons = {};
            common_spes = {};
            
            for k = 1: length(s.anas)
                load(s.anas{k});
                this_neuron = A.neurons{s.anas{k}.song_id};
                Conlist = Neuron(this_neuron).evaluateConResponse;
                if length(Conlist) >= 18 % hard code here
                    counts = counts + 1;
                    con_match = regexp({Conlist.stimuliname}.','[BGYRO]\d{3}','match');
                    con_ids = find(~cellfun(@isempty,con_match));
                    spe_match = regexp({Conlist.stimuliname}.','TUT|BOS|Fcall|Mcall|WNS','match');
                    spe_ids = find(~cellfun(@isempty,spe_match));
                    spe_match = [spe_match{spe_ids}].';
                    % remove TUT and BOS
                    con_ids = setdiff(con_ids,spe_ids);
                    con_match = [con_match{con_ids}].';
                    
                    
                    % add TUT-BOS-Fcall-Mcall-WNS (Special)
                    
                    % Extract con_label
                    con_info(counts).wav_len = this_neuron.calMeanWaveLength;
                    con_info(counts).neuronname = this_neuron.unique_neuronname;
                    con_info(counts).con_match = con_match;
                    con_info(counts).con_resp = [Conlist(con_ids).label].';
                    con_info(counts).spe_match = spe_match;
                    con_info(counts).spe_resp = [Conlist(spe_ids).label].';
                    % find out Common Conspecific songs
                    if counts == 1
                        common_cons = con_info(counts).con_match;
                        %common_spes = con_info(counts).spe_match;
                    else
                        temp = intersect(common_cons,con_info(counts).con_match);
                        
                        common_cons = temp; % weird bugs happened when temp was not used
                        %                         temp = intersect(common_spes,con_info(counts).spe_match);
                        %                         common_spes = temp;
                        
                        if length(common_cons)< 18
                            pause
                        end
                    end
                    
                end
            end
            
            
            % Extract binary con-resp map
            respmap = [];
            for m = 1: length(con_info)
                [~,loc] = ismember (common_cons,con_info(m).con_match);
                
                % new_con_info(m).name = {con_info(m).con_match{loc}}.';
                respmap(m,:) = con_info(m).con_resp(loc);
            end
            
            
            % Extract spe-resp map
            common_spes = {'TUT','BOS','Fcall','Mcall','WNS'};
            spemap = [];
            for m = 1: length(con_info)
                
                if ~isempty(con_info(m).spe_match)
                    [~,loc] = ismember (common_spes,con_info(m).spe_match);
                else
                    [~,loc] = ismember (common_spes,{});
                end
                
                % new_con_info(m).name = {con_info(m).con_match{loc}}.';
                for mm = 1: length(loc)
                    if loc(mm) == 0
                        spemap(m,mm) = nan;
                    else
                        spemap(m,mm) = con_info(m).spe_resp(loc(mm));
                    end
                end
            end
            
            
            % Sort the matrix
            [~,new_rowids] = sort(sum(respmap,2),'descend');
            [~,new_columnids] = sort(sum(respmap,1),2,'descend');
            tempo =  respmap(new_rowids,:);
            new_respmap = tempo(:,new_columnids);
            new_cnames = {common_cons{new_columnids}}; %#ok<CCAT1>
            tempo = {con_info.neuronname};
            new_rnames = {tempo{new_rowids}};
            
            respT = array2table(respmap);
            respT.Properties.VariableNames = new_cnames;
            respT.Properties.RowNames = new_rnames;
            
            % sort spe-map
            new_spemap = spemap(new_rowids,:);
            
            
            % reordered waveforms length
            
            WLs = [con_info.wav_len].';
            WLs = WLs(new_rowids);
            
            wlfr_info = plotWavelengthVsFiringRate(s);
            
            names_in_wlfr = {wlfr_info.neuronname}.';
            [~,ids_for_reorder] = ismember(new_rnames,names_in_wlfr);
            new_wlfr_info = wlfr_info(ids_for_reorder);
            
            for k = 1: size(new_respmap,1)
                value_is_one_ids = find(new_respmap(k,:));
                if new_wlfr_info(k).isBS == 0
                    new_respmap(k,value_is_one_ids) = 0.5;
                elseif new_wlfr_info(k).isBS == 1
                    new_respmap(k,value_is_one_ids) = 1;
                end
            end
            
            fig = figure;
            % colormap('summer');
            imagesc(new_respmap);
            
            map = [ 1 1 1
                0 0.4470 0.7410
                0.8500 0.3250 0.0980];
            
            colormap(fig,map);
            
            %colorbar;
            
            xticks(1:size(new_respmap,2));
            xticklabels(new_cnames);
            
            
            yticks(1:size(new_respmap,1));
            yticklabels(new_rnames);
            set(gca,'TickLabelInterpreter','none');
            set(gca,'TickLength',[0.001, 0.001]);
            
        end
        
        function Deprecated_drawCONSPEResponse_NSBS(s)
            
            % Extract binarized neuron's responses to CONs
            dbstop if error
            con_info = struct;
            counts = 0;
            common_cons = {};
            common_spes = {};
            
            for k = 1: length(s.anas)
                this_neuron = s.anas{k}.neurons{s.anas{k}.song_id};
                Conlist = Neuron(this_neuron).evaluateConResponse;
                if length(Conlist) >= 18 % hard code here
                    counts = counts + 1;
                    con_match = regexp({Conlist.stimuliname}.','CON-[BGYRO]\d{3}|TUT|BOS|Fcall|Mcall|WNS|Het','match');
                    con_ids = find(~cellfun(@isempty,con_match));
                    spe_match = regexp({Conlist.stimuliname}.','TUT|BOS|Fcall|Mcall|WNS','match');
                    spe_ids = find(~cellfun(@isempty,spe_match));
                    spe_match = [spe_match{spe_ids}].';
                    
                    % add TUT-BOS-Fcall-Mcall-WNS (Special)
                    
                    % Extract con_label
                    con_info(counts).wav_len = this_neuron.calMeanWaveLength;
                    con_info(counts).neuronname = this_neuron.unique_neuronname;
                    con_info(counts).con_match = con_match;
                    con_info(counts).con_resp = [Conlist(con_ids).label].';
                    con_info(counts).spe_match = spe_match;
                    con_info(counts).spe_resp = [Conlist(spe_ids).label].';
                    
                end
            end
            
            % Hard coded conspecific songs
            common_cons = {'CON-B346','CON-B512','CON-B521','CON-B554','CON-B606','CON-G429','CON-G506','CON-G518','CON-G548',...
                'CON-G573','CON-G578','CON-O331','CON-O507','CON-O509','CON-O540','CON-Y515','CON-Y606','CON-Y616',...
                'Fcall','BOS','Het','Mcall','TUT','WNS'};
            
            % Extract binary con-resp map
            respmap = [];
            for m = 1: length(con_info)
                [ism,loc] = ismember(common_cons,[con_info(m).con_match{:}]);
                respmap(m, find(ism==0)) = nan; % 不存在的stimuli设定其resp值为nan
                % new_con_info(m).name = {con_info(m).con_match{loc}}.';
                respmap(m,loc(loc>0)) = con_info(m).con_resp(loc(loc>0));
            end
            
            % Sort the matrix
            [~,new_rowids] = sort(sum(respmap,2),'descend');
            [~,new_columnids] = sort(sum(respmap,1),2,'descend');
            tempo =  respmap(new_rowids,:);
            new_respmap = tempo(:,new_columnids);
            new_cnames = {common_cons{new_columnids}}; %#ok<CCAT1>
            tempo = {con_info.neuronname};
            new_rnames = {tempo{new_rowids}};
            
            respT = array2table(respmap);
            respT.Properties.VariableNames = new_cnames;
            respT.Properties.RowNames = new_rnames;
            
            % reordered waveforms length
            
            WLs = [con_info.wav_len].';
            WLs = WLs(new_rowids);
            
            wlfr_info = plotWavelengthVsFiringRate(s);
            
            names_in_wlfr = {wlfr_info.neuronname}.';
            [~,ids_for_reorder] = ismember(new_rnames,names_in_wlfr);
            new_wlfr_info = wlfr_info(ids_for_reorder);
            
            for k = 1: size(new_respmap,1)
                value_is_one_ids = find(new_respmap(k,:));
                if new_wlfr_info(k).isBS == 0
                    new_respmap(k,value_is_one_ids) = 0.5;
                elseif new_wlfr_info(k).isBS == 1
                    new_respmap(k,value_is_one_ids) = 1;
                end
            end
            
            fig = figure;
            % colormap('summer');
            imagesc(new_respmap);
            
            map = [ 1 1 1
                0 0.4470 0.7410
                0.8500 0.3250 0.0980];
            
            colormap(fig,map);
            
            %colorbar;
            
            xticks(1:size(new_respmap,2));
            xticklabels(new_cnames);
            
            
            yticks(1:size(new_respmap,1));
            yticklabels(new_rnames);
            set(gca,'TickLabelInterpreter','none');
            set(gca,'TickLength',[0.001, 0.001]);
            
        end
        
        function Deprecated_drawCONSPEResponse_NSBS_markFrag(s)
            
            % Extract binarized neuron's responses to CONs
            dbstop if error
            con_info = struct;
            counts = 0;
            common_cons = {};
            common_spes = {};
            
            for k = 1: length(s.anas)
                this_neuron = s.anas{k}.neurons{s.anas{k}.song_id};
                Conlist = Neuron(this_neuron).evaluateConResponse;
                if length(Conlist) >= 18 % hard code here
                    counts = counts + 1;
                    con_match = regexp({Conlist.stimuliname}.','[BGYRO]\d{3}','match');
                    con_ids = find(~cellfun(@isempty,con_match));
                    spe_match = regexp({Conlist.stimuliname}.','TUT|BOS|Fcall|Mcall|WNS','match');
                    spe_ids = find(~cellfun(@isempty,spe_match));
                    spe_match = [spe_match{spe_ids}].';
                    % remove TUT and BOS
                    con_ids = setdiff(con_ids,spe_ids);
                    con_match = [con_match{con_ids}].';
                    
                    
                    % add TUT-BOS-Fcall-Mcall-WNS (Special)
                    
                    % Extract con_label
                    con_info(counts).wav_len = this_neuron.calMeanWaveLength;
                    con_info(counts).neuronname = this_neuron.unique_neuronname;
                    con_info(counts).con_match = con_match;
                    con_info(counts).con_resp = [Conlist(con_ids).label].';
                    con_info(counts).spe_match = spe_match;
                    con_info(counts).spe_resp = [Conlist(spe_ids).label].';
                    % find out Common Conspecific songs
                    if counts == 1
                        common_cons = con_info(counts).con_match;
                        %common_spes = con_info(counts).spe_match;
                    else
                        temp = intersect(common_cons,con_info(counts).con_match);
                        
                        common_cons = temp; % weird bugs happened when temp was not used
                        %                         temp = intersect(common_spes,con_info(counts).spe_match);
                        %                         common_spes = temp;
                        
                        if length(common_cons)< 18
                            pause
                        end
                    end
                    
                end
            end
            
            
            % Extract binary con-resp map
            respmap = [];
            for m = 1: length(con_info)
                [~,loc] = ismember (common_cons,con_info(m).con_match);
                
                % new_con_info(m).name = {con_info(m).con_match{loc}}.';
                respmap(m,:) = con_info(m).con_resp(loc);
            end
            
            % Sort the matrix
            [~,new_rowids] = sort(sum(respmap,2),'descend');
            [~,new_columnids] = sort(sum(respmap,1),2,'descend');
            tempo =  respmap(new_rowids,:);
            new_respmap = tempo(:,new_columnids);
            new_cnames = {common_cons{new_columnids}}; %#ok<CCAT1>
            tempo = {con_info.neuronname};
            new_rnames = {tempo{new_rowids}};
            
            respT = array2table(respmap);
            respT.Properties.VariableNames = new_cnames;
            respT.Properties.RowNames = new_rnames;
            
            % sort spe-map
            
            
            
            % reordered waveforms length
            
            WLs = [con_info.wav_len].';
            WLs = WLs(new_rowids);
            
            wlfr_info = plotWavelengthVsFiringRate(s);
            
            names_in_wlfr = {wlfr_info.neuronname}.';
            [~,ids_for_reorder] = ismember(new_rnames,names_in_wlfr);
            new_wlfr_info = wlfr_info(ids_for_reorder);
            
            for k = 1: size(new_respmap,1)
                value_is_one_ids = find(new_respmap(k,:));
                if new_wlfr_info(k).isBS == 0
                    new_respmap(k,value_is_one_ids) = 1;
                elseif new_wlfr_info(k).isBS == 1
                    new_respmap(k,value_is_one_ids) = 3;
                end
            end
            
            frags_exist_names = s.markNeuronsWithFragsAsStimuli;
            
            for k = 1: size(new_respmap,1)
                value_is_one_ids = find(new_respmap(k,:));
                if ismember(new_wlfr_info(k).neuronname,frags_exist_names) && new_wlfr_info(k).isBS == 0
                    new_respmap(k,value_is_one_ids) = 2;
                elseif ismember(new_wlfr_info(k).neuronname,frags_exist_names) && new_wlfr_info(k).isBS == 1
                    new_respmap(k,value_is_one_ids) = 4;
                end
            end
            
            
            
            fig = figure;
            % colormap('summer');
            imagesc(new_respmap);
            
            map = [ 1 1 1  % white for 0
                0 0.4470 0.7410 % shallow blue for 1
                0 0 1          % bright blue for 2
                0.8500 0.3250 0.0980  % shallow red for 3
                1 0 0];        % bright red for 4
            % figure; viscircles([0,0],10,'Color',[0 0 1]);
            colormap(fig,map);
            caxis manual
            caxis([0 4]);
            % colorbar
            
            %colorbar;
            
            xticks(1:size(new_respmap,2));
            xticklabels(new_cnames);
            
            
            yticks(1:size(new_respmap,1));
            yticklabels(new_rnames);
            set(gca,'TickLabelInterpreter','none');
            set(gca,'TickLength',[0.001, 0.001]);
            
        end
        
        function Deprecated_drawCONSPEResponse_NSBS_FragOnly(s)
            
            % Extract binarized neuron's responses to CONs
            dbstop if error
            con_info = struct;
            counts = 0;
            common_cons = {};
            common_spes = {};
            
            for k = 1: length(s.anas)
                this_neuron = s.anas{k}.neurons{s.anas{k}.song_id};
                Conlist = Neuron(this_neuron).evaluateConResponse;
                if length(Conlist) >= 18 % hard code here
                    counts = counts + 1;
                    con_match = regexp({Conlist.stimuliname}.','[BGYRO]\d{3}','match');
                    con_ids = find(~cellfun(@isempty,con_match));
                    spe_match = regexp({Conlist.stimuliname}.','TUT|BOS|Fcall|Mcall|WNS','match');
                    spe_ids = find(~cellfun(@isempty,spe_match));
                    spe_match = [spe_match{spe_ids}].';
                    % remove TUT and BOS
                    con_ids = setdiff(con_ids,spe_ids);
                    con_match = [con_match{con_ids}].';
                    
                    
                    % add TUT-BOS-Fcall-Mcall-WNS (Special)
                    
                    % Extract con_label
                    con_info(counts).wav_len = this_neuron.calMeanWaveLength;
                    con_info(counts).neuronname = this_neuron.unique_neuronname;
                    con_info(counts).con_match = con_match;
                    con_info(counts).con_resp = [Conlist(con_ids).label].';
                    con_info(counts).spe_match = spe_match;
                    con_info(counts).spe_resp = [Conlist(spe_ids).label].';
                    % find out Common Conspecific songs
                    if counts == 1
                        common_cons = con_info(counts).con_match;
                        %common_spes = con_info(counts).spe_match;
                    else
                        temp = intersect(common_cons,con_info(counts).con_match);
                        
                        common_cons = temp; % weird bugs happened when temp was not used
                        %                         temp = intersect(common_spes,con_info(counts).spe_match);
                        %                         common_spes = temp;
                        
                        if length(common_cons)< 18
                            pause
                        end
                    end
                    
                end
            end
            
            
            % Extract binary con-resp map
            respmap = [];
            for m = 1: length(con_info)
                [~,loc] = ismember (common_cons,con_info(m).con_match);
                
                % new_con_info(m).name = {con_info(m).con_match{loc}}.';
                respmap(m,:) = con_info(m).con_resp(loc);
            end
            
            % Sort the matrix
            [~,new_rowids] = sort(sum(respmap,2),'descend');
            [~,new_columnids] = sort(sum(respmap,1),2,'descend');
            tempo =  respmap(new_rowids,:);
            new_respmap = tempo(:,new_columnids);
            new_cnames = {common_cons{new_columnids}}; %#ok<CCAT1>
            tempo = {con_info.neuronname};
            new_rnames = {tempo{new_rowids}};
            
            respT = array2table(respmap);
            respT.Properties.VariableNames = new_cnames;
            respT.Properties.RowNames = new_rnames;
            
            
            
            % reordered waveforms length
            
            WLs = [con_info.wav_len].';
            WLs = WLs(new_rowids);
            
            wlfr_info = plotWavelengthVsFiringRate(s);
            
            names_in_wlfr = {wlfr_info.neuronname}.';
            [~,ids_for_reorder] = ismember(new_rnames,names_in_wlfr);
            new_wlfr_info = wlfr_info(ids_for_reorder);
            
            for k = 1: size(new_respmap,1)
                value_is_one_ids = find(new_respmap(k,:));
                if new_wlfr_info(k).isBS == 0
                    new_respmap(k,value_is_one_ids) = 1;
                elseif new_wlfr_info(k).isBS == 1
                    new_respmap(k,value_is_one_ids) = 3;
                end
            end
            
            frags_exist_names = s.markNeuronsWithFragsAsStimuli;
            
            for k = 1: size(new_respmap,1)
                value_is_one_ids = find(new_respmap(k,:));
                if ismember(new_wlfr_info(k).neuronname,frags_exist_names) && new_wlfr_info(k).isBS == 0
                    new_respmap(k,value_is_one_ids) = 2;
                elseif ismember(new_wlfr_info(k).neuronname,frags_exist_names) && new_wlfr_info(k).isBS == 1
                    new_respmap(k,value_is_one_ids) = 4;
                end
            end
            
            labled_tokeep = [];
            for k = 1: size(new_respmap,1)
                if ismember(4,new_respmap(k,:))
                    labled_tokeep = [labled_tokeep,k];
                end
            end
            
            labeled_respmap = new_respmap(labled_tokeep,:);
            
            
            fig = figure;
            % colormap('summer');
            imagesc(labeled_respmap);
            
            map = [ 1 1 1  % white for 0
                %                  0 0.4470 0.7410 % shallow blue for 1
                %                  0 0 1          % bright blue for 2
                %                  0.8500 0.3250 0.0980  % shallow red for 3
                1 0 0];        % bright red for 4
            % figure; viscircles([0,0],10,'Color',[0 0 1]);
            colormap(fig,map);
            caxis manual
            caxis([0 4]);
            % colorbar
            
            %colorbar;
            
            xticks(1:size(labeled_respmap,2));
            xticklabels(new_cnames);
            
            
            yticks(1:size(new_respmap,1));
            yticklabels({new_rnames{labled_tokeep}});
            set(gca,'TickLabelInterpreter','none');
            set(gca,'TickLength',[0.001, 0.001]);
            
            
            figure;
            
            summed_resps = sum(labeled_respmap,2)/4;
            
            histogram(summed_resps);
            xlabel('Number of response-eliciting songs');
            ylabel ('Number of BS neurons');
            
        end
        
        function wlfr_info = plotWavelengthVsFiringRate(s)
            
            wl_info = calWavelength(s);
            fr_info = multiRepeatsFiringRate(s);
            
            ids_in_fr = [];
            for k = 1: length(wl_info)
                ids_in_fr(k) = find(strcmp(wl_info(k).neuronname,{fr_info.neuronname}.'));
            end
            
            fr_info = fr_info(ids_in_fr); % re-order
            
            fr_info = rmfield( fr_info,'neuronname');
            
            wlfr_info = table2struct([struct2table(wl_info),struct2table(fr_info)]);
            
            fig = figure;
            h = scatter([wlfr_info.wl],[wlfr_info.mean_plt_fr]);
            xlabel('Mean Spike width');
            ylabel('Spontaneous Firing Rate');
            title('Brush BS neurons!');
            brush on
            pause(10)
            brush off
            title('');
            brushdata = logical(get(h, 'BrushData'));
            brushed_ids = find(brushdata);
            not_brushed_ids = find(brushdata == 0);
            [wlfr_info(:).isBS] = deal(0);
            for w = 1: length(brushed_ids)
                wlfr_info(brushed_ids(w)).isBS = 1;
            end
            close(fig);
            
            
            
            figure;
            hold on
            scatter([wlfr_info(brushed_ids).wl],[wlfr_info(brushed_ids).mean_plt_fr],[], [0.8500 0.3250 0.0980],'filled');
            scatter([wlfr_info(not_brushed_ids).wl],[wlfr_info(not_brushed_ids).mean_plt_fr],[],[0 0.4470 0.7410],'filled');
            xlabel('Mean Spike width');
            ylabel('Spontaneous Firing Rate');
            
            %disp(brushed);
            
            %             figure;
            %             scatter([wlfr_info.wl],[wlfr_info.mean_plt_fr]);
            %             xlabel('Mean Spike width');
            %             ylabel('Evoked Firing Rate');
        end
        
        function allSongallNeurons_FolderOrder(s) % 顺序是源文件夹的顺序
            
            % Extract binarized neuron's responses to CONs
            dbstop if error
            
            %             memData = memory;
            %             memLimit = memData.MemAvailableAllArrays*0.95;
            
            conkeywords = {'B346','B512','B521','B554','B606','G429','G506','G518','G548','G573',...
                'G578','O331','O507','O509','O540','Y515','Y606','Y616'};
            spekeywords = {'BOS','TUT','Fcall','Mcall','Het','WNS'};
            
            wb = waitbar(0,'Start processing');
            num_files = length(s.anas);
            % Dummy call to nUpdateWaitbar to initialise
            nUpdateWaitbar(num_files, wb);
            % Go back to simply calling nUpdateWaitbar with the data
            D = parallel.pool.DataQueue;
            afterEach(D, @nUpdateWaitbar);
            
            conallneurons = struct;
            ana_pathes = s.anas;
            for k = 1: length(ana_pathes)
                %                 memData = memory;
                %                 if memData.MemUsedMATLAB > memLimit
                %                     task = getCurrentTask();
                %                     cancel(task);
                %                 end
                
                loaded = load(ana_pathes{k});
                A = loaded.A;
                FRINFO  = A.multiRepeatsFiringRate;
                conallneurons(k).wl =  A.neurons{A.song_id}.calMeanWaveLength;
                conallneurons(k).neuronname = A.formated_name;
                conallneurons(k).mean_plt_fr = FRINFO.mean_plt_fr;
                
                for kk = 1: length(conkeywords) % for Cons
                    
                    thisid = find(~cellfun(@isempty,regexp(cellstr({A.list.stimuliname}.'),['norm\S+(?!(TUT|BOS))',conkeywords{kk},'(?!(TUT|BOS))'] )));
                    if length(thisid) == 1
                        conallneurons(k).figcon{kk} = A.list(thisid).image;
                    elseif isempty(thisid)
                        conallneurons(k).figcon{kk} = uint8(255*ones(size(A.list(1).image)));
                    else
                        conallneurons(k).figcon{kk} = A.list(thisid(1)).image; % 如果norm song 不只播放了一次
                    end
                end
                
                for kk = 1:length(spekeywords) %for Spes
                    
                    thisid = find(~cellfun(@isempty,regexp(cellstr({A.list.stimuliname}.'),['norm\S+',spekeywords{kk}] )));
                    if length(thisid) == 1
                        conallneurons(k).figspe{kk} = A.list(thisid).image;
                    elseif isempty(thisid)
                        conallneurons(k).figspe{kk} = uint8(255*ones(size(A.list(1).image)));
                    else
                        conallneurons(k).figspe{kk} = A.list(thisid(1)).image;
                    end
                end
                
                figure('Position',[2108 544 690 438],'color','w','Visible','off')
                A.neurons{A.song_id}.draw_waveform; % draw waveform plot
                frame = getframe(gcf);close(gcf);
                conallneurons(k).figwf = frame.cdata; % waveform figure
                
                send(D, 1);
                
            end
            
            close(wb);
            
            
            % draw the three plots
            Icollect = {}; % to collect figure frames for each pairwise three plots
            for k = 1: length(conallneurons)
                for kk = 1: length(conallneurons(k).figcon)
                    Icollect{k,kk} = conallneurons(k).figcon{kk};
                end
            end
            
            specollect = {}; % to collect figure frames for each pairwise three plots
            for k = 1: length(conallneurons)
                for kk = 1: length(conallneurons(k).figspe)
                    specollect{k,kk} = conallneurons(k).figspe{kk};
                end
            end
            
            wfIcollect = {};
            for g = 1: length(conallneurons);wfIcollect{g} = conallneurons(g).figwf;end
            Icollect = horzcat(Icollect,specollect,wfIcollect.');
            
            
            % draw neuron ids column
            nameIcollect = {};
            for g = 1: length(conallneurons)
                figure('Position',[2108 544 690 438],'color','w','menubar','none','Visible','off')
                ah = gca ;
                th = text(1,1,conallneurons(g).neuronname,'Interpreter','none','FontSize',51);
                set(ah,'visible','off','xlim',[0 2],'ylim',[0 2],'Position',[0 0 1 1]) ;
                set(th,'visible','on','HorizontalAlignment','center','VerticalAlignment','middle');
                frame = getframe(gcf);
                nameIcollect{g,1} = frame.cdata;
                close(gcf)
            end
            
            finalIcollect = horzcat(Icollect,nameIcollect);
            %finalI = cell2mat(finalIcollect);
            
            numperfig = 50;
            numsections = ceil(length(s.anas)/numperfig);
            
            for k = 1: numsections
                
                if k < numsections
                    Icollect_this_section = finalIcollect((k-1)*numperfig+1:numperfig*k,:);
                elseif k == numsections
                    Icollect_this_section = finalIcollect((k-1)*numperfig+1:end,:);
                end
                
                I_this_section = cell2mat(Icollect_this_section);
                t = Tiff(sprintf('原始顺序_Part%u.tiff',k),'w8');
                setTag(t,'ImageLength',size(I_this_section,1));
                setTag(t,'ImageWidth',size(I_this_section,2));
                setTag(t,'Photometric',Tiff.Photometric.RGB);
                setTag(t,'PlanarConfiguration',Tiff.PlanarConfiguration.Chunky);
                setTag(t,'BitsPerSample',8);
                setTag(t,'SamplesPerPixel',3);
                % write data
                write(t,I_this_section);
                close(t);
                
            end
            
            % subfunctiuon
            function p = nUpdateWaitbar(data, h)
                persistent TOTAL COUNT H
                if nargin == 2
                    % initialisation mode
                    H = h;
                    TOTAL = data;
                    COUNT = 0;
                else
                    % afterEach call, increment COUNT
                    COUNT = 1 + COUNT;
                    p = COUNT / TOTAL;
                    waitbar(p, H,sprintf('此为总共%u个神经元中的%u',TOTAL,COUNT));
                end
            end
            
            
        end
        
        function wlfr_info_pre = How_Could_NCM_Neurons_Be_Splitted_By_WL_And_FR(s)
            dbstop if error
            
            conkeywords = {'B346','B512','B521','B554','B606','G429','G506','G518','G548','G573',...
                'G578','O331','O507','O509','O540','Y515','Y606','Y616'};
            
            spekeywords = {'BOS','TUT','Fcall','Mcall','Het','WNS'};
            
            wb = waitbar(0,'Start processing');
            num_files = length(s.anas);
            % Dummy call to nUpdateWaitbar to initialise
            Utl.UpdateParforWaitbar(num_files, wb);
            % Go back to simply calling nUpdateWaitbar with the data
            D = parallel.pool.DataQueue;
            afterEach(D, @Utl.UpdateParforWaitbar);
            
            conallneurons = struct;
            ana_pathes = s.anas;
            parfor k = 1: length(ana_pathes) % should be par-for
                loaded = load(ana_pathes{k});
                A = loaded.A;
                % A.judgeConResp; % update con resp labels  % should be
                % removed later!
                FRINFO  = A.multiRepeatsFiringRate;
                conallneurons(k).wl =  A.neurons{A.song_id}.calMeanWaveLength;
                conallneurons(k).neuronname = A.formated_name;
                conallneurons(k).mean_pre_fr = FRINFO.mean_pre_fr;
                conallneurons(k).mean_plt_fr = FRINFO.mean_plt_fr;
                send(D, 1);
                
            end
            close(wb);
            
            for k = 1:length(conallneurons)
                conallneurons(k).mean_used_fr = conallneurons(k).mean_pre_fr;
            end
            
            
            wlfr_info_pre = Sultan.plotWLvsFR(conallneurons); %
            
            %             for k = 1:length(conallneurons)
            %                 conallneurons(k).mean_used_fr = conallneurons(k).mean_plt_fr;
            %             end
            %
            
            %             wlfr_info_plt = Sultan.plotWLvsFR(conallneurons)
            
            birdnames = unique(string(regexp(cellstr({wlfr_info_pre.neuronname}.'),'[BGRYO]\d{3}','match')));
            
            bird_number_info = struct;
            for k = 1: length(birdnames)
                bird_number_info(k).birdname = birdnames{k};
                bird_number_info(k).birdnum = length(find(~cellfun(@isempty, regexp(cellstr({wlfr_info_pre.neuronname}.'),birdnames{k}))));
                
            end
            
        end
        
        function conallneurons = How_Do_NCM_Neurons_respond_to_Songs(s)
            
            % Extract binarized neuron's responses to CONs
            dbstop if error
            
            conkeywords = {'B346','B512','B521','B554','B606','G429','G506','G518','G548','G573',...
                'G578','O331','O507','O509','O540','Y515','Y606','Y616'};
            
            spekeywords = {'BOS','TUT','Fcall','Mcall','Het','WNS'};
            
            wb = waitbar(0,'Start processing');
            num_files = length(s.anas);
            % Dummy call to nUpdateWaitbar to initialise
            Utl.UpdateParforWaitbar(num_files, wb);
            % Go back to simply calling nUpdateWaitbar with the data
            D = parallel.pool.DataQueue;
            afterEach(D, @Utl.UpdateParforWaitbar);
            
            conallneurons = struct;
            ana_pathes = s.anas;
            for k = 1: length(ana_pathes) % should be par-for
                loaded = load(ana_pathes{k});
                A = loaded.A;
                A.judgeConResp_FR;
                %A.judgeConResp; % update con resp labels
                FRINFO  = A.multiRepeatsFiringRate;
                conallneurons(k).wl =  A.neurons{A.song_id}.calMeanWaveLength;
                conallneurons(k).neuronname = A.formated_name;
                conallneurons(k).mean_used_fr = FRINFO.mean_pre_fr;
                
                for kk = 1: length(conkeywords) % for Cons
                    
                    thisid = find(~cellfun(@isempty,regexp(cellstr({A.list.stimuliname}.'),['norm\S+(?!(TUT|BOS))',conkeywords{kk},'(?!(TUT|BOS))'] )));
                    if length(thisid) == 1 % 当stimuli sets 有且只有一个对应song时
                        conallneurons(k).figcon{kk} = A.list(thisid).image;
                        conallneurons(k).con_biresp(kk) = A.list(thisid).label;
                    elseif isempty(thisid) % 没有对应song时
                        conallneurons(k).figcon{kk} = uint8(255*ones(size(A.list(1).image)));
                        conallneurons(k).con_biresp(kk) = 0;
                    else
                        conallneurons(k).figcon{kk} = A.list(thisid(1)).image; % 有多个对应时
                        conallneurons(k).con_biresp(kk) = A.list(thisid(1)).label;
                    end
                end
                
                for kk = 1:length(spekeywords) %for Spes
                    
                    thisid = find(~cellfun(@isempty,regexp(cellstr({A.list.stimuliname}.'),['norm\S+',spekeywords{kk}] )));
                    if length(thisid) == 1
                        conallneurons(k).figspe{kk} = A.list(thisid).image;
                        conallneurons(k).spe_biresp(kk) = A.list(thisid).label;
                    elseif isempty(thisid)
                        conallneurons(k).figspe{kk} = uint8(255*ones(size(A.list(1).image)));
                        conallneurons(k).spe_biresp(kk) = 0;
                    else
                        conallneurons(k).figspe{kk} = A.list(thisid(1)).image;
                        conallneurons(k).spe_biresp(kk) = A.list(thisid(1)).label;
                    end
                end
                
                figure('Position',[2108 544 690 438],'color','w','Visible','off')
                A.neurons{A.song_id}.draw_waveform; % draw waveform plot
                frame = getframe(gcf);close(gcf);
                conallneurons(k).figwf = frame.cdata; % waveform figure
                %waitbar(k/length(s.anas),wb,sprintf('%u of %u files',k,length(s.anas)));
                
                % Note we send only an "increment" for the waitbar.
                send(D, 1);
                
            end
            
            close(wb);
            
            con_respmap = cell2mat({conallneurons(:).con_biresp}.'); % old
            
            % Sort the matrix
            [~,new_rowids] = sort(sum(con_respmap,2),'descend');
            [~,new_columnids] = sort(sum(con_respmap,1),'descend');
            
            % edit（reorder） the struct based on matrix  sorting
            conallneurons = conallneurons(new_rowids);
            for k = 1: length(conallneurons)
                conallneurons(k).figcon = conallneurons(k).figcon(new_columnids);
                conallneurons(k).con_biresp = conallneurons(k).con_biresp(new_columnids);
            end
            
            new_con_respmap = cell2mat({conallneurons.con_biresp}.'); % new
            new_spe_respmap = cell2mat({conallneurons.spe_biresp}.'); % new
            new_cnames = {conkeywords{new_columnids}};
            wlfr_info = Sultan.plotWLvsFR(conallneurons); % To judge whether it is BS or NS
            
            for k = 1: size(new_con_respmap,1)
                is1 = find(new_con_respmap(k,:));
                if wlfr_info(k).isBS == 0
                    new_con_respmap(k,is1) = 1;
                elseif wlfr_info(k).isBS == 1
                    new_con_respmap(k,is1) = 2;
                end
            end
            
            for k = 1: size(new_spe_respmap,1)
                is1 = find(new_spe_respmap(k,:));
                if wlfr_info(k).isBS == 0
                    new_spe_respmap(k,is1) = 1;
                elseif wlfr_info(k).isBS == 1
                    new_spe_respmap(k,is1) = 2;
                end
            end
            
            % draw binary response-map
            new_rnames = {conallneurons.neuronname}.';
            %concat_respmap = horzcat(new_con_respmap,new_spe_respmap);
            concat_respmap = new_con_respmap;
            %             ysize = size(concat_respmap,1);
            %             xsize = size(concat_respmap,2);
            %             yvector = linspace(1,ysize,ysize);
            %             xvector = linspace(1,xsize,xsize);
            pcolormap = flip(concat_respmap);
            pcolormap = vertcat(zeros(1,size(pcolormap,2)),pcolormap);
            pcolormap = horzcat(pcolormap,zeros(size(pcolormap,1),1));
            bfig = figure; s = pcolor(pcolormap);
            s.EdgeColor = 'k';
            s.LineWidth = 1.6;
            %contour(concat_respmap,'LineColor','k');
            map = [ 1 1 1
                0 0.4470 0.7410
                0.8500 0.3250 0.0980];
            
            colormap(bfig,map);
            %colorbar;
            xticks(1:size(concat_respmap,2));
            xticklabels(horzcat(new_cnames,spekeywords));
            yticks(1:size(concat_respmap,1));
            yticklabels(new_rnames);
            set(gca,'TickLabelInterpreter','none');
            set(gca,'TickLength',[0.001, 0.001]);
            xtickangle(45)
            savefig(bfig,'Binary_Resp_Map.fig');
            
            
            % draw NS only map
            % ns_rows = find([wlfr_info(k).isBS] == 0)
            % draw the three plots
            Icollect = {}; % to collect figure frames for each pairwise three plots
            for k = 1: length(conallneurons)
                for kk = 1: length(conallneurons(k).figcon)
                    Icollect{k,kk} = conallneurons(k).figcon{kk};
                    if new_con_respmap(k,kk) ==1
                        Icollect{k,kk} = Convert.colorEdge(Icollect{k,kk},'r'); %NS neurons-red
                    elseif new_con_respmap(k,kk) ==2
                        Icollect{k,kk} = Convert.colorEdge(Icollect{k,kk},'b');
                    end
                end
            end
            
            specollect = {}; % to collect figure frames for each pairwise three plots
            for k = 1: length(conallneurons)
                for kk = 1: length(conallneurons(k).figspe)
                    specollect{k,kk} = conallneurons(k).figspe{kk};
                    if new_spe_respmap(k,kk) ==1
                        specollect{k,kk} = Convert.colorEdge(specollect{k,kk},'r'); %NS neurons-red
                    elseif new_spe_respmap(k,kk) ==2
                        specollect{k,kk} = Convert.colorEdge(specollect{k,kk},'b');
                    end
                end
            end
            
            wfIcollect = {};
            for g = 1: length(new_rowids)
                wfIcollect{g} = conallneurons(g).figwf;
            end
            Icollect = horzcat(Icollect,specollect,wfIcollect.');
            
            
            % draw neuron ids column
            nameIcollect = {};
            for g = 1: length(conallneurons)
                figure('Position',[2108 544 690 438],'color','w','menubar','none','Visible','off')
                ah = gca ;
                th = text(1,1,conallneurons(g).neuronname,'Interpreter','none','FontSize',51);
                set(ah,'visible','off','xlim',[0 2],'ylim',[0 2],'Position',[0 0 1 1]) ;
                set(th,'visible','on','HorizontalAlignment','center','VerticalAlignment','middle');
                frame = getframe(gcf);
                nameIcollect{g,1} = frame.cdata;
                close(gcf)
            end
            
            finalIcollect = horzcat(Icollect,nameIcollect);
            %finalI = cell2mat(finalIcollect);
            
            numperfig = 50;
            numsections = ceil(length(s.anas)/numperfig);
            
            for k = 1: numsections
                
                if k < numsections
                    Icollect_this_section = finalIcollect((k-1)*numperfig+1:numperfig*k,:);
                elseif k == numsections
                    Icollect_this_section = finalIcollect((k-1)*numperfig+1:end,:);
                end
                
                I_this_section = cell2mat(Icollect_this_section);
                t = Tiff(sprintf('BS更新排序_Part%u.tiff',k),'w8');
                setTag(t,'ImageLength',size(I_this_section,1));
                setTag(t,'ImageWidth',size(I_this_section,2));
                setTag(t,'Photometric',Tiff.Photometric.RGB);
                setTag(t,'PlanarConfiguration',Tiff.PlanarConfiguration.Chunky);
                setTag(t,'BitsPerSample',8);
                setTag(t,'SamplesPerPixel',3);
                % write data
                write(t,I_this_section);
                close(t);
                
            end
            

            
        end
              
        function arrangeThreePlotsByRespMapAndDraw_IncludeSPE(s)
            
            % Extract binarized neuron's responses to CONs
            dbstop if error
            con_info = struct;
            counts = 0;
            common_cons = {};
            common_spes = {};
            
            for k = 1: length(s.anas)
                load(s.anas{k});
                this_neuron = A.neurons{A.song_id};
                Conlist = Neuron(this_neuron).evaluateConResponse;
                if length(Conlist) >= 18 % hard code here
                    counts = counts + 1;
                    con_match = regexp({Conlist.stimuliname}.','CON-[BGYRO]\d{3}|TUT|BOS|Fcall|Mcall|WNS|Het','match');
                    con_ids = find(~cellfun(@isempty,con_match));
                    spe_match = regexp({Conlist.stimuliname}.','TUT|BOS|Fcall|Mcall|WNS','match');
                    spe_ids = find(~cellfun(@isempty,spe_match));
                    spe_match = [spe_match{spe_ids}].';
                    
                    % Extract con_label
                    con_info(counts).wav_len = this_neuron.calMeanWaveLength;
                    con_info(counts).neuronname = this_neuron.unique_neuronname;
                    con_info(counts).con_match = con_match;
                    con_info(counts).con_resp = [Conlist(con_ids).label].'; % resp is just label
                    con_info(counts).spe_match = spe_match;
                    con_info(counts).spe_resp = [Conlist(spe_ids).label].';
                    
                    
                end
            end
            
            % Hard coded conspecific songs
            common_cons = {'CON-B346','CON-B512','CON-B521','CON-B554','CON-B606','CON-G429','CON-G506','CON-G518','CON-G548',...
                'CON-G573','CON-G578','CON-O331','CON-O507','CON-O509','CON-O540','CON-Y515','CON-Y606','CON-Y616',...
                'Fcall','BOS','Het','Mcall','TUT','WNS'};
            
            % Extract binary con-resp map
            respmap = [];
            for m = 1: length(con_info)
                [ism,loc] = ismember(common_cons,[con_info(m).con_match{:}]);
                respmap(m, find(ism==0)) = nan; % 不存在的stimuli设定其resp值为nan
                % new_con_info(m).name = {con_info(m).con_match{loc}}.';
                respmap(m,loc(loc>0)) = con_info(m).con_resp(loc(loc>0));
            end
            
            
            % Sort the matrix
            [~,new_rowids] = sort(sum(respmap,2),'descend');
            [~,new_columnids] = sort(sum(respmap,1),2,'descend');
            tempo =  respmap(new_rowids,:);
            new_respmap = tempo(:,new_columnids);
            new_cnames = {common_cons{new_columnids}}; %#ok<CCAT1>
            tempo = {con_info.neuronname};
            new_rnames = {tempo{new_rowids}};
            
            respT = array2table(respmap);
            respT.Properties.VariableNames = new_cnames;
            respT.Properties.RowNames = new_rnames;
            
            
            
            % reordered waveforms length
            
            WLs = [con_info.wav_len].';
            WLs = WLs(new_rowids);
            
            wlfr_info = plotWavelengthVsFiringRate(s);
            
            names_in_wlfr = {wlfr_info.neuronname}.';
            [~,ids_for_reorder] = ismember(new_rnames,names_in_wlfr);
            new_wlfr_info = wlfr_info(ids_for_reorder);
            
            for k = 1: size(new_respmap,1)
                value_is_one_ids = find(new_respmap(k,:));
                if new_wlfr_info(k).isBS == 0
                    new_respmap(k,value_is_one_ids) = 1;
                elseif new_wlfr_info(k).isBS == 1
                    new_respmap(k,value_is_one_ids) = 3;
                end
            end
            
            frags_exist_names = s.markNeuronsWithFragsAsStimuli;
            
            for k = 1: size(new_respmap,1)
                value_is_one_ids = find(new_respmap(k,:));
                if ismember(new_wlfr_info(k).neuronname,frags_exist_names) && new_wlfr_info(k).isBS == 0
                    new_respmap(k,value_is_one_ids) = 2;
                elseif ismember(new_wlfr_info(k).neuronname,frags_exist_names) && new_wlfr_info(k).isBS == 1
                    new_respmap(k,value_is_one_ids) = 4;
                end
            end
            
            % draw the three plots
            Icollect = {}; % to collect figure frames for each pairwise three plots
            
            for z = 1: length(new_rowids)
                new_N_id =  new_rowids(z);  % reorder the neurons ranked by numnber of eliciting songs
                
                [e_songs,slist_songs] = s.anas{new_N_id}.neurons{s.anas{new_N_id}.song_id}.onlyExtractEphysOfSongs;
                converted_names = cellfun(@Convert.bid,{slist_songs.name}.','UniformOutput',0);
                [~,order_for_three_plots] = ismember(new_cnames, converted_names);
                
                
                for hh = 1: length(order_for_three_plots)
                    
                    if order_for_three_plots(hh)== 0
                        figure;
                        set(gcf,'Color','[.5 .5 .5 ]');
                        frame = getframe(gcf);
                        Icollect{z,hh} = frame.cdata;
                        close(gcf);
                        continue
                    end
                    
                    e_songs{order_for_three_plots(hh)}.three;
                    subplot(3,1,3);
                    xlabel(sprintf('Experiment:%s---Stimuli:%s',s.anas{new_N_id}.unique_neuronname,...
                        Convert.bid(e_songs{order_for_three_plots(hh)}.sound.name)),'Interpreter', 'none');
                    
                    switch(new_respmap(z,hh)) % change figure color based on resp and Experiment type
                        case 0
                            set(gcf,'Color','[1 1 1 ]')
                        case 1
                            set(gcf,'Color','[0 0.4470 0.7410]')
                        case 2
                            set(gcf,'Color','[0 0 1 ]')
                        case 3
                            set(gcf,'Color','[0.8500 0.3250 0.0980]')
                        case 4
                            set(gcf,'Color','[1 0 0]')
                    end
                    
                    frame = getframe(gcf);
                    Icollect{z,hh} = frame.cdata;
                    close(gcf);
                    
                    
                    
                end
                
            end
            
            %column_shuliang = size(Icollect,2);
            
            wfIcollect = {};
            for g = 1: length(new_rowids)
                s.anas{new_rowids(g)}.neurons{s.anas{new_rowids(g)}.song_id}.draw_waveform; % draw waveform plot
                %s.anas{new_rowids(g)}.draw_waveform; % draw waveform plot
                frame = getframe(gcf);
                wfIcollect{g,1} = frame.cdata;
                close(gcf)
            end
            Icollect = horzcat(Icollect,wfIcollect);
            
            
            % draw neuron ids column
            nameIcollect = {};
            for g = 1: length(new_rowids)
                figure('menubar','none','Color','w') ;
                ah = gca ;
                th = text(1,1,s.anas{new_rowids(g)}.unique_neuronname,'Interpreter','none','FontSize',57);
                set(ah,'visible','off','xlim',[0 2],'ylim',[0 2],'Position',[0 0 1 1]) ;
                set(th,'visible','on','HorizontalAlignment','center','VerticalAlignment','middle');
                frame = getframe(gcf);
                nameIcollect{g,1} = frame.cdata;
                close(gcf)
            end
            
            finalIcollect = horzcat(nameIcollect,Icollect);
            finalI = cell2mat(finalIcollect);
            
            imwrite(finalI,sprintf('AllNeurons_ColoredThree.png'));
            
        end
        
        function arrangeThreePlotsByRespMapAndDraw_NoWaveform(s)
            
            % Extract binarized neuron's responses to CONs
            dbstop if error
            con_info = struct;
            counts = 0;
            common_cons = {};
            common_spes = {};
            
            for k = 1: length(s.anas)
                load(s.anas{k});
                this_neuron = A.neurons{A.song_id};
                Conlist = Neuron(this_neuron).evaluateConResponse;
                if length(Conlist) >= 18 % hard code here
                    counts = counts + 1;
                    con_match = regexp(cellstr({Conlist.stimuliname}.'),'[BGYRO]\d{3}','match');
                    con_ids = find(~cellfun(@isempty,con_match));
                    spe_match = regexp(cellstr({Conlist.stimuliname}.'),'TUT|BOS|Fcall|Mcall|WNS','match');
                    spe_ids = find(~cellfun(@isempty,spe_match));
                    spe_match = [spe_match{spe_ids}].';
                    % remove TUT and BOS
                    con_ids = setdiff(con_ids,spe_ids);
                    con_match = [con_match{con_ids}].';
                    
                    % Extract con_label
                    con_info(counts).wav_len = this_neuron.calMeanWaveLength;
                    con_info(counts).neuronname = this_neuron.unique_neuronname;
                    con_info(counts).con_match = con_match;
                    con_info(counts).con_resp = [Conlist(con_ids).label].'; % resp is just label
                    con_info(counts).spe_match = spe_match;
                    con_info(counts).spe_resp = [Conlist(spe_ids).label].';
                    % find out Common Conspecific songs
                    if counts == 1
                        common_cons = con_info(counts).con_match;
                        %common_spes = con_info(counts).spe_match;
                    else
                        temp = intersect(common_cons,con_info(counts).con_match);
                        
                        common_cons = temp; % weird bugs happened when temp was not used
                        %                         temp = intersect(common_spes,con_info(counts).spe_match);
                        %                         common_spes = temp;
                        
                        
                    end
                    
                end
            end
            
            % Extract binary con-resp map
            respmap = [];
            for m = 1: length(con_info)
                [~,loc] = ismember (common_cons,con_info(m).con_match);
                
                % new_con_info(m).name = {con_info(m).con_match{loc}}.';
                respmap(m,:) = con_info(m).con_resp(loc);
            end
            
            
            % Extract spe-resp map
            common_spes = {'TUT','BOS','Fcall','Mcall','WNS'};
            spemap = [];
            for m = 1: length(con_info)
                
                if ~isempty(con_info(m).spe_match)
                    [~,loc] = ismember (common_spes,con_info(m).spe_match);
                else
                    [~,loc] = ismember (common_spes,{});
                end
                
                % new_con_info(m).name = {con_info(m).con_match{loc}}.';
                for mm = 1: length(loc)
                    if loc(mm) == 0
                        spemap(m,mm) = nan;
                    else
                        spemap(m,mm) = con_info(m).spe_resp(loc(mm));
                    end
                end
            end
            
            % Sort the matrix
            [~,new_rowids] = sort(sum(respmap,2),'descend');
            [~,new_columnids] = sort(sum(respmap,1),2,'descend');
            tempo =  respmap(new_rowids,:);
            new_respmap = tempo(:,new_columnids);
            %frozen_new_respmap = new_respmap;
            new_cnames = {common_cons{new_columnids}}; %#ok<CCAT1>
            tempo = {con_info.neuronname};
            new_rnames = {tempo{new_rowids}};
            
            respT = array2table(respmap);
            respT.Properties.VariableNames = new_cnames;
            respT.Properties.RowNames = new_rnames;
            
            % sort spe-map
            new_spemap = spemap(new_rowids,:);
            
            % reordered waveforms length
            
            WLs = [con_info.wav_len].';
            WLs = WLs(new_rowids);
            
            wlfr_info = plotWavelengthVsFiringRate(s);
            
            names_in_wlfr = {wlfr_info.neuronname}.';
            [~,ids_for_reorder] = ismember(new_rnames,names_in_wlfr);
            new_wlfr_info = wlfr_info(ids_for_reorder);
            
            for k = 1: size(new_respmap,1)
                value_is_one_ids = find(new_respmap(k,:));
                if new_wlfr_info(k).isBS == 0
                    new_respmap(k,value_is_one_ids) = 1;
                elseif new_wlfr_info(k).isBS == 1
                    new_respmap(k,value_is_one_ids) = 3;
                end
            end
            
            frags_exist_names = s.markNeuronsWithFragsAsStimuli;
            
            for k = 1: size(new_respmap,1)
                value_is_one_ids = find(new_respmap(k,:));
                if ismember(new_wlfr_info(k).neuronname,frags_exist_names) && new_wlfr_info(k).isBS == 0
                    new_respmap(k,value_is_one_ids) = 2;
                elseif ismember(new_wlfr_info(k).neuronname,frags_exist_names) && new_wlfr_info(k).isBS == 1
                    new_respmap(k,value_is_one_ids) = 4;
                end
            end
            
            % draw the three plots
            Icollect = {}; % to collect figure frames for each pairwise three plots
            
            for z = 1: length(new_rowids)
                new_N_id =  new_rowids(z);  % reorder the neurons ranked by numnber of eliciting songs
                
                [e_songs,slist_songs] = s.anas{new_N_id}.neurons{s.anas{new_N_id}.song_id}.onlyExtractEphysOfSongs;
                converted_names = cellfun(@Convert.bid,{slist_songs.name}.','UniformOutput',0);
                [~,order_for_three_plots] = ismember(new_cnames, converted_names);
                
                
                for hh = 1: length(order_for_three_plots)
                    e_songs{order_for_three_plots(hh)}.three;
                    subplot(3,1,3);
                    xlabel(sprintf('Experiment:%s---Stimuli:%s',s.anas{new_N_id}.unique_neuronname,...
                        Convert.bid(e_songs{order_for_three_plots(hh)}.sound.name)),'Interpreter', 'none');
                    
                    switch(new_respmap(z,hh)) % change figure color based on resp and Experiment type
                        case 0
                            set(gcf,'Color','[1 1 1 ]')
                        case 1
                            set(gcf,'Color','[0 0.4470 0.7410]')
                        case 2
                            set(gcf,'Color','[0 0 1 ]')
                        case 3
                            set(gcf,'Color','[0.8500 0.3250 0.0980]')
                        case 4
                            set(gcf,'Color','[1 0 0]')
                    end
                    frame = getframe(gcf);
                    Icollect{z,hh} = frame.cdata;
                    close(gcf);
                end
                
            end
            
            
            % draw neuron ids column
            nameIcollect = {};
            for g = 1: length(new_rowids)
                figure('menubar','none','Color','w') ;
                ah = gca ;
                th = text(1,1,s.anas{new_rowids(g)}.unique_neuronname,'Interpreter','none','FontSize',57);
                set(ah,'visible','off','xlim',[0 2],'ylim',[0 2],'Position',[0 0 1 1]) ;
                set(th,'visible','on','HorizontalAlignment','center','VerticalAlignment','middle');
                frame = getframe(gcf);
                nameIcollect{g,1} = frame.cdata;
                close(gcf)
            end
            
            finalIcollect = horzcat(nameIcollect,Icollect);
            finalI = cell2mat(finalIcollect);
            
            imwrite(finalI,sprintf('NoWaveform_AllNeurons_ColoredThree.png'));
            
        end
        
        function drawSongOnlyWaveformVsAllWaveform(s)
            
            dbstop if error
            con_info = struct;
            counts = 0;
            common_cons = {};
            common_spes = {};
            
            for k = 1: length(s.anas)
                this_neuron = s.anas{k}.neurons{s.anas{k}.song_id};
                Conlist = Neuron(this_neuron).evaluateConResponse;
                if length(Conlist) >= 18 % hard code here
                    counts = counts + 1;
                    con_match = regexp({Conlist.stimuliname}.','[BGYRO]\d{3}','match');
                    con_ids = find(~cellfun(@isempty,con_match));
                    spe_match = regexp({Conlist.stimuliname}.','TUT|BOS|Fcall|Mcall|WNS','match');
                    spe_ids = find(~cellfun(@isempty,spe_match));
                    spe_match = [spe_match{spe_ids}].';
                    % remove TUT and BOS
                    con_ids = setdiff(con_ids,spe_ids);
                    con_match = [con_match{con_ids}].';
                    % add TUT-BOS-Fcall-Mcall-WNS (Special)
                    % Extract con_label
                    con_info(counts).wav_len = this_neuron.calMeanWaveLength;
                    con_info(counts).neuronname = this_neuron.unique_neuronname;
                    con_info(counts).con_match = con_match;
                    con_info(counts).con_resp = [Conlist(con_ids).label].';
                    con_info(counts).spe_match = spe_match;
                    con_info(counts).spe_resp = [Conlist(spe_ids).label].';
                    % find out Common Conspecific songs
                    if counts == 1
                        common_cons = con_info(counts).con_match;
                    else
                        temp = intersect(common_cons,con_info(counts).con_match);
                        common_cons = temp; % weird bugs happened when temp was not used
                        if length(common_cons)< 18
                            pause
                        end
                    end
                    
                end
            end
            % Extract binary con-resp map
            respmap = [];
            for m = 1: length(con_info)
                [~,loc] = ismember (common_cons,con_info(m).con_match);
                
                % new_con_info(m).name = {con_info(m).con_match{loc}}.';
                respmap(m,:) = con_info(m).con_resp(loc);
            end
            % Sort the matrix
            [~,new_rowids] = sort(sum(respmap,2),'descend');
            
            
            Icollect = {};
            
            column_shuliang = size(Icollect,2);
            
            % first column song only waveform
            
            for g = 1: length(new_rowids)
                s.anas{new_rowids(g)}.neurons{s.anas{new_rowids(g)}.song_id}.draw_waveform; % draw waveform plot
                frame = getframe(gcf);
                Icollect{g, column_shuliang + 1} = frame.cdata;
                close(gcf)
            end
            
            column_shuliang = size(Icollect,2);
            
            % second column all waveforms
            for g = 1: length(new_rowids)
                s.anas{new_rowids(g)}.draw_waveform; % draw waveform plot
                frame = getframe(gcf);
                Icollect{g, column_shuliang + 1} = frame.cdata;
                close(gcf)
            end
            
            
            % neuron ids
            nameIcollect = {};
            parfor g = 1: length(new_rowids)
                figure('menubar','none','Color','w') ;
                ah = gca ;
                th = text(1,1,s.anas{new_rowids(g)}.unique_neuronname,'Interpreter','none','FontSize',57);
                set(ah,'visible','off','xlim',[0 2],'ylim',[0 2],'Position',[0 0 1 1]) ;
                set(th,'visible','on','HorizontalAlignment','center','VerticalAlignment','middle');
                frame = getframe(gcf);
                nameIcollect{g,1} = frame.cdata;
                close(gcf)
                
            end
            
            Icollect = horzcat(nameIcollect,Icollect);
            
            
            finalI = cell2mat(Icollect);
            
            
            imwrite(finalI,sprintf('SongOnlyWaveforms_Vs_AllWaveforms.png'));
            
            
            
            
        end
        
        function info = get_NumResp_WL_FR_Info(s)
            
            dbstop if error
            con_info = struct;
            counts = 0;
            common_cons = {};
            common_spes = {};
            
            for k = 1: length(s.anas)
                this_neuron = s.anas{k}.neurons{s.anas{k}.song_id};
                Conlist = Neuron(this_neuron).evaluateConResponse;
                if length(Conlist) >= 18 % hard code here
                    counts = counts + 1;
                    con_match = regexp({Conlist.stimuliname}.','[BGYRO]\d{3}','match');
                    con_ids = find(~cellfun(@isempty,con_match));
                    spe_match = regexp({Conlist.stimuliname}.','TUT|BOS|Fcall|Mcall|WNS','match');
                    spe_ids = find(~cellfun(@isempty,spe_match));
                    spe_match = [spe_match{spe_ids}].';
                    % remove TUT and BOS
                    con_ids = setdiff(con_ids,spe_ids);
                    con_match = [con_match{con_ids}].';
                    
                    
                    % add TUT-BOS-Fcall-Mcall-WNS (Special)
                    
                    % Extract con_label
                    con_info(counts).wav_len = this_neuron.calMeanWaveLength;
                    con_info(counts).neuronname = this_neuron.unique_neuronname;
                    con_info(counts).con_match = con_match;
                    con_info(counts).con_resp = [Conlist(con_ids).label].';
                    con_info(counts).spe_match = spe_match;
                    con_info(counts).spe_resp = [Conlist(spe_ids).label].';
                    % find out Common Conspecific songs
                    if counts == 1
                        common_cons = con_info(counts).con_match;
                        %common_spes = con_info(counts).spe_match;
                    else
                        temp = intersect(common_cons,con_info(counts).con_match);
                        
                        common_cons = temp; % weird bugs happened when temp was not used
                        %                         temp = intersect(common_spes,con_info(counts).spe_match);
                        %                         common_spes = temp;
                        
                        if length(common_cons)< 18
                            pause
                        end
                    end
                    
                end
            end
            
            
            % Extract binary con-resp map
            respmap = [];
            for m = 1: length(con_info)
                [~,loc] = ismember (common_cons,con_info(m).con_match);
                
                % new_con_info(m).name = {con_info(m).con_match{loc}}.';
                respmap(m,:) = con_info(m).con_resp(loc);
            end
            
            % Sort the matrix
            [~,new_rowids] = sort(sum(respmap,2),'descend');
            [~,new_columnids] = sort(sum(respmap,1),2,'descend');
            tempo =  respmap(new_rowids,:);
            new_respmap = tempo(:,new_columnids);
            new_cnames = {common_cons{new_columnids}}; %#ok<CCAT1>
            tempo = {con_info.neuronname};
            new_rnames = {tempo{new_rowids}};
            
            respT = array2table(respmap);
            respT.Properties.VariableNames = new_cnames;
            respT.Properties.RowNames = new_rnames;
            
            
            
            % reordered waveforms length
            
            WLs = [con_info.wav_len].';
            WLs = WLs(new_rowids);
            
            wlfr_info = plotWavelengthVsFiringRate(s);
            
            names_in_wlfr = {wlfr_info.neuronname}.';
            [~,ids_for_reorder] = ismember(new_rnames,names_in_wlfr);
            new_wlfr_info = wlfr_info(ids_for_reorder);
            
            for k = 1: size(new_respmap,1)
                value_is_one_ids = find(new_respmap(k,:));
                if new_wlfr_info(k).isBS == 0
                    new_respmap(k,value_is_one_ids) = 1;
                elseif new_wlfr_info(k).isBS == 1
                    new_respmap(k,value_is_one_ids) = 3;
                end
            end
            
            frags_exist_names = s.markNeuronsWithFragsAsStimuli;
            
            for k = 1: size(new_respmap,1)
                value_is_one_ids = find(new_respmap(k,:));
                if ismember(new_wlfr_info(k).neuronname,frags_exist_names) && new_wlfr_info(k).isBS == 0
                    new_respmap(k,value_is_one_ids) = 2;
                elseif ismember(new_wlfr_info(k).neuronname,frags_exist_names) && new_wlfr_info(k).isBS == 1
                    new_respmap(k,value_is_one_ids) = 4;
                end
            end
            
            labled_tokeep = [];
            for k = 1: size(new_respmap,1)
                if ismember(4,new_respmap(k,:))
                    labled_tokeep = [labled_tokeep,k];
                end
            end
            
            
            % add number of responsive songs into info
            for k = 1: length(new_wlfr_info)
                new_wlfr_info(k).numResp = length(find(new_respmap(k,:)));
                if ismember(new_wlfr_info(k).neuronname,frags_exist_names)
                    new_wlfr_info(k).fragexist = 1;
                else
                    new_wlfr_info(k).fragexist = 0;
                end
            end
            
            info = new_wlfr_info;
            
        end
        
        function WLvsNumberOfRespnsiveSongs(s)
            
            info = s.get_NumResp_WL_FR_Info;
            
            BSinfo = info(find([info.isBS]==1));
            
            figure('Color','w');
            subplot(1,3,1)
            scatter([BSinfo.numResp],[BSinfo.wl],[],[0.8500 0.3250 0.0980],'filled');
            xL=xlim;
            yL=ylim;
            ylim([yL(1),yL(2)]);
            [cc,p] = corrcoef([BSinfo.numResp],[BSinfo.wl]);
            text(0.99*xL(2),0.99*yL(2),sprintf('corr-coef: %.3f \n p-value: %.3f',cc(1,2),p(1,2)),'HorizontalAlignment','right','VerticalAlignment','top');
            xlabel('Number of response-eliciting songs');
            ylabel('Mean wavelength');
            
            subplot(1,3,2)
            scatter([BSinfo.numResp],[BSinfo.mean_plt_fr],[],[0.8500 0.3250 0.0980],'filled');
            xL=xlim;
            yL=ylim;
            [cc,p] = corrcoef([BSinfo.numResp],[BSinfo.mean_plt_fr]);
            text(0.99*xL(2),0.99*yL(2),sprintf('corr-coef: %.3f \n p-value: %.3f',cc(1,2),p(1,2)),'HorizontalAlignment','right','VerticalAlignment','top');
            xlabel('Number of response-eliciting songs');
            ylabel('Evoked firing rate');
            
            subplot(1,3,3)
            scatter([BSinfo.numResp],[BSinfo.mean_pre_fr],[],[0.8500 0.3250 0.0980],'filled');
            xL=xlim;
            yL=ylim;
            [cc,p] = corrcoef([BSinfo.numResp],[BSinfo.mean_pre_fr]);
            text(0.99*xL(2),0.99*yL(2),sprintf('corr-coef: %.3f \n p-value: %.3f',cc(1,2),p(1,2)),'HorizontalAlignment','right','VerticalAlignment','top');
            xlabel('Number of response-eliciting songs');
            ylabel('Spontaneous firing rate');
            
        end
        
        function WLvsNumberOfRespnsiveSongs_ImportClassifyInfo(s,path_classifyfile)
            
            classify_info = table2struct(readtable(path_classifyfile));
            
            class_id = {};
            fnames = fieldnames(classify_info);
            for k = 1: length(fnames)
                class_id{k} = rmmissing([classify_info.(fnames{k})].');
            end
            
            info = s.get_NumResp_WL_FR_Info;
            
            BSinfo = info(find([info.isBS]==1));
            
            temp = {BSinfo.neuronname}.';
            
            num_id = [];
            for k = 1: length(temp)
                guodu = split(temp{k},'_');
                num_id(k) = str2num(guodu{2}); % Extract num id from BSinfo
            end
            
            converted_id = {};
            for k = 1: length(class_id)
                [~,converted_id{k}] = ismember(class_id{k},num_id);
            end
            %converted_id regexp([info.neuronname]
            
            
            figure('Color','w');
            
            subplot(1,3,1)
            hold on
            for k = 1:length(converted_id)
                ids_todraw = converted_id{k}(converted_id{k}~=0); % remove zeros
                scatter([BSinfo(ids_todraw).numResp],[BSinfo(ids_todraw).wl],[],'filled');
            end
            %legend
            xL=xlim;
            yL=ylim;
            ylim([yL(1),yL(2)]);
            [cc,p] = corrcoef([BSinfo.numResp],[BSinfo.wl]);
            text(0.99*xL(2),0.99*yL(2),sprintf('corr-coef: %.3f \n p-value: %.3f',cc(1,2),p(1,2)),'HorizontalAlignment','right','VerticalAlignment','top');
            xlabel('Number of response-eliciting songs');
            ylabel('Mean wavelength');
            
            subplot(1,3,2)
            hold on
            for k = 1:length(converted_id)
                ids_todraw = converted_id{k}(converted_id{k}~=0); % remove zeros
                scatter([BSinfo(ids_todraw).numResp],[BSinfo(ids_todraw).mean_plt_fr],[],'filled');
            end
            %legend
            xL=xlim;
            yL=ylim;
            [cc,p] = corrcoef([BSinfo.numResp],[BSinfo.mean_plt_fr]);
            text(0.99*xL(2),0.99*yL(2),sprintf('corr-coef: %.3f \n p-value: %.3f',cc(1,2),p(1,2)),'HorizontalAlignment','right','VerticalAlignment','top');
            xlabel('Number of response-eliciting songs');
            ylabel('Evoked firing rate');
            
            subplot(1,3,3)
            hold on
            for k = 1:length(converted_id)
                ids_todraw = converted_id{k}(converted_id{k}~=0); % remove zeros
                scatter([BSinfo(ids_todraw).numResp],[BSinfo(ids_todraw).mean_pre_fr],[],'filled');
            end
            legend
            %scatter([BSinfo.numResp],[BSinfo.mean_pre_fr],[],[0.8500 0.3250 0.0980],'filled');
            xL=xlim;
            yL=ylim;
            [cc,p] = corrcoef([BSinfo.numResp],[BSinfo.mean_pre_fr]);
            text(0.99*xL(2),0.99*yL(2),sprintf('corr-coef: %.3f \n p-value: %.3f',cc(1,2),p(1,2)),'HorizontalAlignment','right','VerticalAlignment','top');
            xlabel('Number of response-eliciting songs');
            ylabel('Spontaneous firing rate');
            hold off
        end
        
        function drawThreePlots_withSongOnlyWaveforms(s)
            dbstop if error
            for k = 1: length(s.anas)
                loaded = load(s.anas{k});
                A = loaded.A;
                this_neuron = A.neurons{A.song_id};
                %this_neuron.three;
                this_neuron.selected_pltthree;
            end
        end
        
        function neuroninf = What_percent_are_neurons_tested_with_different_stimuli_sets(s)
            dbstop if error
            tic
            
            wb = waitbar(0,'Start processing');
            Utl.UpdateParforWaitbar(length(s.anas), wb);
            D = parallel.pool.DataQueue;
            afterEach(D, @Utl.UpdateParforWaitbar);
            
            neuroninf = struct;
            parfor k = 1:length(s.anas)
                loaded = load(s.anas{k});
                A = loaded.A;
                neuroninf(k).name = A.formated_name;
                neuroninf(k).path = s.anas{k};
                conids = find(~cellfun(@isempty, regexp([A.list.stimuliname].','norm|con')));
                if ~isempty(conids);neuroninf(k).conexist = 1; else;neuroninf(k).conexist = 0;end
                
                degids = find(~cellfun(@isempty, regexp([A.list.stimuliname].','Deg|deg')));
                if ~isempty(degids);neuroninf(k).degexist = 1; else;neuroninf(k).degexist = 0;end
                
                fragids = find(~cellfun(@isempty, regexp([A.list.stimuliname].','frag|Frag|syl|Syl')));
                if ~isempty(fragids);neuroninf(k).fragexist = 1; else;neuroninf(k).fragexist = 0;end
                
                replaids = find(~cellfun(@isempty, regexp([A.list.stimuliname].','Repla|repla|catego')));
                if ~isempty(replaids);neuroninf(k).replaexist = 1; else;neuroninf(k).replaexist = 0;end
                
                send(D, 1);
            end
            
            con_only = length(mintersect( find([neuroninf.conexist] ==1), find([neuroninf.degexist] == 0)));
            con_deg = length(mintersect( find([neuroninf.conexist] ==1), find([neuroninf.degexist] == 1),...
                find([neuroninf.replaexist] == 0), find([neuroninf.fragexist] == 0) ));
            con_deg_frag = length(mintersect( find([neuroninf.conexist] ==1), find([neuroninf.degexist] == 1),...
                find([neuroninf.replaexist] == 0), find([neuroninf.fragexist] == 1) ));
            con_deg_repla = length(mintersect( find([neuroninf.conexist] ==1), find([neuroninf.degexist] == 1),...
                find([neuroninf.replaexist] == 1), find([neuroninf.fragexist] == 0) ));
            con_deg__frag_repla = length(mintersect( find([neuroninf.conexist] ==1), find([neuroninf.degexist] == 1),...
                find([neuroninf.replaexist] == 1), find([neuroninf.fragexist] == 1) ));
            
            
            figure;
            pie([con_only,con_deg,con_deg_frag,con_deg_repla,con_deg__frag_repla],...
                {'CONs only','CONs/Degs','CONs/Degs/elements','CONs/Degs/replacements','All'});
            
            toc
            
            
            
            
            con_only2 = length(mintersect( find([neuroninf.conexist] ==1), find([neuroninf.degexist] == 0),...
                find([neuroninf.replaexist] == 0), find([neuroninf.fragexist] == 0) ));
            con_frag = length(mintersect( find([neuroninf.conexist] ==1), find([neuroninf.degexist] == 0),...
                find([neuroninf.replaexist] == 0), find([neuroninf.fragexist] == 1) ));
            con_repla = length(mintersect( find([neuroninf.conexist] ==1), find([neuroninf.degexist] == 0),...
                find([neuroninf.replaexist] == 1), find([neuroninf.fragexist] == 0) ));
            con_frag_repla = length(mintersect( find([neuroninf.conexist] ==1), find([neuroninf.degexist] == 0),...
                find([neuroninf.replaexist] == 1), find([neuroninf.fragexist] == 1) ));
            
            figure;
            pie([con_only2,con_frag,con_repla,con_frag_repla,con_deg,con_deg_frag,con_deg_repla,con_deg__frag_repla],...
                {'CONs only','CONs/elements','CONs/replacements','No Degs','CONs/Degs','No replacements','No elements','All'});
            
            toc
            
            
        end
        
        function WhereRespLocatesInSongs(s)
            
            dbstop if error
            
            wb = waitbar(0,'Start processing');
            Utl.UpdateParforWaitbar(length(s.anas), wb);
            D = parallel.pool.DataQueue;
            afterEach(D, @nUpdateWaitbar);
            
            
            
            conkeywords = {'B346','B512','B521','B554','B606','G429','G506','G518','G548','G573',...
                'G578','O331','O507','O509','O540','Y515','Y606','Y616'};
            
            respmap = [];
            for k = 1:length(s.anas)
                loaded = load(s.anas{k});
                insonglist = loaded.A.getInsongFragRespList;
                selected_ids = find(~cellfun(@isempty, regexp({insonglist.name}.',strjoin(conkeywords,'|'))));
                selectedlist = insonglist(selected_ids);
                respmap(k,:) = [selectedlist.label].';
                
                send(D, 1);
            end
            
            figure;
            imagesc(respmap)
            
        end
        
        function cdf_collect = Which_acoustic_feature_matters(s)
            % To draw the cumulative density function (cdf) of pairwise
            % feature distance
            dbstop if error
            wb = waitbar(0,'Start processing');
            Utl.UpdateParforWaitbar(length(s.anas), wb);
            D = parallel.pool.DataQueue;
            afterEach(D, @nUpdateWaitbar);
            cdf_collect = struct;
            for k = 1:length(s.anas) % parfor
                loaded = load(s.anas{k});
                A = loaded.A;
                if ~isempty(A.frag_id)
                    cdf_collect(k).neuronname = A.formated_name;
                    [cdf_collect(k).dists1_pitch,cdf_collect(k).dists0_pitch,cdf_collect(k).featurename{1}] = A.calCumulativeFeatureDiff('pitch');
                    [cdf_collect(k).dists1_amp,cdf_collect(k).dists0_amp,cdf_collect(k).featurename{2}] = A.calCumulativeFeatureDiff('amplitude');
                    [cdf_collect(k).dists1_FM,cdf_collect(k).dists0_FM,cdf_collect(k).featurename{3}] = A.calCumulativeFeatureDiff('FM');
                    [cdf_collect(k).dists1_AM,cdf_collect(k).dists0_AM,cdf_collect(k).featurename{4}] = A.calCumulativeFeatureDiff('AM');
                    [cdf_collect(k).dists1_good,cdf_collect(k).dists0_good,cdf_collect(k).featurename{5}] = A.calCumulativeFeatureDiff('goodness');
                    [cdf_collect(k).dists1_entro,cdf_collect(k).dists0_entro,cdf_collect(k).featurename{6}] = A.calCumulativeFeatureDiff('entropy');
                    send(D,1);
                end
                %             A.drawMeanFeaturesVsRespAsLineChart;
                %             A.draw_SortedRespToFrags;
            end
        end
         
        function How_Do_Resp_Eliciting_Elements_Distributed_In_Space(s,con_allspe_inf)
            dbstop if error
            %              fraginf = MetaStimuli.getAllTwoMotifEleinf("E:\StimuliSource");
            %              fraginf1 = fraginf(1:300);
            %              fraginf2 = fraginf(301:600);
            %              fraginf3 = fraginf(601:900);
            %              preprocessVrae(fraginf1);
            %               preprocessVrae(fraginf2);
            %              preprocessVrae(fraginf3);
            %              for p = 1: length(fraginf1)
            %                  fraginf1(p).coor_1 = coor_Z(p,1);
            %                  fraginf1(p).coor_2 = coor_Z(p,2);
            %              end
            %                for p = 1: length(fraginf2)
            %                  fraginf2(p).coor_1 = coor_Z(p,1);
            %                  fraginf2(p).coor_2 = coor_Z(p,2);
            %                end
            %               for p = 1: length(fraginf3)
            %                  fraginf3(p).coor_1 = coor_Z(p,1);
            %                  fraginf3(p).coor_2 = coor_Z(p,2);
            %               end
            %
            %               new_fraginf = horzcat(fraginf1,fraginf2,fraginf3);
            %
            %               con_allspe_inf = horzcat(new_fraginf,all_eleinf);
            %
            %               for k = 1: length(con_allspe_inf)
            %                   con_allspe_inf(k).fullname = sprintf('%s-%02u',con_allspe_inf(k).songname,con_allspe_inf(k).fragid);
            %
            %               end
            wb = waitbar(0,'Starting');
            for index = 1:length(s.anas)
                waitbar(index/length(s.anas),wb,'running');
                load(s.anas{index}); % k = 24 shi ting le
                A.judgeFragResp_FR;
                
                fraglist = A.list(find(~cellfun(@isempty, regexp(cellstr({A.list.stimuliname}.'),'Frag|frag|syl'))));
                
                for k = 1: length(fraglist)
                    tomatch = regexp(fraglist(k).stimuliname,'(?<=Frag-)\S+(?=-\d+Pulses)','match');
                    if isempty(tomatch)
                        continue
                    end
                    ids = find(~cellfun(@isempty, regexp(cellstr({con_allspe_inf.fullname}.'),tomatch)));
                    if length(ids)>1
                        fraglist(k).coor_1 = con_allspe_inf(ids(1)).coor_1;
                        fraglist(k).coor_2 = con_allspe_inf(ids(1)).coor_2;
                    elseif length(ids) == 1
                        fraglist(k).coor_1 = con_allspe_inf(ids).coor_1;
                        fraglist(k).coor_2 = con_allspe_inf(ids).coor_2;
                    end
                end
                
                
                figure;
                labe1_ids = find([fraglist.label].'== 1);
                if ~isempty(labe1_ids)
                    try
                        scatter([fraglist(labe1_ids).coor_1].',[fraglist(labe1_ids).coor_2].',[],[0 0.4470 0.7410],'filled')
                    catch ME
                    end
                end
                hold on
                labe0_ids = find([fraglist.label].'== 0);
                if ~isempty(labe0_ids)
                    try
                        scatter([fraglist(labe0_ids).coor_1].',[fraglist(labe0_ids).coor_2].',[],[0.8500 0.3250 0.0980],'filled')
                    catch ME
                    end
                end
                title(A.formated_name);
                
                saveas(gcf,sprintf('Scatter_%s.fig',A.formated_name));
                saveas(gcf,sprintf('PngScatter_%s.png',A.formated_name));
                close(gcf)
            end
            
            
        end  
        
    end
   
    methods(Static) % 新的静态方法
        
        function writeCONSPEFig(matdir)
            anafiles = Extract.filename(matdir,'*.mat');
            songkeywords = {'B346','B512','B521','B554','B606','G429','G506','G518','G548','G573',...
                'G578','O331','O507','O509','O540','Y515','Y606','Y616','BOS','TUT','Fcall','Mcall','Het','WNS'};
            
            img = {};
            for k = 1: length(anafiles)
                load(anafiles{k});
                
                for kk = 1: length(songkeywords)
                    
                    if length(find(~cellfun(@isempty, regexp([A.figdata.imagename].',songkeywords{kk})), 1)) ==1
                        img{k,kk} = A.figdata(find(~cellfun(@isempty, regexp([A.figdata.imagename].',songkeywords{kk})))).image;
                    elseif length(find(~cellfun(@isempty, regexp([A.figdata.imagename].',songkeywords{kk})), 1)) == 2
                        conid = setdiff(find(~cellfun(@isempty, regexp([A.figdata.imagename].',songkeywords{kk})),...
                            find(~cellfun(@isempty, regexp([A.figdata.imagename].','TUT|BOS')) )));
                        img{k,kk} = A.figdata(conid).image;
                    elseif length(find(~cellfun(@isempty, regexp([A.figdata.imagename].',songkeywords{kk})), 1)) == 0
                        img{k,kk} = uint8(255*ones(size(A.figdata(1).image))); % 如果keyword项不存在的话，把目标图像存为白色
                    end
                end
            end
            
            IMG = cell2mat(img);
            imwrite(IMG,'CON_SPE.png');
        end
        
        function conlist = plotWLvsFR(conlist)
            
            
            fig = figure;
            h = scatter([conlist.wl],[conlist.mean_used_fr]);
            xlabel('Mean Spike width');
            ylabel('Spontaneous Firing Rate');
            title('Brush BS neurons!');
            roi = drawfreehand;
            pause(15);
            xv = roi.Position(:,1);
            yv = roi.Position(:,2);
            
            for k = 1:length(conlist)
                
                conlist(k).isBS = inpolygon(conlist(k).wl,conlist(k).mean_used_fr,xv,yv); % brushed is BS
                
            end
            
            % %             brush on
            % %             pause(10)
            % %             brush off
            % %             title('');
            % %             brushdata = logical(get(h, 'BrushData'));
            % %             brushed_ids = find(brushdata);
            % %             not_brushed_ids = find(brushdata == 0);
            %             [conlist(:).isBS] = deal(0);
            %             for w = 1: length(brushed_ids)
            %                 conlist(brushed_ids(w)).isBS = 1;
            %             end
            %close(fig);
            
            brushed_ids = find([conlist.isBS] == 1);
            not_brushed_ids = find([conlist.isBS] == 0);
            figure;
            hold on                                                % used can be plt or pre
            scatter([conlist(brushed_ids).wl],[conlist(brushed_ids).mean_used_fr],[], [0.8500 0.3250 0.0980],'filled');
            scatter([conlist(not_brushed_ids).wl],[conlist(not_brushed_ids).mean_used_fr],[],[0 0.4470 0.7410],'filled');
            xlabel('Mean Spike width');
            ylabel('Spontaneous Firing Rate');
            savefig(gcf,'WL_Vs_FR_Plot.fig');
            
            %disp(brushed);
            
            %             figure;
            %             scatter([wlfr_info.wl],[wlfr_info.mean_plt_fr]);
            %             xlabel('Mean Spike width');
            %             ylabel('Evoked Firing Rate');
        end
        
        function How_DO_Neurons_Respond_To_Degressive_Songs
            
            
            
            num1 = 2;
            name1 = 'dddd';
            
            num2 = 2;
            name2 = 'dddd';
            
            num3 = 2;
            name3 = 'dddd';
            
            
            
            figure;
            pie([num1,num2,num3],...
                {name1,name2,name3});
            
            
        end
        
        function How_Many_NS_BS_Others(num_NS,num_BS,num_Others)
            
            
            
            
            name1 = 'NS';
            
            
            name2 = 'BS';
            
            
            name3 = 'No response';
            
            
            
            figure;
            pie([num_NS,num_BS,num_Others],...
                [0,1,0],... % explode
                {name1,name2,name3});
        end
        
        function How_Neurons_Resp_To_DegsFragsReplas(neuroninf)
            dbstop if error
            
            wb = waitbar(0,'Start processing');
            Utl.UpdateParforWaitbar(length(neuroninf), wb);
            D = parallel.pool.DataQueue;
            afterEach(D, @Utl.UpdateParforWaitbar);
            
            for k = 54:length(neuroninf) % bug in 45,53
                loaded = load(neuroninf(k).path);
                A = loaded.A;
                A.Whether_NeuResp_To_SinFrags_Coms_Or_FragsResps_affected_By_Pres;
                send(D,1);
            end
        end
        
        function copyANAFiles(inputanalist,targetdir)
            dbstop if error
            for k = 1:length(inputanalist)
                oldpath = inputanalist(k).filepath;
                
                [~,name,ext] = fileparts(oldpath);
                
                newpath = fullfile(targetdir,strcat(name,ext));
                copyfile(oldpath,newpath);
                
            end
            
            
        end
        
    end
    
    methods % 弃用方法
        
        function Deprecated_arrangeThreePlotsByRespMapAndDraw(s)
            
            % Extract binarized neuron's responses to CONs
            dbstop if error
            con_info = struct;
            counts = 0;
            common_cons = {};
            common_spes = {};
            
            for k = 1: length(s.anas)
                load(s.anas{k});
                this_neuron = A.neurons{A.song_id};
                Conlist = Neuron(this_neuron).evaluateConResponse;
                if length(Conlist) >= 18 % hard code here
                    counts = counts + 1;
                    con_match = regexp(cellstr({Conlist.stimuliname}.'),'[BGYRO]\d{3}','match');
                    con_ids = find(~cellfun(@isempty,con_match));
                    spe_match = regexp(cellstr({Conlist.stimuliname}.'),'TUT|BOS|Fcall|Mcall|WNS','match');
                    spe_ids = find(~cellfun(@isempty,spe_match));
                    spe_match = [spe_match{spe_ids}].';
                    % remove TUT and BOS
                    con_ids = setdiff(con_ids,spe_ids);
                    con_match = [con_match{con_ids}].';
                    
                    
                    % add TUT-BOS-Fcall-Mcall-WNS (Special)
                    
                    % Extract con_label
                    con_info(counts).wav_len = this_neuron.calMeanWaveLength;
                    con_info(counts).neuronname = A.formated_name;
                    con_info(counts).con_match = con_match;
                    con_info(counts).con_resp = [Conlist(con_ids).label].'; % resp is just label
                    con_info(counts).spe_match = spe_match;
                    con_info(counts).spe_resp = [Conlist(spe_ids).label].';
                    % find out Common Conspecific songs
                    if counts == 1
                        common_cons = con_info(counts).con_match;
                        %common_spes = con_info(counts).spe_match;
                    else
                        temp = intersect(common_cons,con_info(counts).con_match);
                        
                        common_cons = temp; % weird bugs happened when temp was not used
                        %                         temp = intersect(common_spes,con_info(counts).spe_match);
                        %                         common_spes = temp;
                        
                        if length(common_cons)< 18
                            pause
                        end
                    end
                    
                end
            end
            
            % Extract binary con-resp map
            respmap = [];
            parfor m = 1: length(con_info)
                [~,loc] = ismember (common_cons,con_info(m).con_match);
                
                % new_con_info(m).name = {con_info(m).con_match{loc}}.';
                respmap(m,:) = con_info(m).con_resp(loc);
            end
            
            
            % Extract spe-resp map
            common_spes = {'TUT','BOS','Fcall','Mcall','WNS'};
            spemap = [];
            for m = 1: length(con_info)
                
                if ~isempty(con_info(m).spe_match)
                    [~,loc] = ismember (common_spes,con_info(m).spe_match);
                else
                    [~,loc] = ismember (common_spes,{});
                end
                
                % new_con_info(m).name = {con_info(m).con_match{loc}}.';
                for mm = 1: length(loc)
                    if loc(mm) == 0
                        spemap(m,mm) = nan;
                    else
                        spemap(m,mm) = con_info(m).spe_resp(loc(mm));
                    end
                end
            end
            
            % Sort the matrix
            [~,new_rowids] = sort(sum(respmap,2),'descend');
            [~,new_columnids] = sort(sum(respmap,1),2,'descend');
            tempo =  respmap(new_rowids,:);
            new_respmap = tempo(:,new_columnids);
            new_cnames = {common_cons{new_columnids}}; %#ok<CCAT1>
            tempo = {con_info.neuronname};
            new_rnames = {tempo{new_rowids}};
            
            respT = array2table(respmap);
            respT.Properties.VariableNames = new_cnames;
            respT.Properties.RowNames = new_rnames;
            
            % sort spe-map
            new_spemap = spemap(new_rowids,:);
            
            % reordered waveforms length
            
            WLs = [con_info.wav_len].';
            WLs = WLs(new_rowids);
            
            wlfr_info = plotWavelengthVsFiringRate(s);
            
            names_in_wlfr = {wlfr_info.neuronname}.';
            [~,ids_for_reorder] = ismember(new_rnames.',names_in_wlfr);
            new_wlfr_info = wlfr_info(ids_for_reorder);
            
            for k = 1: size(new_respmap,1)
                value_is_one_ids = find(new_respmap(k,:));
                if new_wlfr_info(k).isBS == 0
                    new_respmap(k,value_is_one_ids) = 1;
                elseif new_wlfr_info(k).isBS == 1
                    new_respmap(k,value_is_one_ids) = 3;
                end
            end
            
            frags_exist_names = s.markNeuronsWithFragsAsStimuli;
            
            for k = 1: size(new_respmap,1)
                value_is_one_ids = find(new_respmap(k,:));
                if ismember(new_wlfr_info(k).neuronname,frags_exist_names) && new_wlfr_info(k).isBS == 0
                    new_respmap(k,value_is_one_ids) = 2;
                elseif ismember(new_wlfr_info(k).neuronname,frags_exist_names) && new_wlfr_info(k).isBS == 1
                    new_respmap(k,value_is_one_ids) = 4;
                end
            end
            
            % draw the three plots
            Icollect = {}; % to collect figure frames for each pairwise three plots
            
            for z = 1: length(new_rowids)
                new_N_id =  new_rowids(z);  % reorder the neurons ranked by numnber of eliciting songs
                loaded = load(s.anas{new_N_id});
                AA = loaded.A;
                [e_songs,slist_songs] = AA.neurons{AA.song_id}.onlyExtractEphysOfSongs;
                converted_names = cellfun(@Convert.bid,{slist_songs.name}.','UniformOutput',0);
                [~,order_for_three_plots] = ismember(new_cnames, cellstr(converted_names));
                
                
                for hh = 1: length(order_for_three_plots)
                    e_songs{order_for_three_plots(hh)}.pltthree;
                    subplot(3,1,3);
                    xlabel(sprintf('Experiment:%s---Stimuli:%s',AA.formated_name,...
                        Convert.bid(e_songs{order_for_three_plots(hh)}.sound.name)),'Interpreter', 'none');
                    
                    switch(new_respmap(z,hh)) % change figure color based on resp and Experiment type
                        case 0
                            set(gcf,'Color','[1 1 1 ]')
                        case 1
                            set(gcf,'Color','[0 0.4470 0.7410]')
                        case 2
                            set(gcf,'Color','[0 0 1 ]')
                        case 3
                            set(gcf,'Color','[0.8500 0.3250 0.0980]')
                        case 4
                            set(gcf,'Color','[1 0 0]')
                    end
                    
                    
                    
                    frame = getframe(gcf);
                    Icollect{z,hh} = frame.cdata;
                    close(gcf);
                    
                    
                    
                end
                
            end
            
            
            wfIcollect = {};
            for g = 1: length(new_rowids)
                figure('menubar','none','Color','w');
                load(s.anas{new_rowids(g)});
                A.neurons{A.song_id}.draw_waveform; % draw waveform plot
                %s.anas{new_rowids(g)}.draw_waveform; % draw waveform plot
                frame = getframe(gcf);
                wfIcollect{g,1} = frame.cdata;
                close(gcf)
            end
            Icollect = horzcat(Icollect,wfIcollect);
            
            
            % draw neuron ids column
            nameIcollect = {};
            for g = 1: length(new_rowids)
                load(s.anas{new_rowids(g)});
                figure('menubar','none','Color','w') ;
                ah = gca ;
                th = text(1,1,A.neuronname,'Interpreter','none','FontSize',57);
                set(ah,'visible','off','xlim',[0 2],'ylim',[0 2],'Position',[0 0 1 1]) ;
                set(th,'visible','on','HorizontalAlignment','center','VerticalAlignment','middle');
                frame = getframe(gcf);
                nameIcollect{g,1} = frame.cdata;
                close(gcf)
            end
            
            finalIcollect = horzcat(nameIcollect,Icollect);
            finalI = cell2mat(finalIcollect);
            
            imwrite(finalI,sprintf('AllNeurons_ColoredThree.png'));
            
        end
        
        function wlfr_info = plotWavelengthVsFiringRate_ImportClassifyInfo(s,path_classifyfile)
            
            wl_info = calWavelength(s);
            fr_info = multiRepeatsFiringRate(s);
            
            ids_in_fr = [];
            for k = 1: length(wl_info)
                this_nname = wl_info(k).neuronname;
                ids_in_fr(k) = find(strcmp(this_nname,{fr_info.neuronname}.'));
            end
            
            fr_info = fr_info(ids_in_fr); % re-order
            
            fr_info = rmfield( fr_info,'neuronname');
            
            wlfr_info = table2struct([struct2table(wl_info),struct2table(fr_info)]);
            
            %%%%%%%%%%% For classify
            classify_info = table2struct(readtable(path_classifyfile));
            
            class_id = {};
            fnames = fieldnames(classify_info);
            for k = 1: length(fnames)
                class_id{k} = rmmissing([classify_info.(fnames{k})].');
            end
            
            temp = {wlfr_info.neuronname}.';
            
            num_id = [];
            for k = 1: length(temp)
                guodu = split(temp{k},'_');
                num_id(k) = str2num(guodu{2}); % Extract num id from BSinfo
            end
            
            converted_id = {};
            for k = 1: length(class_id)
                [~,converted_id{k}] = ismember(class_id{k},num_id);
            end
            
            figure;
            hold on
            for k = 1:length(converted_id)
                ids_todraw = converted_id{k}(converted_id{k}~=0); % remove zeros
                scatter([wlfr_info(ids_todraw).wl],[wlfr_info(ids_todraw).mean_plt_fr],[],'filled');
            end
            legend
            hold off
            
            xlabel('Mean Spike width');
            ylabel('Spontaneous Firing Rate');
            
            
        end
        
    end
    
    methods(Static) %弃用的静态方法
        
        function all_info = getNeuronSuoYouDeInfo(anas_dir,path_classifyfile)
            dbstop if error
            ANAfiles = Extract.filename(anas_dir,'*.mat');
            
            for k = 1: length(ANAfiles)
                load(ANAfiles{k});
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % clculate wl_info = calWavelength(s);
                all_info(k).neuronname = A.neuronname;
                all_info(k).wl = A.calMeanWaveLength;
                
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % calculate fr_info = multiRepeatsFiringRate(s);
                
                all_info(k).neuronname = A.neuronname;
                
                sum_prelen = 0; % summed prey length
                concat_presptimes = []; % concatenated prey sptimes
                
                sum_pltlen = 0; %summed prey( stimuli y, not plty or rawy) length
                concat_pltsptimes = []; %  % concatenated y sptimes
                
                all_es = A.getAllEphysObject;
                for m = 1: length(all_es)
                    
                    
                    % for prey
                    all_info(k).presptimes{m} = all_es{m}.presptimes
                    all_info(k).preylen{m} = length(all_es{m}.y)/all_es{m}.fs;
                    all_info(k).repnum{m} = size(all_es{m}.presptimes,2);
                    temp = all_es{m}.presptimes.';
                    concat_presptimes = [concat_presptimes;vertcat(vertcat(temp{:}))+ sum_prelen];
                    sum_prelen = sum_prelen +  all_info(k).preylen{m};
                    
                    % for plty
                    all_info(k).pltsptimes{m} = all_es{m}.pltsptimes
                    all_info(k).pltlen{m} = length(all_es{m}.plty)/all_es{m}.fs;
                    temp = all_es{m}.pltsptimes.';
                    concat_pltsptimes = [concat_pltsptimes;vertcat(vertcat(temp{:}))+ sum_pltlen];
                    sum_pltlen = sum_pltlen +  all_info(k).pltlen{m};
                    
                end
                % for pre_y
                all_info(k).concat_pre_sptimes = concat_presptimes;
                all_info(k).concat_pre_len = sum_prelen;
                all_info(k).mean_pre_fr = length(concat_presptimes)/sum_prelen;
                
                % for plt_y
                all_info(k).concat_plt_sptimes = concat_pltsptimes;
                all_info(k).concat_plt_len = sum_pltlen;
                all_info(k).mean_plt_fr = length(concat_pltsptimes)/sum_pltlen;
                
                %all_info = rmfield( all_info,'neuronname');
                %wlfr_info = table2struct([struct2table(wl_info),struct2table(fr_info)]);
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%%%%% For classify
                classify_info = table2struct(readtable(path_classifyfile));
                
                Nid = regexp(regexp(ANAfiles{k},'_\d+','match'),'\d+','match');
                Nid = Nid{1};
                Nid = str2num(Nid{1});
                
                id_in_cla = find(ismember([classify_info.NeuronID].',Nid));
                all_info(k).neurontype = classify_info(id_in_cla).Type;
                all_info(k).reliableDeg = classify_info(id_in_cla).Deg;
                all_info(k).reliableFrag = classify_info(id_in_cla).Frag;
                all_info(k).reliableRepla = classify_info(id_in_cla).Repla;
                
                
            end
            
        end
        
        function runAllAnalysis(anas_dir)
            dbstop if error
            
            ANAfiles = Extract.filename(anas_dir,'*.mat');
            
            wuhu = waitbar(0,'Start processing');
            
            for m = 1 : length(ANAfiles)
                
                load(ANAfiles{m});
                if ~isempty(regexp(ANAfiles{m},'R690|R693|G649'))
                    A.set_eleinf("F:\Shared_Stimuli_Pool\CON_OTE_NoTUTBOS_eleinf.mat");
                else
                    A.set_eleinf("C:\Users\Zhehao\Dropbox (OIST)\SaveAllMatXlsData\My_eleinf\all_eleinf.mat");
                end
                %A.set_eleinf("Z:\Zhehao\Dropbox (OIST)\SaveAllMatXlsData\My_eleinf\all_eleinf.mat");
                A.V1drawMeanFeaturesInSongVsRespAsLineChart;
                A.drawDTWSimilarityMatrixBasedOnZscoredData;
                A.drawDTWSimilarityMatrix;
                A.drawCoeffOfFeaturesLinearFit;
                A.drawMeanFeatureVsResp;
                A.drawMeanFeaturesVsRespAsLineChart;
                A.drawPairwiseFragmentsMeanFeaturesDistribution;
                A.threePlotsWithPitch;
                A.V2drawMeanFeaturesInSongVsRespAsLineChart
                waitbar(m/length(ANAfiles),wuhu,sprintf('%u of totally %u files',m,length(ANAfiles)));
            end
            
            close(wuhu);
        end
        
        function runAllAnalysis_SimpleVersion(anas_dir)
            dbstop if error
            
            ANAfiles = Extract.filename(anas_dir,'*.mat');
            
            wuhu = waitbar(0,'Start processing');
            
            for m = 1 : length(ANAfiles)
                
                load(ANAfiles{m});
                %                  if ~isempty(regexp(ANAfiles{m},'R690|R693|G649'))
                %                      A.set_eleinf("F:\Shared_Stimuli_Pool\CON_OTE_NoTUTBOS_eleinf.mat");
                %                  else
                %                      A.set_eleinf("C:\Users\Zhehao\Dropbox (OIST)\SaveAllMatXlsData\My_eleinf\all_eleinf.mat");
                %                  end
                %A.set_eleinf("Z:\Zhehao\Dropbox (OIST)\SaveAllMatXlsData\My_eleinf\all_eleinf.mat");
                %A.V1drawMeanFeaturesInSongVsRespAsLineChart;
                %A.drawDTWSimilarityMatrixBasedOnZscoredData;
                %A.drawDTWSimilarityMatrix;
                %A.drawCoeffOfFeaturesLinearFit;
                %A.drawMeanFeatureVsResp;
                A.drawMeanFeaturesVsRespAsLineChart;
                %A.drawPairwiseFragmentsMeanFeaturesDistribution;
                A.threePlotsWithPitch;
                %A.V2drawMeanFeaturesInSongVsRespAsLineChart
                waitbar(m/length(ANAfiles),wuhu,sprintf('%u of totally %u files',m,length(ANAfiles)));
            end
            
            close(wuhu);
        end
        
        function pickNeurons_then_drawFragOrderArranged(anas_dir,unique_ids)
            dbstop if error
            
            ANAfiles = Extract.filename(anas_dir,'*.mat');
            selected_ids = [];
            for m = 1: length(unique_ids)
                selected_ids(m) = find(~cellfun(@isempty, regexp({ANAfiles{:}}.',num2str(unique_ids(m)))));
            end
            wuhu = waitbar(0,'Start processing');
            
            for k = 1:length(selected_ids)
                load(ANAfiles{selected_ids(k)});
                A.sort_frags_by_response_strength_and_then_draw
                waitbar(m/length(ANAfiles),wuhu,sprintf('%u of totally %u files',m,length(selected_ids)));
            end
            close(wuhu);
        end
        
        function drawReplaPlots_forEachAnalysis(analysis_dir)
            dbstop if error
            
            ANAfiles = Extract.filename(analysis_dir,'*.mat');
            wuhu = waitbar(0,'Start processing');
            for m = 1 : length(ANAfiles)
                load(ANAfiles{m});
                A.AlignReplasWithNormsThenDraw
                waitbar(m/length(ANAfiles),wuhu,sprintf('%u of totally %u files',m,length(ANAfiles)));
            end
            
            close(wuhu);
        end
        
        function runBatch(dirpath)
            if ~exist('dirpath','var')
                dirpath = './';
            end
            
            anapath = Extract.filename(dirpath,'*.mat');
            
            for k = 1:length(anapath)
                load(anapath{k});
                A.Whether_NeuResp_To_SinFrags_Coms_Or_FragsResps_affected_By_Pres;
            end
            
        end
        
        function applySameFunctionForAll(dirpath)
            dbstop if error
            %ana_files = Extract.filename("C:\Users\Zhehao\Desktop\FragRespAs_fromCDRF",'*.mat')
            ana_files = Extract.filename(dirpath,'*.mat');
            wb = waitbar(0,'Start processing');
            for k = 1: length(ana_files)
                
                load(ana_files{k});
                % functions to run
                try
                    %A.saveSeparatedWaveform;
                    for nid = 1:length(A.neurons)
                        A.neurons{nid}.rawthree;
                    end
                    A.sort_frags_by_response_strength_and_then_draw;
                    A.drawMeanFeaturesVsRespAsLineChart;
                    A.drawPairwiseFragmentsMeanFeaturesDistribution;
                    A.draw_CDF_And_PitchHarmo;
                catch ME
                end
                
                waitbar(k/length(ana_files),wb,sprintf('%u of totally %u files',k,length(ana_files)));
            end
            
        end
    end
    
end

