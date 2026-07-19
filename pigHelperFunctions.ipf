#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma once 			// to avoid compilation errors from name used twice

// this file contains helper/auxiliary functions for pig
// to avoid making pig.ipf too confusing, i'm just using an x
// at the end of the original names 
// to avoid compilation conflicts
// and to allow for anyone to look for the original fx, just in case

// some useful fxs to remember:
// getWavesDataFolder
// nameOfWave
// getDataFolder
// winName
// parseFilePath
// stringByKey
// numberByKey
// itemsInList


// have to check this
function splitZmovies(wave movie, variable zSlices, variable zLayers, variable zVolumes)
	string basename = nameOfWave(movie)
	variable framesPerMovie = 180
	variable nMovies = 11
	variable i
	for (i = 0; i < nMovies; i += 1)
		variable startFrame = i * framesPerMovie
		variable endFrame = startFrame + framesPerMovie - 1
		string newName = basename + "_" + num2str(i+1)
		Duplicate/O/RMD=[][][startFrame, endFrame] movie, $newName
		// fix time scaling
		CopyScales movie, $newName
		SetScale/P z, startFrame * DimDelta(movie, 2), DimDelta(movie, 2), WaveUnits(movie, 2), $newName
		print "created: " + newName
	endfor
end


// fix issue when loading tif RGB movies
// swap (wrong) layers into channels (RGB channels)
// and (wrong) chunks into layers (movie frames)
function correctRGB4layers(wave movie)
	// get dims
	variable nRows = dimSize(movie, 0)
	variable nCols = dimSize(movie, 1)
	variable nChannels = dimSize(movie, 2)
	variable nFrames = dimSize(movie, 3)
	// mk copy & swap layers and chunks
	// make/o/u/n=(nRows, nCols, nFrames, nChannels) movieCopy
	// movieCopy = movie[p][q][s][r]
	duplicate/O movie, movieCopy
	redimension/N=(nRows, nCols, nFrames, nChannels) movieCopy
	movieCopy = movie[p][q][s][r]
	// copy scales of swapped dims
	copyScales movie, movieCopy
	setScale/p z, 0, dimDelta(movie, 3), waveUnits(movie, 3), movieCopy
	setScale/p t, 0, dimDelta(movie, 2), waveUnits(movie, 2), movieCopy
	string movieName = nameOfWave(movie)
	rename movieCopy, $(movieName + "_rgb")
end


// check wether fpath in notes still exists there
// if not, make a temporal copy and change in notes
// if stop: just check & abort; otherwise, create a temp copy
function/s checkMoviePath(wave movie, [variable stop])
	// optional stop of main function calling this one
	variable stopExecution
	if (paramIsDefault(stop) == 0 && stop > 0)
		stopExecution = 1
	else
		stopExecution = 0
	endif
	string pathToMovieIgor = stringByKey("fpath",note(movie),"=","\r")
	string pathToMovie = renamePath_igor2sys(pathToMovieIgor)
	string isPath = doesFileExist(pathToMovie)
	print pathToMovieIgor
	print pathToMovie
	// if not found
	if (cmpstr(isPath,"found") != 0)
		print "\nmovie does not exist anymore at: " + pathToMovie
		// optional abort
		if (stopExecution == 1)
			print "...abort"
			abort
		endif
		// else, make copy of movie at temp
		saveMovieWithMetadata(movie)
		string movieName = parseFilePath(0, pathToMovieIgor, ":", 1, 0)
		string altPath = specialDirPath("Temporary",0,0,0) + movieName
		note movie, "altPath="+altPath
		pathToMovie = renamePath_igor2sys(altPath)
		print "--> used temporary copy at: " + pathToMovie
	endif
	return pathToMovie	
end


// normally when exporting Igor movies, you lose the metadata
// there are some cases in which these are important though
function saveMovieWithMetadata(wave movie, [string savePath])
	// get notes
	string movieName = stringByKey("fname",note(movie),"=","\r")
	string notes = note(movie)
	// i'm leaving this here, coz in theory if too long it could fail
	// print "length notes: " + num2str(strlen(notes))
    
	// create tag wave mirroring T_Tags format:
	// 00 = tag.key, this is the index to open the metadata in python
	// 01 = description (can be blank, is not written when exported)
	// 02 = type (2=ASCII), 03 = notes length, 04 = notes
	make/O/T/N=(1,5) tagWave
	tagWave[0][0] = "111"
	tagWave[0][1] = "igorWavedata"
	tagWave[0][2] = "2"
	tagWave[0][3] = num2str(strlen(notes))
	tagWave[0][4] = notes
    
	// save if is not already saved
	string movieTempPath = renamePath_igor2sys(specialDirPath("Temporary",0,0,0) + movieName)
	string isTempFile = doesFileExist(movieTempPath)
	if (cmpstr(isTempFile,"found") != 0)
		// check savepath & save with metadata as stack
		if (paramIsDefault(savePath) == 0)
			newPath/c/o/q exportPath, savePath
			imageSave/T="TIFF"/DS=16/S/O/P=exportPath/WT=tagWave movie as movieName
		else
			imageSave/T="TIFF"/DS=16/S/O/P=tempFolder/WT=tagWave movie as movieName
		endif
	endif
	// remove tagwave afterwards
	killWaves/z tagWave
end

// abort if python interpreter hasn't been correctly defined
function checkPythonInterpreter([variable stop])
	// optional stop of main function calling this one
	variable stopExecution
	if (paramIsDefault(stop) == 0 && stop > 0)
		stopExecution = 1
	else
		stopExecution = 0
	endif
	// check python interpreter
	svar pathToPython = root:Packages:pig:pigPathToPythonInterpreter
	string isPath = doesFileExist(pathToPython)
	if (cmpstr(isPath,"found") != 0)
		print "\n\tThe path to the interpreter is invalid"
		print "\tPIG cannot run without a Python interpreter. Please define one"
		if (stopExecution == 1)
			abort
		endif
	endif
end

// igor cannot handle aliases, and python locations normally are
// returns a string: "found" or "not found"
function/s doesFileExist(string filepath)
	string platform = IgorInfo(2)
	if (CmpStr(platform, "Windows") == 0)
		// on windows you need /b to pass the command directly to cmd (ommiting cmd.exe)
		string cmd = "cmd.exe /c if exist \"" + filepath + "\" (echo found) else (echo not found)"
		executeScriptText/b/z cmd
	else
		cmd = "do shell script \"test -f  \'" + filepath + "\' && echo 'found' || echo 'not found'\""
		executeScriptText/z cmd
	endif
	return trimString(s_value)
end

// change igor path route name into system naming convention
function/s renamePath_igor2sys(string igorPath)
	string path
	string platform = IgorInfo(2)
	if (CmpStr(platform, "Windows") == 0)
		path = ParseFilePath(5, igorPath, "\\", 0, 0)
	else
		// already unix style
		if (CmpStr(igorPath[0], "/") == 0)
			path = igorPath
		else
			// path = parseFilePath(5, igorPath, "/", 0, 0)
			// for macos, this function fails if path doesn't start with "macintosh hd"
			// to be safe, i'm hardcoding the thing manually
			variable firstColonPos = strsearch(igorPath, ":", 0)
			string volumeName = igorPath[0, firstColonPos-1]
			string restOfPath = ReplaceString(":", igorPath[firstColonPos+1, strlen(igorPath)-1], "/")
			if (CmpStr(volumeName, "Macintosh HD") == 0)
				path = "/" + restOfPath
			else
				path = "/Volumes/" + volumeName + "/" + restOfPath
			endif
		endif
	endif
	return path
end

// split delta (from Pawel)
function splitDeltaF(wave popwave, variable n_reps)

	variable i, j, k, n_pnts = dimsize(popwave, 0), rep_pnts = round(n_pnts/n_reps)
	make/o/n=(0) splitDf
	for (i=0; i<n_reps; i+=1)
		duplicate/o/rmd=[i*rep_pnts, (i+1)*rep_pnts-1][] popwave, $(nameOfWave(popwave)+"_rep"+num2str(i))
		// popdf((nameOfWave(popwave)+"_rep"+num2str(i)))
			
		if (numpnts(splitDf) == 0)
			duplicate/o $(nameOfWave(popwave)+"_rep"+num2str(i)+"_DF"), splitDf
		else
			concatenate/np=0 {$(nameOfWave(popwave)+"_rep"+num2str(i)+"_DF")}, splitDf
		endif
		killwaves/z $(nameOfWave(popwave)+"_rep"+num2str(i)+"_DF"), $(nameOfWave(popwave)+"_rep"+num2str(i))
	endfor
	duplicate/o splitDf, $(nameOfWave(popwave)+"_split_DF")
	killwaves/z splitDf
end

// mk std map from image (from Z-project)
function stdev(picwave, outputwave)
	wave picwave
	string outputwave
	imagetransform averageimage picwave
	Wave M_StdvImage
	duplicate /o M_StdvImage, $outputwave
	CopyScalingx(picwave, $outputwave)
	killwaves/z M_AveImage, M_StdvImage
end

// (from LoadScanImage)
function nChannelsFromHeaderx(PicWave)
	wave PicWave
	string header = note(PicWave)
	variable nChannels=0
	nChannels = NumberByKey("ImageDescription.state.acq.savingChannel1", Header, "=","\r") + NumberByKey("ImageDescription.state.acq.savingChannel2", Header, "=","\r") + NumberByKey("ImageDescription.state.acq.savingChannel3", Header, "=","\r") +  NumberByKey("ImageDescription.state.acq.savingChannel4", Header, "=","\r")
	return nChannels
end

// (also from LoadScanImage)
// mostly the same, but makes the nChannels argument optional
// if not defined, it makes nchannels = 2
function SplitChannelsx(PicWave, [nChannels])
	wave PicWave
	variable nChannels	
	// assume 2 channels if not found/provided
   if (ParamIsDefault(nChannels))
   	print("\nDidn't find info for nChannels in the metadata: assuming 2 channels\n")
   	nChannels = 2
   endif
	variable nFrames = DimSize(PicWave,2), FramesPerChannel, Rest, ii
	string wvName
	FramesPerChannel=nFrames/nChannels
	Rest=FramesPerChannel-trunc(FramesPerChannel)	
	if(Rest)
		Print "WARNING: inequal number of frames per channel."
		FramesPerChannel=trunc(FramesPerChannel)
	endif	
	for(ii=0;ii<nChannels;ii+=1)
		wvName=NameOfWave(PicWave)+"_Ch"+Num2Str(ii+1)
		Duplicate /o PicWave $wvName
		wave w=$wvName
		Redimension/n=(-1,-1,FramesPerChannel) w
		MultiThread w=PicWave[p][q][r*nChannels+ii]	
	endFor	
end

// (from EqualizeScaling)
function CopyScalingx(source, destination)
	wave source, destination
	variable dimnums, dimnumd
	string snote, dnote
	snote = note(source)
	dnote = note(destination)
	if (cmpstr(snote,dnote) != 0)	//are wave notes different?
		note destination, snote
	endif
	dimnums = wavedims(source)
	dimnumd = wavedims(destination)
	setscale d -inf, inf, waveunits(source,-1), destination
	setscale /P x, DimOffset(source, 0),  DimDelta(source, 0),WaveUnits(source, 0), destination
	if ((dimnums > 0) && (dimnumd > 0))
		setscale /P y, DimOffset(source, 1),  DimDelta(source, 1),WaveUnits(source, 1), destination
	endif
	if  ((dimnums > 1) && (dimnumd > 1))
		setscale /P z, DimOffset(source, 2),  DimDelta(source, 2),WaveUnits(source, 2), destination
	endif
	if  ((dimnums > 2) && (dimnumd > 2))
		setscale /P t, DimOffset(source, 3),  DimDelta(source, 3),WaveUnits(source, 3), destination
	endif
end

// same as imshow, but for 4 dims also
// used claude to fix the problem of the slider bars on mac
// (to adjust them according to the size of the window)
function pigImshow()

	string list=wavelist("*",";","DIMS:3")
	list += waveList("*", ";", "DIMS:4")
	string wn
	prompt wn, "Display this movie", popup, list
	doprompt "Select movie" wn
	string/g root:Packages:pig:wavenameingraph=wn 
	if(V_flag==1)
		Abort
	endif
	wave w=$wn
	Display /W=(451,49,1139,294)/K=1 
	AppendImage w
	SetAxis/A/R left
	ModifyGraph mirror(left)=0,mirror(bottom)=2
	ModifyGraph axisEnab(bottom)={0,0.85}
	WMAppend3DImageSlider()
	WM3DSliderEnableResize()
	imagestats w
	// variable/g low=V_min
	// variable/g high=V_max
	variable/g root:Packages:pig:imshow_low=V_min
	variable/g root:Packages:pig:imshow_high=V_max
	SetVariable Set_Zero,pos={577,204},size={104,15},proc=SetVarProcx,title="Set Zero"
	SetVariable Set_Zero, Value=low
	Slider slider0,pos={613,42},size={53,154},proc=SliderProcx
	Slider slider0,limits={V_min,V_max,-1},value= V_max	
end
Function SetVarProcx(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			SVAR wn=root:Packages:pig:wavenameingraph
			variable/G low=dval
			NVAR high=root:Packages:pig:imshow_high
			ModifyImage $wn ctab= {low,high,Grays,0}
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End
Function SliderProcx(sa) : SliderControl
	STRUCT WMSliderAction &sa
	switch( sa.eventCode )
		case -1: // control being killed
			break
		default:
			if( sa.eventCode & 1 ) // value set
				Variable curval = sa.curval	
				SVAR wn=root:Packages:pig:wavenameingraph
				variable/g root:Packages:pig:imshow_high=curval
				NVAR low=root:Packages:pig:imshow_low
				NVAR high=root:Packages:pig:imshow_high
				ModifyImage $wn ctab= {low,high,Grays,0}
			endif
			break
	endswitch
	return 0
End
// call this after WMAppend3DImageSlider to enable resize (from Claude)
Function WM3DSliderEnableResize()
    String grfName = WinName(0, 1)
    SetWindow $grfName, hook(WM3DSliderResize)=WM3DSliderResizeHook
End
Function WM3DSliderResizeHook(s)
    STRUCT WMWinHookStruct &s
    if (s.eventCode == 6)  // resize event
        GetWindow $s.winName, gsize
        variable newWidth = V_right - V_left
        variable newHeight = V_bottom - V_top
        // resize main slider
        Slider WM3DAxis, win=$s.winName, size={newWidth - kImageSliderLMargin, 16}
        SetVariable WM3DVal, win=$s.winName, pos={newWidth - kImageSliderLMargin + 15, 0}
        // move vertical slider and setvariable to right edge
        variable sliderLeft = newWidth - 70  // 70px from right edge
        Slider slider0, win=$s.winName, pos={sliderLeft, 42}, size={53, newHeight-60}
        SetVariable Set_Zero, win=$s.winName, pos={sliderLeft-50, newHeight-1}
    endif
    return 0
End


// to make a background image with ROIs on top
function overlay_circles(wave image, wave synapses_data, [variable r])
	// radius in pixels
	if (ParamIsDefault(r))
        r = 3
   endif
   // copy image
   string im = nameOfWave(image) + "_rois"
   duplicate/o image, $im
   wave newImage = $im
	// coords
	variable nROIs = DimSize(synapses_data, 0)
   variable maxVal = WaveMax(image)
   variable i, angle
   variable nAngles = 360
   
   for (i = 0; i < nROIs; i += 1)
   	// x = cols, y = rows, i = synapse
   	variable x0 = round(synapses_data[i][2])
   	variable y0 = round(synapses_data[i][1])
   	// draw circle outline only
      for (angle = 0; angle < nAngles; angle += 1)
			variable px = round(x0 + r * cos(2 * pi * angle / nAngles))
			variable py = round(y0 + r * sin(2 * pi * angle / nAngles))
         if (px >= 0 && px < DimSize(newImage, 0) && py >= 0 && py < DimSize(newImage, 1))
				newImage[px][py] = maxVal
			endif
		endfor
	endfor

   // display image
   string windowName = im + "_win"
   Display/N=$windowName
   AppendImage/W=$windowName newImage
   ModifyImage/W=$windowName $(im) ctab={*,*, Grays, 0}
    
   // add numbers at each coordinate
   variable xDim = DimSize(newImage, 0)
   variable yDim = DimSize(newImage, 1)
    
   for (i = 0; i < nROIs; i += 1)
		x0 = round(synapses_data[i][2])
      y0 = round(synapses_data[i][1])
        
        // normalize to 0-1 for DrawText
        variable xpos = x0 / xDim
        variable ypos = 1 - y0 / yDim
        
        SetDrawLayer/W=$windowName UserFront
        SetDrawEnv/W=$windowName xcoord=prel, ycoord=prel, textrgb=(65535, 0, 0), fsize=10
        DrawText/W=$windowName xpos, ypos, num2str(i)
   endfor	
end


