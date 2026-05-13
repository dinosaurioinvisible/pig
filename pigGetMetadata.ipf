#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


// define path to script
function pigDefinePathToGetMetadata()
	// path to pig directory in user procedures
	string pigPath = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "User Procedures:Pig:"
	string pathToGetMetadataIgor = pigPath + "get_metadata.py"
	// make path to file
	string platform = IgorInfo(2)
	string pathToGetMetadata
	if (CmpStr(platform, "Windows") == 0)
		pathToGetMetadata = parseFilePath(5, pathToGetMetadataIgor, "\\", 0, 0)
	else
		pathToGetMetadata = parseFilePath(5, pathToGetMetadataIgor, "/", 0, 0)
	endif
	string/g root:Packages:pig:pigPathToGetMetadata = pathToGetMetadata
end


// this function uses pig to retrieve full metadata
function pigGetMetadata(wave movie)
	string platform = IgorInfo(2)
	// get path to movie
	string info = note(movie)
	string dirPath = stringByKey("fdir",info,"=","\r") + "python_output:"
	string moviePath = stringByKey("fpath",info,"=","\r")
	string basename = stringByKey("basename",info,"=","\r")
	// change to system format
	if (CmpStr(platform, "Windows") == 0)
		dirPath = parseFilePath(5, dirPath, "\\", 0, 0)
		moviePath = parseFilePath(5, moviePath, "\\", 0, 0)
	else
		// dirPath = parseFilePath(5, dirPath, "/", 0, 0)
		// this doesn't work here & actually crashes the program
		// so it's better to do it manually
		dirPath = replaceString("Macintosh HD:", dirPath, "")
		dirPath = replaceString(":", dirPath, "/")
		dirPath = "/" + dirPath
		moviePath = parseFilePath(5, moviePath, "/", 0, 0)
	endif
	// we need python interpreter & path to the python script
	svar pigPathToPythonInterpreter = root:Packages:pig:pigPathToPythonInterpreter
	svar pigPathToGetMetadata = root:Packages:pig:pigPathToGetMetadata
	// run script on movie - this produces the txt with the metadata
	if (CmpStr(platform, "Windows") == 0)
		runPythonScriptOnMovieWindows(pigPathToPythonInterpreter, pigPathToGetMetadata, moviePath)
	else
		runPythonScriptOnMovieMacOs(pigPathToPythonInterpreter, pigPathToGetMetadata, moviePath)
	endif
	// load and remove temp 
	pigLoadAndRemoveTempFolder(dirPath)
	
end


// look into metadata and append info to notes
function appendMetadata(wave movie)
	// get name of metadata file
	string info = note(movie)
	string baseName = stringByKey("basename",info,"=","\r")
	string metadata = "root:" + baseName + ":" + baseName + "_metadata"
	// merge metadata
	wave/t metadataWave = $metadata
	string allMetadata = ""
	variable i
	for (i = 0; i < numpnts(metadataWave); i += 1)
   	allMetadata += metadataWave[i] + "\r"
	endfor
	// look for necessary data (notes (so ImageDescription), software data, artist)
	// zoom
	variable zoomFactor = numberByKey("zoomFactor", info, "=", "\r")
	// =2 means NaN or empty
	if (numtype(zoomFactor) == 2)
   	zoomFactor = numberByKey("Software.SI.hRoiManager.scanZoomFactor", allMetadata, "=", "\r")
   endif
   if (numtype(zoomFactor)==2)
   	zoomFactor = numberByKey("Artist.RoiGroups.imagingRoiGroup.rois.UserData.scanZoomFactor", allMetadata, "=", "\r")
   endif
   note movie, "zoomFactor=" + num2str(zoomFactor)
	// scanAngleMultiplierFast
	variable angleFast = numberByKey("scanAngleMultiplierFast", info, "=", "\r")
	if (numtype(angleFast) == 2) 
   	angleFast = numberByKey("Software.SI.hRoiManager.scanAngleMultiplierFast", allMetadata, "=", "\r")
   endif
   if (numtype(angleFast)==2)
		angleFast = 1
	endif
 	note movie, "scanAngleMultiplierFast=" + num2str(angleFast)
	// scanAngleMultiplierSlow
	variable angleslow = numberByKey("scanAngleMultiplierSlow", info, "=", "\r")
	if (numtype(angleslow) == 2) 
   	angleFast = numberByKey("Software.SI.hRoiManager.scanAngleMultiplierSlow", allMetadata, "=", "\r")
   endif
   if (numtype(angleSlow)==2)
		angleSlow = numberByKey("Artist.RoiGroups.imagingRoiGroup.rois.UserData.scanAngleMultiplierSlow", allMetadata, "=", "\r")
	endif
   if (numtype(angleSlow)==2)
   	print("Couldnt find info for scanAngleMultiplierSlow, set to 1")
		angleSlow = 1
	endif
 	note movie, "scanAngleMultiplierSlow=" + num2str(angleSlow)
 	// msPerLine
 	variable linePeriod = numberByKey("Software.SI.hRoiManager.linePeriod", allMetadata, "=", "\r")
	variable msPerLine = linePeriod * 1000
	note movie, "msPerLine=" + num2str(msPerLine)
	// frameRate
	variable frameRate = numberByKey("frameRate", info, "=", "\r")
	if (numtype(frameRate) == 2)
   	frameRate = numberByKey("Software.SI.hRoiManager.scanFrameRate", allMetadata, "=", "\r")
   endif
	note movie, "frameRate="+num2str(frameRate)
	// dt
	variable dt = 1/frameRate
	// note movie, "dt="+num2str(dt)
	if (strlen(StringByKey("dt", info, "=", "\r")) == 0)
   	note movie, "dt=" + num2str(dt) + "\r"
	endif
	// variable msPerLine? - couldn'r find this in the metadata
	// note $movieName, "msPerLine="+num2str(msPerLine)
end