#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// #include "pig"

// panel for pig
Window pigPanel(): Panel_pig

	PauseUpdate; Silent 1	
	// global variables
	NewDataFolder/o root:Packages:pig
	variable/g root:Packages:pig:FOV=610
	variable/g root:Packages:pig:alpha=0.05
	variable/g root:Packages:pig:approxROIsize=2
	variable/g root:Packages:pig:minDist=3
	variable/g root:Packages:pig:mkVideos=0
	string/g root:Packages:pig:ccMovies=""
	newDataFolder/o root:analysisWaves
	// define other useful paths (pig, temp)
	string pigPath = specialDirPath("Igor Pro User Files",0,0,0) + "User Procedures:pig:"
	string/g root:Packages:pig:pigPathToPigFolder = renamePath_igor2sys(pigPath)
	string pigTempFolder = specialDirPath("Temporary",0,0,0) + "pig:"
	string/g root:Packages:pig:pigPathToTempFolder = renamePath_igor2sys(pigTempFolder)
	newPath/c/o/q pigTemp, pigTempFolder
	newPath/c/o/q tempFolder, specialDirPath("Temporary",0,0,0)
	// get path to python interpreter
	pigDefinePythonInterpreterPath()
	pigDefinePathToKS()
	pigDefinePathToGetMetadata()
	
	// main panel
	// /w=(left, top, right, bottom)
	NewPanel/w = (666,111,1055,474) as "Pig — KS analysis"
	ModifyPanel cbRGB = (0, 13107, 26214)
	SetDrawLayer UserBack
	// ks: main box
	// /w=(left, top, right, bottom)
	SetDrawEnv linethick=0, fillfgc=(64824,27308,21496)
	DrawRRect 20,35,370,105
	SetDrawEnv fsize = 16, fstyle = 1, textrgb = (65535,65535,65535)
	DrawText 33, 30, "KS analysis"
	// ks: box for FOV 
	SetVariable FOV, pos={30,45}, size={70,30}, proc=button_setFOV, title="FOV"
	SetVariable FOV,help={"Field of view in µm at zoom 1"},fSize=12,fStyle=1
	SetVariable FOV,fColor=(65535,65535,65535)
	SetVariable FOV,limits={0,inf,0},value = root:Packages:pig:FOV
	// ks: box for alpha 
	SetVariable alpha, pos={105,45}, size={80,30}, proc=button_setAlpha, title="alpha"
	SetVariable alpha,help={"pre-set significance threshold for p-values"},fSize=12,fStyle=1
	SetVariable alpha,fColor=(65535,65535,65535)
	SetVariable alpha,limits={0,inf,0},value = root:Packages:pig:alpha
	// ks: box for ROIsize
	SetVariable approxROIsize, pos={195,45}, size={80,30}, proc=button_setROIsize, title="ROIsize"
	SetVariable approxROIsize,help={"approx. diameter of ROIs, in µm"},fSize=12,fStyle=1
	SetVariable approxROIsize,fColor=(65535,65535,65535)
	SetVariable approxROIsize,limits={0,inf,0},value = root:Packages:pig:approxROIsize
	// ks: box for minDist
	SetVariable minDist, pos={280,45}, size={80,30}, proc=button_setMinDist, title="minDist"
	SetVariable minDist,help={"min dist between ROIs centres, in pixels"},fSize=12,fStyle=1
	SetVariable minDist,fColor=(65535,65535,65535)
	SetVariable minDist,limits={0,inf,0},value = root:Packages:pig:minDist
	// ks: load movie
	Button Load, pos={25,77}, size={80,20}, proc=button_loadMovie, title="Load movie"
	Button Load, fColor=(16191,18504,18761)
	// ks: multiload movie
	Button multiLoad, pos={110,77}, size={75,20}, proc=button_multiLoad, title="MultiLoad"
	Button multiLoad, fColor=(16191,18504,18761)
	// ks: Load analysis Wave -- load experiment (stimulus/analysis) wave
	Button LoadAnalysisWave, pos={190,77}, size={90,20}, proc=button_LoadAnalysisWave, title="Load anWave"
	Button LoadAnalysisWave, fColor=(16191,18504,18761)
	// ks: run
	Button runKS, pos={290,77}, size={75,20}, proc=button_runKS, title="Run KS"
	Button runKS, fColor=(16191,18504,18761), fstyle=1
	// ks: save -- make overlay & overlay + input movies
	checkBox mkVideos, pos={300,15}, size={10,20}, proc=pigMakeVideos, title="Save"
	checkBox mkVideos, help={"output overlay & overlay + stimulus videos"}, fSize=12, fStyle=1
	checkBox mkVideos, fsize=12, side=0, value=0, fcolor = (65535,65535,65535)
	// other functions: main box
	// /w=(left, top, right, bottom)
	SetDrawEnv linethick = 0,fillfgc = (10283,48779,31735)
	DrawRRect 20,140,370,240
	SetDrawEnv fsize = 16,fstyle = 1,textrgb = (65535,65535,65535)
	DrawText 33,135,"More"
	
	// more buttons
	Button button1,pos={30,150},size={75,20},proc=button1,title="01"
	Button button1,help={"free button"}
	Button button1,fColor=(16191,18504,18761)
	Button button2,pos={115,150},size={75,20},proc=button2,title="02"
	Button button2,help={"free button"}
	Button button2,fColor=(16191,18504,18761)
	Button button3,pos={200,150},size={75,20},proc=button3,title="03"
	Button button3,help={"free button"}
	Button button3,fColor=(16191,18504,18761)
	Button button4,pos={285,150},size={75,20},proc=button4,title="04"
	Button button4,help={"free button"}
	Button button4,fColor=(16191,18504,18761)
	Button button5,pos={30,180},size={75,20},proc=button5,title="05"
	Button button5,help={"free button"}
	Button button5,fColor=(16191,18504,18761)
	Button button6,pos={115,180},size={75,20},proc=button6,title="06"
	Button button6,help={"free button"}
	Button button6,fColor=(16191,18504,18761)
	Button button7,pos={200,180},size={75,20},proc=button7,title="07"
	Button button7,help={"free button"}
	Button button7,fColor=(16191,18504,18761)
	// button for show
	Button show,pos={285,180},size={75,20},proc=button_show,title="Show"
	Button show,help={"display using imshow()"}
	Button show,fColor=(16191,18504,18761)
	// initially free, but now following suggestions from Jose, Marios and Jonny
	Button getMetadata,pos={30,210},size={100,20},proc=button_getMetadata,title="Get metadata"
	Button getMetadata,help={"retrieves metadata using PIG"}
	Button getMetadata,fColor=(16191,18504,18761)
	Button ROIbuddy,pos={145,210},size={100,20},proc=button_ROIbuddy,title="ROI buddy"
	Button ROIbuddy,help={"ROI buddy, from ART"}
	Button ROIbuddy,fColor=(16191,18504,18761)
	Button zapBadROIs,pos={260,210},size={100,20},proc=button_zapBadROIs,title="Zap bad ROIs"
	Button zapBadROIs,help={"Discard ROIs with bad signals"}
	Button zapBadROIs,fColor=(16191,18504,18761)

	// pig: main box
	// /w=(left, top, right, bottom)
	SetDrawEnv linethick = 0,fillfgc = (64824,27308,21496)
	DrawRRect 20,275,370,345
	SetDrawEnv fsize = 16,fstyle = 1,textrgb = (65535,65535,65535)
	DrawText 33,270,"pig - others"
	// pig: choose script
	Button pigScript, pos={30,285}, size={100,20}, proc=button_pigScript, title="choose script"
	Button pigScript, fColor=(16191,18504,18761)
	// pig: run
	Button pigRun, pos={270,285}, size={90,20}, proc=button_pigRun, title="run"
	Button pigrun, fColor=(16191,18504,18761)
	// pig: box for interpreter path
	SetVariable pigPathToInterpreter, pos={30,315}, size={333,20}, proc=button_setPythonInterpreter, title="python interpreter"
	SetVariable pigPathToInterpreter, help={"path to python interpreter"},fSize=12,fStyle=1
	SetVariable pigPathToInterpreter, fColor=(65535,65535,65535)
	SetVariable pigPathToInterpreter, value = root:Packages:pig:pigPathToPythonInterpreter
endMacro

menu "Macros"
	"Load PIG - KS analysis", pigPanel()
end

// pig: select python interpreter - automatic at the start
// to manually write the path to the interpreter & create txt
// it overwrites whatever it is written in the txt in the pig folder
function button_setPythonInterpreter(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			// string/g root:Packages:pig:pigPathToPythonInterpreter = sval
			
			// TODO:
			// make a function in a different .ipf for this
			// create txt file 
			string pigPath = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "User Procedures:Pig:"
			// create pig folder if it doesn't exists
			// q: supresses dialogs, z: prevents abort if folder doesn't exist
			getFileFolderInfo/q/z pigPath
			// path to file to be created
			string pigPythonPath_txt = pigPath + "pig_path_to_python_interpreter.txt"
			// some string vars
			string pathToTxt
			string pathToPython = sval
			string pythonEnvironmentDir = pigPath
			// check if python interpreter actually exists
			checkPythonInterpreter(stop=1)
			// if OK, save interpreter
			string/g root:Packages:pig:pigPathToPythonInterpreter = sval
			// check platform
			string platform = IgorInfo(2)
			if (CmpStr(platform, "Windows") != 0)
				pathToTxt = pigPythonPath_txt
				pathToTxt = ReplaceString("Macintosh HD:", pathToTxt, "/")
				pathToTxt = ReplaceString(":", pathToTxt, "/")
				string cmd
				sprintf cmd, "do shell script \"touch '%s' && echo %s > '%s'\"", pathToTxt, pathToPython, pathToTxt
				executeScriptText cmd
				print "\npath to python saved at: "+pathToTxt
			else
				pathToTxt = parseFilePath(5, pigPythonPath_txt, "\\", 0, 0)		
				executeScriptText/b/z "cmd.exe /c echo "+pathToPython+" >> \""+pathToTxt+"\""
				print "\npath to python saved at: "+pathToTxt
			endif
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
end


// pig: load movie
function button_loadMovie(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
		
			pigLoadMovie()
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end

// pig: load multiple movies
function button_multiLoad(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
			
			print "\nLoading:"
			pigMultiLoad()
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end

// pig: load analysis wave
function button_loadAnalysisWave(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up

			pigLoadAnalysisWave()
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end

// pig: define FOV
function button_setFOV(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			variable/g root:packages:pig:FOV=dval
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end

// pig: define alpha
function button_setAlpha(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			variable/g root:packages:pig:alpha=dval
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end

// pig: define ROIsize
function button_setROIsize(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			variable/g root:packages:pig:approxROIsize=dval
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end

// pig: define min distance
function button_setMinDist(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			variable/g root:packages:pig:minDist=dval
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end

// checkbox for making videos
Function pigMakeVideos(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba	
	switch( cba.eventCode )
		case 2: // mouse up
		
			variable/g root:packages:pig:mkVideos = cba.checked
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
end

// pig: run ks analysis
function button_runKS(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
			
			// drop-down menu for movie
			string expName, expWave
			string cwd = getDataFolder(1)
			// this removes all the ks processed movies from the list
			string moviesInFolder = wavelist("!*_reg*",";","DIMS:3")
			prompt expName, "pick movie (in current data folder)", popup, moviesInFolder
			// drop-down menu for type of analysis -- analysis wave
			setDataFolder root:analysisWaves
			string expWaves = "default;"+waveList("*", ";", "")
			setDataFolder cwd
			prompt expWave, "pick analysis file (default = baseline/responses)", popup, expWaves
			// pop-up window
			doprompt "pick movie (& analysis wave)", expName, expWave
			if(V_flag==1)
				Abort
			endif
			
			// movie & analysis wave
			// we need full paths, because they're from different dirs
			string picwave_filepath = cwd + expName
			wave picwave = $picwave_filepath
			string expwave_filepath = "root:analysisWaves:" + expwave
			wave anWave = $expWave_filepath
			
			// cmpstr: 0 = equal, 1 = different
			if (cmpstr(expWave_filepath,"root:analysisWaves:default") == 0)
				pigRunKS(picwave)
			else
				// pass analysis wave as optional argument
				pigRunKS(picwave, analysisWave=anWave)	
			endif
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
end


// pig: select python script
function button_pigScript(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
		
			pigSelectPythonScript()
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end


// pig: run python script on Igor wave
function button_pigRun(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
		
			string list=wavelist("*",";","DIMS:3")
			string name
			prompt name, "pick movie (in current data folder)", popup,list
			doprompt "pick movie ", name
				if(V_flag==1)
					Abort
				endif	
			wave picwave=$name
			
			// TODO 
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end


///////////////////////
//							//
//	  free buttons		//
//							//
///////////////////////


// button 01
function button1(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
		
			// function 01
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end

// button 02
function button2(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
		
			// function 02
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end

// button 03
function button3(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
		
			// function 03
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end

// button 04
function button4(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
		
			// function 04
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end

// button 05
function button5(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
		
			// function 05
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end

// button 06
function button6(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
		
			// function 06
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end

// button 07
function button7(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
		
			// function 07
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end


/////////////////////////////
//									//
//	  some more functions		//
//									//
/////////////////////////////


// 08. Show
function button_show(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
		
			pigImshow()
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end


// 09. metadata
function button_GetMetadata(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up

			// function: get metadata
			string list=wavelist("*",";","DIMS:3")
			string name
			prompt name, "pick movie (in current data folder)", popup,list
			doprompt "pick movie ", name
				if(V_flag==1)
					Abort
				endif	
			wave picwave=$name
			pigGetMetadata(picwave)
			// appendMetadata(picwave)
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end

// 10. ROI buddy
function button_ROIbuddy(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
			
			// function: ROI buddy
			string list=wavelist("*traces*",";","DIMS:2")
			string name
			prompt name, "Data wave", popup,list
			doprompt "Pick data to examine ", name
				if(V_flag==1)
					Abort
				endif
				
			wave w=$name
			pigROIbuddy(w)
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end

// 11. Zap Bad ROIs
function button_zapBadROIs(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
		
			// function: ROI buddy
			string list=wavelist("*traces*",";","DIMS:2")
			string name
			prompt name, "Data wave", popup,list
			doprompt "Pick data to examine ", name
				if(V_flag==1)
					Abort
				endif
				
			wave w=$name
			zapBadROIs(w)
			
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end