% PDBfile stores file details for specified events in PatientDB
classdef PDBfile < handle
    properties
        name    char
        path    char
        type    PDBfileType
        onset   double
        offset  double
    end
    
    methods
        function obj = PDBfile()
            obj.type = 'unknown';
        end
        
        function [filepath, updated] = findLostFile(obj, searchPath, overwrite, ext)
        % filepath = findLostFile(searchPath, overwrite)
        %   search for the filename at the specified path, recursively
        %   If overwrite == true then it will automatically update the
        %   field, otherwise it will prompt for confirmation.
        %   Search path defaults to /storage/patients/
            if nargin < 2 || isempty(searchPath)
                searchPath = '/storage/patients/';
            end
            if nargin < 3 || isempty(overwrite)
                overwrite = false;
            end
            if nargin < 4 || isempty(ext)
                if obj.type == PDBfileType.both || obj.type == PDBfileType.micros
                    ext = '.ns5';
                else
                    ext = '.ns3';
                end
            end
            updated = false;
            cmd = sprintf('find %s -name "%s" 2>&1 | grep -v "Permission denied"',searchPath,[obj.name ext]);
            [v,filepath] = system(cmd);
            if v
                disp([9 'Response was ' filepath])
                error('Problem running system command');
            else
                filepath = strsplit(filepath,'\n');
                filepath = strtrim(filepath{1}); % only keep the first result if many
                filepath = fileparts(filepath);
                if overwrite
                    obj.path = filepath;
                    updated = true;
                else
                    disp([9 'Response was: ' filepath])
                    g = input([9 9 'Update accordingly? y/N\n'],'s');
                    if strcmpi(g,'y')
                        obj.path = filepath;
                        updated = true;
                    end
                end
            end
        end
        
        function fn = fullpath(obj, ext)
            if nargin < 2 || isempty(ext)
                switch obj.type
                    case {PDBfileType.both, PDBfileType.micros}
                        ext = 'ns5';
                    case {PDBfileType.macros, PDBfileType.sync}
                        ext = 'ns3';
                    otherwise
                        error(['Please supply an extension for ' obj.type ' files'])
                end
            end
            fn = [obj.path filesep obj.name '.' ext];
        end
    end
end