#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


// define path to script
function pigDefinePathToGetMetadata()
	// path to pig directory in user procedures
	svar pigPath = root:Packages:pig:pigPathToPigFolder
	string/g root:Packages:pig:pigPathToGetMetadata = pigPath + "get_metadata.py"
end


// this function uses pig to retrieve full metadata
function pigGetMetadata(wave movie)
	// check if movie exists, otherwise abort
	checkMoviePath(movie, stop=1)
	string platform = IgorInfo(2)
	// get path to movie
	string info = note(movie)
	string moviePathNotes = stringByKey("fpath",info,"=","\r")
	string moviePath = renamePath_igor2sys(moviePathNotes)
	// we need python interpreter, path to the python script & to the temp folder
	svar pigPathToPythonInterpreter = root:Packages:pig:pigPathToPythonInterpreter
	svar pigPathToGetMetadata = root:Packages:pig:pigPathToGetMetadata
	svar pigPathToTempFolder = root:Packages:pig:pigPathToTempFolder
	// run script on movie - this produces the txt with the metadata
	string temp
	if (CmpStr(platform, "Windows") == 0)		
		sprintf temp, "--tempFolder=%s", pigPathToTempFolder
		runPythonScriptOnMovieWindows(pigPathToPythonInterpreter, pigPathToGetMetadata, moviePath, args=temp)
	else
		sprintf temp, "--tempFolder=%s", pigPathToTempFolder
		runPythonScriptOnMovieMacOs(pigPathToPythonInterpreter, pigPathToGetMetadata, moviePath, args=temp)
	endif
	// load and remove temp 
	pigLoadAndRemoveTempFolder()
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
	if (numtype(zoomFactor)==2)
   	zoomFactor = numberByKey("ImageDescription.state.acq.zoomFactor", allMetadata, "=", "\r")
   endif
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
   	angleFast = numberByKey("ImageDescription.state.acq.scanAngleMultiplierFast", allMetadata, "=", "\r")
   endif
	if (numtype(angleFast) == 2) 
   	angleFast = numberByKey("Software.SI.hRoiManager.scanAngleMultiplierFast", allMetadata, "=", "\r")
   endif
   if (numtype(angleFast)==2)
		angleFast = 1
	endif
 	note movie, "scanAngleMultiplierFast=" + num2str(angleFast)
	// scanAngleMultiplierSlow
	variable angleSlow = numberByKey("scanAngleMultiplierSlow", info, "=", "\r")
	if (numtype(angleSlow) == 2) 
   	angleSlow = numberByKey("ImageDescription.state.acq.scanAngleMultiplierSlow", allMetadata, "=", "\r")
   endif
	if (numtype(angleSlow) == 2) 
   	angleSlow = numberByKey("Software.SI.hRoiManager.scanAngleMultiplierSlow", allMetadata, "=", "\r")
   endif
   if (numtype(angleSlow)==2)
		angleSlow = numberByKey("Artist.RoiGroups.imagingRoiGroup.rois.UserData.scanAngleMultiplierSlow", allMetadata, "=", "\r")
	endif
   if (numtype(angleSlow)==2)
   	print("Couldnt find info for scanAngleMultiplierSlow, set to 1")
		angleSlow = 1
	endif
 	note movie, "scanAngleMultiplierSlow=" + num2str(angleSlow)
 	// calculate fovx and fovy (zoomed)
	nvar fov = root:Packages:pig:FOV
	variable fovx = fov * angleFast / zoomFactor
	variable fovy = fov * angleSlow / zoomFactor
	note movie, "fovZoom_x=" + num2str(fovx) 
	note movie, "fovZoom_y=" + num2str(fovy)	
 	// msPerLine
 	variable msPerLine = numberByKey("ImageDescription.state.acq.msPerLine",allMetadata,"=","\r")
 	if (numType(msPerLine)==2)
 		variable linePeriod = numberByKey("Software.SI.hRoiManager.linePeriod", allMetadata, "=", "\r")
		msPerLine = linePeriod * 1000
	endif
	note movie, "msPerLine=" + num2str(msPerLine)
	// frameRate
	variable frameRate = numberByKey("frameRate", info, "=", "\r")
	if (numtype(frameRate) == 2)
   	frameRate = numberByKey("ImageDescription.state.acq.frameRate", allMetadata, "=", "\r")
   endif
	if (numtype(frameRate) == 2)
   	frameRate = numberByKey("Software.SI.hRoiManager.scanFrameRate", allMetadata, "=", "\r")
   endif
	note movie, "frameRate="+num2str(frameRate)
	// dt
	variable dt = 1/frameRate
	// note movie, "dt="+num2str(dt)
	if (strlen(StringByKey("dt", info, "=", "\r")) == 0)
   	note movie, "dt=" + num2str(dt)
	endif
	// time info
	variable duration = dimSize(movie,2)/2/frameRate
	note movie, "duration="+num2str(duration)
	note movie, ""
	note movie, ""	
	// generally whatever the remaining is not so relevant
	// but i'm appending it anyway, as it may be
	note movie, allMetadata
end