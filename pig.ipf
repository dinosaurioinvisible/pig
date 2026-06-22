#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include <ProcedureBrowser>
#include "pigPanel"
#include "pigGetMetadata"
// these have been previously developed in the lab
// i have modified them (some much more than others) & added them to the PIG folder
// for stand-alone use, and to avoid compilation confusions/issues
#include "pigLoadMultipleFiles"
#include "pigHelperFunctions"
#include "pigZapBadROIs"
#include "pigROIbuddy"
#include "pigCh2LineRes"
#include "pigWM4DImageSlider"


// ~ index
// 0. brief comment
// 1. runCommandOnWindowsCmd
// 2. runCommandOnMacosShell 
// 3. runPythonScriptOnMovieWindows
// 4. runPythonScriptOnMovieMacOs
// 5. pigDefinePythonInterpreterPath
// 6. pigDefinePathToKS
// 7. pigLoadMovie
// 8. pigMultiLoad
// 9. pigLoadAnalysisWave
// 10. pigRunKS 
// 11. pigSelectPythonScript
// 12. pigLoadAndRemoveTempFolder
// 13. pigRunPythonScriptOnMovie 


// 0.
// we want to define paths that can be reused
// for the path to the python interpreter: 
// we're creating a txt file that can be read every time pig is loaded
// the txt file stores the path written in the panel
// that path (if exists) is loaded as a global variable
// every time pig is initialized
// there are hardcoded paths to some python functions as well:
// ks_method.py & getMetadata.py
// if necessary, these can be changed from the pigPanel.ipf script


// 1.
// basic fx for running single commands in macos shell & windows cmd
// print s_value isn't really needed, can be ommitted, but may be useful
function runCommandOnWindowsCmd(string command)
	executeScriptText/z "cmd.exe /c "+command
	print s_value
end


// 2.
// runs simple command in macos terminal
function runCommandOnMacosShell(string command)
	string igorcmdx
	sprintf igorcmdx, "do shell script \"%s\"", command
	executeScriptText/z igorcmdx
	print s_value
end 


// 3.
// runs a python script into a movie using windows cmd
function runPythonScriptOnMovieWindows(string path_to_python, string path_to_python_script, string path_to_movie, [string args])
	string igorcmd
	if (paramIsDefault(args) == 0)
		igorcmd = "\""+path_to_python+"\" \""+path_to_python_script+"\" \""+path_to_movie+"\" "+args
	else
		igorcmd = "\""+path_to_python+"\" \""+path_to_python_script+"\" \""+path_to_movie+"\""
	endif
	// you may want to comment out these 2 lines
	print "\nwindows cmd command:"
	print igorcmd
	executeScriptText/b/z igorcmd
	// s_value actually returns eventual errors in execution, so is better not to comment this out
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
   // do not comment this out, it shows statements coming from python (including errors)
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
	// if not, user has to choose an interpreter
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
	
	// check python interpreter
	// it's necessary for getMetadata()
	checkPythonInterpreter()
	// in case the user is loading from inside another dir
	setDataFolder root:
	// load normally
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
	// print s_info
	string metadata = s_info
	// this is to check access to metadata
	// get info - to access note info: print note($"movieName")
	variable zoomFactor = numberByKey("state.acq.zoomFactor",s_info,"=","\r")
	// string expDate = stringByKey("state.internal.triggerTimeString",s_info,"=","\r")
	variable msPerLine = numberByKey("state.acq.msPerLine",s_info,"=","\r")
	variable frameRate = numberByKey("state.acq.frameRate",s_info,"=","\r")
	variable angleFast = numberByKey("state.acq.scanAngleMultiplierFast",s_info,"=","\r")
	variable angleSlow = numberByKey("state.acq.scanAngleMultiplierSlow",s_info,"=","\r")
	
	// if this fails (the access to the metadata)
	// scaling would void the picture with nans
	// safest option is to retrieve whatever info available and abort
	// here I try to get the info using the getMetadata() function first
	variable meta = 0
	if (numtype(zoomFactor) == 2)
		// for later check
		meta = 1
		// i'm defining this here anyway, for getMetadata()
		note $movieName, "fdir="+s_path
		note $movieName, "fname="+s_filename
		note $movieName, "basename="+fname
		string fpath = s_path+s_filename
		note $movieName, "fpath="+fpath
		note $movieName, ""
		nvar fov = root:Packages:pig:FOV
		note $movieName, "fov=" + num2str(fov)
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
		// now we need the values for scaling
		string info = note($movieName)
		// get data from same notes
		zoomFactor = NumberByKey("zoomFactor", info, "=", "\r")
		angleFast = NumberByKey("scanAngleMultiplierFast", info, "=", "\r")
		angleSlow = NumberByKey("scanAngleMultiplierSlow", info, "=", "\r")
		msPerLine = NumberByKey("msPerLine", info, "=", "\r")
		frameRate = NumberByKey("frameRate", info, "=", "\r")
		variable dt = 1/frameRate
		// generally whatever the info available is, is not so relevant
		// but i'm appending it anyway
		note $movieName, metadata
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
	string filePath = s_path+s_filename
	dt = 1/frameRate
	// check if not already appended
	// so metadata was taken using pig
	if (meta == 0)
		// note $movieName, "expDate="+expDate
		nvar fov = root:Packages:pig:FOV
		note $movieName, "fdir="+s_path
		note $movieName, "fname="+s_filename
		note $movieName, "basename="+fname
		note $movieName, "fpath="+filePath
		note $movieName, ""
		note $movieName, "fov=" + num2str(fov)
		note $movieName, "zoomFactor="+num2str(zoomFactor)
		note $movieName, "scanAngleMultiplierFast="+num2str(angleFast)
		note $movieName, "scanAngleMultiplierSlow="+num2str(angleSlow)
		variable fovx = fov * angleFast / zoomFactor
		variable fovy = fov * angleSlow / zoomFactor
		fovx = fov * angleFast / zoomFactor
		fovy = fov * angleSlow / zoomFactor
		note $movieName, "fovZoom_x=" + num2str(fovx) 
		note $movieName, "fovZoom_y=" + num2str(fovy)
		note $movieName, "msPerLine="+num2str(msPerLine)
		note $movieName, "frameRate="+num2str(frameRate)
		note $movieName, "dt="+num2str(dt)
		variable dur = dimSize($movieName,2)/2/frameRate
		note $movieName, "duration="+num2str(dur)
		note $movieName, ""
		// append all info (in case it's needed)
		note $movieName, metadata
	endif
	
	// split channels (using fxs from LoadScanImage
	variable nChannels = nChannelsFromHeaderx($movieName)
	// in case there's no info in the header (so nChannels = nan)
	if (numtype(nChannels) == 2)
		print("\nDidn't find info for nChannels in the metadata: assuming 2 channels")
		nChannels = 2
	endif
	splitChannelsx($movieName, nChannels=nChannels)

	// move files to movie folder
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
	pigWaveCh2lineRes($movieName)
	string cwd = getDataFolder(1)
	string stimulusWaveDefault = cwd+"timewave"
	string stimulusWaveCh2res = movieName+"_ch2stim"
	// if it exists, erase (otherwise yields error)
	if (waveExists($stimulusWaveCh2res))
		killwaves/z $stimulusWaveCh2res
	endif
	moveWave $stimulusWaveDefault, $stimulusWaveCh2res
	// ch2res makes 1d wave, so has to be scaled in x
	setscale /P x, 0, dt,"s",$stimulusWaveCh2res
	
	// move to new folder in the data browser
	setDataFolder "root:" + fname
	print "\nloaded movie from: "+filePath
end



// 8. 
// load multiple movies
function pigMultiLoad()
	
	// check python interpreter
	// it's necessary for getMetadata()
	checkPythonInterpreter()
	
	// select movies
	variable refnum
	string fileFilters = "tiff,tif"
	string message = "select files"
	open/D/R/MULT=1/F=fileFilters/M=message refNum
	string outputPaths = s_fileName
	// cancel
	if (strlen(outputPaths) == 0)
		abort
	endif
	// in case the user is loading from inside another dir
	setDataFolder root:
	// number of files selected
	string sep = "\r"
	variable nfiles = itemsInList(outputPaths, sep)
	// use first file basename as folder name
	string basename = stringFromList(0, outputPaths, sep)
	basename = basename[0,strsearch(basename,".tif",0)-1]
	basename = basename[strsearch(basename,":",inf,1)+1,strlen(basename)-1]
	// replace spaces with underscores (to avoid failure at loading)
	basename = ReplaceString(" ", basename, "_")
	// create folder for movie and move loaded movie there
	string dirName = basename + "_multi" + num2str(nfiles)
	// newDataFolder/o root:$basename
	// setDataFolder "root:" + basename
	newDataFolder/o root:$dirName
	setDataFolder "root:" + dirName
	// iterate 
	// load, get metadata & de-interleave
	variable ifile
	string fdir, fname, fpath, movieName
	for(ifile=0; ifile < nfiles; ifile+=1)
		string path = stringFromList(ifile, outputPaths, sep)
		printf "%d: %s\r", ifile, path
		fdir = path[0,strsearch(path,":",inf,1)]
		fname = path[strsearch(path,":",inf,1)+1,strlen(path)-1]
		movieName = fname[0,strsearch(fname,".tif",0)-1]
		movieName = ReplaceString(" ", movieName, "_")
		// if movie exists, overwrite
		if (waveExists($movieName))
			killwaves/z $movieName
		endif
		// load normally
		imageload/q/o/n=$movieName/c=-1 path
		// flag=0 is no image in imageload
		if (v_flag == 0)
			Abort
		endif
		// metadata
		string metadata = s_info
		variable zoomFactor = numberByKey("state.acq.zoomFactor",s_info,"=","\r")
		variable msPerLine = numberByKey("state.acq.msPerLine",s_info,"=","\r")
		variable frameRate = numberByKey("state.acq.frameRate",s_info,"=","\r")
		variable angleFast = numberByKey("state.acq.scanAngleMultiplierFast",s_info,"=","\r")
		variable angleSlow = numberByKey("state.acq.scanAngleMultiplierSlow",s_info,"=","\r")
		// append metadata to movies
		nvar fov = root:Packages:pig:FOV
		note $movieName, "fdir="+fdir
		note $movieName, "fname="+fname
		note $movieName, "basename="+movieName
		note $movieName, "fpath="+path
		note $movieName, ""
		note $movieName, "fov=" + num2str(fov)
		note $movieName, "zoomFactor="+num2str(zoomFactor)
		note $movieName, "scanAngleMultiplierFast="+num2str(angleFast)
		note $movieName, "scanAngleMultiplierSlow="+num2str(angleSlow)
		variable fovx = fov * angleFast / zoomFactor
		variable fovy = fov * angleSlow / zoomFactor
		fovx = fov * angleFast / zoomFactor
		fovy = fov * angleSlow / zoomFactor
		note $movieName, "fovZoom_x=" + num2str(fovx) 
		note $movieName, "fovZoom_y=" + num2str(fovy)
		// this will change after the KS squaring
		// note $movieName, "pixelSize_x="
		// note $movieName, "pixelSize_y="
		note $movieName, "msPerLine="+num2str(msPerLine)
		note $movieName, "frameRate="+num2str(frameRate)
		variable dt = 1/frameRate
		note $movieName, "dt="+num2str(dt)
		note $movieName, ""
		note $movieName, metadata
		// split channels (using fxs from LoadScanImage
		variable nChannels = nChannelsFromHeaderx($movieName)
		// in case there's no info in the header (so nChannels = nan)
		if (numtype(nChannels) == 2)
			// print("\nDidn't find info for nChannels in the metadata: assuming 2 channels")
			nChannels = 2
		endif
		splitChannelsx($movieName, nChannels=nChannels)
		// erase non deinterleaved movie
		// killwaves/z $movieName
		// rename for concat
		string movieName0 = movieName + "_mov"
		rename $movieName, $movieName0
	endfor
	
	// concatenate main movie
	string movWavesInFolder = WaveList("*_mov", ";", "")
	string movName = basename + "_movs"
	concatenate/o/np=2 movWavesInFolder, $movName
	// concatenate waves ch1 & ch2 movies
	string ch1WavesInFolder = WaveList("*_Ch1", ";", "")
	string respName = basename + "_ch1cc"
	concatenate/o/np=2 ch1WavesInFolder, $respName
	string ch2WavesInFolder = WaveList("*_Ch2", ";", "")	
	string stimName = basename + "_ch2cc"
	concatenate/o/np=2 ch2WavesInFolder, $stimName
	// remove mov, ch1 & ch2 movies
	for(ifile=0; ifile < nfiles; ifile+=1)
		string movMovie = stringFromList(ifile, movWavesInFolder, ";")
		killwaves/z $movMovie
		string ch1movie = stringFromList(ifile, ch1WavesInFolder, ";")
		killwaves/z $ch1movie
		string ch2movie = stringFromList(ifile, ch2WavesInFolder, ";")
		killwaves/z $ch2movie
	endfor
		
	// get deltas to scale 
	// not the same, but basically from apply header info (in LoadScanImage)
	variable x_res,y_res
	variable timePerLine = msPerLine/1000
	x_res = fov / zoomFactor * angleFast / dimsize($movName,0)
	y_res = fov / zoomFactor * angleSlow / dimsize($movName,1)
	// setscale dim, num1, num2 (x: rows, y: cols)
	// /p is for changing the delta value according to num2
	setscale /p x, 0, x_res,"µm",$movName
	setscale /p y, 0, y_res,"µm",$movName
	variable z_res
	dt = timePerLine *  dimsize($movName,1)
	setscale /P z, 0, dt,"s",$movName
	// copy scales to ch1 & ch2
	copyscales $movName, $respName
	setscale/p z, 0,  dt, "s", $respName
	copyscales $movName, $stimName
	setscale/p z, 0,  dt, "s", $stimName
	
	// add movie to the list of concatenated
	svar ccMovies = root:Packages:pig:ccMovies
	if (WhichListItem(basename, ccMovies) < 0)
		ccMovies += basename + ";"
		ccMovies += basename + "=" + "["
		for(ifile=0; ifile < nfiles; ifile+=1)
			string cxPath = stringFromList(ifile, outputPaths, sep)
			ccMovies += cxPath
			if (ifile < nfiles-1)
				ccMovies += ","
			endif
		endfor
		ccMovies += "];"
	endif
	
	// make stimulus file
	pigWaveCh2lineRes($stimName)
	string ch2stim = basename+"_ch2stim"
	if (waveExists($ch2stim))
		killwaves/z $ch2stim
	endif
	rename timewave, $ch2stim
	// ch2res makes 1d wave, so has to be scaled in x
	setscale /P x, 0, dt,"s",$ch2stim
	// ch2res values are too high (sum all matrix per frame)
	wave ch2stimWave = $ch2stim
	ch2stimWave = ch2stimWave / 1000000
		
	// change name back to ch2 (remove the 'cc' from concat ch2s)
	rename $movName, $basename
	string respName0 = basename + "_ch1"
	rename $respName, $respName0
	string stimName0 = basename + "_ch2"
	rename $stimName, $stimName0
end


// 9.
// Load experiment wave - for stimulus/analysis wave
// string expWaves = pigLoadFiles(filters=".ibw;.txt",returnOnly=1,mkFolder="analysisWaves")
function pigLoadAnalysisWave()

	string cwd = getDataFolder(1)
	// pop-up window
	string message = "choose analysis/stimulus wave"
	string fileFilters = "Data files (*.ibw,*.txt):.ibw,.txt;"
	open/d/r/f=fileFilters/m=message refNum
	string path = S_fileName
	// cancel
	if (strlen(path) == 0)
		abort
	endif
	// get filenames for igor data browser
	string fname
	string platform = IgorInfo(2)
	if (CmpStr(platform, "Windows") == 0)
		// removes everything before the last ":" or "\\", etc
		fname = parseFilePath(3, path, "\\", 0, 0)
		fname = parseFilePath(3, path, ":", 0, 0)
	else
		fname = ParseFilePath(3, path, "/", 0, 0)
		fname = ParseFilePath(3, path, ":", 0, 0)
	endif
	fname = ReplaceString(" ", fname, "_")
	// create folder, move and load waves there
	// the /o here is not overwrite, but create if not
	newDataFolder/o/s root:$"analysisWaves"
	// load
	if (cmpStr(path[strlen(path)-4,strlen(path)-1], ".txt") == 0)
		loadWave/q/J/M/U={0,0,1,0}/D/A/K=0/L={0,0,0,0,0}/o/n=$fname path
		// remove 0 at the end of fname
		wave w = $(fname+"0")
		if (waveExists($fname))
			killWaves $fname
		endif
		rename w, $fname
	elseif (cmpStr(path[strlen(path)-4,strlen(path)-1], ".ibw")  == 0)	
		loadWave/q/o/n=$fname path
	endif
	note $fname, "fpath="+path
	// now come back to original location/folder
	setDataFolder cwd
	// try to change scale, according to base movie
	string list = wavelist("!*_ch*",";","DIMS:3")
	if (strlen(list) > 0)
		string baseMovie = stringFromList(0, list)
		variable dt = numberByKey("dt",note($baseMovie),"=","\r")
		string wx = "root:analysisWaves:" + fname
		setscale/p x, 0,  dt, "s", $wx
		redimension/n=(dimSize($wx, 0)) $wx
	endif
end



// 10.
// this functions has 4 main parts:
// a) definitions and checks
// b) run python script
// c) load and remove temp files
// d) renaming and scaling
// run ks analysis
function pigRunKS(wave movie [wave analysisWave])
	
	// first of all - check python interpreter
	checkPythonInterpreter()
	// define basic names
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
	// definitions for optional parameters
	nvar fov = root:Packages:pig:FOV
	nvar alpha = root:Packages:pig:alpha
	nvar approxROIsize = root:Packages:pig:approxROIsize
	nvar minDist = root:Packages:pig:minDist
	svar ccMovies = root:Packages:pig:ccMovies
	nvar mkVideos = root:Packages:pig:mkVideos
	svar pathToTempFolder = root:Packages:pig:pigPathToTempFolder
	// convert path to temp folder to system naming
	string sysPathToTempFolder = renamePath_igor2sys(pathToTempFolder)
	// if ks files in folder, mk new (avoid confusion)
	string newFolderName = nameOfWave(movie) + "_f" + num2str(fov) + "_a" + num2str(alpha)[2,3] + "_r" + num2str(approxROIsize) + "_d" + num2str(minDist)
	// to avoid naming problems for folder (bad character)
	newFolderName = ReplaceString(".", newFolderName, "")
	if (dataFolderExists("root:" + newFolderName))
		// prevent running same exp (same movie & params)
		print("\nit seems you've already processed this same movie & parameters?\n")
		abort
	endif
	// optional analysis wave
	// create & move to new folder in the data browser
	newDataFolder/o root:$newFolderName
	setDataFolder $("root:" + newFolderName)
	// check if concatenated or not (cc do not need deinterleaving)
	string bn = stringByKey("basename",note(movie),"=","\r")
	// this is to see check for concatenated movies
	// whichListItem return the index, if found (ccx = 1 if none)
	variable ccx = whichListItem(bn, ccMovies)
	// now check for analysis wave
	variable anx = 0
	if (paramIsDefault(analysisWave) == 0)
		anx = 1
		// make stimulus for ks in python
		// g:general text, m:terminator string, o:overwrites
		string fdir = stringByKey("fdir",note(movie),"=","\r")
		newPath/o/q anWavePath, fdir
		save/g/m="\n"/dlim=","/p=anWavePath/o analysisWave as "anWave.txt"
	endif
	
	// define arguments before runnning
	string ks_args
	// check platform
	if (CmpStr(platform, "Windows") == 0)
		// base optional arguments for running ks
   	sprintf ks_args, "--fov=%s --alpha=%s --ROIsize=%s --minDist=%s --tempFolder=%s", num2str(fov), num2str(alpha), num2str(approxROIsize), num2str(minDist), sysPathToTempFolder
   	// mk videos opt
    	if (mkVideos == 1)
       	ks_args += " --mk-videos"
    	endif
    	// if concatenated movies (multiload)
    	if (ccx > -1)
	    	string ccList = stringByKey(bn,ccMovies,"=",";")
       	ks_args += " --concat=" + ccList
    	endif
    	// if analysis wave
    	if (anx == 1)
    		ks_args += " --anWave"
    	endif
    else
    	// for mac it's a bit more difficult (for me at least)
    	// base arguments (alpha, ROIsize, minDist)
    	sprintf ks_args, "--fov=%s\' \'--alpha=%s\' \'--ROIsize=%s\' \'--minDist=%s\' \'--tempFolder=%s", num2str(fov), num2str(alpha), num2str(approxROIsize), num2str(minDist), sysPathToTempFolder
    	// if concatenated movies (multi load)
    	if (ccx > -1)
    		ccList = stringByKey(bn,ccMovies,"=",";")
	    	sprintf ks_args, "--fov=%s\' \'--alpha=%s\' \'--ROIsize=%s\' \'--minDist=%s\' \'--tempFolder=%s\' \'--concat=%s", num2str(fov), num2str(alpha), num2str(approxROIsize), num2str(minDist), sysPathToTempFolder, ccList
		endif
		// if mkVideos, create output videos in folder
		if (mkVideos == 1)
			ks_args += "\' \'--mk-videos"
		endif
		// if anwave, use analysis wave, instead of ch2
		if (anx == 1)
			ks_args += "\' \'--anwave"
		endif
    endif
    
	// check platform & run KS script
	string movieDirpath
	if (CmpStr(platform, "Windows") == 0)
		RunPythonScriptOnMovieWindows(pigPathToPython, pigPathToKS, pathToMovie, args=ks_args)
		movieDirpath = pathToMovie[0,strsearch(pathToMovie, "\\", strlen(pathToMovie)-1, 3)]
	else
	   RunPythonScriptOnMovieMacOs(pigPathToPython, pigPathToKS, pathToMovie, args=ks_args)
   	movieDirpath = pathToMovie[0,strsearch(pathToMovie, "/", strlen(pathToMovie)-1, 3)]
	endif
	
	// load files into igor
	// this is a proper temp folder now, instead of same movieDirpath
	string path_to_python_output = sysPathToTempFolder
	print "temporal files at: "+path_to_python_output
	pigLoadFiles(dirpath=path_to_python_output)
	// remove temporal files
	print "removing temporal files from: "+path_to_python_output
	if (CmpStr(platform, "Windows") == 0)
		executeScriptText/b/z "cmd.exe /c rmdir /s /q "+path_to_python_output
	else
		string igorcmd = "do shell script \"rm -rf \'" + path_to_python_output + "\'\""
		print igorcmd
   	executeScriptText/z igorcmd
		print s_value
	endif
	// create new empty pig temp folder
	newPath/c/o/q pigTemp, pathToTempFolder
	
	// rename & scale ks imported files
	// location in data browser
	string movieWave = getWavesDataFolder(movie,2)
	// to adjust temporal scaling
	variable dt = numberByKey("dt",note(movie),"=","\r")
	// copyscales sourceWave, destinationWave
	// we may have changed dirs, so:
	string cwdir = getDataFolder(1)
	string basename = stringByKey("basename",note(movie),"=","\r")
	string wx = cwdir + basename + "_reg"
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
   		print "most likely it wasn't created (and there's some problem during the python execution)"
	endif
	// bleach correction	
	wx = wx + "_bc"
	copyscales $movieWave, $wx
	setscale/p z, 0,  dt, "s", $wx
	// movie with overlayed synapses
	string wx_overlay = wx + "_overlay"
	copyscales $movieWave, $wx_overlay
	setscale/p z, 0,  dt, "s", $wx_overlay
	// these have different terminations
	string wx_df = wx + "_deltaf"
	copyscales $movieWave, $wx_df
	string wx_pm = wx + "_pixelmask"
	copyscales $movieWave, $wx_pm
	string wx_rm = wx + "_roimask"
	copyscales $movieWave, $wx_rm
	string wx_sm = wx + "_synapses_map"
	copyscales $movieWave, $wx_sm
	
	// for these, time goes in the x axis
	// also, for traces we want to have the metadata
	string wx_dff = wx + "_dff_traces"
	string wx_info = note(movie)
	note $wx_dff, wx_info
	string wx_gas = wx + "_gs_amps"
	// /p: change delta, x:dim, 0:start, dt:delta val, s:units, $wx: wave
	setscale/p x, 0,  dt, "s", $wx_dff
	setscale/p x, 0,  dt, "s", $wx_gas
	
	// redimension stimulus wave from python
	string stimulusWaveKS = cwdir + basename +"_stimulus"
	// we may have changed folders so:
	string stimulusWave = cwdir + basename + "_stim"
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
	string stdWaveName = nameOfWave($wx)+"_std"
	if (waveExists($stdWaveName))
		killwaves/z $stdWaveName
	endif
	stdev($(nameOfWave($wx)),stdWaveName)
	// make std image with ROIs on top
	// overlay_circles($(nameOfWave($wx)+"_std"),$(nameOfWave($wx)+"_synapses"))
end



// 11.
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



// 12.
// to load python outputs and then remove temporal folders
// function pigLoadAndRemoveTempFolder(string pathToTempFolder)
function pigLoadAndRemoveTempFolder()
	// quick check
	svar pathToTempFolder = root:Packages:pig:pigPathToTempFolder
	print "\npathToTempFolder: " + pathToTempFolder
	if (strlen(pathToTempFolder) == 0)
		print("\nnull path\n")
		abort
	endif
	// load
	pigLoadFiles(dirpath=pathToTempFolder)
	print "loaded temporal files at: "+pathToTempFolder
	// remove
	string cmd
	string platform = IgorInfo(2)
	if (CmpStr(platform, "Windows") == 0)
		cmd = "cmd.exe /c rmdir /s /q \""+pathToTempFolder+"\""
		// debugging now kkk
		print "pilhjsdf"
		print cmd
		executeScriptText/b/z cmd
		print s_value
	else
		cmd = "do shell script \"rm -rf \'" + pathToTempFolder + "\'\""
		executeScriptText/b/z cmd
		print s_value
	endif
	print "removed temporal files from: "+pathToTempFolder
end


// 13
// runs script on movie depending whether system is windows or macos
function pigRunPythonScriptOnMovie([string pathToPython, string pathToScript, string pathToMovie])
	// check platform
	string platform = IgorInfo(2)
	
	// 13.1 lookup paths
	
	// 13.1.1 check whether python interpreter has been defined
	if (paramIsDefault(pathToPython) != 0)
		// this functions looks up for, or creates a txt file with the path to python
		// the path inside the txt file is made a global string = pigthonPythonPath
		pigDefinePythonInterpreterPath()
		// svar makes a reference to the global string pigPythonPath
		svar pigPathToPython = root:Packages:pig:pigPathToPython
		// trim removes whitespaces & newlines, need because of echo + just in case
		pathToPython = TrimString(pigPathToPython)
	endif

	// 13.1.2 check for path to script	
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
	
	// 13.1.3 check path to movie
	svar/z pigPathToMovie = root:pigPathToMovie
	// same as 13.1.2
	if (paramIsDefault(pathToMovie) == 0)
		string/g pigPathToMovie = pathToMovie
	// if not, and there is preferred script, used that
	elseif (svar_Exists(pigPathToMovie) == 1)
		pathToMovie = pigPathToMovie
	else
		pigLoadMovie()
		pathToMovie = pigPathToMovie
	endif
	
	
	// 13.2. print & double check
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


	// 13.3. run python script from terminal
	if (CmpStr(platform, "Windows") == 0)
		RunPythonScriptOnMovieWindows(pathToPython, pathToScript, pathToMovie)
	else
		RunPythonScriptOnMovieMacOs(pathToPython, pathToScript, pathToMovie)
	endif
	
	
	// 13.4. load files from python output folder into igor
	string dirpath
	if (CmpStr(platform, "Windows") == 0)
		dirpath = pathToMovie[0,strsearch(pathToMovie, "\\", strlen(pathToMovie)-1, 3)]
	else
		dirpath = pathToMovie[0,strsearch(pathToMovie, "/", strlen(pathToMovie)-1, 3)]
	endif
	string path_to_python_output = dirpath+"python_output"
	pigLoadFiles(dirpath=path_to_python_output)
	print "temporal files at: "+path_to_python_output
	
	
	// 13.5. remove temporal folder
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




