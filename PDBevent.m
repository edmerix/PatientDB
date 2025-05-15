classdef PDBevent < PDBseizure
    properties
        electrode       PDBelectrode
        time            datetime
    end
    
    properties (SetAccess = private, Hidden = true)
        
    end
    
    methods
        function obj = PDBevent(patientObj,varargin)
            if nargin < 1 || isempty(patientObj)
                patientObj = PDBpatient('unknown');
            end
            obj.patient = patientObj;
            allowable = fieldnames(obj);
            if mod(length(varargin),2) ~= 0
                error('Inputs must be in name, value pairs');
            end
            for v = 1:2:length(varargin)
                if find(ismember(allowable,varargin{v}))
                    obj.(varargin{v}) = varargin{v+1};
                else
                    disp([9 'Not assigning ''' varargin{v} ''': not a field in PDBevent']);
                end
            end
        end
    end
end