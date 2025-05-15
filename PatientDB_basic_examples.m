%% Load the PatientDB data:
load('PatientDB.mat')

%% Basic structure examples:
% Get info about the 3rd seizure in a patient with the identifier "PT_04":
% (All patient identifiers in this example code are fictional)
pdb.patients.PT_04.seizures(3)

% Get the full file location for the file that is listed as containing the 
% micro electrodes for PT_16's second seizure:
filename = pdb.patients.PT_16.seizures(2).micros().fullpath();
% And get the seizure onset time (in seconds) for that file:
seizure_onset = pdb.patients.PT_16.seizures(2).micros().onset;
% seizure_onset will now contain the seizure onset time within that file, 
% in seconds

% Get all seizures that were CPS:
CPS_seizures = pdb.getSeizures('type','CPS');
% CPS_seizures will now contain multiple seizure objects that are all CPS.

% Get all seizures that were GTC and had electrodes 'uLHC' AND 'u*H':
% (* is a wildcard, so this would match uLH, uRH, or uHH for example)
specific_data = pdb.getSeizures('type','GTC','label',{'uLHC','u*H'});
% specific_data now contains whichever seizures matched your requirements.

% If you just want every seizure in the database, they're all in:
pdb.seizures

% Check if the patient with identifier PT_89 is a reimplant of another:
pdb.patients.PT_89.reimplantOf.id
% If this patient had prior surgery with another implant, the output will
% give the identifier from that implant.
% So, say we want to get all the units from this patient, across both 
% implants, without wanting to look up prior patient identifiers:
units = [pdb.patients.PT_89.units; pdb.patients.PT_89.reimplantOf.units];
% et voila.

% Similarly, unit objects point to whichever seizure/event they're
% referring to in "relatedSeizure" and "relatedEvent" fields, and to
% another unit from a different file if they've been deemed to be the same
% neuron, in "sameUnit". Check the PatientDB_map.pdf for more of these
% relationships between objects, which automatically remain linked once
% added.

%% Example for loading a micro-electrode file, relative to seizure onset:
% Find all seizures that were CPS and recorded on Behnke-Fried microwires:
data = pdb.getSeizures('implantType','BF','type','CPS');
% data now contains all seizure objects that meet those criteria. Now say 
% we want to load the data from 2 minutes before seizure onset until 1
% minute after seizure offset from the first of these:
[nsx, onset, offset] = data(1).loadMicros();
% nsx has now read the header for the relevant data file. Let's actually
% read the relevant data:
nsx.read('time',[onset-120 offset+60]);
% Now nsx.data will have been populated with the requested data. Note that
% this depends on my NSxFile object. If preferred, just the file location
% and onset/offset can be returned as strings to enable loading however
% desired:
filepath = data(1).micros.fullpath;
onset = data(1).micros.onset;
offset = data(1).micros.offset;


%% Saving backups of the PatientDB data: 
% (recommended before altering anything in it)
% Save a backup of the PatientDB object in its current state, with default
% settings:
pdb.backup();
% Alternatively, save a backup in your home directory, renaming the 
% variable as "patient_database":
pdb.backup('path','~','name','patient_database');
% Both backups will default to calling the file
% 'PatientDB_backup_{datetime}.mat, where {datetime} is the current date
% and time, and will update the pdb.info message to say it's a backup from
% that date and time.

%% See PatientDB_map.pdf for the structural overview of PatientDB
% The data are stored in an object-oriented, mutable manner, meaning you
% can get the data you want in many different ways, and they can reference
% themselves circularly. For example:
truism = pdb.patients.PT_23.seizures(1).patient == pdb.patients.PT_23;
% will be true. And you can go in circles forever:
also_truism = strcmp(pdb.seizures(20).patient.seizures(6).patient.seizures(4).patient.id,...
    pdb.seizures(20).patient.id);
% This seems odd at first, but it means we can quickly get a list of
% patients by selecting seizures without knowing which patients had them,
% for example:
data = pdb.getSeizures('type','SecondaryGTC');
% will fill the variable data with an array of seizure data (each in a
% PDBseizure object).
% From this we can get all the patients that had secondary GTCs, without
% having to go through the pdb.patients list:
patientsObject = [data.patient];
patients = unique({patientsObject.id});
% the 'patients' variable now contains the IDs of patients that had
% secondary GTCs logged in the PatientDB.

%% For adding data to the PatientDB object, use the following methods:
% e.g., add a 4th seizure for PT_07:
sz = pdb.addSeizure('PT_07',4);
% 'sz' now contains a handle to that seizure, anything you update in the
% 'sz' variable will also update in the pdb variable, both in pdb.seizures
% and pdb.patients.PT_07.seizures, because it's circular and uses pointers
% instead of hardcoded data.
% So, let's update the seizure type of the seizure we just added to CPS:
sz.type = 'CPS'; 
% seizure types in PatientDB are a PDBseizureType enumeration object,
% meaning they can only be updated to one of the values in PDBseizureType:
%   'GTC','SecondaryGTC','CPS','SPS','Subclinical','Atypical','Unknown'
% or it will give an error. If none is supplied it defaults to 'Unknown'
% (note that the ILAE has updated this terminology, which will be available
% in a future release)

% Add a note to the seizure you just added:
sz.notes = 'This is not a real seizure, just an example';
% If the seizure already exists, it'll say so and not change anything.
% If the patient doesn't exist in the PatientDB yet, it'll add them for you
% If you want to update an item that already exists, just update it in
% the structure, e.g.
pdb.patients.PT_23.seizures(4).type = 'CPS';
% or grab a handle to it and update as before:
sz = pdb.patients.PT_23.seizures(4);

% Add a file name that contains the macros to the seizure in your 'sz'
% variable:
fl = sz.addFile('name','example-file');
% We should say that it contains the macros, and the seizure onset and 
% offset in that file should be added too:
fl.type = 'macros';
fl.onset = 732;
fl.offset = 765;
% That's a bit wordy, so it could have just been compressed to a one-liner:
sz.addFile('name','example-file','type','macros','onset',732,'offset',765);

% Cool, now PatientDB has a filename for that seizure, but doesn't know
% where it is on the server/drive. We can use the findLostFile method to 
% let it search for it automatically:
fl.findLostFile();
% If it finds a file, it will tell you where it found it and ask if you
% want to update accordingly

% If you want to automatically update a file path for a specific
% patient/seizure combo, and not be prompted for confirmation (careful...),
% and you want to search in a specific directory:
pdb.patients.PT01.seizures(1).micros.findLostFile('/directory/to/search',true);
% The first input is always the directory to search, and if you pass in
% true to the second input it won't ask for confirmation.

% Other methods for adding data to PatientDB are:
pdb.addPatient();
pdb.addElectrode();
pdb.addUnit();
pdb.addIED();
% They all require the patient ID as first input, and then a variety of
% optional inputs depending on what you're adding. Look in their methods or
% PatientDB_manual.pdf for the options.
% Only the addPatient() and addSeizure() methods check if the info you're 
% adding already exists, to avoid accidentally blocking the addition of the
% same unit/electrode in different times/seizures etc.

% If you've actually added a real seizure/updated something real, then it 
% needs to be saved back to PatientDB.mat to be permanent. 
% Run a backup first (pdb.backup();)
% Then:
pdb.save();
% to save in the default location.