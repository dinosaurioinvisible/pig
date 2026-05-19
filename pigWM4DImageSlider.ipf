#pragma rtGlobals=2		// Need new syntax
#include <Image Common>
#include <Image Threshold Panel>
#include <ImageSlider>

//*******************************************************************************************************
// AG 24JAN02
// Procedure to add a slider to 3D images in order to simplify the display
// of different layers.  Modified from LH procedure AxisSlider.ipf
// 01SEP06
// Changed the ValDisplay to SetVariable so that the control up and down arrows can be used to precisely move by one frame.

//*******************************************************************************************************
Function WM4DImageSliderProc(name, value, event)
	String name			// name of this slider control
	Variable value		// value of slider
	Variable event		// bit field: bit 0: value set; 1: mouse down, //   2: mouse up, 3: mouse moved

	String dfSav= GetDataFolder(1)
	String grfName= WinName(0, 1)
	SetDataFolder root:Packages:WM4DImageSlider:$(grfName)

	NVAR gLayer
	SVAR imageName

	ModifyImage  $imageName plane=(gLayer)	
	SetDataFolder dfSav

	// 08JAN03 Tell us if there is an active LineProfile
	SVAR/Z imageGraphName=root:Packages:WMImProcess:LineProfile:imageGraphName
	if(SVAR_EXISTS(imageGraphName))
		if(cmpstr(imageGraphName,grfName)==0)
			ModifyGraph/W=$imageGraphName offset(lineProfileY)={0,0}			// This will fire the S_TraceOffsetInfo dependency
		endif
	endif	
		
	SVAR/Z imageGraphName=root:Packages:WMImProcess:ImageThreshold:ImGrfName
	if(SVAR_EXISTS(imageGraphName))
		if(cmpstr(imageGraphName,grfName)==0)
			WMImageThreshUpdate()
		endif
	endif
	
	return 0				// other return values reserved
End

//*******************************************************************************************************
//constant kImageSliderLMargin= 80

Function WMAppend4DImageSlider()
	String grfName= WinName(0, 1)
	DoWindow/F $grfName
	if( V_Flag==0 )
		return 0			// no top graph, exit
	endif


	String iName= WMTopImageGraph()		// find one top image in the top graph window
	if( strlen(iName) == 0 )
		DoAlert 0,"No image plot found"
		return 0
	endif
	
	Wave w= $WMGetImageWave(iName)	// get the wave associated with the top image.	
	if(DimSize(w,2)<=0)
		DoAlert 0,"Need a 3D image"
		return 0
	endif
	
	ControlInfo WM4DAxis
	if( V_Flag != 0 )
		return 0			// already installed, do nothing
	endif
	
	String dfSav= GetDataFolder(1)
	NewDataFolder/S/O root:Packages
	NewDataFolder/S/O WM4DImageSlider
	NewDataFolder/S/O $grfName
	
	Variable/G gLeftLim=0,gRightLim,gLayer=0
	
	if((dimSize(w,3) > 0 && dimSize(w,2)==3))						//#MMD
		gRightLim=DimSize(w,3)-1				//image is 4D with RGB as 3rd dim
	else
		gRightLim=DimSize(w,2)-1				//image is 3D grayscale
	endif
	
	String/G imageName=nameOfWave(w)
	ControlInfo kwControlBar
	Variable/G gOriginalHeight= V_Height		// we append below original controls (if any)
	ControlBar gOriginalHeight+30

	GetWindow kwTopWin,gsize
	
	Slider WM4DAxis,pos={V_left+10,gOriginalHeight+9},size={V_right-V_left-kImageSliderLMargin,16},proc=WM4DImageSliderProc
	// uncomment the following line if you want do disable live updates when the slider moves.
	// Slider WM4DAxis live=0	
	Slider WM4DAxis,limits={0,gRightLim,1},value= 0,vert= 0,ticks=0,side=0,variable=gLayer	
	
	SetVariable WM4DVal,pos={V_right-kImageSliderLMargin+15,gOriginalHeight+9},size={60,14}
	SetVariable WM4DVal,limits={0,INF,1},title=" ",proc=WM4DImageSliderSetVarProc
	
	String cmd
	sprintf cmd,"SetVariable WM4DVal,value=%s",GetDataFolder(1)+"gLayer"
	Execute cmd

	ModifyImage $imageName plane=0
	// 
	WaveStats/Q w
	ModifyImage $imageName ctab= {V_min,V_max,,0}	// missing ctb to leave it unchanced.
	
	SetDataFolder dfSav
End

//*******************************************************************************************************
Function WM4DImageSliderSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		// comment the following line if you want to disable live updates.
		case 3: // Live update
			Variable dval = sva.dval
			WM4DImageSliderProc("",0,0)
			break
	endswitch

	return 0
End
//*******************************************************************************************************
