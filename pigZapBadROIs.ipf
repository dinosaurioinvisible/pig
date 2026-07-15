#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3


// modified version of the original script made by Patricio
// changes are mostly to accommodate pig files 
// & to avoid creating so many files in the same folder
// (ks already returns a lot of files)


function ZapBadROIs (wave w, [wave stimulus])
	// check stimulus
	if (ParamIsDefault(stimulus))
		string info = note(w)
		string basename = StringByKey("basename", info, "=", "\r")
		string stimWaveName = basename + "_stim"
		wave stimWave = $stimWaveName
	else
		wave stimWave = stimulus
		stimWaveName = getWavesDataFolder(stimWave,2)
   endif
	// make global vars: nROI, onROI, wn (wavename), zn (stimulusname)
	string name = nameofwave(w)
	string/g root:Packages:pig:zap_wn = name
	string/g root:Packages:pig:zap_zn = stimWaveName
	variable/g root:Packages:pig:zap_nROIs = dimsize(w,1)
	variable onROI = 0
	variable/g root:Packages:pig:zap_onROI = onROI
	string/g root:Packages:pig:zap_good = ""
	// panel window size
	variable/g root:Packages:pig:zap_left = 100
	variable/g root:Packages:pig:zap_top = 0
	variable/g root:Packages:pig:zap_right = 800
	variable/g root:Packages:pig:zap_bottom = 400
	makeZapWindow()
end


function makeZapWindow()
	// call global vars
	svar wn = root:Packages:pig:zap_wn
	svar zn = root:Packages:pig:zap_zn
	nvar nROIs = root:Packages:pig:zap_nROIs
	nvar onROI = root:Packages:pig:zap_onROI
	wave wx = $wn
	wave zx = $zn
	// panel	dimensions
	nvar left = root:Packages:pig:zap_left
	nvar top = root:Packages:pig:zap_top
	nvar right = root:Packages:pig:zap_right
	nvar bottom = root:Packages:pig:zap_bottom
	// display
	Display/K=1/W=(left,top,right,bottom)/N=roiThingy zx, wx[][onROI] as "Bad ROI GUI"
	ModifyGraph rgb($zn)=(0,0,0)
	ModifyGraph margin(bottom)=100
	ModifyGraph nticks(bottom)=24
	// display current ROI number
	ValDisplay whichROI title="ROI:", value=#"root:Packages:pig:zap_onROI"
	ValDisplay totalROIs title="Total:", value=#"root:Packages:pig:zap_nROIs"
	// good/bad buttons
	Button goodRoiButton, proc=goodButton, title="Good"
	Button badRoiButton, proc=badButton, title="Bad"	
end


// simple function to avoid having to enlarge image everytime
function saveWindowSize()
    GetWindow roiThingy wsize
    variable/g root:Packages:pig:zap_left = V_left
    variable/g root:Packages:pig:zap_top = V_top
    variable/g root:Packages:pig:zap_right = V_right
    variable/g root:Packages:pig:zap_bottom = V_bottom
end


// GOOD button saves index into goodROIs file
function goodButton(ba) : buttonControl
struct WMButtonAction&ba
	switch(ba.eventcode)
		case 2:
			saveWindowSize()
			dowindow/k roiThingy
			nvar nROIs = root:Packages:pig:zap_nROIs
			nvar onROI = root:Packages:pig:zap_onROI
			svar goodROIs = root:Packages:pig:zap_good
			goodROIs += num2str(onROI) + ";"
			if (onROI < nROIs-1)
				onROI+=1
				makeZapWindow()
			else
				makeGoodROIsFiles()
			endif
	endswitch
end


// basically the BAD button, just skip to the next ROI
function badButton(ba) : buttonControl
struct WMButtonAction&ba
	switch(ba.eventcode)
		case 2:
			saveWindowSize()
			dowindow/k roiThingy
			nvar nROIs = root:Packages:pig:zap_nROIs
			nvar onROI = root:Packages:pig:zap_onROI
			if (onROI < nROIs-1)
				onROI+=1
				makeZapWindow()
			else
				makeGoodROIsFiles()
			endif
	endswitch
end


// makes a copy of traces, only with the selected ROIs
function makeGoodROIsFilesx()
	// get files
	svar goodROIs = root:Packages:pig:zap_good
	svar wn = root:Packages:pig:zap_wn
	wave traces = $wn
	string pixelmask = waveList("*pixelmask", ";", "DIMS:2")
	pixelmask = pixelmask[0,strsearch(pixelmask,";",1)-1]
	string roimask = waveList("*roimask", ";", "DIMS:2")
	roimask = roimask[0,strsearch(roimask,";",1)-1]
	
	// make new traces file (rows and cols are inverted)
	variable nrois = itemsInList(goodROIs)
	variable nrows = dimSize(traces,0)
	make/o/n=(nrows, nrois) goodTraces
	variable i
	for (i = 0; i < nrois; i += 1)
		variable col = str2num(StringFromList(i, goodROIs))
		// p iterates on rows, q on cols
		goodTraces[][i] = traces[p][col]
	endfor
	// rename, copy scales & note info
	string x = wn + "_good"
	if (waveExists($x))
		killwaves/z $x
	endif
	rename goodTraces, $x
	copyScales $wn, $x
	setscale/p y, 0,  1, "", $x
	note $x, note($wn)
	
	// make new masks
	string masksInFolder = waveList("*mask", ";", "")
	for (i = 0; i < itemsInList(masksInFolder); i += 1)
		string maskName = StringFromList(i, masksInFolder)
		wave maskWave = $maskName
		makeNewROIMask(maskWave, goodROIs)
	endfor
	// make new list (assuming 1 _synapse_data file in folder)
	string synapsesName = waveList("*synapses_data", ";", "")
	synapsesName = synapsesName[0, strsearch(synapsesName, ";", 0)-1]
	wave synapsesData = $synapsesName
	makeNewSynapsesData(synapsesData, goodROIs)
	// make new synapses_map image (this uses python)
	string backgroundImageName = waveList("*_deltaf", ";", "")
	wave backgroundImage = $(backgroundImageName[0, strsearch(backgroundImageName, ";", 0)-1])
	string goodSynapsesName = waveList("*synapses_data_good", ";", "DIMS:2")
	wave goodSynapses = $(goodSynapsesName[0, strsearch(goodSynapsesName, ";", 0)-1])
	// this is necessary to avoid Igor crashing, in case the files are not there
	if (WaveExists(backgroundImage) == 0 || WaveExists(goodSynapses) == 0)
		print "could not find background image or synapses data"
 	   abort
	endif
	newSynapsesMap(backgroundImage, goodSynapses)
end

function makeNewROIMaskx(wave ROImask, string goodROIs)
	// make a copy
	string copyName = nameOfWave(ROImask) + "_good"
	duplicate/O roimask, $copyName
	wave maskCopy = $copyName
	// to find number of ROIs (most negative = nROIs)
	waveStats/Q maskCopy
	variable nROIs = abs(V_min)
	// find bad ROIS (not in list) and remove them (=1) 
	variable i
	for (i = 0; i < nROIs; i += 1)
		if (WhichListItem(num2str(i), goodROIs) < 0)
			// ? : works same as in python if-else 1 liner
			maskCopy = (maskCopy[p][q] == -(i+1)) ? 1 : maskCopy[p][q]
		endif
	endfor
end

function makeNewSynapsesDatax(wave synapsesData, string goodROIs)
	// make a new table size=good
	variable nrois = itemsInList(goodROIs)
	string tableName = nameOfWave(synapsesData) + "_good"
	make/o/n=(nrois, 6) $tableName
	wave goodSynapsesData = $tableName
	// copy column labels
	variable j
	for (j = 0; j < 6; j += 1)
		setDimLabel 1, j, $getDimLabel(synapsesData, 1, j), goodSynapsesData
	endfor
	// copy good data
	variable i
	for (i = 0; i < nrois; i += 1)
		variable row = str2num(stringFromList(i, goodROIs))
		// save data from previous table (saves old index)
		goodSynapsesData[i][0,5] = synapsesdata[row][q]
	endfor
end

function newSynapsesMapx(wave image, wave synapsesData)
	string basename = stringByKey("basename", note(image), "=", "\r")
	// save image as TIFF & synapses data as CSV
	imageSave/T="TIFF"/O/P=pigTemp image as basename + "_background.tif"
	save/G/M="\n"/DLIM=","/O/P=pigTemp synapsesData as basename + "_synapses.csv"
	// imageSave/T="TIFF"/O/P=desktop image as basename + "_background.tif"
	// save/G/M="\n"/DLIM=","/O/P=desktop synapsesData as basename + "_synapses.csv"
	// basic info
	string platform = IgorInfo(2)
	string igorcmd
	svar pathToTempFolder = root:Packages:pig:pigPathToTempFolder
	svar pathToPython = root:Packages:pig:pigPathToPythonInterpreter
	svar pathToPigPlots = root:Packages:pig:pigPathToPigPlots
	// define arguments
	string temp
	sprintf temp, "--tempFolder='%s'", pathToTempFolder
	// sprintf temp, "--tempFolder='%s'", renamePath_igor2sys(specialDirPath("Desktop",0,0,0))
	nvar roisize = root:Packages:pig:approxROIsize
	string synMapName = waveList("*synapses_map", ";", "")
	synMapName = synMapName[0, strsearch(synMapName, ";", 0)-1]
	string args = temp + " --roiRadius=" + num2str(roisize) + " --saveName=" + synMapName
	// run in python
	if (CmpStr(platform, "Windows") == 0)
		runPythonScriptOnWindows(pathToPython, pathToPigPlots, args=args)
	else
		runPythonScriptOnMacOs(pathToPython, pathToPigPlots, args=args)
	endif
	// load and remove temp 
	pigLoadAndRemoveTempFolder()
	// scale
	string goodSynMapName = waveList("*synapses_map_good", ";", "")
	wave goodSynapsesMap = $(goodSynMapName[0, strsearch(goodSynMapName, ";", 0)-1])
	// copyscales $synMapName, goodSynapsesMap
end



// Patricio 9.3.21
// fernando 6/26