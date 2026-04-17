#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include "Ch2LineRes"
#include "pig"

// panel for pig
Window pigPanel(): Panel_pig
	PauseUpdate; Silent 1	
	NewDataFolder/O root:Packages:pig
	// manually defining FOV, alpha
	Variable/G root:Packages:pig:FOV=610
	Variable/G root:Packages:pig:alpha=0.05
	// /w=(left, top, right, bottom)
	NewPanel /W=(666,111,1111,333) as "new KS analysis"
	//ModifyPanel cbRGB=(11454,30202,51877)
	ModifyPanel cbRGB = (0, 13107, 26214)
	SetDrawLayer UserBack
	SetDrawEnv linethick= 0,fillfgc= (64824,27308,21496)
	DrawRRect 5,50,290,205
	// input
	DrawText 30,26,"Input"
	SetDrawEnv fsize= 16,fstyle= 1,textrgb= (65535,65535,65535)
EndMacro