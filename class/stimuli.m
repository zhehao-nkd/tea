%%% a class to generate stimuli

% stimuli generator 


% segment songs to get a syllable table
% generate normalized songs
% generate reversed songs
% generate single syllables
% generate mirrored songs
% generate context replaced songs
% select syllable from different clusters
% add trigger channel

% the name of this class will be stimuli??? ort other names???

classdef stimuli < handle
    
    properties
        sylinf
        fs
        splited % splited is a struct for each song, by modifying the splited, like delete a syllable or, replace the y to the normalize y, or even replace the syllable to other syllables, ne wstimuli will be gnerated
        %%% That is to say, function normalize should be renewed to
        %%% become a general function. Used by all other fucntions to
        %%% assemble the syllable/elemnt within songs into a single song
    end
    
    methods
       
        function s = stimuli(sylinf)
            s.fs = 32000;
            s.sylinf = sylinf; % syllable information structure generated by class Neuron
            
        end
        
        function newsyl = normalize(s,singlesyl)
            % this normalize all element/syllable to have the same rms
            syl = singlesyl;
            
            for k = 1: length(syl)
                syl(k).y = constitute(syl(k).y,s.fs).normalized;
            end
            
            newsyl = syl;
        end
        
        function newsyl = normalize2(~,singlesyl,target_rms)
            % normalize to make the song have the same rms
            syl = singlesyl;
            ys = {syl(:).y}.';
            sumy = vertcat(ys{:});
            
            sumrms = rms(sumy);
            
            for k = 1: length(syl)
               
                ratio = target_rms/sumrms;
                syl(k).y = ratio*syl(k).y;
            end
            
            newsyl = syl;
        end
        
         function newsyl = highpass(s,singlesyl,hpf) % hpf is the high pass frequency
            % this normalize all element/syllable to have the same rms
            syl = singlesyl;
            
            for k = 1: length(syl)
                syl(k).y = highpass(syl(k).y, hpf,s.fs);
            end
            
            newsyl = syl;
        end
        
        function writenorm(s)
            
            splited = s.split;
            for m = 1: length(splited)
                syl = splited{m};
                newsyl = s.normalize(syl);
                summer = s.assemble(newsyl);
                audiowrite(sprintf('norm-%s.wav',string(unique({newsyl.sound}.'))),summer,s.fs);
                disp(string(unique({newsyl.sound}.')));
            end
        end
        
        
        function summed = assemble(s, singleinf) % a function to assemble constitute together
            
            
            thiss = singleinf;
            ys = {thiss.y}.';
            gaps = [thiss(:).pregap].';
            gaps(1) = 0; % replace the first pregap to 0,which is a inf
            
            for putin = 1: length(ys)
                normys{putin} = constitute(ys{putin},s.fs).normalized;
            end
            
            summed = [];
            
            for haris = 1: length(normys)
                summed = [summed;  normys{haris};zeros(int64(gaps(haris)*s.fs),1)];
            end
            
            
        end
        
        function splited = split(s) % input is the s.sylinf, output is the sylinf for each each song
            dbstop if error
            songs = unique({s.sylinf(:).sound}.');
            
            for kk = 1: length(songs)
                idxs = find( strcmp({s.sylinf(:).sound}.' ,songs{kk}) );
                if length(idxs) == 1
                    thisT = struct2table(s.sylinf(idxs),'AsArray',1);
                else
                    thisT =  struct2table(s.sylinf(idxs));
                end
                
                thisT = sortrows(thisT,'number');  % 这里可能会改   order the struct based on the syllable number
                splited{kk} = table2struct(thisT);
                
            end
            
        end
        
        
    end
    
    methods(Static)
        function sylinf = syl(dir) % this function convert songs from a folder into a single syl struct
            
            names = extract.filename(dir,'*.wav');
            sylinf = struct;
            count = 0;
            for idx = 1: length(names)
                [y,fs] = audioread(names{idx});
                
                [~,soundname,~] = fileparts(names{idx});
                
                frag = segment(y,fs).seg3;
                
                for k = 1: length(frag)
                    count = count + 1;
                    sylinf(count).sound = soundname;
                    sylinf(count).y = y(frag(k).initial:frag(k).terminal);
                    sylinf(count).initial = frag(k).initial;
                    sylinf(count).terminal = frag(k).terminal;
                    if k ~= 1
                        sylinf(count).pregap = (frag(k).initial - frag(k-1).terminal)/s.fs;
                    else
                        sylinf(count).pregap = inf; % pre-gap duration
                    end
                    sylinf(n).dur = length(sylinf(n).y)/s.fs;
                    
                end
                
            end
        end
    end
end