#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include <ProcedureBrowser>
#include "pigPanel"
#include "pigGetMetadata"
// these have been previously developed in the lab
// i have modified them (some more than others) & added them to the PIG folder
// for stand-alone use, and to avoid compilation confusions/issues
#include "pigLoadMultipleFiles"
#include "pigHelperFunctions"
#include "pigROIbuddy"
#include "pigCh2LineRes"
#include "pigWM4DImageSlider"


// ~ index
// 0. brief comment

// general functions to run python
// 1. runCommandOnWindowsCmd
// 2. runCommandOnMacosShell 
// 3. runPythonScriptOnWindows
// 4. runPythonScriptOnMacOs
// 5. runPythonScriptOnMovieWindows
// 6. runPythonScriptOnMovieMacOs

// init functions
// 7. pigDefinePythonInterpreterPath
// 8. pigDefinePathToPythonScripts

// different kinds of loading fxs
// 9. pigLoadMovie
// 10. pigMultiLoad
// 11. pigLoad5dMovie
// 12. pigLoadAnalysisWave
// 13. pigLoadAndRemoveTempFolder

// more complex running functions
// 14. pigRun
// 15. pigRunKS 



// 0.
// we want to define paths that can be reused
// for the path to the python interpreter: 
// we're creating a txt file that can be read every time pig is loaded
// the txt file stores the path written in the panel
// that path (if exists) is loaded as a global variable
// every time pig is initialized
// there are hardcoded paths to some python functions as well:
// ks_method.py, getMetadata.py & pig_plots.py


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
// runs a python script using windows cmd
function runPythonScriptOnWindows(string path_to_python, string path_to_python_script, [string args])
	string igorcmd
	if (paramIsDefault(args) == 0)
        igorcmd = "\"" + path_to_python + "\" \"" + path_to_python_script + "\" " + args
    else
        igorcmd = "\"" + path_to_python + "\" \"" + path_to_python_script + "\""
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
// seemiingly you can do without it, but it can get quite confusing
function runPythonScriptOnMacOs(string path_to_python, string path_to_python_script, [string args])
	string igorcmd
	if (paramIsDefault(args) == 0)
        igorcmd = "do shell script \"'" + path_to_python + "' '" + path_to_python_script + "' " + args + "\""
    else
        igorcmd = "do shell script \"'" + path_to_python + "' '" + path_to_python_script + "'\""
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


// 6.
// again: on mac this can be a pain, mostly because of the "do shell script"
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



////////// 7 & 8 are automatically run at start


// 7.
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
		print "\n\tpython path saved in txt file at: "+pathToTxt
		print "\tusing python interpreter at: "+pathToPython
		string/g root:Packages:pig:pigPathToPythonInterpreter = TrimString(pathToPython)
	else
		print "\npig_path_to_python_interpreter.txt not found"
		string/g root:Packages:pig:pigPathToPythonInterpreter = ""
	endif
	// final check (stop=1 = True)
	checkPythonInterpreter(stop=0)
end



// 8.
function pigDefinePathToPythonScripts()
	// path to pig directory in users procedures
	string pigPath = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "User Procedures:Pig:"
	// search for txt file with location of python interpreter in pig folder
	string pathToKSIgor = pigPath + "ks_method.py"
	string pathToPigPlotsIgor = pigPath + "pig_plots.py"
	string platform = IgorInfo(2)
	string pathToKS, pathToPigPlots
	if (CmpStr(platform, "Windows") != 0)
		pathToKS = parseFilePath(5, pathToKSIgor, "/", 0, 0)
		pathToPigPlots = parseFilePath(5, pathToPigPlotsIgor, "/", 0, 0)
	else
		pathToKS = parseFilePath(5, pathToKSIgor, "\\", 0, 0)
		pathToPigPlots = parseFilePath(5, pathToPigPlotsIgor, "\\", 0, 0)
	endif
	string/g root:Packages:pig:pigPathToKS = pathToKS
	string/g root:Packages:pig:pigPathToPigPlots = pathToPigPlots
end





///////////// 9 - 12 are basically loading functions 


// 9.                                      
// load movie
function pigLoadMovie()
	
	// check python interpreter
	// it's necessary for getMetadata()
	checkPythonInterpreter()
	
	// load movie
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
	newDataFolder/o root:$fname
	string movieName = "root:" +fname+ ":" +fname
	// if movie exists, overwrite
	if (waveExists($movieName))
		killwaves/z $movieName
	endif
	// move movie to its own folder
	moveWave $s_filename, $movieName
	// and now we move into folder
	setDataFolder root:$fname
	
	// append file data to notes and later proccessing
	note $movieName, "fdir="+s_path
	note $movieName, "fname="+s_filename
	note $movieName, "basename="+fname
	string fpath = s_path+s_filename
	note $movieName, "fpath="+fpath
	note $movieName, ""
	nvar fov = root:Packages:pig:FOV
	note $movieName, "fov=" + num2str(fov)
	
	// get metadata (this uses python)
	// it's a bit slower than directly doing on igor, but is safer
	// because some data formats are not accessible from Igor
	pigGetMetadata($movieName)
	appendMetadata($movieName)
	
	// now we need the values for scaling
	string info = note($movieName)
	// get data from same notes
	variable zoomFactor, angleFast, angleSlow, msPerLine, framerate, dt
	zoomFactor = NumberByKey("zoomFactor", info, "=", "\r")
	angleFast = NumberByKey("scanAngleMultiplierFast", info, "=", "\r")
	angleSlow = NumberByKey("scanAngleMultiplierSlow", info, "=", "\r")
	msPerLine = NumberByKey("msPerLine", info, "=", "\r")
	frameRate = NumberByKey("frameRate", info, "=", "\r")
	dt = 1/frameRate
	
	// get deltas to scale 
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
	
	// split channels (using fxs from LoadScanImage
	variable nChannels = nChannelsFromHeaderx($movieName)
	// in case there's no info in the header (so nChannels = nan)
	if (numtype(nChannels) == 2)
		print("\nDidn't find info for nChannels in the metadata: assuming 2 channels")
		nChannels = 2
	endif
	splitChannelsx($movieName, nChannels=nChannels)
	
	// mk stimulus wave
	pigWaveCh2lineRes2($(movieName+"_ch2"))
	string cwd = getDataFolder(1)
	string stimulusWaveDefault = cwd+"timewave"
	string stimulusWaveCh2res = movieName+"_ch2stim"
	// if it exists, erase (otherwise yields error)
	if (waveExists($stimulusWaveCh2res))
		killwaves/z $stimulusWaveCh2res
	endif
	moveWave $stimulusWaveDefault, $stimulusWaveCh2res
	// ch2res makes 1d wave, so has to be scaled in x
	setscale/p x, 0, dt,"s",$stimulusWaveCh2res

	print "\nloaded movie from: "+fpath
end



// 10. 
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
	string multiName0 = basename + "_" + num2str(nfiles) + "movs"
	// rename $movName, $basename
	rename $movName, $multiName0
	// string respName0 = basename + "_ch1"
	string respName0 = multiname0 + "_ch1"
	rename $respName, $respName0
	// string stimName0 = basename + "_ch2"
	string stimName0 = multiname0 + "_ch2"
	rename $stimName, $stimName0
	// change name to main movie	
end


// 11.
// to organize layered/volumetric python output
function pigOrganize5dMovieData(wave movie5d) 
	// basically there are 3 locations for
	// 1) the movie, 2) the slices 3) new folder to move the slices in
	string movieName = nameOfWave(movie5d)
	string moviePath = getWavesDataFolder(movie5d,2)
	// because we have moved into the KS results folder
	string ksMoviePath = getDataFolder(1)
	print(ksMoviePath)
	string basename = stringByKey("basename",note(movie5d),"=","\r")
	print(basename)
	variable dt = numberByKey("dt",note(movie5d),"=","\r")
	string wx_info = note(movie5d)
	// iterate through loaded data
	variable i
	variable zSlices = numberBykey("Software.SI.hStackManager.actualNumSlices",note(movie5d),"=","\r")
	for (i = 0; i < zSlices; i += 1)
		// make folder		
		string newFolderPath = ksMoviePath + basename + "_z" + num2str(i)
		newDataFolder/o $newFolderPath
		
		// copy scales, copy notes & move movies
		string wz = basename + "_z" + num2str(i)
		// reg
		string wz_reg = wz + "_reg"
		copyScales movie5d, $wz_reg
		setscale/p z, 0,  dt, "s", $wz_reg
		note $wz_reg, wx_info
		moveWave $wz_reg, $(newFolderPath + ":" + wz_reg)
		// isq
		string wz_isq = wz_reg + "_isq"
		copyScales movie5d, $wz_isq
		setscale/p z, 0,  dt, "s", $wz_isq
		note $wz_isq, wx_info
		moveWave $wz_isq, $(newFolderPath + ":" + wz_isq)
		// bc
		string wz_bc = wz_isq + "_bc"
		copyScales movie5d, $wz_bc
		setscale/p z, 0,  dt, "s", $wz_bc
		note $wz_bc, wx_info
		moveWave $wz_bc, $(newFolderPath + ":" + wz_bc)
		
		// check if if other files exist & do the same
		string wx = basename + "_z" + num2str(i)
		// deltaf
		string wx_df = wx + "_deltaf"
		// skip to next iteration if it doesn't exist
		// assuming the other files don't exist either
		if (!waveExists($wx_df))
			continue
		endif
		copyscales movie5d, $wx_df
		note $wx_df, wx_info
		moveWave $wx_df, $(newFolderPath + ":" + wx_df)
		// masks and map of synapses
		string wx_pm = wx + "_pixelmask"
		copyscales movie5d, $wx_pm
		note $wx_pm, wx_info
		moveWave $wx_pm, $(newFolderPath + ":" + wx_pm)
		string wx_rm = wx + "_roimask"
		copyscales movie5d, $wx_rm
		note $wx_rm, wx_info
		moveWave $wx_rm, $(newFolderPath + ":" + wx_rm)
		string wx_sm = wx + "_synapses_map"
		copyscales movie5d, $wx_sm
		setscale/p z, 0, 1, "RGB", $wx_sm
		moveWave $wx_sm, $(newFolderPath + ":" + wx_sm)
		// overlay
		string wx_overlay = wx + "_overlay"
		copyscales movie5d, $wx_overlay
		setscale/p t, 0,  dt, "s", $wx_overlay
		setscale/p z, 0,  1, "RGB", $wx_overlay
		note $wx_overlay, wx_info
		moveWave $wx_overlay, $(newFolderPath + ":" + wx_overlay)
		// 2d traces
		string wx_dff = wx + "_dff_traces"
		setscale/p x, 0,  dt, "s", $wx_dff
		note $wx_dff, wx_info
		moveWave $wx_dff, $(newFolderPath + ":" + wx_dff)
		string wx_gas = wx + "_gs_amps"
		setscale/p x, 0,  dt, "s", $wx_gas
		moveWave $wx_gas, $(newFolderPath + ":" + wx_gas)
		// synapses data
		string wx_sd = wx + "_synapses_data"
		moveWave $wx_sd, $(newFolderPath + ":" + wx_sd)
	endfor
	// redimension stimulus wave from python
	string stimulusWaveKS = ksMoviePath + basename +"_stimulus"
	// we may have changed folders so:
	string stimulusWave = ksMoviePath + basename + "_stim"
	// if it exists, erase (otherwise yields error)
	if (waveExists($stimulusWave))
		killwaves/z $stimulusWave
	endif
	// have to create a new wave to get rid of col1
	variable nrows = dimSize($stimulusWaveKS,0)
	make/o/n=(nrows) $stimulusWave 
	wave sti = $stimulusWave
	wave stiKS = $stimulusWaveKS
	sti = stiKS[p][1]
	setScale/p x 0, dt, "s", sti
	killwaves stiKS
end


// 12.
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


// 13.
// to load python outputs and then remove temporal folders
// function pigLoadAndRemoveTempFolder(string pathToTempFolder)
function pigLoadAndRemoveTempFolder()
	// quick check
	svar pathToTempFolder = root:Packages:pig:pigPathToTempFolder
	// print "\npathToTempFolder: " + pathToTempFolder
	if (strlen(pathToTempFolder) == 0)
		print("\nnull path\n")
		abort
	endif
	// load
	pigLoadFiles(dirpath=pathToTempFolder)
	// print "loaded temporal files at: "+pathToTempFolder
	// remove
	string platform = IgorInfo(2)
	// print "removing temporal files from: " + pathToTempFolder
	if (CmpStr(platform, "Windows") == 0)
		executeScriptText/b/z "cmd.exe /c del /q " + pathToTempFolder + "\\*.*"
	else
		string igorcmd = "do shell script \"rm -rf '" + pathToTempFolder + "'*\""
   	executeScriptText/z igorcmd
		print s_value
	endif
	// this is only to organize 5d movies
	
end





////////////  13 & 14 are for running general scripts & KS, respectively


// 14.
// select python script, optionally a wave and run it
// it doesn't accept extra arguments
// so those changes have to made on the python script itself
// [write] -> run python script -> load & remove
function pigRun([string pigWaveName])
	// get basic info
	string platform = IgorInfo(2)
	svar pigPython = root:Packages:pig:pigPathToPythonInterpreter
	svar pigScript = root:Packages:pig:pigPathToScript
	svar pigTempFolder = root:Packages:pig:pigPathToTempFolder
	// if wave: export file for python
	if (paramIsDefault(pigWaveName) == 0)
		wave pigWave = $pigWaveName
		// this is just the name, without the full path
		string basename = nameOfWave(pigWave)
		// check whether it is an image, table, or movie
		// 0=float32, 2=int16, 4=float64, 8=u8bit, 16 = uint16, 32=uint32
		// variable type = waveType(pigWave)
		variable dims = waveDims(pigWave)
		// save
		string filename
		if (dims == 1 || dims == 2)
			filename = basename + ".csv"
			save/G/M="\n"/DLIM=","/O/P=pigTemp pigWave as filename
		elseif (dims == 3 || dims == 4)
			filename = basename + ".tif"
			imageSave/T="TIFF"/S/O/P=pigTemp pigWave as filename
		endif
	endif
	// run (still have to pass tempFolder loc)
	string temp
	sprintf temp, "--tempFolder='%s'", pigTempFolder
	string waveFilename
	sprintf waveFilename, "--waveFilename='%s'", filename
	string args = temp + " " + waveFilename
	if (CmpStr(platform, "Windows") == 0)
		runPythonScriptOnWindows(pigPython, pigScript, args=args)
	else 
		runPythonScriptOnMacOs(pigPython, pigScript, args=args)
	endif
	// load and remove
	pigLoadAndRemoveTempFolder()
end


// 15.
// this functions has 4 parts:
// a) definitions and checks
// b) run python script
// c) load and remove temp files
// d) renaming and scaling
// run ks analysis
function pigRunKS(wave movie [wave analysisWave])
	
	// first of all - check python interpreter
	checkPythonInterpreter(stop=1)
	// path to python interpreter, KS.py & movie file
	svar pigPathToPython = root:Packages:pig:pigPathToPythonInterpreter
	svar pigPathToKS = root:Packages:pig:pigPathToKS
	// this also checks whether movie exists outside igor
	string pathToMovie = checkMoviePath(movie)
	// string pathToMovie = renamePath_igor2sys(stringByKey("fpath",note(movie),"=","\r"))
	// definitions for optional parameters
	string platform = IgorInfo(2)
	nvar fov = root:Packages:pig:FOV
	nvar alpha = root:Packages:pig:alpha
	nvar approxROIsize = root:Packages:pig:approxROIsize
	nvar minDist = root:Packages:pig:minDist
	svar ccMovies = root:Packages:pig:ccMovies
	nvar mkVideos = root:Packages:pig:mkVideos
	svar pathToTempFolder = root:Packages:pig:pigPathToTempFolder
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
		// pigTemp = pathToTempFolder, but as symbolic path
		save/g/m="\n"/dlim=","/p=pigTemp/o analysisWave as "anWave.txt"
	endif
	
	// define arguments before runnning
	string ks_args
	// check platform
	if (CmpStr(platform, "Windows") == 0)
		// base optional arguments for running ks
	   	sprintf ks_args, "--fov=%s --alpha=%s --ROIsize=%s --minDist=%s --tempFolder=%s", num2str(fov), num2str(alpha), num2str(approxROIsize), num2str(minDist), pathToTempFolder
    	// if concatenated movies (multiload)
    	if (ccx > -1)
	    	string ccList = stringByKey(bn,ccMovies,"=",";")
	    	// sprintf ks_args, "--fov=%s --alpha=%s --ROIsize=%s --minDist=%s --tempFolder=%s --concat=%s", num2str(fov), num2str(alpha), num2str(approxROIsize), num2str(minDist), pathToTempFolder, ccList
       	ks_args += " \"--concat=" + ccList +"\""
    	endif
    	// mk videos opt
    	if (mkVideos == 1)
       	ks_args += " --mk-videos"
    	endif
    	// if analysis wave
    	if (anx == 1)
    		ks_args += " --anWave"
    	endif
    else
    	// for mac it's a bit more difficult (for me at least)
    	// base arguments (alpha, ROIsize, minDist)
    	sprintf ks_args, "--fov=%s\' \'--alpha=%s\' \'--ROIsize=%s\' \'--minDist=%s\' \'--tempFolder=%s", num2str(fov), num2str(alpha), num2str(approxROIsize), num2str(minDist), pathToTempFolder
    	// if concatenated movies (multi load)
    	if (ccx > -1)
    		ccList = stringByKey(bn,ccMovies,"=",";")
	    	sprintf ks_args, "--fov=%s\' \'--alpha=%s\' \'--ROIsize=%s\' \'--minDist=%s\' \'--tempFolder=%s\' \'--concat=%s", num2str(fov), num2str(alpha), num2str(approxROIsize), num2str(minDist), pathToTempFolder, ccList
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
	// i'm not using the load&remove function, for specific differences
	// this is a proper temp folder now, instead of same movieDirpath
	print "temporal files at: " + pathToTempFolder
	pigLoadFiles(dirpath=pathToTempFolder)
	// remove temporal files
	// these remove files inside the folder, but not the folder itself
	print "removing temporal files from: " + pathToTempFolder
	if (CmpStr(platform, "Windows") == 0)
		// executeScriptText/b/z "cmd.exe /c rmdir /s /q " + pathToTempFolder
		executeScriptText/b/z "cmd.exe /c del /q " + pathToTempFolder + "\\*.*"
	else
		string igorcmd = "do shell script \"rm -rf '" + pathToTempFolder + "'*\""
		print igorcmd
		executeScriptText/z igorcmd
		print s_value
	endif
	
	// rename & scale ks imported files
	// location in data browser
	string movieWave = getWavesDataFolder(movie,2)
	// to adjust temporal scaling
	variable dt = numberByKey("dt",note(movie),"=","\r")
	// copyscales sourceWave, destinationWave
	// we may have changed dirs, so:
	string cwdir = getDataFolder(1)
	string basename = stringByKey("basename",note(movie),"=","\r")
		
	// if reg is not there, there was some problem
	string wx = cwdir + basename + "_reg"
	if (waveExists($wx))
		// copyscales and notes
		copyscales $movieWave, $wx
		setscale/p z, 0,  dt, "s", $wx
		// this wave name can change
		// _int is for interpolation method
		string wx_int = wx + "_int"
		// _isq is for pixel squaring
		string wx_isq = wx + "_isq"
		if (WaveExists($wx_isq))
			CopyScales $movieWave, $wx_isq
			setscale/p z, 0,  dt, "s", $wx_isq
			wx = wx + "_isq"
		else
			// this is just a double safety check, in case _reg is there
			// but no interpolation method could be applied correctly
			print "\ncouldnt find aspect-correction/interpolated movie file"
			print "most likely it wasn't created (and there's some problem during the python execution)"
			print "check the console for info\n"
			abort
		endif
		// bleach correction	
		wx = wx + "_bc"
		copyscales $movieWave, $wx
		setscale/p z, 0,  dt, "s", $wx
		// movie with overlayed synapses
		// overlay layers are imported as RGB=4 & frames as chunks=nFrames
		string wx_overlay = wx + "_overlay"
		copyscales $movieWave, $wx_overlay
		setscale/p t, 0,  dt, "s", $wx_overlay
		setscale/p z, 0,  1, "RGB", $wx_overlay
		// these have different terminations
		string wx_df = wx + "_deltaf"
		copyscales $movieWave, $wx_df
		string wx_pm = wx + "_pixelmask"
		copyscales $movieWave, $wx_pm
		string wx_rm = wx + "_roimask"
		copyscales $movieWave, $wx_rm
		string wx_sm = wx + "_synapses_map"
		copyscales $movieWave, $wx_sm
		setscale/p z, 0, 1, "RGB", $wx_sm
	
		// for these, time goes in the x axis
		// also, for traces we want to have the metadata
		string wx_dff = wx + "_dff_traces"
		string wx_gas = wx + "_gs_amps"
		// /p: change delta, x:dim, 0:start, dt:delta val, s:units, $wx: wave
		setscale/p x, 0,  dt, "s", $wx_dff
		setscale/p x, 0,  dt, "s", $wx_gas
		// copy notes in files that may be used later
		string wx_info = note(movie)
		note $wx, wx_info
		note $wx_df, wx_info
		note $wx_pm, wx_info
		note $wx_rm, wx_info
		note $wx_dff, wx_info
		note $wx_overlay, wx_info
	
		// redimension stimulus wave from python
		string stimulusWaveKS = cwdir + basename +"_stimulus"
		// we may have changed folders so:
		string stimulusWave = cwdir + basename + "_stim"
		// if it exists, erase (otherwise yields error)
		if (waveExists($stimulusWave))
			killwaves/z $stimulusWave
		endif
		// have to create a new wave to get rid of col1
		variable nrows = dimSize($stimulusWaveKS,0)
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
	endif 
	
	// organize data if movies is 5d
	pigOrganize5dMovieData(movie)
end










