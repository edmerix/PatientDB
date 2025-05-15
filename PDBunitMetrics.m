classdef PDBunitMetrics < handle
    properties
        threshold           (1,1)   double
        matchConfidence     (1,:)   double
        firingRate          (1,:)   double
        missingRate         (1,1)   double
        rpvRate             (1,1)   double
        gmFalsePos          (1,:)   double
        gmFalseNeg          (1,:)   double
        FWHM                (1,1)   double
        troughToPeak        (1,1)   double
        meanAC              (1,1)   double
        ACarea              (1,1)   double
        repolarizationSlope (1,1)   double
        recoverySlope       (1,1)   double
    end
    
    methods
        function obj = PDBunitMetrics(varargin)
            allowable = fieldnames(obj);
            if mod(length(varargin),2) ~= 0
                error('Inputs must be in name, value pairs');
            end
            for v = 1:2:length(varargin)
                if find(ismember(allowable,varargin{v}))
                    obj.(varargin{v}) = varargin{v+1};
                else
                    disp([9 'Not assigning ''' varargin{v} ''': not a field in PDBunitMetrics']);
                end
            end
        end
        
        function fp = falsePositiveRate(obj)
            fp = max(obj.rpvRate, sum(obj.gmFalsePos));
        end
        
        function fn = falseNegativeRate(obj)
            fn = (1 - (1-obj.missingRate)) + sum(obj.gmFalseNeg);
        end
    end
end