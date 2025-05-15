classdef PDBmultiunit < handle
    properties
        UID                     int32
        patient                 PDBpatient
        electrode               PDBelectrode
        waveform                double
        waveformSD              double
        Fs                      single
        times           (1,:)   double
        metrics                 PDBunitMetrics
        relatedEvent            PDBevent
        relatedSeizure          PDBseizure
        file                    PDBfile
        notes                   char
    end
    
    properties (SetAccess = private, Hidden = true)
        
    end
    
    methods
        function obj = PDBmultiunit(patientObj,varargin)
            if nargin < 1 || isempty(patientObj)
                patientObj = PDBpatient('unknown');
            end
            obj.patient = patientObj;
            allowable = fieldnames(obj);
            if ~isempty(varargin) && mod(length(varargin),2) ~= 0
                error('Inputs must be in name, value pairs');
            end
            for v = 1:2:length(varargin)
                if find(ismember(allowable,varargin{v}))
                    obj.(varargin{v}) = varargin{v+1};
                else
                    disp([9 'Not assigning ''' varargin{v} ''': not a field in PDBmultiunit']);
                end
            end
        end
        
        function [combined, multiunits] = getBundle(obj,bundle)
            if length(obj) <= 1
                error('To return a bundle selection, call on an array of multiunits')
            end
            elecs = [obj.electrode];
            banks = elecs.getBank();
            inds = strcmp(banks,bundle);
            multiunits = obj(inds);
            combined.patient = obj.patient;
            combined.bundle = bundle;
            combined.times = sort([multiunits.times]);
            combined.waveform = cell2mat({multiunits.waveform}');
            combined.waveformSD = cell2mat({multiunits.waveformSD}');
        end
        
        function calculateFiringMetrics(obj,varargin)
            if isempty(obj.times)
                disp([9 'No spike times, nothing to calculate'])
                return;
            end
            
            settings.bins = 0:100;
            settings.epoch = [-Inf Inf];
            
            allowable = fieldnames(settings);
            if ~isempty(varargin) && mod(length(varargin),2) ~= 0
                error('Inputs must be in name, value pairs');
            end
            for v = 1:2:length(varargin)
                if find(ismember(allowable,varargin{v}))
                    settings.(varargin{v}) = varargin{v+1};
                else
                    disp([9 'Not assigning ''' varargin{v} ''': not a setting in PDBunit:calculateFiringMetrics()']);
                end
            end
            
            if isempty(obj.metrics)
                obj.metrics = PDBunitMetrics();
            end
            tt = obj.times(obj.times >= settings.epoch(1) & obj.times <= settings.epoch(2));
            
            % Firing rate:
            a = max(min(tt),settings.epoch(1)); % use epoch if set, otherwise must rely on where spikes are
            b = min(max(tt),settings.epoch(2));
            obj.metrics.firingRate = length(tt)./(b-a);
            % TODO: contemplate calculating the gaussian FR and then using
            % the median gaussian Fr for firing rate, to account for
            % quiescent periods. Perhaps as a secondary FR metric.
            
            % AC calculation:
            bigMat = repmat(tt,1,length(tt));
            bigMat = bigMat - diag(bigMat)';
            bigMat = bigMat * 1e3; % ms

            ac = histcounts(bigMat(:),settings.bins);
            ac(1) = ac(1) - length(tt); % remove self from AC
            % calculate area under the cumulative AC, per ms:
            obj.metrics.ACarea = (sum(cumsum(ac))/sum(ac))/length(settings.bins) * range(settings.bins);
            
            % RPV percentage:
            rpvs = length(find(bigMat(:) >= 0 & bigMat(:) < 2));
            rpvs = rpvs - length(tt); % remove self from count
            obj.metrics.rpvRate = rpvs/length(tt);
            
            % Mean AC:
            subset = bigMat(bigMat >= settings.bins(1) & bigMat < settings.bins(end));
            subset(subset == 0) = [];
            obj.metrics.meanAC = nanmean(subset);
        end
    end
end