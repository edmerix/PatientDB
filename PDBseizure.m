classdef PDBseizure < handle
    % TODO: this could simply inherit from PDBevent, adding just number and
    % type properties.
    properties
        patient    (1,1)    PDBpatient
        number     (1,1)    uint16
        type       (1,1)    PDBseizureType = 'Unknown'
        onsetInfo           PDBonsetInfo
        files               PDBfile
        units               PDBunit
        multiunits          PDBmultiunit
        notes               char
    end
    
    properties (SetAccess = private, Hidden = true)
        
    end
    
    methods
        function obj = PDBseizure(patientObject, number, varargin)
            if nargin < 1 || isempty(patientObject)
                patientObject = PDBpatient('unknown');
            end
            if nargin < 2  || isempty(number)
                number = 0;
            end
            obj.patient = patientObject;
            obj.number = number;
            allowable = fieldnames(obj);
            if mod(length(varargin),2) ~= 0
                error('Inputs must be in name, value pairs');
            end
            for v = 1:2:length(varargin)
                if find(ismember(allowable,varargin{v}))
                    obj.(varargin{v}) = varargin{v+1};
                else
                    disp([9 'Not assigning ''' varargin{v} ''': not a field in PDBseizure']);
                end
            end
        end
        
        function file = addFile(obj, varargin)
            file = PDBfile();
            allowable = fieldnames(file);
            if mod(length(varargin),2) ~= 0
                error('Inputs must be in name, value pairs');
            end
            for v = 1:2:length(varargin)
                if find(ismember(allowable,varargin{v}))
                    file.(varargin{v}) = varargin{v+1};
                else
                    disp([9 'Not assigning ''' varargin{v} ''': not a field in PDBfile']);
                end
            end
            obj.files(end+1) = file;
        end
        
        function file = micros(obj)
            file = PDBfile();
            fTypes = [obj.files.type];
            ind = find(fTypes == 'micros' | fTypes == 'both');
            if isempty(ind)
                disp([9 'A micros file hasn''t been stored for this seizure'])
            else
                file = obj.files(ind);
            end
        end
        
        function file = macros(obj)
            file = PDBfile();
            fTypes = [obj.files.type];
            ind = find(fTypes == 'macros' | fTypes == 'both');
            if isempty(ind)
                disp([9 'A macros file hasn''t been stored for this seizure'])
            else
                file = obj.files(ind);
            end
        end
        
        function [nsx, onset, offset] = loadMicros(obj)
            if ~exist('NSxFile','file')
                error('Need NSxFile on the path to load micros files');
            end
            file = obj.micros();
            if ~isempty(file)
                onset = file.onset;
                offset = file.offset;
                nsx = NSxFile('filename',file.fullpath);
            else
                error('No micros file logged for this seizure');
            end
        end
        
        function [nsx, onset, offset] = loadMacros(obj)
            if ~exist('NSxFile','file')
                error('Need NSxFile on the path to load micros files');
            end
            file = obj.macros();
            if ~isempty(file)
                onset = file.onset;
                offset = file.offset;
                nsx = NSxFile('filename',file.fullpath('ns3'));
            else
                error('No macros file logged for this seizure');
            end
        end
        
        function onsetInfo = addOnsetInfo(obj,selectorType,selector,varargin)
            onsetInfo = PDBonsetInfo(obj.patient,'seizure',obj);
            
            if nargin < 3 || ~any(strcmp({'electrode','elec','eleclabel','electrodelabel','channel','chan','channumber','channelnumber'},selectorType))
                error('Must supply either an electrode label or a channel number as a name, value pair to assign onset info to (e.g. ''electrode'',''uTP4'' or ''channel'',41) as first and second input')
            end
            switch selectorType
                case {'electrode','elec','eleclabel','electrodelabel'}
                    ind = find(strcmp({obj.patient.electrodes.label},selector));
                    if isempty(ind)
                        error(['Cannot find ' selector ' in electrode list for this seizure. If necessary use addElectrode method on root PatientDB object'])
                    end
                case {'channel','chan','channumber','channelnumber'}
                    ind = find([obj.patient.electrodes.channel] == selector);
                    if isempty(ind)
                        error(['Cannot find channel ' num2str(selector) ' in electrode list for this seizure. If necessary use addElectrode method on root PatientDB object']);
                    end
                otherwise
                    error('Second input needs to either be electrode or channel (or shorthands of those)')
            end
            onsetInfo.electrode = obj.patient.electrodes(ind);
            if ~isempty(varargin)
                onsetInfo.addPattern(varargin{:});
                onsetInfo.removePattern('unk');
            end
            obj.onsetInfo(end+1) = onsetInfo;
            obj.patient.electrodes(ind).onsetInfo = onsetInfo;
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