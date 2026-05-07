
#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

////////////////////////////////////////////////////////////////////////////////////////////////////////
// Input is any kind of file from a given folder
// Output is the conversion of files into IGOR 2D wave(s)
////////////////////////////////////////////////////////////////////////////////////////////////////////
 


Function/S LoadFiles([string dirpath])
	variable refNum
	string message = "Select one or more files"
	string outputPaths
	string fileFilters = "All Files"
	string sep = "\r"
	string platform = IgorInfo(2)

	// quick check
	print "dirpath= " + dirpath
	if (strlen(dirpath)==0)
		print("\nnull path in LoadFiles()\n")
		abort
	endif
	// look for path
	if (paramIsDefault(dirpath) == 0)
		Print "\nauto loading from: "+dirpath
		// dirpath has to end with ": or / or \\"
		if (cmpstr(dirpath[0],dirpath[strlen(dirpath)-1]) != 0)
			if (cmpStr(platform, "Windows") != 0)
				dirpath += dirpath[0]
			else
				dirpath += "\\"
			endif
		endif
		sep = ";"
		// for macos only
		if (cmpStr(platform, "Windows") != 0)
			string macdirpath = "Macintosh HD:" + ReplaceString("/", dirpath[1,strlen(dirpath)-1], ":")
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
   
	if (strlen(outputPaths) == 0)
		Print "Cancelled"
	else
		// for optional dirpath
		variable numFilesSelected = ItemsInList(outputPaths, sep)
		Variable iFile
		
		for(iFile=0; iFile<numFilesSelected; iFile+=1)
			String path = dirpath+StringFromList(iFile, outputPaths, sep)
			Printf "%d: %s\r", iFile, path
			// for macos
			if (CmpStr(platform, "Windows") != 0)
				path = "Macintosh HD:" + ReplaceString("/", path[1,strlen(path)-1], ":")
				// Printf "%d: %s\r", iFile, path
			endif
			// get filenames for igor data browser
			if (CmpStr(platform, "Windows") == 0)
				string fname = ParseFilePath(3, path, "\\", 0, 0)
			else
				fname = ParseFilePath(3, path, ":", 0, 0)
			endif
			
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
				LoadWave/J/M/U={0,0,1,0}/D/A/K=0/L={0,0,0,0,0}/o/n=$fname path
				// remove 0 at the end of fname
				wave w = $(fname+"0")
				if (WaveExists($fname))
		      	KillWaves $fname
			   endif
				rename w, $fname
			else
				print fname
				print "No recognized file type (tif, tiff, png, jpeg, csv, txt)"
				print path
			endif 
			
		endfor
		wave tempwave0     
		killwaves tempwave0
	endif
   
	return outputPaths      // Will be empty if user canceled
End


// Patricio 1/5/25
// Fernando & Pawel 2/3/26