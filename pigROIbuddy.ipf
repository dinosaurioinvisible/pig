#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// modified version of the original to accommodate data from KS analysis
// I used Marios' ROI buddy version to include the stimulus
// plus pigZapBadROIs to discard bad ROIS


function pigROIbuddy(wave w)
	
	string/g root:packages:pig:ROIbuddy_rois = nameofwave(w)
	string basename = nameOfWave(w)[0,strSearch(nameOfWave(w),"_reg_",0)-1]
	if (strlen(basename) == 0)
		basename = nameOfWave(w)[0,strSearch(nameOfWave(w),"_dff_",0)-1]
	endif
	string/g root:packages:pig:ROIbuddy_basename = basename
	// from pigZap: make global vars: nROI, onROI, wn (wavename), zn (stimulusname)
	string name = nameofwave(w)
	string/g root:Packages:pig:zap_wn = name
	// string/g root:Packages:pig:zap_zn = stimWaveName
	variable/g root:Packages:pig:zap_nROIs = dimsize(w,1)
	variable onROI = 0
	variable/g root:Packages:pig:zap_onROI = onROI
	string/g root:Packages:pig:zap_good = ""
	
	// from Marios' ROIbuddy:
	string fdir = getWavesDataFolder(w,1)
	string stimulus = fdir + basename + "_stim"
	wave ws = $stimulus
	if (!waveExists(ws))
		string cwd = getDataFolder(1)
		cwd = removeEnding(cwd, ":")
		string parentFolder = cwd[0, strsearch(cwd, ":", strlen(cwd)-1, 1)]
		print parentFolder
		string movieName = stringByKey("basename",note(w),"=","\r")
		stimulus = parentfolder + movieName + "_stim"
		print(stimulus)
		wave ws = $stimulus
	endif
	
	// these files are different for KS
	// look for the STD and ROImask files for background
	// this assumes the processing made by the KS algorithm: 
	// registration, interpolation/squaring & bleach correction
	// string avg_image = basename + "_reg_isq_bc_std"
	string avg_image = basename + "_deltaf"
	if (!waveExists($avg_image))
		avg_image = basename + "_reg_isq_bc_deltaf"
	endif
	wave avg = $avg_image
	string roin = basename + "_roimask"
	if (!waveExists($roin))
		roin = basename + "_reg_isq_bc_roimask"
	endif
	wave roi = $roin
	string/g root:Packages:pig:zapBackground = roin
	variable/g root:packages:pig:ROI2display=0
	nvar ROI2display=root:packages:pig:ROI2display
	variable/g root:packages:pig:CompareROI=0
	nvar CompareROI=root:packages:pig:CompareROI
	
	// all the commented lines were actually causing double plotting or other issues
	// i'm leaving them, just in case someone wants to play with them
	//Display/K=1 /W=(79,45,688,549)/L=DF/B=Time w[*][ROI2display]
	Display/K=1/n=pigROIbuddyWindow/W=(79,45,688,549)/L=DF w[*][ROI2display] as "ROI buddy2"
	ModifyGraph rgb=(52171,0,5911)
	AppendImage/T avg
	AppendImage/T roi
	SetAxis/A/R left
	ModifyImage $roin ctab= {*,0,Grays,0}
	ModifyImage $roin maxRGB=nan
	ModifyImage $roin explicit=1,eval={-1,52171,0,5911} 
	ModifyGraph mirror(left)=0,mirror(top)=0
	ModifyGraph standoff(top)=0
	// ModifyGraph lblPos(left)=53,lblPos(Time)=47
	ModifyGraph freePos(DF)=0
	// ModifyGraph freePos(Time)=0
	ModifyGraph axisEnab(left)={0.55,1}
	ModifyGraph axisEnab(DF)={0,0.45}
	// modifyGraph noLabel(bottom)=2, axThick(bottom)=0
	// AppendImage/T/B=top avg
	// modifyGraph axisEnab(Time)={0,1}
	Label top "µm"
	// Label Time "Time (s)"
	Label df "ÆF/F"
	ModifyGraph lblPos(DF)=65
	ControlBar 30
	// from Marios: append stimulus
	AppendToGraph/L=DF/C=(0,0,0) ws[][0]
	
	SetVariable ShowROI,pos={320,3},size={130,23},proc=pigShowROI,title="ShowROI"
	SetVariable ShowROI limits={0,dimsize(w,1)-1,1}
	SetVariable ShowROI,fSize=15,value=ROI2display
	CheckBox Compare,pos={110,7},size={16,15},proc=pigCompareCB,title=""
	CheckBox Compare,value= 0,side= 1
	SetVariable Compar,pos={130,3},size={172,23},proc=pigCompareROIsetvar,title="Compare ROI#"
	SetVariable Compar,fSize=15,value= CompareROI
	// display current ROI number
	ValDisplay totalROIs title="Total:", pos={20,4}, size={80,50}, fsize=14, value=#"root:Packages:pig:zap_nROIs"
	// good/bad buttons
	Button goodRoiButton, pos={470,3}, proc=pigGoodButton, fsize=14, fstyle=0, title="Good"
	Button badRoiButton, pos={530,3}, proc=pigBadButton, fsize=14, fstyle=0, title="Bad"

end


///////////////////////////////////// 


Function pigShowROI(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	svar wn = root:Packages:pig:ROIbuddy_rois
	svar roin = root:Packages:pig:zapBackground
	wave w = $wn
	wave roi = $roin

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			variable/g root:packages:pig:ROI2display=dval
			nvar ROI2display=root:packages:pig:ROI2display
			// we need to update for pigZapBadROIs as well
			// in case user goes back
			variable/g root:Packages:pig:zap_onROI=dval
		
			// AppendToGraph/L=DF/B=Time w[][ROI2display]
			AppendToGraph/L=DF w[][ROI2display]
			RemoveFromGraph $wn
			ModifyGraph rgb($wn)=(52171,0,5911)
			
			AppendImage/T $roin
			RemoveImage $roin
			ModifyImage $roin ctab= {*,0,Grays,0}
			ModifyImage $roin maxRGB=nan
			ModifyImage $roin explicit=1,eval={-(roi2display+1),52171,0,5911}
					
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

////////////////////////////

Function pigCompareCB(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	
	svar wn = root:Packages:pig:ROIbuddy_rois
	svar roin = root:Packages:pig:zapBackground
	wave w = $wn
	wave roi = $roin
	nvar CompareROI=root:packages:pig:CompareROI
	
	switch( cba.eventCode )
		case 2: // mouse up
		
			Variable/G root:packages:pig:checkBoxCompare = cba.checked
			nvar checkBoxCompare=root:packages:pig:checkBoxCompare
			
			if(checkBoxCompare==1)		
				duplicate/o roi, compareROImask
				duplicate/o w, compareData
				AppendToGraph/L=DF/B=Time compareData[][CompareROI]
				ModifyGraph rgb(compareData)=(9252,26214,42919)
				AppendImage/T compareROImask
				ModifyImage compareROImask ctab= {*,0,Grays,0}
				ModifyImage compareROImask maxRGB=nan
				ModifyImage compareROImask explicit=1,eval={-(CompareROI+1),9252,26214,42919}		
			elseif(checkBoxCompare==0)
				wave compareData,compareROImask
				RemoveFromGraph compareData
				Removeimage compareROImask
				killwaves/Z compareData,compareROImask
			endif
						
			break
		case -1: // control being killed
			break
	endswitch

	return 0
end

////////////////////////////

Function pigCompareROIsetvar(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	svar wn = root:Packages:pig:ROIbuddy_rois
	svar roin = root:Packages:pig:zapBackground
	wave w = $wn
	wave roi = $roin
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			variable/g root:packages:pig:CompareROI=dval
			
			variable/g root:packages:pig:ROI2display=dval
			nvar ROI2display=root:packages:pig:ROI2display
			// we need to update for pigZapBadROIs as well
			// in case user goes back
			variable/g root:Packages:pig:zap_onROI=dval
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End



///////////////// from pigZapBadROIs
			


// GOOD button saves index into goodROIs file
// and updates the ROI buddy display & info
function pigGoodButton(ba) : buttonControl
	struct WMButtonAction&ba
	
	// we need this global vars now, for updating the display
	svar wn = root:Packages:pig:ROIbuddy_rois
	// svar basename = root:Packages:pig:ROIbuddy_basename
	svar roin = root:Packages:pig:zapBackground
	wave w = $wn
	wave roi = $roin
			
	switch(ba.eventcode)
		case 2:
			// this is for saving good ones
			nvar nROIs = root:Packages:pig:zap_nROIs
			nvar onROI = root:Packages:pig:zap_onROI
			svar goodROIs = root:Packages:pig:zap_good
			// check whether ROI is already in goodROIs
			if (whichListItem(num2str(onROI), goodROIs) < 0)
				goodROIs += num2str(onROI) + ";"
			endif
			// update
			if (onROI < nROIs-1)
				onROI+=1
				// update display
				nvar ROI2display = root:Packages:pig:ROI2display
				variable/g root:packages:pig:ROI2display=onROI
				SetVariable ShowROI, value=ROI2display
				AppendToGraph/L=DF w[][ROI2display]
				RemoveFromGraph $wn
				ModifyGraph rgb($wn)=(52171,0,5911)
				AppendImage/T $roin
				RemoveImage $roin
				ModifyImage $roin ctab= {*,0,Grays,0}
				ModifyImage $roin maxRGB=nan
				ModifyImage $roin explicit=1,eval={-(roi2display+1),52171,0,5911}
			else
				// close display and make files
				doWindow/k pigROIbuddyWindow
				makeGoodROIsFiles()
			endif
	endswitch
end


// basically the BAD button, just skip to the next ROI
// still has to update ROI buddy info
function pigBadButton(ba) : buttonControl
	struct WMButtonAction&ba
	
	svar wn = root:Packages:pig:ROIbuddy_rois
	// svar basename = root:Packages:pig:ROIbuddy_basename
	svar roin = root:Packages:pig:zapBackground
	wave w = $wn
	wave roi = $roin
	
	// procedure as such
	switch(ba.eventcode)
		case 2:
			nvar nROIs = root:Packages:pig:zap_nROIs
			nvar onROI = root:Packages:pig:zap_onROI
			// check whether onROI was previously considered as good
			// if that's the case: remove
			svar goodROIs = root:Packages:pig:zap_good
			if (whichListItem(num2str(onROI), goodROIs) >= 0)
				goodROIs = removeFromList(num2str(onROI), goodROIs)
			endif
			// update
			if (onROI < nROIs-1)
				onROI+=1
				// update display
				nvar ROI2display = root:Packages:pig:ROI2display
				variable/g root:packages:pig:ROI2display=onROI
				SetVariable ShowROI, value=ROI2display
				AppendToGraph/L=DF w[][ROI2display]
				RemoveFromGraph $wn
				ModifyGraph rgb($wn)=(52171,0,5911)
				AppendImage/T $roin
				RemoveImage $roin
				ModifyImage $roin ctab= {*,0,Grays,0}
				ModifyImage $roin maxRGB=nan
				ModifyImage $roin explicit=1,eval={-(roi2display+1),52171,0,5911}
			else
				// close display and make files
				doWindow/k pigROIbuddyWindow
				makeGoodROIsFiles()
			endif
	endswitch
end


// makes a copy of traces, only with the selected ROIs
function makeGoodROIsFiles()
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
	makeNewSynapsesMap(backgroundImage, goodSynapses)
	
	// make new overlay movie
	string backgroundMovieName = waveList("*_reg_isq_bc",";","DIMS:3")
	backgroundMovieName = backgroundMovieName[0, strsearch(backgroundMovieName,";",0)-1]
	wave backgroundMovie = $backgroundMovieName
	makeNewoverlayMovie(backgroundMovie, goodSynapses)
end


function makeNewROIMask(wave ROImask, string goodROIs)
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


function makeNewSynapsesData(wave synapsesData, string goodROIs)
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


function makeNewSynapsesMap(wave image, wave synapsesData)
	// string basename = stringByKey("basename", note(image), "=", "\r")
	svar basename = root:Packages:pig:ROIbuddy_basename
	// save image as TIFF & synapses data as CSV
	imageSave/T="TIFF"/O/P=pigTemp image as basename + "_background.tif"
	save/G/M="\n"/DLIM=","/O/P=pigTemp synapsesData as basename + "_synapses.csv"
	// for debugging only
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
	nvar roisize = root:Packages:pig:approxROIsize
	string synMapName = waveList("*synapses_map", ";", "")
	synMapName = synMapName[0, strsearch(synMapName, ";", 0)-1]
	string args = temp + " --roiRadius="+num2str(roisize) + " --saveName="+synMapName
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
	copyscales $synMapName, goodSynapsesMap
end


function makeNewOverlayMovie(wave movie, wave goodSynapses)
	// basic info
	string platform = IgorInfo(2)
	string igorcmd
	svar pathToTempFolder = root:Packages:pig:pigPathToTempFolder
	svar pathToPython = root:Packages:pig:pigPathToPythonInterpreter
	svar pathToPigPlots = root:Packages:pig:pigPathToPigPlots
	// make movie for python to load
	string basename = nameOfWave(movie)
	imageSave/u/T="TIFF"/s/O/P=pigTemp movie as basename + "_movie.tif"
	save/G/M="\n"/DLIM=","/O/P=pigTemp goodSynapses as basename + "_synapses.csv"
	// define arguments
	string temp
	sprintf temp, "--tempFolder='%s'", pathToTempFolder
	nvar roisize = root:Packages:pig:approxROIsize
	string overlayName = waveList("*_overlay", ";", "")
	overlayName = overlayName[0, strsearch(overlayName, ";", 0)-1]
	string args = temp + " --roiRadius="+num2str(roisize) + " --saveName="+overlayName
	// run in python
	if (CmpStr(platform, "Windows") == 0)
		runPythonScriptOnWindows(pathToPython, pathToPigPlots, args=args)
	else
		runPythonScriptOnMacOs(pathToPython, pathToPigPlots, args=args)
	endif
	// load and remove temp 
	pigLoadAndRemoveTempFolder()
	// scale
	string overlayGoodName = waveList("*_overlay_good", ";", "")
	wave overlayGood = $(overlayGoodName[0, strsearch(overlayGoodName, ";", 0)-1])
	copyscales $overlayName, overlayGood
end