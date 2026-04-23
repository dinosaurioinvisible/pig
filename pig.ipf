#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include "LoadMultipleFiles"

// ~ index
// 1. runCommandOnWindowsCmd, runCommandOnMacosShell - to run single commands
// 2. runPythonScriptOnMovieWindows - to run a script on a movie in windows
// 3. runPythonScriptOnMovieMacOs - to run a script on a movie in macos
// 4. definePythonInterpreterPath - to look up for a python interp.
// 5. pigLoadMovie - simpler than ART Load, for python processing
// 6. pigSelectPythonScript - to choose a python script
// 7. pigRunPythonScriptOnMovie - general fx


// this is a small manual, for debugging or testing:
// (these examples kind of go increasing in difficulty)
// to execute a line command in the macos terminal from Igor:
	// string igorcmd0
	// command0 = "here goes any shell command"
	// sprintf igorcmd0, "do shell script \"%s\"", command0
	// executeScriptText/z igorcmd0
	// print s_value

	// other commands:
	// create an empty file
	// command0 = "touch ~/Desktop/test.txt"
	// create/write something into a file (> overwrites, >> appends new line)
	// command0 = "echo is invisibility a super power really?  >> ~/Desktop/test.txt"
	// you can put things together using &&
	// command0 = command0 = "touch ~/Desktop/test2.txt && echo im hungry now >> ~/Desktop/test2.txt"
	// note that you can do the same without writing out, for text-like output
	// command0 = "ls -a"
	// but then you have to look at it using:
	// print s_value 
	// (usually this shows issues if some, or nothing if fine)
	
	// now then, to look for python interpreters, first you'd do things like:
	// command0 = "find ~ name pyvenv.cfg -maxdepth 3 2>/dev//null >> test2.txt"
	// command0 = conda env list
	// for venvs or conda envs, respectively. Or, for system interepreters:
	// command0 = "which -a python3 >> ~/Desktop/test.txt"
	// but, results prob. be different from results in the actual terminal
	// in fact, for conda/venvs you most likely will see "exited with non-zero status" 
	// this is basically "not found", because Igor's $PATH is different, you can check with:
	// command0 = "echo $PATH >> ~/Desktop/test.txt"
	// or simply:
	// command0 = "echo $PATH" (and then checking s_value after executing)
	// so, either we pass the location to the interpreter (text or window) 
	// or search in common locations, like conda, miniconda, homebrew, etc
	// here we'll try to guess, and if this fails, ask for user input
	
	// note on windows:
	// in windows calling programs is more straightforward
	// and you can do things like:
	// executeScriptText "notepad.exe"
	// so you don't really need a function for that
	// however, calling cmd itself has to be done explicitely
	// so we need to use 'cmd.exe /c' for cmd instructions like echo, >>, etc.
	// unlike macos which passes the command directly to the shell (bash/zsh)


// 0
// we want to define paths that can be reused
// for the path to the python interpreter: 
// there is a function that may be called only once
// we're creating a txt file that can be read every time pig is loaded
// the txt contains the path to the python interpreter
// that path (if exists) is loaded as a global variable
// when pressing the 'python' button


// 1
// basic fx for running single commands in macos shell & windows cmd
// print s_value isn't really needed, can be ommitted, but may be useful
function runCommandOnWindowsCmd(string command)
	executeScriptText/z "cmd.exe /c "+command
	print s_value
end

function runCommandOnMacosShell(string command)
	string igorcmdx
	sprintf igorcmdx, "do shell script \"%s\"", command
	executeScriptText/z igorcmdx
	print s_value
end 


// 2
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


// 3
// on mac this can be a pain, mostly because of the "do shell script"
// you can do without it, but it can get quite confusing
function runPythonScriptOnMovieMacOs(string path_to_python, string path_to_python_script, string path_to_movie)
	// pawell fix, really classy
	string igorcmd = "do shell script \"\'" + path_to_python+"\' \'" + path_to_python_script + "\' \'" + path_to_movie + "\'\""
	// for debugging only
	// string igorcmd
	// sprintf igorcmd, "do shell script \"%s %s %s\"", path_to_python, path_to_python_script, path_to_movie
	// not necessary, but guess more info is better than less
	print "\nshell command:"
	print igorcmd
   executeScriptText/z igorcmd
   // this shows errors from python
   print "s_value:"
   print s_value
end


// 4
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


// 5
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

// 6
// loads movie only - split channels & ch2stimulus > in python
function pigLoadMovie()
	imageload/q/o/c=-1
	// flag=0 is no image in imageload
	if (v_flag == 0)
		Abort
	endif
	// remove extension from name 
	string fname = s_filename[0,strsearch(s_filename,".tif",0)-1]
	// create folder for movie and move loaded movie there
	NewDataFolder/O root:$fname
	string movieName = "root:" +fname+ ":" +fname
	// if movie exists, overwrite
	if (waveExists($movieName))
		killwaves/z $movieName
	endif
	moveWave $s_filename, $movieName
	// retrieve necessary info
	// this works eith the older version of scan image only
	// when working with the newer version, python will return an _info.txt file
	// with FOV, zoomFactor & frameRate
	print s_info
	string metadata = s_info
	// get info - to access note info: print note($"movieName")
	string expDate = stringByKey("state.internal.triggerTimeString",s_info,"=","\r")
	//variable msPerLine = numberByKey("state.acq.msPerLine",s_info,"=","\r")
	variable frameRate = numberByKey("state.acq.frameRate",s_info,"=","\r")
	variable zoomFactor = numberByKey("state.acq.zoomFactor",s_info,"=","\r")
	note $movieName, "expDate="+expDate
	//note $movieName, "msPerLine="+num2str(msPerLine)
	note $movieName, "frameRate="+num2str(frameRate)
	note $movieName, "zoomFactor="+num2str(zoomFactor)
	// note $movieName, metadata
	note $movieName, "fdir="+s_path
	note $movieName, "fname="+s_filename
	string filePath = s_path+s_filename
	note $movieName, "fpath="+filePath
	// convert to double precision floating point
	// redimension /d $movieName
	// make global string for path
	string platform = IgorInfo(2)
	if (CmpStr(platform, "Windows") != 0)
		string/g root:Packages:pig:pigPathToMovie = parseFilePath(5,filePath,"/",0,0)
	else 
		string/g root:Packages:pig:pigPathToMovie = parseFilePath(5,filePath,"\\",0,0)
	endif
	// print "\nloaded movie from: "+pigPathToMovie
	print "\nloaded movie from: "+filePath
end


// 7
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
	string/g pigPathToScript = path_to_python_script
	print "\n\tselected python script at: "+pigPathToScript
end


// 8
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
	svar fov = root:Packages:pig:FOV
	svar alpha = root:Packages:pig:alpha
	// run KS
	string dirpath
	if (CmpStr(platform, "Windows") == 0)
		RunPythonScriptOnMovieWindows(pigPathToPython, pigPathToKS, pathToMovie)
		dirpath = pathToMovie[0,strsearch(pathToMovie, "\\", strlen(pathToMovie)-1, 3)]
	else
		// string igorcmd = "do shell script \"\'" + pigPathToPython+"\' \'" + pigPathToKS + "\' \'" + pathToMovie + "\'\""
		// print "\nshell command:"
		// print igorcmd
   	// executeScriptText/z igorcmd
   	// this shows errors from python
	   // print "s_value:"
   	// print s_value
   	RunPythonScriptOnMovieMacOs(pigPathToPython, pigPathToKS, pathToMovie)
   	dirpath = pathToMovie[0,strsearch(pathToMovie, "/", strlen(pathToMovie)-1, 3)]
	endif
	// load files into igor
	string path_to_python_output = dirpath+"python_output"
	LoadFiles(dirpath=path_to_python_output)
	print "temporal files at: "+path_to_python_output
	// remove temporal files
	
end

// 9
// runs script on movie depending whether system is windows or macos
function pigRunPythonScriptOnMovie([string pathToPython, string pathToScript, string pathToMovie])
	// check platform
	string platform = IgorInfo(2)
	
	// 1. lookup paths
	
	// 1.1 check whether python interpreter has been defined
	if (paramIsDefault(pathToPython) != 0)
		// this functions looks up for, or creates a txt file with the path to python
		// the path inside the txt file is made a global string = pigthonPythonPath
		pigDefinePythonInterpreterPath()
		// svar makes a reference to the global string pigPythonPath
		svar pigPathToPython = root:Packages:pig:pigPathToPython
		// trim removes whitespaces & newlines, need because of echo + just in case
		pathToPython = TrimString(pigPathToPython)
	endif

	// 1.2 check for path to script	
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
	
	// 1.3 check path to movie
	svar/z pigPathToMovie = root:pigPathToMovie
	// same as 1.2
	if (paramIsDefault(pathToMovie) == 0)
		string/g pigPathToMovie = pathToMovie
	// if not, and there is preferred script, used that
	elseif (svar_Exists(pigPathToMovie) == 1)
		pathToMovie = pigPathToMovie
	else
		pigLoadMovie()
		pathToMovie = pigPathToMovie
	endif
	
	
	// 2. print & double check
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


	// 3. run python script from terminal
	if (CmpStr(platform, "Windows") == 0)
		RunPythonScriptOnMovieWindows(pathToPython, pathToScript, pathToMovie)
	else
		RunPythonScriptOnMovieMacOs(pathToPython, pathToScript, pathToMovie)
	endif
	
	
	// 4. load files from python output folder into igor
	string dirpath
	if (CmpStr(platform, "Windows") == 0)
		dirpath = pathToMovie[0,strsearch(pathToMovie, "\\", strlen(pathToMovie)-1, 3)]
	else
		dirpath = pathToMovie[0,strsearch(pathToMovie, "/", strlen(pathToMovie)-1, 3)]
	endif
	string path_to_python_output = dirpath+"python_output"
	LoadFiles(dirpath=path_to_python_output)
	print "temporal files at: "+path_to_python_output
	
	
	// 5. remove temporal folders
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





