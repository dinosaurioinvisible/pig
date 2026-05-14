#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// this file contains helper/auxiliary functions for pig
// to avoid making pig.ipf too confusing to read
// just using an x before to avoid compilation conflicts

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
	nChannels = NumberByKey("state.acq.savingChannel1", Header, "=","\r") + NumberByKey("state.acq.savingChannel2", Header, "=","\r") + NumberByKey("state.acq.savingChannel3", Header, "=","\r") +  NumberByKey("state.acq.savingChannel4", Header, "=","\r")
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

