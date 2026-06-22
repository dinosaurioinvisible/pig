
#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Modified version for PIG

////////////////////////////////////////////////////////////////////////////////////////////////////////
// Input is any kind of file from a given folder
// Output is the conversion of files into IGOR 2D wave(s)
////////////////////////////////////////////////////////////////////////////////////////////////////////


Function/S pigLoadFiles([string dirpath, string filters, variable returnOnly, string mkFolder])
	variable refNum
	string message = "Select one or more files"
	string outputPaths, fileFilters
	string sep = "\r"
	string platform = IgorInfo(2)
	
	// chekc optional arguments apart from dirpath
	// check if return only (so no load here)
	if (paramIsDefault(returnOnly) == 0)
		returnOnly = 1
	else
		returnOnly = 0
	endif
	// check for mkFolder (to create a new folder and put things there)
	if (paramIsDefault(mkFolder) == 0)
		// no need to create folder if return only
		if (returnOnly == 0)
			// this /o is not overwrite, but avoid error if folder exists
			newDataFolder/o/s root:$mkFolder
		endif
	endif
	// check if filters
	if (paramIsDefault(filters) == 0)
		// this is a bit convoluted, but is to include optional filters
		// example: fileFilters = "Data files (*.ibw,*.dat):.ibw,.dat;"
		variable i
		variable nf = itemsInList(filters)
		fileFilters = "Data files (*"
		for (i=0; i<nf; i+=1)
			fileFilters += stringFromList(i,filters)
			if (i<nf-1)
				fileFilters += ","
			else
				fileFilters += "):"
			endif
		endfor
		for (i=0; i<nf; i+=1)
			fileFilters += stringFromList(i,filters)
			if (i<nf-1)
				fileFilters += ","
			else
				fileFilters += ";"
			endif
		endfor
		// just a checkpoint
		// print "fileFilters: " + fileFilters
	else
		fileFilters = "All Files"
	endif
	
	// look for path
	if (paramIsDefault(dirpath) == 0)
		Print "\nauto loading from: "+dirpath
		// dirpath has to end with ": or / or \\"
		if (cmpStr(platform, "Windows") == 0)
			// in windows it isn't always the case
			// this leads to errors if not cheked
			if (cmpstr(dirpath[strlen(dirpath)-1],"\\") != 0)
				dirpath += "\\"
				print "dir path: " + dirpath
			endif
		else
			// this seems to be enough for macos
			if (cmpstr(dirpath[0],dirpath[strlen(dirpath)-1]) != 0)
				if (cmpstr(dirpath[0],"/") == 0 || cmpstr(dirpath[0],":") == 0) 
					dirpath += dirpath[0]
					print "dir path: " + dirpath
				endif
			endif
		endif
		sep = ";"
		// for macos only
		if (cmpStr(platform, "Windows") != 0)
			if (cmpStr(dirpath[0,12],"Macintosh HD:") != 0)
				string macdirpath = "Macintosh HD:" + ReplaceString("/", dirpath[1,strlen(dirpath)-1], ":")
			else
				macdirpath = ReplaceString("/", dirpath[0,strlen(dirpath)-1], ":")
			endif
			newPath/O/q sdirpath, macdirpath
		else
			newPath/O/q sdirpath, dirpath
		endif
		// indexFile only takes symbolic path as arg1, not str
		// arg3 takes exactly 4 chars matching last 4 chars in filename
		outputPaths = indexedFile(sdirpath, -1, "????")
	else
		dirpath = ""
		Open /D /R /MULT=1 /F=fileFilters /M=message refNum
		outputPaths = S_fileName
	endif
   // cancel if empty
	if (strlen(outputPaths) == 0)
		Abort
	elseif (returnOnly == 1)
		return outputPaths
	else
		// for optional dirpath
		variable numFilesSelected = ItemsInList(outputPaths, sep)
		Variable iFile
		for(iFile=0; iFile<numFilesSelected; iFile+=1)
			String path = dirpath+StringFromList(iFile, outputPaths, sep)
			// printf "%d: %s\r", iFile, path
			// for macos
			if (CmpStr(platform, "Windows") != 0)
				if (cmpStr(path[0,12],"Macintosh HD:") != 0)
					path = "Macintosh HD:" + ReplaceString("/", path[1,strlen(path)-1], ":")
				else
					path = ReplaceString("/", path[0,strlen(path)-1], ":")
				endif
			endif
			// get filenames for igor data browser
			if (CmpStr(platform, "Windows") == 0)
				string fname = ParseFilePath(3, path, "\\", 0, 0)
				printf "%d: %s\r", iFile, path
			else
				fname = ParseFilePath(3, path, ":", 0, 0)
				printf "%d: %s\r", iFile, path
			endif
			// replace spaces with underscores (to avoid issues at loading/processing)
			fname = ReplaceString(" ", fname, "_")
			// load
			if (cmpStr(path[strlen(path)-4,strlen(path)-1], ".tif")  == 0)
				ImageLoad/Q/T=TIFF/N=$fname/S=0/C=-1/LR3D path
				// to remove extra layer (3d dim) from 2d arrays
				wave w = $fname
				if (Dimsize(w,2)==1)
					Redimension/n=(DimSize(w,0), DimSize(w,1)) w
				endif
			elseif (cmpStr(path[strlen(path)-5,strlen(path)-1], ".tiff")  == 0) 
				ImageLoad/Q/T=TIFF/N=$fname/S=0/C=-1/LR3D path
				// to remove extra layer (3d dim) from 2d arrays
				wave w = $fname
				if (Dimsize($fname,2)==1)
					Redimension/n=(DimSize(w,0), DimSize(w,1)) w
				endif
			elseif (cmpStr(path[strlen(path)-4,strlen(path)-1], ".png")  == 0)
				ImageLoad/Q/T=rpng/N=$fname path
			elseif (cmpStr(path[strlen(path)-5,strlen(path)-1], ".jpeg")  == 0)	
				ImageLoad/Q/T=jpeg/N=$fname path
			elseif (cmpStr(path[strlen(path)-4,strlen(path)-1], ".csv")  == 0)
				LoadWave/q/J/M/U={0,0,1,0}/D/A/K=0/L={0,0,0,0,0}/n=$fname path
				// remove the 0 after loading (to avoid confusion)
				wave w = $(fname+"0")
				rename w, $fname
			elseif (cmpStr(path[strlen(path)-4,strlen(path)-1], ".txt")  == 0)	
				LoadWave/q/J/M/U={0,0,1,0}/D/A/K=0/L={0,0,0,0,0}/o/n=$fname path
				// remove 0 at the end of fname
				wave w = $(fname+"0")
				if (WaveExists($fname))
		      	KillWaves $fname
			   endif
				rename w, $fname
			elseif (cmpStr(path[strlen(path)-4,strlen(path)-1], ".ibw")  == 0)	
         		LoadWave/q/o/n=$fname path
			else
				print fname
				print "No recognized file type (tif, tiff, png, jpeg, csv, txt, ibw)"
				print path
			endif 
			
		endfor
		wave tempwave0     
		killwaves tempwave0
	endif

	return outputPaths
End


// Patricio 1/5/25
// Fernando & Pawel 2/3/26