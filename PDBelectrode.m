classdef PDBelectrode < handle
    properties
        patient         PDBpatient
        label           char        = ''
        channel         int16       = 0
        bundle          PDBelectrode
        onsetInfo       PDBonsetInfo
        units           PDBunit
        multiunits      PDBmultiunit
    end
    
    properties (SetAccess = private, Hidden = true)
        
    end
    
    methods
        function obj = PDBelectrode(patientObject, varargin)
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
                    disp([9 'Not assigning ''' varargin{v} ''': not a field in PDBelectrode']);
                end
            end
        end
        
        function name = getName(obj)
            name = cell(1,length(obj));
            for i = 1:length(obj)
                if obj(i).channel < 1
                    name{i} = obj(i).label;
                else
                    name{i} = ['channel ' num2str(obj(i).channel)];
                end
            end
            if length(obj) == 1
                name = name{1};
            end
        end
        
        function bank = getBank(obj)
            bank = cell(1,length(obj));
            for i = 1:length(obj)
                if obj(i).channel < 1
                    bank{i} = obj(i).label;
                    bank{i}(regexp(bank{i},'[\d]')) = [];
                else
                    bank{i} = 'unlabelled';
                end
            end
            if length(obj) == 1
                bank = bank{1};
            end
        end
        
        function bundle = getBundle(obj)
            bundle = obj.getBank();
        end
        
        function onsetInfo = addOnsetInfo(obj,seizureNumber,varargin)            
            if nargin < 2
                error('Must supply a seizure number as first input')
            end
            onsetInfo = PDBonsetInfo(obj.patient,'electrode',obj);
            if length(obj.patient.seizures) < seizureNumber || isempty(obj.patient.seizures(seizureNumber))
                error(['Seizure number ' num2str(seizureNumber) ' hasn''t been added for this patient yet. Use addSeizure method on root PatientDB object'])
            end
            onsetInfo.seizure = obj.patient.seizures(seizureNumber);
            
            if ~isempty(varargin)
                onsetInfo.addPattern(varargin{:});
                onsetInfo.removePattern('unk');
            end
            obj.onsetInfo = onsetInfo;
            obj.patient.seizures(seizureNumber).onsetInfo(end+1) = onsetInfo;
        end
        
        function printOnsetInfo(obj)
            for i = 1:length(obj.onsetInfo)
                if obj.onsetInfo(i).electrode.channel == 0
                    elecChan = [' electrode ' obj.onsetInfo(i).electrode.label];
                else
                    elecChan = [' channel ' num2str(obj.onsetInfo(i).electrode.channel)];
                end
                disp(['In seizure ' num2str(obj.onsetInfo(i).seizure.number) elecChan ' was ' strjoin(obj.onsetInfo(i).pattern,' & ')])
            end
        end
    end
end