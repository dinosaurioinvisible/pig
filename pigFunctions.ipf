#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// this file contains helper/auxiliary functions for pig
// to avoid making pig.ipf too confusing to read

// mk std map from image
function mkSTDmap(wave movie)
	imageTransform stdMovie movie
	// igor auto file from ImageTransform
	wave stdMap = m_stdDev
	// make gray
	ModifyImage stdMap ctab = {*,*,Grays,0}
	rename stdMap, $(nameOfWave(movie) + "_std")
end

// function to overimpose circles in images
// it assumes pigSynapses: n, row, col, ∆f/f, ks-d, ks-p
function overimposeCirclesOnImage(wave image, wave pigSynapses, variable r)
	// mk copy
   string newImageName = nameOfWave(image) + "_xys"
   duplicate/o image, $newImageName
   wave newImage = $newImageName
   // make image gray in case it isn't
   modifyImage $(nameOfWave(newImage)) ctab={*,*, Grays, 0}
   // normalize to 0-1 for display
   // newImage = (newImage - WaveMin(newImage)) / (WaveMax(newImage) - WaveMin(newImage))
   // 
   variable i 
   variable nrows = DimSize(pigSynapses, 0)
   // variable i, angle
   // variable nAngles = 360
   // 
   for (i = 0; i < nrows; i += 1)
   	variable x0 = round(pigSynapses[i][1])
      variable y0 = round(pigSynapses[i][2])
   	//
	   // draw circle by iterating over angles
      // variable a
      // for (a = 0; a < nAngles; a += 1)
      	// variable cx = round(x0 + r * cos(2 * pi * a / nAngles))
         // variable cy = round(y0 + r * sin(2 * pi * a / nAngles))
         // check bounds
         // if (cx >= 0 && cx < DimSize(newImage, 0) && cy >= 0 && cy < DimSize(newImage, 1))
         		// newImage[cx][cy] = WaveMax(image)  // draw circle as bright pixels
         // endif
      // endfor
   endfor
end


// simple function to overimpose circles in images
// it assumes pigSynapses: n, row, col, ∆f/f, ks-d, ks-p
function overimposeCircles(wave image, wave pigSynapses, variable r)
	// display image first, THEN modify it 
	display
   appendImage image
   // make correct sizes
   variable xSize = DimSize(image, 0)
	variable ySize = DimSize(image, 1)
	setAxis left 0, xSize
	setAxis bottom 0, ySize
	// setAxis/a left
	// setAxis/a bottom
   // make image gray in case it isn't
   modifyImage $(nameOfWave(image)) ctab={*,*, Grays, 0}
	// make circles i=start, nrows=end
	variable i
	variable nrows = dimSize(pigSynapses,0)
	for (i = 0; i < nrows; i += 1)
		// [i][0] = n = i
		variable x0 = pigSynapses[i][1]
    	variable y0 = pigSynapses[i][2]
    	// make parametric circle wave
      string circleName = "s" + num2str(i)
      // /o is to overwrite, /n is the number of points
      make/o/n=100 $(circleName + "_x"), $(circleName + "_y")
      wave cx = $(circleName + "_x")
      wave cy = $(circleName + "_y")
      // actually make circle
      cx = x0 + r * cos(2 * pi * p / 99)
      cy = y0 + r * sin(2 * pi * p / 99)
      // append to graph
      appendToGraph cy vs cx
      // 0,65535,0=green, 0,0,65535=blue, 65535,0,0=red
      if (i < nrows/3)
	      modifyGraph rgb($(circleName+"_y")) = (0, 65535, 0)
	   elseif (i < nrows*2/3)
	   	modifyGraph rgb($(circleName+"_y")) = (0, 0, 65535)
	   else
	   	modifyGraph rgb($(circleName+"_y")) = (65535, 0, 0)
	   endif
	endfor	
end

function overimposeCircles2(wave image, wave pigSynapses, variable r)
    // create new image as a copy
    string newImageName = nameOfWave(image) + "_circles"
    Duplicate/O image, $newImageName
    wave newImage = $newImageName
    
    // display
    Display
    AppendImage newImage
    ModifyImage $(newImageName) ctab={*,*, Grays, 0}
    SetAxis/A left
    SetAxis/A bottom
    
    variable nrows = DimSize(pigSynapses, 0)
    variable i
    
    for (i = 0; i < nrows; i += 1)
        variable x0 = pigSynapses[i][1]
        variable y0 = pigSynapses[i][2]
        
        // make circle waves
        string circleName = "s" + num2str(i)
        Make/O/N=100 $(circleName + "_x"), $(circleName + "_y")
        wave cx = $(circleName + "_x")
        wave cy = $(circleName + "_y")
        cx = x0 + r * cos(2 * pi * p / 99)
        cy = y0 + r * sin(2 * pi * p / 99)
        
        AppendToGraph cy vs cx
        
        // color by third
        if (i < nrows/3)
            ModifyGraph rgb($(circleName+"_y")) = (0, 65535, 0)
        elseif (i < nrows*2/3)
            ModifyGraph rgb($(circleName+"_y")) = (0, 0, 65535)
        else
            ModifyGraph rgb($(circleName+"_y")) = (65535, 0, 0)
        endif
        
        // add number label at center
        SetDrawLayer UserFront
        SetDrawEnv xcoord=bottom, ycoord=left, textrgb=(65535, 65535, 0), fsize=8
        DrawText x0, y0, num2str(i)
    endfor
End