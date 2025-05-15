classdef PDBunit < handle
    properties
        UID                     int32
        patient                 PDBpatient
        electrode               PDBelectrode
        waveform                double
        waveformSD              double
        Fs                      single
        times           (1,:)   double
        wideband                double
        widebandSD              double
        type                    PDBcellType
        typeProb                double {mustBeNonnegative, mustBeLessThanOrEqual(typeProb,1)}
        metrics                 PDBunitMetrics
        relatedEvent            PDBevent
        relatedSeizure          PDBseizure
        sameUnit                PDBunit
        file                    PDBfile
        notes                   char
    end
    
    properties (SetAccess = private, Hidden = true)
        
    end
    
    methods
        function obj = PDBunit(patientObj,varargin)
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
                    disp([9 'Not assigning ''' varargin{v} ''': not a field in PDBunit']);
                end
            end
        end
        
        function linkUnits(obj,otherUnit)
            obj.sameUnit(end+1) = otherUnit;
            otherUnit.sameUnit(end+1) = obj;
        end
        
        function calculateWaveformMetrics(obj, varargin)
            if isempty(obj.wideband)
                disp('Need to have the wideband stored to calculate waveform metrics')
                return;
            end
            [~,settings.troughIndex] = min(obj.wideband);
            settings.uprate = 4;
            settings.idealized = false;  % if true, fit a polynomial to spike's return to baseline to remove artifacts
            settings.idealizedOrder = 4; % polynomial order for idealized spike waveform
            
            allowable = fieldnames(settings);
            if ~isempty(varargin) && mod(length(varargin),2) ~= 0
                error('Inputs must be in name, value pairs');
            end
            for v = 1:2:length(varargin)
                if find(ismember(allowable,varargin{v}))
                    settings.(varargin{v}) = varargin{v+1};
                else
                    disp([9 'Not assigning ''' varargin{v} ''': not a setting in PDBunit:calculateWaveformMetrics()']);
                end
            end
            
            if isempty(obj.metrics)
                obj.metrics = PDBunitMetrics();
            end
            
            if range(obj.wideband) == 0
                warning('Wideband waveform is flat, not calculating')
                return;
            end
            
            if any(isnan(obj.wideband))
                warning('NaN values in wideband waveform, not calculating')
                return;
            end
            %TODO: should normalize the wideband waveform before these. If
            % just subtracting mean and dividing by trough, that's easy, 
            % but if z-scoring to other units in same event/seizure, need  
            % to go up a level and access those, which ain't easy.
            % For now:
            wv = obj.wideband;% - mean(obj.wideband);
            wv = wv/-wv(settings.troughIndex);
            
            % Fit the polynomial if idealized == true:
            if settings.idealized
                t = (0:(length(wv)-settings.troughIndex));
                p = polyfit(t',wv(settings.troughIndex:end),settings.idealizedOrder);
                returnWv = polyval(p,t);
            else
                returnWv = wv(settings.troughIndex:end);
            end
            
            % get indices that are positive to find zero crossings:
            postPos = find(returnWv >= 0);
            if isempty(postPos)
                postPos = length(returnWv);
            end
            
            % Repol & recov slopes are based on Allen Institute spike sort:
            % (https://github.com/AllenInstitute/ecephys_spike_sorting/tree/master/ecephys_spike_sorting/modules/mean_waveforms)
            
            % Repolarization slope:
            subset = returnWv(1:postPos(1));
            t = (0:postPos(1)-1)/(obj.Fs/1e3);
            lm = fitlm(t,subset);
            obj.metrics.repolarizationSlope = lm.Coefficients.Estimate(2);
            
            % Recovery slope:
            %[~,w] = max(returnWv);
            [~,w] = findpeaks(returnWv);
            if isempty(w)
                [~,w] = max(returnWv);
            else
                w = w(1); % TODO: run some test waveforms to check this is never tripped up (shouldn't be if idealized == true, but maybe in raw?)
            end
            runTo = min(w+ceil(0.5*obj.Fs),length(returnWv)); % look over half a millisecond
            subset = returnWv(w-1:runTo);
            t = (w-1:runTo)/(obj.Fs/1e3);
            lm = fitlm(t,subset);
            obj.metrics.recoverySlope = lm.Coefficients.Estimate(2);
            
            % Trough to peak delay:
            obj.metrics.troughToPeak = (w-1)/(obj.Fs/1e3);
            
            % FWHM:
            fwhmWv = interp(wv,settings.uprate);
            [~,ind] = min(fwhmWv((settings.troughIndex*settings.uprate)-20:(settings.troughIndex*settings.uprate)+20));
            keypoint = ind + (settings.troughIndex*settings.uprate) - 21;
            fwhmWv = fwhmWv - fwhmWv(keypoint);
            fwhmWv = 2 * (fwhmWv/max(fwhmWv(settings.troughIndex*settings.uprate:end)) - 0.5);
            inds = find(fwhmWv >= 0);
            pre_inds = inds(inds < keypoint);
            post_inds = inds(inds > keypoint);
            if ~isempty(pre_inds) && ~isempty(post_inds)
                pre_ind = pre_inds(end);
                post_ind = post_inds(1);

                n = fwhmWv(pre_ind);
                m = fwhmWv(pre_ind+1);
                addition = n/(n-m);

                n = fwhmWv(post_ind);
                m = fwhmWv(post_ind-1);
                subtraction = n/(n-m);

                obj.metrics.FWHM = ((post_ind-subtraction) - (pre_ind+addition))/((obj.Fs/1e3)*settings.uprate);
            else
                obj.metrics.FWHM = Inf;
                disp([9 'Couldn''t find FWHM'])
            end
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
            if isrow(tt)
                tt = tt';
            end
            bigMat = repmat(tt,1,length(tt));
            bigMat = bigMat - diag(bigMat)';
            bigMat = bigMat * 1e3; % ms

            ac = histcounts(bigMat(:),settings.bins);
            [~,wh] = min(abs(settings.bins));
            ac(wh) = ac(wh) - length(tt); % remove self from AC
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