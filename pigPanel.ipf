#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// #include "pig"

// panel for pig
Window pigPanel(): Panel_pig
	PauseUpdate; Silent 1	
	// for manually defining FOV & alpha
	NewDataFolder/O root:Packages:pig
	variable/g root:Packages:pig:FOV=610
	variable/g root:Packages:pig:alpha=0.05
	// get path to python interpreter
	pigDefinePythonInterpreterPath()
	pigDefinePathToKS()
	// main panel
	// /w=(left, top, right, bottom)
	NewPanel/w = (666,111,1055,400) as "Pig — KS analysis"
	ModifyPanel cbRGB = (0, 13107, 26214)
	SetDrawLayer UserBack
	// ks: main box
	SetDrawEnv linethick=0, fillfgc=(64824,27308,21496)
	DrawRRect 20,35,370,70
	SetDrawEnv fsize = 16, fstyle = 1, textrgb = (65535,65535,65535)
	DrawText 33, 30, "Pig - KS analysis"
	// ks: load movie
	Button Load, pos={30,43}, size={70,20}, proc=button_loadMovie, title="Load"
	Button Load, fColor=(16191,18504,18761)
	// ks: box for FOV 
	SetVariable FOV, pos={110,43}, size={70,40}, proc=button_setFOV, title="FOV"
	SetVariable FOV,help={"Field of view in µm @ zoom 1"},fSize=12,fStyle=1
	SetVariable FOV,fColor=(65535,65535,65535)
	SetVariable FOV,limits={0,inf,0},value = root:Packages:pig:FOV
	// ks: box for alpha 
	SetVariable alpha, pos={190,43}, size={85,40}, proc=button_setAlpha, title="alpha"
	SetVariable alpha,help={"pre-set significance threshold for p-values"},fSize=12,fStyle=1
	SetVariable alpha,fColor=(65535,65535,65535)
	SetVariable alpha,limits={0,inf,0},value = root:Packages:pig:alpha
	// ks: run
	Button runKS, pos={290,42}, size={70,20}, proc=button_runKS, title="Run KS"
	Button runKS,fColor=(16191,18504,18761)
	// other functions: main box
	SetDrawEnv linethick = 0,fillfgc = (10283,48779,31735)
	DrawRRect 20,105,370,175
	SetDrawEnv fsize = 16,fstyle = 1,textrgb = (65535,65535,65535)
	DrawText 33,100,"More"
	// other functions: buttons
	Button button1,pos={30,115},size={75,20},proc=button1,title="01"
	Button button1,help={"free button"}
	Button button1,fColor=(16191,18504,18761)
	Button button2,pos={115,115},size={75,20},proc=button2,title="02"
	Button button2,help={"free button"}
	Button button2,fColor=(16191,18504,18761)
	Button button3,pos={200,115},size={75,20},proc=button3,title="03"
	Button button3,help={"free button"}
	Button button3,fColor=(16191,18504,18761)
	Button button4,pos={285,115},size={75,20},proc=button4,title="04"
	Button button4,help={"free button"}
	Button button4,fColor=(16191,18504,18761)
	Button button5,pos={30,147},size={100,20},proc=button5,title="05"
	Button button5,help={"free button"}
	Button button5,fColor=(16191,18504,18761)
	Button button6,pos={145,147},size={100,20},proc=button6,title="06"
	Button button6,help={"free button"}
	Button button6,fColor=(16191,18504,18761)
	Button button7,pos={260,147},size={100,20},proc=button7,title="07"
	Button button7,help={"free button"}
	Button button7,fColor=(16191,18504,18761)	
	// pig: main box
	SetDrawEnv linethick = 0,fillfgc = (64824,27308,21496)
	DrawRRect 20,210,370,270
	SetDrawEnv fsize = 16,fstyle = 1,textrgb = (65535,65535,65535)
	DrawText 33,205,"pig - others"
	// pig: choose script
	Button pyScript, pos={30,220}, size={100,20}, proc=button_pyScript, title="choose script"
	Button pyScript, fColor=(16191,18504,18761)
	// pig: run
	Button pigRun, pos={285,220}, size={75,20}, proc=button_pyScript, title="run"
	Button pigrun, fColor=(16191,18504,18761)
	// pig: box for interpreter path
	SetVariable pigPathToInterpreter, pos={30,245}, size={333,20}, proc=button_setPythonInterpreter, title="python interpreter"
	SetVariable pigPathToInterpreter, help={"path to python interpreter"},fSize=12,fStyle=1
	SetVariable pigPathToInterpreter, fColor=(65535,65535,65535)
	SetVariable pigPathToInterpreter, value = root:Packages:pig:pigPathToPythonInterpreter
EndMacro

Menu "Macros"
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
			
			string/g root:Packages:pig:pigPathToPythonInterpreter = sval
			
			// TODO:
			// make a function in pig.ipf for this
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
				executeScriptText "cmd.exe /c echo "+pathToPython+" >> \""+pathToTxt+"\""
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


// pig: run ks analysis
function button_runKS(ba) : ButtonControl
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
			
			pigRunKS(picwave)
			
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
end


// pig: select python script
function button_pyScript(ba) : ButtonControl
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