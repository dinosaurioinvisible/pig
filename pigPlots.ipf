#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


// mk std map from image
function mkSTDimage(wave movie)
	imageTransform stdMovie movie
	// igor auto file from ImageTransform
	wave stdMap = m_stdDev
	// make gray
	ModifyImage stdMap ctab = {*,*,Grays,0}
	rename stdMap, $(nameOfWave(movie) + "_std")
end

// function to overimpose circles in images
// it assumes pigSynapses: n, row, col, ∆f/f, ks-d, ks-p
function overimposeROIs(wave image, wave pigSynapses, variable r)
	// mk copy
   string background = nameOfWave(image) + "_ooo"
   duplicate/o image, $background
   // wave newImage = $newImageName
   // make image gray in case it isn't
   modifyImage background ctab={*,*, Grays, 0}
end