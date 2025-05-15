classdef PDBonsetInfo < handle
    properties
        patient     (1,1)   PDBpatient
        seizure     (1,1)   PDBseizure
        electrode   (1,1)   PDBelectrode
        %location    (1,1)   PDBonsetLocation
    end
    
    properties (SetAccess = private, Hidden = true)
        % NOTE: IF ADDING NEW OPTIONS, PREPEND THEM TO THESE LISTS, DO NOT
        %       ADD THEM TO THE END OR IDENTITIES WILL BECOME
        %       CROSS-REFERENCED. PDBonsetInfo (this class) will check the
        %       integrity of this list automatically and alert the user if
        %       it has been altered other than adding new options at the
        %       beginning of the lists. If the list becomes longer than 16
        %       values then patternCode's type must be similarly increased.
        patterns = {'herald spike','low voltage fast','repetitive spiking','rhythmic slowing','other','unknown'};
        shorthands = {'HS','LVF','RepSp','RhySl','oth','unk'};
        patternCode  (1,1) int16 {mustBePositive,mustBeInteger} = 1
    end
    
    methods
        function obj = PDBonsetInfo(patientObject, varargin)
            obj.checkPatterns();
            if nargin < 1 || isempty(patientObject)
                patientObject = PDBpatient('unknown');
            end
            obj.patient = patientObject;
            allowable = fieldnames(obj);
            if mod(length(varargin),2) ~= 0
                error('Inputs must be in name, value pairs');
            end
            for v = 1:2:length(varargin)
                if find(ismember(allowable,varargin{v}))
                    obj.(varargin{v}) = varargin{v+1};
                else
                    disp([9 'Not assigning ''' varargin{v} ''': not a field in PDBonsetInfo']);
                end
            end
        end
        
        function addPattern(obj,varargin)
            obj.checkPatterns();
            bin = obj.patterns2binary(varargin{:});
            curVal = dec2bin(obj.patternCode,length(obj.patterns));
            curValArr = arrayfun(@str2double,curVal(:))'; % turn binary string into array
            newVal = bin | curValArr;
            obj.patternCode = bin2dec(arrayfun(@num2str,newVal));
        end
        
        function removePattern(obj,varargin)
            obj.checkPatterns();
            bin = obj.patterns2binary(varargin{:});
            curVal = dec2bin(obj.patternCode,length(obj.patterns));
            curValArr = arrayfun(@str2double,curVal(:))'; % turn binary string into array
            newVal = curValArr - bin;
            obj.patternCode = bin2dec(arrayfun(@num2str,newVal));
        end
        
        function overwritePattern(obj,varargin)
            obj.checkPatterns();
            bin = obj.patterns2binary(varargin{:});
            obj.patternCode = bin2dec(arrayfun(@num2str,bin));
        end
        
        function listPatterns(obj)
            obj.checkPatterns();
            disp('Current patterns available are: (shorthands in parentheses)')
            for p = 1:length(obj.patterns)
                disp([9 '-' 9 obj.patterns{p} 9 '(' obj.shorthands{p} ')'])
            end
            disp('Extras can be added before these options in the PDBonsetInfo class')
        end
        
        function [ptrn,shrt] = pattern(obj)
            obj.checkPatterns();
            curVal = dec2bin(obj.patternCode,length(obj.patterns));
            curValArr = arrayfun(@str2double,curVal);
            ptrn = obj.patterns(curValArr == 1);
            shrt = obj.shorthands(curValArr == 1);
        end
                
    end
    
    methods (Access = protected, Hidden = true)
        function ok = checkPatterns(obj)
            check = 'ITMWGSfqTqSizTmpuivol';
            ok = strcmp(cell2mat(obj.shorthands(end-5:end)),char(check-1));
            checkLong = 'ifsbme!tqjlfmpx!wpmubhf!gbtusfqfujujwf!tqjljohsizuinjd!tmpxjohpuifsvolopxo';
            okLong = strcmp(cell2mat(obj.patterns(end-5:end)),char(checkLong-1));
            if ~ok || ~okLong
                error('The internal pattern structure of PDBonsetInfo has been damaged. Please redownload a fresh copy or undo changes to the originals in the list')
            end
        end
        
        function [bin,binStr] = patterns2binary(obj,varargin)
            inds = false(length(varargin),length(obj.patterns));
            for v = 1:length(varargin)
                inds(v,:) = strcmpi(obj.patterns,varargin{v}) | strcmpi(obj.shorthands,varargin{v});
            end
            if length(varargin) == 1
                bin = inds;
            else
                bin = any(inds);
            end
            binStr = num2str(bin,'%i');
            for b = find(sum(inds,2) < 1) % if any didn't match, warn user
                disp([9 '''' varargin{b} ''' is not a pattern option, not including'])
            end
        end
    end
end

%-Current options and their shorthands and integer identities:
% herald spike          (HS)        32
% low voltage fast      (LVF)       16
% repetitive spiking    (RepSp)     8
% rhythmic slowing      (RhySl)     4
% other                 (oth)       2
% unknown               (unk)       1