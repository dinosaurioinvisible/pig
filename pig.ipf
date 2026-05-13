#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include <ProcedureBrowser>
#include "pigPanel"
#include "pigGetMetadata"
// these have been previously developed in the lab
// i have modified them (more or less) & added them to the PIG folder
// for stand-alone use, and to avoid confusion from diff versions
#include "Ch2LineRes"
#include "pigLoadMultipleFiles"
#include "pigHelperFunctions"
#include "pigROIbuddy"


// ~ index
// 0. brief comment
// 1. runCommandOnWindowsCmd
// 2. runCommandOnMacosShell 
// 3. runPythonScriptOnMovieWindows
// 4. runPythonScriptOnMovieMacOs
// 5. pigDefinePythonInterpreterPath
// 6. pigDefinePathToKS
// 7. pigLoadMovie
// 8. pigSelectPythonScript
// 9. pigRunKS 
// 10. pigLoadAndRemoveTempFolder
// 11. pigRunPythonScriptOnMovie 


// 0.
// we want to define paths that can be reused
// for the path to the python interpreter: 
// there is a function that may be called only once
// we're creating a txt file that can be read every time pig is loaded
// the txt contains the path to the python interpreter
// that path (if exists) is loaded as a global variable
// when pressing the 'python' button


// 1.
// basic fx for running single commands in macos shell & windows cmd
// print s_value isn't really needed, can be ommitted, but may be useful
function runCommandOnWindowsCmd(string command)
	executeScriptText/z "cmd.exe /c "+command
	print s_value
end

// 2.
function runCommandOnMacosShell(string command)
	string igorcmdx
	sprintf igorcmdx, "do shell script \"%s\"", command
	executeScriptText/z igorcmdx
	print s_value
end 


// 3.
// runs a python script into a movie using windows cmd
function runPythonScriptOnMovieWindows(string path_to_python, string path_to_python_script, string path_to_movie)
	string igorcmd = path_to_python+" "+path_to_python_script+" "+path_to_movie
	// you may want to comment out these 2 lines
	print "\nwindows cmd command:"
	print igorcmd
	ExecuteScriptText/b/z "\""+path_to_python+"\" \""+path_to_python_script+"\" \""+path_to_movie+"\""
	// s_value actually returns eventual errors in execution, so better not to comment this out
	print "s_value:"
   print s_value
end


// 4.
// on mac this can be a pain, mostly because of the "do shell script"
// you can do without it, but it can get quite confusing
function runPythonScriptOnMovieMacOs(string path_to_python, string path_to_python_script, string path_to_movie, [string args])
	string igorcmd
	if (paramIsDefault(args) == 0)
		igorcmd = "do shell script \"\'" + path_to_python + "\' \'" + path_to_python_script + "\' \'" + path_to_movie + "\' \'" + args + "\'\""
	else
		// pawell fix, really classy
		igorcmd = "do shell script \"\'" + path_to_python + "\' \'" + path_to_python_script + "\' \'" + path_to_movie + "\'\""
	endif
	// for debugging only
	// string igorcmd
	// sprintf igorcmd, "do shell script \"%s %s %s\"", path_to_python, path_to_python_script, path_to_movie
	print "\nshell command:"
	print igorcmd
   executeScriptText/z igorcmd
   // this shows errors from python
   print "s_value:"
   print s_value
end


// 5.
// look up for txt with python interpreter in default txt, otherwise create one
function pigDefinePythonInterpreterPath()
	// define path to pig directory in users procedures
	string pigPath = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "User Procedures:Pig:"
	// create pig folder if it doesn't exists
	// q: supresses dialogs, z: prevents abort if folder doesn't exist
	getFileFolderInfo/q/z pigPath
	if (v_flag != 0)
		// c: creates dir, /o: overwrites to avoid error
		newPath/c/o pigPath, pigPath
	endif
	// search for txt file with location of python interpreter in pig folder
	string pigPythonPath_txt = pigPath + "pig_path_to_python_interpreter.txt"
	variable fref
	// string line
	string pathToTxt
	string platform = IgorInfo(2)
	string pathToPython
	// try to read python interpreter location from txt file in pig folder
	// r: read only, z: prevents abort if file doesn't exist
	open/r/z fref as pigPythonPath_txt
	// if not, user has choose an interpreter
	if (v_flag == 0)
		freadLine fref, pathToPython
		close fref
		// just for information, when loading pathToPython from txt
		// this is a bit weird, but couldn't make it work for null otherwise
		if (numtype(strlen(pathToTxt)) == 2)
			if (CmpStr(platform, "Windows") != 0)
				pathToTxt = parseFilePath(5, pigPythonPath_txt, "/", 0, 0)
			else
				pathToTxt = parseFilePath(5, pigPythonPath_txt, "\\", 0, 0)
			endif
		endif
		// print info
		print "\n\tusing python interpreter at: "+pathToPython
		print "\tpython path saved in txt file at: "+pathToTxt
		string/g root:Packages:pig:pigPathToPythonInterpreter = TrimString(pathToPython)
	else
		print "\npig_path_to_python_interpreter.txt not found"
		string/g root:Packages:pig:pigPathToPythonInterpreter = ""
	endif
end


// 6.
function pigDefinePathToKS()
	// path to pig directory in users procedures
	string pigPath = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "User Procedures:Pig:"
	// search for txt file with location of python interpreter in pig folder
	string pathToKSIgor = pigPath + "ks_method.py"
	string platform = IgorInfo(2)
	string pathToKS
	if (CmpStr(platform, "Windows") != 0)
		pathToKS = parseFilePath(5, pathToKSIgor, "/", 0, 0)
	else
		pathToKS = parseFilePath(5, pathToKSIgor, "\\", 0, 0)
	endif
	string/g root:Packages:pig:pigPathToKS = pathToKS
end


// 7.
// load movie
function pigLoadMovie()

	imageload/q/o/c=-1
	// flag=0 is no image in imageload
	if (v_flag == 0)
		Abort
	endif
	// remove extension from name 
	string fname = s_filename[0,strsearch(s_filename,".tif",0)-1]
	// replace spaces with underscores (to avoid failure at loading)
	fname = ReplaceString(" ", fname, "_")
	// create folder for movie and move loaded movie there
	NewDataFolder/O root:$fname
	string movieName = "root:" +fname+ ":" +fname
	// if movie exists, overwrite
	if (waveExists($movieName))
		killwaves/z $movieName
	endif
	// move to its own folder
	moveWave $s_filename, $movieName
	
	// retrieve necessary info	
	// this works with the older version of scan image only
	print s_info
	string metadata = s_info
	// this is to check access to metadata
	// get info - to access note info: print note($"movieName")
	variable zoomFactor = numberByKey("state.acq.zoomFactor",s_info,"=","\r")
	string expDate = stringByKey("state.internal.triggerTimeString",s_info,"=","\r")
	variable msPerLine = numberByKey("state.acq.msPerLine",s_info,"=","\r")
	variable frameRate = numberByKey("state.acq.frameRate",s_info,"=","\r")
	variable angleFast = numberByKey("state.acq.scanAngleMultiplierFast",s_info,"=","\r")
	variable angleSlow = numberByKey("state.acq.scanAngleMultiplierSlow",s_info,"=","\r")
	
	// if this fails (the access to the metadata)
	// scaling would void the picture with nans
	// safest option is to retrieve whatever info available and abort
	// here I try to get the info using the getMetadata() function first
	if (numtype(zoomFactor) == 2)
		// i'm defining this here anyway, for getMetadata()
		note $movieName, "fdir="+s_path
		note $movieName, "fname="+s_filename
		note $movieName, "basename="+fname
		string fpath = s_path+s_filename
		note $movieName, "fpath="+fpath
		note $movieName, ""
		// try to get metadata
		pigGetMetadata($movieName)
		// move metadata from root: to movie folder
		string cwdx = getDataFolder(1)
		string metadataWaveDefault = cwdx + fname + "_metadata"
		string metadataWave = movieName+"_metadata"
		// if it exists, erase (otherwise yields error)
		if (waveExists($metadataWave))
			killwaves/z $metadataWave
		endif
		moveWave $metadataWaveDefault, $metadataWave
		// try to extract info from it & append it to the notes
		appendMetadata($movieName)
		// generally whatever the info available is, is not so relevant
		// but probabbly is better than nothing anyway
		note $movieName, metadata
		// now we need the values for scaling
		string info = note($movieName)
		zoomFactor = NumberByKey("zoomFactor", info, "=", "\r")
		angleFast = NumberByKey("scanAngleMultiplierFast", info, "=", "\r")
		angleSlow = NumberByKey("scanAngleMultiplierSlow", info, "=", "\r")
		frameRate = NumberByKey("frameRate", info, "=", "\r")
		msPerLine = NumberByKey("msPerLine", info, "=", "\r")
	endif
	
	// get deltas to scale 
	// not the same, but basically from apply header info (in LoadScanImage)
	variable x_res,y_res
	variable timePerLine = msPerLine/1000
	nvar fov = root:Packages:pig:FOV
	x_res = fov / zoomFactor * angleFast / dimsize($movieName,0)
	y_res = fov / zoomFactor * angleSlow / dimsize($movieName,1)
	// setscale dim, num1, num2 (x: rows, y: cols)
	// /p is for changing the delta value according to num2
	setscale /p x, 0, x_res,"µm",$movieName
	setscale /p y, 0, y_res,"µm",$movieName
	variable z_res
	z_res = timePerLine *  dimsize($movieName,1)
	setscale /P z, 0, z_res,"s",$movieName
	
	// append info to notes
	note $movieName, "expDate="+expDate
	note $movieName, "msPerLine="+num2str(msPerLine)
	note $movieName, "frameRate="+num2str(frameRate)
	variable dt = 1/frameRate
	note $movieName, "dt="+num2str(dt)
	note $movieName, "zoomFactor="+num2str(zoomFactor)
	note $movieName, "scanAngleMultiplierFast="+num2str(angleFast)
	note $movieName, "scanAngleMultiplierSlow="+num2str(angleSlow)
	note $movieName, "fdir="+s_path
	note $movieName, "fname="+s_filename
	note $movieName, "basename="+fname
	string filePath = s_path+s_filename
	note $movieName, "fpath="+filePath
	note $movieName, ""
	// append all info (in case it's needed)
	note $movieName, metadata
	
	// split channels (using fxs from LoadScanImage
	variable nChannels = nChannelsFromHeaderx($movieName)
	// in case there's no info in the header (so nChannels = nan)
	if (numtype(nChannels) == 2)
		print("\nDidn't find info for nChannels in the metadata: assuming 2 channels")
		nChannels = 2
	endif
	splitChannelsx($movieName, nChannels=nChannels)

	// move to movie folder
	variable i
	string chName, chPath
	for (i=0; i<nChannels; i+=1)
		chName = fname+"_ch"+num2str(i+1)
		chPath = movieName+"_ch"+num2str(i+1)
		// if channel movie exists, erase (otherwise yields error)
		if (waveExists($chPath))
			killwaves/z $chPath
		endif
		moveWave $chName, $chPath
	endFor
	
	// mk stimulus wave
	waveCh2lineRes($movieName)
	string cwd = getDataFolder(1)
	string stimulusWaveDefault = cwd+"timewave"
	string stimulusWaveCh2res = movieName+"_ch2stim"
	// if it exists, erase (otherwise yields error)
		if (waveExists($stimulusWaveCh2res))
			killwaves/z $stimulusWaveCh2res
		endif
	moveWave $stimulusWaveDefault, $stimulusWaveCh2res
		
	print "\nloaded movie from: "+filePath
end


// 8.
// select python script
function pigSelectPythonScript()
	// d: dialog, r: read only
	string filter_script = ".py"
	string message_script = "select python script"
	Open/d/r/f=filter_script/m=message_script refNum
	// print whether current script is loaded or not
	if (cmpstr(s_filename,"") == 0)
		print "\n\tno .py file selected"
		svar pigPathToScript
		if (numtype(strlen(pigPathToScript)) == 2)
			print "\tno script chosen yet"
		else
			print "\tcurrent python script: "+pigPathToScript
		endif
		abort 
	endif
	string path_to_python_script = s_fileName
	//for debugging
	//print path_to_python_script
	//mode 5 is for turning igor spaths into unix/windows type paths
	string platform = IgorInfo(2)
	if (CmpStr(platform, "Windows") == 0)
		path_to_python_script = parseFilePath(5,path_to_python_script,"\\",0,0)
	else
		path_to_python_script = parseFilePath(5,path_to_python_script,"/",0,0)
	endif
	string/g root:Packages:pig:pigPathToScript = path_to_python_script
	print "\n\tselected python script at: "+path_to_python_script
end


// 9.
// run ks analysis
function pigRunKS(wave movie)
	string platform = IgorInfo(2)
	// path to python interpreter
	svar pigPathToPython = root:Packages:pig:pigPathToPythonInterpreter
	// path to KS.py
	svar pigPathToKS = root:Packages:pig:pigPathToKS
	// get path to file
	string pathToMovieIgor = stringByKey("fpath",note(movie),"=","\r")
	string pathToMovie
	if (CmpStr(platform, "Windows") == 0)
		pathToMovie = parseFilePath(5, pathToMovieIgor,"\\",0,0)
	else
		pathToMovie = parseFilePath(5, pathToMovieIgor,"/",0,0)
	endif
	// optional parameters
	nvar fov = root:Packages:pig:FOV
	nvar alpha = root:Packages:pig:alpha
	// run KS
	string dirpath
	if (CmpStr(platform, "Windows") == 0)
		RunPythonScriptOnMovieWindows(pigPathToPython, pigPathToKS, pathToMovie)
		dirpath = pathToMovie[0,strsearch(pathToMovie, "\\", strlen(pathToMovie)-1, 3)]
	else
   	string ks_args
		sprintf ks_args, "--fov=%s\' \'--alpha=%s", num2str(fov), num2str(alpha)
   	
   	RunPythonScriptOnMovieMacOs(pigPathToPython, pigPathToKS, pathToMovie, args=ks_args)
   	dirpath = pathToMovie[0,strsearch(pathToMovie, "/", strlen(pathToMovie)-1, 3)]
	endif
	// load files into igor
	string path_to_python_output = dirpath+"python_output"
	LoadFiles(dirpath=path_to_python_output)
	print "temporal files at: "+path_to_python_output
	// remove temporal files
	if (CmpStr(platform, "Windows") == 0)
		executeScriptText/b/z "cmd.exe /c rmdir /s /q "+path_to_python_output 
	else
		string igorcmd = "do shell script \"rm -rf \'" + path_to_python_output + "\'\""
		print igorcmd
   	executeScriptText/z igorcmd
		print s_value
	endif
	print "removed temporal files from: "+path_to_python_output
	
	// scale ks imported files
	// location in data browser 
	string movieWave = getWavesDataFolder(movie,2)
	// to adjust temporal scaling
	variable dt = numberByKey("dt",note(movie),"=","\r")
	// copyscales sourceWave, destinationWave
	string wx = movieWave + "_reg"
	copyscales $movieWave, $wx
	setscale/p z, 0,  dt, "s", $wx
	// this wave name can change
	// _int is for interpolation method
	string wx_int = wx + "_int"
	// _isq is for pixel squaring
	string wx_isq = wx + "_isq"
	if (WaveExists($wx_int))
   	copyScales $movieWave, $wx_int
   	setscale/p z, 0,  dt, "s", $wx_int
   	wx = wx + "_int"
	elseif (WaveExists($wx_isq))
    	CopyScales $movieWave, $wx_isq
    	setscale/p z, 0,  dt, "s", $wx_isq
    	wx = wx + "_isq"
	else
   	print "\ncouldn't find aspect correction file\n"
	endif
	// bleach correction	
	wx = wx + "_bc"
	copyscales $movieWave, $wx
	setscale/p z, 0,  dt, "s", $wx
	// movie with overlayed synapses
	string wx_overlay = wx + "_overlay"
	copyscales $movieWave, $wx_overlay
	setscale/p z, 0,  dt, "s", $wx_overlay
	// same base name, different terminations
	string wx_df = wx + "_deltaf"
	copyscales $movieWave, $wx_df
	string wx_pm = wx + "_pixelmask"
	copyscales $movieWave, $wx_pm
	string wx_rm = wx + "_roimask"
	copyscales $movieWave, $wx_rm
	// for these, time goes in the x axis
	string wx_dff = wx + "_dff_traces"
	string wx_gas = wx + "_gs_amps"
	// /p: change delta, x:dim, 0:start, dt:delta val, s:units, $wx: wave
	setscale/p x, 0,  dt, "s", $wx_dff
	setscale/p x, 0,  dt, "s", $wx_gas
	
	// redimension stimulus wave from python
	string stimulusWaveKS = movieWave+"_stimulus"
	string stimulusWave = movieWave+"_sti"
	// if it exists, erase (otherwise yields error)
		if (waveExists($stimulusWave))
			killwaves/z $stimulusWave
		endif
	// have to create a new wave to get rid of col1
	variable nrows = Dimsize($stimulusWaveKS,0)
	make/o/n=(nrows) $stimulusWave 
	wave sti = $stimulusWave
	wave stiKS = $stimulusWaveKS
	sti = stiKS[p][1]
	setScale/p x 0, dt, "s", sti
	killwaves stiKS
	
	// make a standar deviation image from processed movie
	stdev($(nameOfWave($wx)), (nameOfWave($wx)+"_std"))
end


// 10.
// to load python outputs and then remove temporal folders
function pigLoadAndRemoveTempFolder(string pathToTempFolder)
	// quick check
	print "pathToTempFolder= " + pathToTempFolder
	if (strlen(pathToTempFolder)==0)
		print("\nnull path\n")
		abort
	endif
	// load
	LoadFiles(dirpath=pathToTempFolder)
	print "loaded temporal files at: "+pathToTempFolder
	// remove
	string platform = IgorInfo(2)
	if (CmpStr(platform, "Windows") == 0)
		executeScriptText/b/z "cmd.exe /c rmdir /s /q "+pathToTempFolder
	else
		string cmd
		sprintf cmd, "do shell script \"rm -rf %s\"", pathToTempFolder
		executeScriptText/b/z cmd
		print s_value
	endif
	print "removed temporal files from: "+pathToTempFolder
end


// 11
// runs script on movie depending whether system is windows or macos
function pigRunPythonScriptOnMovie([string pathToPython, string pathToScript, string pathToMovie])
	// check platform
	string platform = IgorInfo(2)
	
	// 11.1 lookup paths
	
	// 11.1.1 check whether python interpreter has been defined
	if (paramIsDefault(pathToPython) != 0)
		// this functions looks up for, or creates a txt file with the path to python
		// the path inside the txt file is made a global string = pigthonPythonPath
		pigDefinePythonInterpreterPath()
		// svar makes a reference to the global string pigPythonPath
		svar pigPathToPython = root:Packages:pig:pigPathToPython
		// trim removes whitespaces & newlines, need because of echo + just in case
		pathToPython = TrimString(pigPathToPython)
	endif

	// 11.1.2 check for path to script	
	svar/z pigPathToScript = root:pigPathToScript
	// if script in args, make script as preferred
	if (paramIsDefault(pathToScript) == 0)
		string/g pigPathToScript = pathToScript
	// if not, and there is preferred script, used that
	elseif (svar_Exists(pigPathToScript) == 1)
		pathToScript = pigPathToScript
	else
		pigSelectPythonScript()
		pathToScript = pigPathToScript
	endif
	
	// 11.1.3 check path to movie
	svar/z pigPathToMovie = root:pigPathToMovie
	// same as 11.1.2
	if (paramIsDefault(pathToMovie) == 0)
		string/g pigPathToMovie = pathToMovie
	// if not, and there is preferred script, used that
	elseif (svar_Exists(pigPathToMovie) == 1)
		pathToMovie = pigPathToMovie
	else
		pigLoadMovie()
		pathToMovie = pigPathToMovie
	endif
	
	
	// 11.2. print & double check
	print "\npig:"
	// path to interpreter
	if (numtype(strlen(pathToPython)) == 2)
		print "you need to choose a python interpreter"
		abort
	else
		print "path to python interpreter: "+pathToPython
	endif
	// path to python script
	if (numtype(strlen(pigPathToScript)) == 2)
		print "you need to choose some python script"
		abort
	else
		print "path to python script: "+pathToScript
	endif
	// path to movie
	if (numtype(strlen(pigPathToMovie)) == 2)
		print "you haven't chosen a movie yet"
		abort
	else
		print "path to movie: "+pigPathToMovie
	endif


	// 11.3. run python script from terminal
	if (CmpStr(platform, "Windows") == 0)
		RunPythonScriptOnMovieWindows(pathToPython, pathToScript, pathToMovie)
	else
		RunPythonScriptOnMovieMacOs(pathToPython, pathToScript, pathToMovie)
	endif
	
	
	// 11.4. load files from python output folder into igor
	string dirpath
	if (CmpStr(platform, "Windows") == 0)
		dirpath = pathToMovie[0,strsearch(pathToMovie, "\\", strlen(pathToMovie)-1, 3)]
	else
		dirpath = pathToMovie[0,strsearch(pathToMovie, "/", strlen(pathToMovie)-1, 3)]
	endif
	string path_to_python_output = dirpath+"python_output"
	LoadFiles(dirpath=path_to_python_output)
	print "temporal files at: "+path_to_python_output
	
	
	// 11.5. remove temporal folder
	if (CmpStr(platform, "Windows") == 0)
		executeScriptText/b/z "cmd.exe /c rmdir /s /q "+path_to_python_output 
	else
		string cmd
		sprintf cmd, "do shell script \"rm -rf %s\"", path_to_python_output
		executeScriptText/b/z cmd
		print s_value
	endif
	print "removed temporal files from: "+path_to_python_output
end




