#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


function ZapBadROIs (wave w, [wave stimulus])

	// check stimulus
	if (ParamIsDefault(stimulus))
		string info = note(w)
		string basename = StringByKey("basename", info, "=", "\r")
		string stimWaveName = basename + "_sti"
		wave stimWave = $stimWaveName
	else
		wave stimWave = stimulus
   endif
   
	//
	// SetScale/P x 0,0.05,w
	// subroutine to determine if stim_wave is a timewave (a nx1 wave) or a ch2 movie
	// if timewave it goes straigth to background of routine
	// if ch2 movie (usually by channel separation from Sarfia) it does waveCh2lineRes, 
	// makes the background timewave.
	// Scaling between w and stim_wave (of both types) seem to work well.
	//
	variable/g Layers = dimsize(stimWave,2)
	if (Layers==0)
		wave timewave
		duplicate /o stimWave, stimtype1
	else
		waveCh2lineRes(stimWave)
		wave timewave
		duplicate/o timewave, stimtype1
	endif

	//////

	string name= nameofwave(w)
	string/g wn = name
	string/g zn= nameofwave(stimtype1)
	variable/g nROI = dimsize(w,1)
	variable/g framerate=1/dimDelta(w,0)

	make/o/n=(nROI) goodBad
	string/g goodBadName= nameofwave(w) + "_GB"
	duplicate/o goodBad, $goodBadName
	variable/g onROI = 0
	makeZapWindow()

end



Function makeZapWindow()

	//wave z
	string/g wn
	string/g zn
	variable/g nROI
	variable/g onROI
	variable/g framerate
	duplicate/o $wn, data
	duplicate/o $zn, bkgr

	// Panel
	duplicate/o/RMD=[][onROI]data, waveData
	duplicate/o/RMD=[][]bkgr, wavebkgr
	Display/K=1/W=(100,0,800,400)/N=roiThingy wavebkgr,waveData as "Bad ROI GUI"
	ModifyGraph rgb(wavebkgr)=(0,0,0)
	ModifyGraph margin(bottom)=100
	ModifyGraph nticks(bottom)=24

	///times for start and end stimulus
	//variable startstim=0
	//variable endstim=36
	///// alter to have the relevant stimulus itnerval

	//SetAxis bottom startstim,endstim 
	//SetAxis left -1,2

	//Val Display
	ValDisplay whichROI value= #"onROI"

	// Good Button
	Button goodRoiButt, proc = goodButt, title = "Good"
	Button badRoiButt, proc = badButt, title = "Bad"
	killwaves data 

end

Function goodButt(ba) : buttonControl
struct WMButtonAction&ba
	switch(ba.eventcode)
		case 2:
			dowindow/k roiThingy
			variable/g onROI
			variable/g nROI
			string/g goodBadName
			duplicate/o $goodBadName, gB
			gB[onRoi] = 1
			duplicate/o gb, $goodBadName
			if (onROI < nROI-1)
				onROI+=1
				makeZapWindow()
			else
				finishUpZap()
			endif
	endswitch
end


Function badButt(ba) : buttonControl
struct WMButtonAction&ba
	switch(ba.eventcode)
		case 2:
			dowindow/k roiThingy
			variable/g onROI
			variable/g nROI
			string/g goodBadName
			duplicate/o $goodBadName, gB
			gB[onRoi] = 0
			duplicate/o gb, $goodBadName
			if (onROI < nROI-1)
				onROI+=1
				makeZapWindow()
			else
				finishUpZap()
			endif
	endswitch
end


Function finishUpZap()

	string/g wn
	string/g goodBadName
	variable/g nROI
	variable nstart= strsearch(wn,"QA",0)-1
	string goodROIs=wn[0,nstart] +"QA_goodROIlist"
	string goodROIDat = wn[0,nstart]+"QA_goodROIdata"
	killwaves/z $goodROIDat, goodROIs
	duplicate/o $goodBadName, gb, good
	good = 0
	variable i 
	variable j = 0
	for (i=0;i<nROI;i+=1)
		if (gb[i]==1)
			good[j]=i
			j+=1
		endif
	endfor
	deletepoints j,nROI, good
	duplicate/o good, $goodROIs
	for (i=0;i<dimsize(good,0);i+=1)
		variable goodOne = good[i]
		duplicate/o/RMD=[][goodOne] $wn, goodDat
		concatenate/NP=1 {goodDat}, $goodROIDat
	endfor
	
	killwaves $goodBadName gb good goodDat
	killthemall()	
end

/////////
function killthemall()
	wave waveData
	wave goodBad
	killwaves waveData goodBad 

	wave wavebkgr
	wave waveData
	wave bkgr
	//wave timewave
	wave stimtype1
	killwaves wavebkgr waveData bkgr
	killwaves   stimtype1

end

///////////////
function waveCh2lineResk(w)
	
	wave w
	
	variable msPline=1 //change here for the number of ms per line (usually 1) 
	
	duplicate/o/FREE w, temp
	
	matrixop/o/FREE trans=transposevol(temp,5)
	matrixop/o/FREE lines=sumrows(trans)
	
	variable xx=dimsize(lines,0), zz=dimsize(lines,2)
	
	redimension/N=(xx*zz) lines
	
	setscale/P x,0,(mspline/1000), lines
	
	duplicate/o lines, timewave
	//
	timewave/=wavemax(lines)
		
end


goodROImap(w,$goodROIs)








//Patricio 9.3.21