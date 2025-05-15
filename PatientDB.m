classdef PatientDB < handle
    properties
        creationDate        datetime
        modifiedDate        datetime
        patients            struct
        seizures            PDBseizure
        electrodes          PDBelectrode
        units               PDBunit
        multiunits          PDBmultiunit
        markers             PDBevent
        info                char
    end
    
    properties (SetAccess = private, Hidden = true)
        
    end
    
    % Publicly accessible methods:
    methods
        function obj = PatientDB(info)
            if nargin >= 1 && ~isempty(info)
                obj.info = info;
            end
            obj.creationDate = datetime;
            obj.modifiedDate = datetime;
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Functions that adjust the internal data (without saving): %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%      
        function pt = addPatient(obj, identifier, varargin)
            if any(contains(fieldnames(obj.patients),identifier))
                pt = obj.patients.(identifier);
                disp([9 identifier ' already exists'])
                return;
            end
            obj.patients(1).(identifier) = PDBpatient(identifier,varargin{:});
            pt = obj.patients(1).(identifier);
            obj.modifiedDate = datetime;
        end
        
        function sz = addSeizure(obj, identifier, number, varargin)
            pt = obj.checkPatientExists(identifier);
            % Check if it already exists:
            [ids,nums] = obj.listSeizures();
            inds = find(strcmpi(ids,identifier) & nums == number, 1);
            % Add the seizure to the specified patient:
            if isempty(inds)
                sz = PDBseizure(pt, number, varargin{:});
                % Add the seizure to the PDB seizure list, as well as under the
                % patient:
                pt.seizures(number) = sz;
                obj.seizures(end+1) = sz;
                obj.modifiedDate = datetime;
            else
                disp([9 identifier ' seizure ' num2str(number) ' already exists'])
                sz = obj.seizures(inds(1));
                %{
                if length(pt.seizures) < number || pt.seizures(number).number < 1
                    pt.seizures(number) = sz;
                end
                %}
            end
        end
        
        function event = addEvent(obj, identifier, number, varargin)
            pt = obj.checkPatientExists(identifier);
            % Check if it already exists:
            [ids,nums] = obj.listEvents();
            inds = find(strcmpi(ids,identifier) & nums == number, 1);
            % Add the event to the specified patient:
            if isempty(inds)
                event = PDBevent(pt, varargin{:});
                % Add the event to the PDB markers list, as well as under the
                % patient:
                pt.markers(number) = event;
                obj.markers(end+1) = event;
                obj.modifiedDate = datetime;
            else
                disp([9 identifier ' event ' num2str(number) ' already exists'])
                event = obj.patients(1).(identifier).markers(number);
            end
        end
        
        function elec = addElectrode(obj, identifier, varargin)
            pt = obj.checkPatientExists(identifier);
            
            elec = PDBelectrode(pt, varargin{:});
            % check if electrode in the specified patient already exists 
            % before adding:
            [ids, chans, labels] = obj.listElectrodes();
            if elec.channel < 1
                inds = find(strcmpi(ids,identifier) & strcmpi(labels,elec.label));
            else
                inds = find(strcmpi(ids,identifier) & chans == elec.channel);
            end
            if isempty(inds)
                % Add the electrode to the specified patient, in the correct
                % location if it's a channel number:
                if elec.channel > 0
                    pos = elec.channel;
                else
                    pos = length(obj.patients(1).(identifier).electrodes) + 1;
                end
                obj.patients(1).(identifier).electrodes(pos) = elec;
                % Add the electrode to the PDB electrode list, as well as under
                % the patient:
                obj.electrodes(end+1) = elec;
                obj.modifiedDate = datetime;
            else
                disp([9 identifier ' electrode ' elec.getName() ' already exists'])
            end
        end
        
        function unit = addUnit(obj, identifier, varargin)
            pt = obj.checkPatientExists(identifier);
            
            dropList = zeros(1,4);
            elecLabel = find(strcmpi(varargin,'label'));
            isElec = false;
            isChan = false;
            if ~isempty(elecLabel) % electrode labels take precedence over chan nums
                elec = obj.checkElectrodeExists(identifier,varargin{elecLabel+1});
                isElec = true;
                dropList(1) = elecLabel;
                dropList(2) = elecLabel + 1;
            else
                chanNum = find(strcmpi(varargin,'channel'));
                if ~isempty(chanNum)
                    elec = obj.checkChannelExists(identifier,varargin{chanNum+1});
                    isChan = true;
                    dropList(1) = chanNum;
                    dropList(2) = chanNum + 1;
                end
            end
            
            if ~isElec && ~isChan
                error('Need to provide either an electrode label or channel number, in name value pairs (''label'' or ''channel'')');
            end
            
            dropList(dropList < 1) = [];
            varargin(dropList) = [];
            
            isSeizure = find(strcmpi(varargin,'seizure'));
            isIED = find(strcmpi(varargin,'IED'));
            dropList = zeros(1,4);
            if ~isempty(isSeizure)
                sznum = varargin{isSeizure + 1};
                dropList(1) = isSeizure;
                dropList(2) = isSeizure + 1;
            end
            if ~isempty(isIED)
                IEDnum = varargin{isIED + 1};
                dropList(3) = isIED;
                dropList(4) = isIED + 1;
            end
            dropList(dropList < 1) = [];
            varargin(dropList) = [];
            unit = PDBunit(pt, varargin{:});
            unit.electrode = elec;
            UID = length(obj.units) + 1;
            unit.UID = UID;
            obj.units(UID) = unit;
            
            pt.units(end+1) = unit;
            elec.units(end+1) = unit;
            
            if ~isempty(isSeizure)
                sz = obj.checkSeizureExists(identifier,sznum);
                unit.relatedSeizure = sz;
                sz.units(end+1) = unit;
            end
            
            if ~isempty(isIED)
                event = obj.checkEventExists(identifier,IEDnum);
                unit.relatedEvent = event;
                event.units(end+1) = unit;
            end
            
            obj.modifiedDate = datetime;
                
        end
        
        function multiunit = addMultiunit(obj, identifier, varargin)
            pt = obj.checkPatientExists(identifier);
            
            dropList = zeros(1,4);
            elecLabel = find(strcmpi(varargin,'label'));
            isElec = false;
            isChan = false;
            if ~isempty(elecLabel) % electrode labels take precedence over chan nums
                elec = obj.checkElectrodeExists(identifier,varargin{elecLabel+1});
                isElec = true;
                dropList(1) = elecLabel;
                dropList(2) = elecLabel + 1;
            else
                chanNum = find(strcmpi(varargin,'channel'));
                if ~isempty(chanNum)
                    elec = obj.checkChannelExists(identifier,varargin{chanNum+1});
                    isChan = true;
                    dropList(1) = chanNum;
                    dropList(2) = chanNum + 1;
                end
            end
            
            if ~isElec && ~isChan
                error('Need to provide either an electrode label or channel number, in name value pairs (''label'' or ''channel'')');
            end
            
            dropList(dropList < 1) = [];
            varargin(dropList) = [];
            
            isSeizure = find(strcmpi(varargin,'seizure'));
            isIED = find(strcmpi(varargin,'IED'));
            dropList = zeros(1,4);
            if ~isempty(isSeizure)
                sznum = varargin{isSeizure + 1};
                dropList(1) = isSeizure;
                dropList(2) = isSeizure + 1;
            end
            if ~isempty(isIED)
                IEDnum = varargin{isIED + 1};
                dropList(3) = isIED;
                dropList(4) = isIED + 1;
            end
            dropList(dropList < 1) = [];
            varargin(dropList) = [];
            multiunit = PDBmultiunit(pt, varargin{:});
            multiunit.electrode = elec;
            UID = length(obj.multiunits) + 1;
            multiunit.UID = UID;
            obj.multiunits(UID) = multiunit;
            
            pt.multiunits(end+1) = multiunit;
            elec.multiunits(end+1) = multiunit;
            
            if ~isempty(isSeizure)
                sz = obj.checkSeizureExists(identifier,sznum);
                multiunit.relatedSeizure = sz;
                sz.multiunits(end+1) = multiunit;
            end
            
            if ~isempty(isIED)
                event = obj.checkEventExists(identifier,IEDnum);
                multiunit.relatedEvent = event;
                event.multiunits(end+1) = multiunit;
            end
            
            obj.modifiedDate = datetime;
                
        end
        
        function linkBundles(obj,identifier)
            % Automatically find electrodes that came from the same bundle
            % and link them together. With no input argument it will run on
            % all patients, otherwise it will run only on the patient
            % identifier(s) provided as the first input (use a cell array
            % for multiple)
            % (Note, Utah arrays get automatically grouped as a bundle in
            % this method)
            if nargin < 2 || isempty(identifier)
                identifier = fieldnames(obj.patients);
            elseif ~iscell(identifier)
                identifier = {identifier};
            end
            for i = 1:length(identifier)
                elecs = obj.patients.(identifier{i}).electrodes;
                banks = elecs.getBank();
                for e = 1:length(elecs)
                    inds = strcmp(banks,banks{e});
                    elecs(e).bundle = elecs(inds);
                end
            end
            obj.modifiedDate = datetime;
        end
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Functions that do not adjust the internal data at all: %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [identifiers, numbers] = listSeizures(obj)
            if isempty(obj.seizures)
                identifiers = {};
                numbers = [];
                return;
            end
            numbers = [obj.seizures.number];
            identifiers = cell(1,length(obj.seizures));
            for s = 1:length(obj.seizures)
                identifiers{s} = obj.seizures(s).patient.id;
            end
        end
        
        function [identifiers, numbers] = listEvents(obj)
            if isempty(obj.markers)
                identifiers = {};
                numbers = [];
                return;
            end
            numbers = [obj.markers.number];
            identifiers = cell(1,length(obj.markers));
            for i = 1:length(obj.markers)
                identifiers{i} = obj.markers(i).patient.id;
            end
        end
        
        function [identifiers, channels, labels] = listElectrodes(obj)
            if isempty(obj.electrodes)
                identifiers = {};
                channels = [];
                labels = {};
                return;
            end
            channels = [obj.electrodes.channel];
            labels = {obj.electrodes.label};
            identifiers = cell(1,length(obj.electrodes));
            for e = 1:length(obj.electrodes)
                identifiers{e} = obj.electrodes(e).patient.id;
            end
        end
        
        function data = getSeizures(obj, varargin)
            %TODO: write this help section! (explain the "allowable"
            %selectors below, which make up varargin) Remember that label
            %and channel inputs can be a cell array/vector respectively, so
            %you only select seizures that had all of the requested values.
            allowable = {'patient', 'type', 'implantType', 'label', 'channel'};
            criteria.patient = [];
            criteria.type = [];
            criteria.implantType = [];
            criteria.label = [];
            criteria.channel = [];
            allowableCriteria = fieldnames(criteria);
            if mod(length(varargin),2) ~= 0
                error('Input selectors must be in name, value pairs');
            end
            for v = 1:2:length(varargin)
                if find(ismember(allowableCriteria,varargin{v}))
                    criteria.(varargin{v}) = varargin{v+1};
                else
                    disp([9 'Not assigning ''' varargin{v} ''': not a selctor in select() method']);
                end
            end
            % go through each criterion, create a logical index vector for
            % each, then && them all together and return the list of
            % requested objects
            ptList = [obj.seizures.patient];
            ptIDs = {ptList.id};
            implantTypes = {ptList.implantType};
            elecs = {ptList.electrodes};
            
            matches = ones(length(allowable),length(ptIDs)); % start by matching everything
            if ~isempty(criteria.patient)
                matches(strcmp(allowable,'patient'),:) = ~cellfun(@isempty,regexp(ptIDs,regexptranslate('wildcard',criteria.patient)));
            end
            if ~isempty(criteria.type)
                matches(strcmp(allowable,'type'),:) = double([obj.seizures.type]) == double(PDBseizureType.(criteria.type));
            end
            if ~isempty(criteria.implantType)
                matches(strcmp(allowable,'implantType'),:) = ~cellfun(@isempty,regexp(implantTypes,regexptranslate('wildcard',criteria.implantType)));
            end
            if ~isempty(criteria.label)
                for e = 1:length(elecs)
                    if isempty(elecs{e})
                        matches(strcmp(allowable,'label'),e) = 0;
                    else
                        if iscell(criteria.label)
                            matchInner = zeros(1,length(criteria.label));
                            for c = 1:length(criteria.label)
                                matchInner(c) = max(~cellfun(@isempty,regexp({elecs{e}.label},regexptranslate('wildcard',criteria.label{c}))));
                            end
                            matches(strcmp(allowable,'label'),e) = min(matchInner); % only accept seizures that had all requested electrode labels
                        else
                            %matches(strcmp(allowable,'label'),e) = max(contains({elecs{e}.label},criteria.label)); %(this method is concise but doesn't allow for wildcards)
                            matches(strcmp(allowable,'label'),e) = max(~cellfun(@isempty,regexp({elecs{e}.label},regexptranslate('wildcard',criteria.label))));
                        end
                    end
                end
            end
            if ~isempty(criteria.channel)
                for e = 1:length(elecs)
                    if isempty(elecs{e})
                        matches(strcmp(allowable,'channel'),e) = 0;
                    else
                        matchInner = zeros(1,length(criteria.channel));
                        for c = 1:length(criteria.channel)
                            matchInner(c) = any([elecs{e}.channel] == criteria.channel(c));
                        end
                        matches(strcmp(allowable,'channel'),e) = min(matchInner); % only accept seizures that had all requested channel numbers
                    end
                end
            end
            
            matched = min(matches) == 1;
            data = obj.seizures(matched);
        end
        
        function save(obj,where)
            if nargin < 2 || isempty(where)
                where = '/storage/software/PatientDB/PatientDB.mat';
            end
            obj.backup();
            %{
            % Using this method makes a larger file than using the save 
            % function, because it saves an instance of the whole class,
            % causing it to save the full workspace, or something.
            mat = matfile(where,'Writable',true);
            mat.pdb = obj;
            %}
            pdb = obj;
            save(where,'pdb');
            clear pdb
        end
        
        function backup(obj,varargin)
            settings.path = mfilename('fullpath');
            settings.path = [fileparts(settings.path) filesep 'backups'];
            settings.name = 'pdb';
            
            allowable = fieldnames(settings);
            if mod(length(varargin),2) ~= 0
                error('Inputs must be in name, value pairs');
            end
            for v = 1:2:length(varargin)
                if find(ismember(allowable,varargin{v}))
                    settings.(varargin{v}) = varargin{v+1};
                else
                    disp([9 'Not assigning ''' varargin{v} ''': not an option in PatientDB.backup()']);
                end
            end
            if ~strcmp(settings.name,'pdb')
                warning('Backups now require the variable to be called pdb to avoid larger file saves');
            end
            
            if ~exist(settings.path,'dir')
                mkdir(settings.path);
            end
            
            dt = datetime;
            oldInfo = obj.info;
            obj.info = ['Backup at ' char(dt)];
            dt.Format = 'uuuuMMdd_HHmmss';
            savename = [settings.path filesep 'PatientDB_backup_' char(dt) '.mat'];
            %{
            % Same issue with larger files as mentioned in .save() above.
            % Which is a shame, because I like the ability to choose what
            % the variable is saved as, and don't want to use eval.
            mat = matfile(savename,'Writable',true);
            mat.(settings.name) = obj;
            disp(['Saved backup as variable ''' settings.name ''' in:'])
            disp([9 savename]);
            clear mat
            %}
            pdb = obj;
            save(savename,'pdb');
            obj.info = oldInfo;
        end
        
    end
    
    % Internal methods:
    methods (Access = protected, Hidden = true)
        function pt = checkPatientExists(obj,identifier)
            if any(contains(fieldnames(obj.patients),identifier))
                pt = obj.patients.(identifier);
            else
                disp([9 'Couldn''t find patient ' identifier ', creating now'])
                pt = obj.addPatient(identifier);
            end
        end
        
        function sz = checkSeizureExists(obj,identifier,sznum)
            pt = obj.checkPatientExists(identifier);
            existsInPatient = length(pt.seizures) >= sznum && pt.seizures(sznum).number == sznum;
            [ids,nums] = obj.listSeizures();
            inds = find(strcmpi(ids,identifier) & nums == sznum, 1);
            existsInObj = ~isempty(inds);
            
            if existsInPatient
                sz = pt.seizures(sznum);
                if ~existsInObj
                    obj.seizures(end+1) = sz;
                end
            else
                if existsInObj
                    sz = obj.seizures(inds(1));
                    pt.seizures(sznum) = sz;
                else
                    disp([9 'Couldn''t find seizure ' num2str(sznum) ' in patient ' identifier ', creating now'])
                    sz = obj.addSeizure(identifier,sznum);
                end
            end
        end
        
        function event = checkEventExists(obj,identifier,eventNum)
            %TODO: need to update the format of this to match
            %   checkSeizureExists() method (check both patient and root
            %   object)
            pt = obj.checkPatientExists(identifier);
            if length(pt.markers) >= eventNum && pt.markers(eventNum).number == eventNum
                event = obj.patients.(identifier).markers(eventNum);
            else
                event = obj.addEvent(identifier,eventNum);
            end
        end
        
        function elec = checkElectrodeExists(obj,identifier,label)
            [ids, ~, labels] = obj.listElectrodes();
            inds = find(strcmpi(ids,identifier) & strcmpi(labels,label));
            if isempty(inds)
                elec = obj.addElectrode(identifier,'label',label);
            else
                elec = obj.electrodes(inds);
            end
        end
        
        function elec = checkChannelExists(obj,identifier,number)
            [ids, chans, ~] = obj.listElectrodes();
            inds = find(strcmpi(ids,identifier) & chans == number);
            if isempty(inds)
                elec = obj.addElectrode(identifier,'channel',number);
            else
                elec = obj.electrodes(inds);
            end
        end
    end
end