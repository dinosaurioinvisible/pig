#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// slightly modified version of the original
function pigWaveCh2lineRes(w)
	
	wave w
	string notes=note(w)
	duplicate/o/FREE w, temp
	
	// reorders the dimension, so that frames are the last dim
	matrixop/o/FREE trans=transposevol(temp,5)
	// collapses (sums) spatial dims into rows
	matrixop/o/FREE lines=sumrows(trans)
	// get delta	
	variable xx=dimsize(lines,0), zz=dimsize(lines,2)
	// flattens into 1D
	redimension/N=(xx*zz) lines
	// replace starting value = 0
	lines[0] = lines[1]

	// output with name "timewave"
	duplicate/o lines, timewave
	
end


// this is a different version, 
// based on the simpler one in python
// it assumes a correct delta 
function pigWaveCh2lineRes2(ch2)
	wave ch2
    
	variable nFrames = dimSize(ch2, 2)
	variable dt = dimDelta(ch2, 2)
	// make recipient timewave
	make/O/N=(nFrames) timewave
    
	variable i
   // for every frame
	for (i = 0; i < nFrames; i += 1)
    	// layer extracts a 2D frame from the movie
      matrixOP/FREE frame = layer(ch2, i)
      // frame average
		timewave[i] = mean(frame)
	endfor
    
    // replace first point with second to avoid artifact
	timewave[0] = timewave[1]
    // normalize values between 0 and 1
    // to avoid the unnecessary high values from the means
	variable minVal = waveMin(timewave)
	variable maxVal = waveMax(timewave)
	timewave = (timewave - minVal) / (maxVal - minVal)
	
	setScale/p x, 0, dt, "s", timewave
end