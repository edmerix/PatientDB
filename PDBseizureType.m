classdef PDBseizureType < int16
    enumeration
        GTC             (5)
        SecondaryGTC    (4)
        CPS             (3)
        SPS             (2)
        Subclinical     (1)
        Atypical        (0)
        Unknown         (-1)
    end
end