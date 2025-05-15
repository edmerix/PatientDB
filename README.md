
# PatientDB

![PatientDB cover image](Docs/PatientDB_cover.png?raw=true "Cover image for PatientDB")
A Matlab toolbox and database for storing and accessing patient recordings.

### What is this?
Keeping track of where specific data are stored in huge datasets of continuous recordings in patients is unwieldy. Making changes to the original, raw recordings to add notes for when various things occur is risky, so we want to have a separate entity that knows where everything is, and points to the right locations in a human-readable manner. PatientDB is a combination of a "database" (storage of raw data) and "methods" (ways to interact with the data) in a single _object-oriented_  toolbox to achieve this format.

### Why is this?
PatientDB is entirely MATLAB code. This allows for raw data to be stored in-line, and for the interactive methods to exist within the same object. It also allows the data to be stored in an "object-oriented" manner, meaning if you change info about a specific item in the PatientDB, whatever you update will immediately apply everywhere else in the database that the item is referenced/stored, avoiding mismatched, out-of-sync data or broken links.

This means that data can be accessed  _circularly_, and  _infinitely/recursively_. It also means that data access follows an "object" approach such that data within an item is accessed via a "dot". So if you have a variable called  `patient`, which has specific seizures in it—stored in an array called  `seizures`–and each one had a  file  in it, you'd access the second seizure's file with:

`patient.seizures(2).file`

From there, each object (i.e. each item before or after a dot) has its own methods and properties, while the PatientDB as a whole has methods to access most of the data intuitively.

Check out the [schematic ("subway map") below](#schematic) for an overview of the structure and how the data interact with each other, and for detailed information on the structure, each object's methods, and how to build your own database, check out the [full manual](Docs/PatientDB_manual.pdf).

### Quick start
##### Load the PatientDB data:
`load('PatientDB.mat')`
##### Basic usage examples:
Get info about the 3rd seizure in a patient with the identifier "PT_04":
(All patient identifiers in this example code are fictional)
```
pdb.patients.PT_04.seizures(3)
```

Get the full file location for the file that is listed as containing the
micro electrodes for PT_16's second seizure:
```
filename = pdb.patients.PT_16.seizures(2).micros().fullpath();
```
And get the seizure onset time (in seconds) for that file:
```
seizure_onset = pdb.patients.PT_16.seizures(2).micros().onset;
```
seizure_onset will now contain the seizure onset time within that file,  in seconds

Get all seizures that were CPS:
```
CPS_seizures = pdb.getSeizures('type','CPS');
```
CPS_seizures will now contain multiple seizure objects that are all CPS.

Get all seizures that were GTC and had electrodes 'uLHC' AND 'u\*H': (\* is a wildcard, so this would match uLH, uRH, or uHH for example)
```
specific_data = pdb.getSeizures('type','GTC','label',{'uLHC','u*H'});
```
`specific_data` now contains whichever seizures matched your requirements.

If you just want every seizure in the database, they're all in:
`pdb.seizures`

Check if the patient with identifier PT_89 is a reimplant of another:
```
pdb.patients.PT_89.reimplantOf.id
```
If this patient had prior surgery with another implant, the output will give the identifier from that implant.

So, say we want to get all the units from this patient, across both implants, without wanting to look up prior patient identifiers:
```
units = [pdb.patients.PT_89.units; pdb.patients.PT_89.reimplantOf.units];
```
et voila.

Similarly, unit objects point to whichever seizure/event they're referring to in `relatedSeizure` and `relatedEvent` fields, and to another unit from a different file if they've been deemed to be the same neuron, in `sameUnit`. Check the [PatientDB map](#schematic) for more of these relationships between objects, which automatically remain linked once added.
##### Structure
The data are stored in an object-oriented, mutable manner, meaning you can get the data you want in many different ways, and they can reference themselves circularly. For example:
`truism = pdb.patients.PT_23.seizures(1).patient == pdb.patients.PT_23;`
will be `true`.

And you can go in circles forever:
```
also_truism = strcmp(...
pdb.seizures(20).patient.seizures(6).patient.seizures(4).patient.id,...
pdb.seizures(20).patient.id);
```
This seems odd at first, but it means we can quickly get a list of
patients by selecting seizures without knowing which patients had them, for example:
```
data = pdb.getSeizures('type','SecondaryGTC');
```
will fill the variable data with an array of seizure data (each in a `PDBseizure` object). From this we can get all the patients that had secondary GTCs, without having to go through the `pdb.patients` list:
```
patientsObject = [data.patient];
patients = unique({patientsObject.id});
```
The 'patients' variable now contains the IDs of patients that had secondary GTCs.

##### Example loading of raw data
Find all seizures that were CPS and recorded on Behnke-Fried microwires:
```
data = pdb.getSeizures('implantType','BF','type','CPS');
```
data now contains all seizure objects that meet those criteria.

Now say we want to load the data from 2 minutes before seizure onset until 1 minute after seizure offset from the first of these:
```
[nsx, onset, offset] = data(1).loadMicros();
```
`nsx` has now read the header for the relevant data file. Let's actually read the relevant data:
```
nsx.read('time',[onset-120 offset+60]);
```
Now `nsx.data` will have been populated with the requested data.

Note that this depends on my [NSxFile object](https://github.com/edmerix/NSxFile). If preferred, just the file location and onset/offset can be returned as strings to enable loading however desired:
```
filepath = data(1).micros.fullpath;
onset = data(1).micros.onset;
offset = data(1).micros.offset;
```

For more examples, including how to add data, backup and save the database, etc., see the [example code](PatientDB_basic_examples.m), which expands on the above.

### Schematic
![PatientDB subway map](Docs/PatientDB_map.png?raw=true "Schematic design for PatientDB")
