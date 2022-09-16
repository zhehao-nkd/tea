classdef categoFrags
    %this class categorize eleinf by their spectral similarity
    
    properties
        global_eleinf 
    end
    
    methods
        
        function c = categoFrags(global_eleinf)
            c.global_eleinf = global_eleinf;
        end
        
        function unique_eleinf = eachsong(c)
            % this function categorize eleinf for each unique songname
            mergedeleinf = c.global_eleinf;
            songs = unique(cellstr({mergedeleinf.songname}.'));
            
            % this section split the whole eleinf to separated ones for each unique
            % songname
            for omega = 1: length(songs)
                
                this_ids = find( ~cellfun(@isempty, regexp(cellstr({mergedeleinf.songname}.'),songs{omega}))  );
                
                if isempty(this_ids) % in case that songname contain parentheses()
                    this_ids = find( ~cellfun(@isempty, regexp(cellstr({mergedeleinf.songname}.'),songs{omega}(1:end-1)))  );
                end
                
                bird_ele_collect{omega} = mergedeleinf(this_ids);
            end
            
            birdcollect = {};
            % wb = waitbar(0,'Categorizing Fragments...');
            for omega = 1: length(bird_ele_collect)
                birdcollect{omega} = categoFrags.core( bird_ele_collect{omega});
                %waitbar(omega/length(bird_ele_collect),wb,sprintf('Categorizing Fragments...%u of %u',omega,length(bird_ele_collect) ));
            end
            % close(wb);
            
            unique_eleinf = horzcat(birdcollect{:});
            
            %             fields = {};
            %             for p = 1: length(birdcollect)
            %                 fields{p} = fieldnames(birdcollect{p});
            %                 disp(fields{p}.')
            %                 disp(p)
            %             end
        end
        
        function output_fraginf = forall(c,thres)
            % categorize the global_eleinf as a whole
            if ~exist('thres','var')
                thres = 0.9;
            end
            output_fraginf = categoFrags.core(c.global_eleinf,thres);
            
        end
        function unique_eleinf = include_con(c,con_eleinf)
            % this function categorize eleinf for each unique songname
            oteeleinf = c.global_eleinf;
            
            parfor k = 1: length(oteeleinf)
                oteeleinf(k).normed_name = convert.bid(oteeleinf(k).songname); % normalized name of mergedeleinf;
                oteeleinf(k).type = 0; % 0 indicate the OTE eleinf (eleinf generated by songs other than selected songs)
            end
            
            parfor z = 1: length(con_eleinf)
                con_eleinf(z).normed_name = convert.bid(con_eleinf(z).songname); % normalized name of con_eleinf;
                con_eleinf(z).type = 1;
            end
            
            if isfield(con_eleinf,'catego')
                con_eleinf = rmfield(con_eleinf,'catego');
            end
            
            %             if isfield(oteeleinf,'fragI')
            %                 oteeleinf = rmfield(oteeleinf,'fragI');
            %             end
            
            mergedeleinf = horzcat(oteeleinf,con_eleinf);
            
            songs = unique(cellstr({mergedeleinf.normed_name}));
            
            
            % this section split the whole eleinf to separated ones for each unique
            % songname
            parfor omega = 1: length(songs)
                
                this_ids = find(~ cellfun(@isempty, regexp([mergedeleinf.normed_name].',songs{omega} )));
                
                bird_ele_collect{omega} = mergedeleinf(this_ids);
            end
            
            birdcollect = {};
            
            %wb = waitbar(0,'Categorizing Fragments...');
            parfor omega = 1: length(bird_ele_collect)
                
                birdcollect{omega} = categoFrags.core( bird_ele_collect{omega});
                % waitbar(omega/length(bird_ele_collect),wb,sprintf('Categorizing Fragments...%u of %u',omega,length(bird_ele_collect) ));
            end
            %close(wb);
            
            unique_eleinf = horzcat(birdcollect{:});
            
            %             fields = {};
            %             parfor p = 1: length(birdcollect)
            %                 fields{p} = fieldnames(birdcollect{p});
            %                 disp(fields{p}.')
            %                 disp(p)
            %             end
        end
    end
    
    
    
    methods(Static)
         function bird_eleinf = core(bird_eleinf, similarity_thres)
            % @-----@ This section is for finding the similar fragments
            frag_img = {};
            if isfield(bird_eleinf,'fragI')
                for u = 1: length(bird_eleinf)
                    frag_img{u} = bird_eleinf(u).fragI;
                end
            else % This code may be dangerous
                for k = 1:length(bird_eleinf)
                    fg = figure('Position',[1146 532 50 257])%,'Visible','off'); % a bug with visible off!!!!!!!$
                    draw.spec(bird_eleinf(k).y,bird_eleinf(k).fs);
                    set(gca,'xtick',[],'ytick',[]);
                    axis tight
                    %set(gca,'visible','off');
                    frag_img{k} = getframe(gca).cdata;
                    bird_eleinf(k).fragI = frag_img{k};
                    close(fg);
                end
                
            end
            
            %figure; montage(frag_img)
            
            heatmap_count = 0;
            %heatT = table;
            img_sim = []; % image similarityu matrix
            tic
            for z = 1: length(frag_img)
                for s = 1: length(frag_img)
                    img_sim(z,s) = ssim(frag_img{z},frag_img{s});
                    
                    % The following two lines are used to create the heat map
                    %heatmap_count = heatmap_count + 1;
                    %             heatT.first(heatmap_count) = z;
                    %             heatT.second(heatmap_count) = s;
                    %             heatT.sim(heatmap_count) = img_sim(z,s);
                    
                end
            end
            toc
            
            
            img_sim = (img_sim + img_sim.')/2; % make img_sim symmetric
            %min_sim = 0.7;% minimum similarity to sort fragments together
            % figure; imagesc(img_sim); % plotting
            %img_sim_tri = triu(img_sim,1); % triangular
            
            %figure; heatmap(heatT,'first','second','ColorVariable','sim')
            group = {}; %v this is very important for par-for
            
            if ~exist('similarity_thres','var')
                similarity_thres = 0.7; % default as 0.7
            end
            
            for c = 1:length(img_sim)
                group{c} = find(img_sim(c,:)>similarity_thres);  %% I don't know whether this value is good or not !!!!!!!
            end
            
            if isempty(group) % in case that group is empty
                for L = 1: length(bird_eleinf)
                    bird_eleinf(L).catego = L;
                end
                % remove field fragI
                if isfield(bird_eleinf,'fragI')
                    bird_eleinf = rmfield(bird_eleinf,'fragI');
                end
            
                return
            end
            
            
            num_of_catego = 0;
            not_accessed = linspace(1,length(group),length(group));
            categos = {};
            
            for k = 1 :length(group)
                if ismember(k,not_accessed)
                    
                    num_of_catego = num_of_catego + 1;
                    
                    categos{num_of_catego} =  group{k};
                    while sum(cellfun(@length,cellfun(@(x) intersect(categos{num_of_catego},x),group(not_accessed),'UniformOutput',0)))~= 0
                        ids= find(cellfun(@length,cellfun(@(x) intersect(categos{num_of_catego},x),group(not_accessed),'UniformOutput',0)));
                        categos{num_of_catego} = unique(horzcat(categos{num_of_catego}, horzcat( group{not_accessed(ids) })));
                        not_accessed(ids) = []; % delete accessed
                        disp('Loop!!!')
                    end
                    
                else
                    continue
                end
            end
            
            
            % assign the catego info to th eleinf
            
            for trump = 1: length(bird_eleinf)
                
                this_catego = find(cellfun(@(x) ismember(trump,x),categos));
                bird_eleinf(trump).catego = this_catego;
                
            end
            
            
            % remove field fragI
            bird_eleinf = rmfield(bird_eleinf,'fragI');
            
            %fprintf('Now__%u__of %u songs are processed',omega,length(songs));
            
            fprintf('祇今尚有清流月，曾照高王万马过')
            
            names = fieldnames(bird_eleinf );
            joined_name = join(names);
            disp(joined_name);
            
        end
    end
end

