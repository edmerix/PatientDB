classdef PDBpatient < handle
    properties
        id              char
        implantType     char
        reimplantOf     PDBpatient
        seizures        PDBseizure
        electrodes      PDBelectrode
        units           PDBunit
        multiunits      PDBmultiunit
        markers         PDBevent
        notes           char
    end
    
    properties (SetAccess = private, Hidden = true)
        
    end
    
    methods
        function obj = PDBpatient(identifier,varargin)
            if nargin < 1 || isempty(identifier)
                identifier = 'unknown';
            end
            obj.id = identifier;
            allowable = fieldnames(obj);
            if mod(length(varargin),2) ~= 0
                error('Inputs must be in name, value pairs');
            end
            for v = 1:2:length(varargin)
                if find(ismember(allowable,varargin{v}))
                    obj.(varargin{v}) = varargin{v+1};
                else
                    disp([9 'Not assigning ''' varargin{v} ''': not a field in PDBpatient']);
                end
            end
        end
    end
end