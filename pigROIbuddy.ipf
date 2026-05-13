#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// slightly modified version of the original to accommodate data from KS analysis

Function pigROIbuddy(w)

	wave w
	string/g root:packages:pig:ROIbuddy_rois = nameofwave(w)
	string basename = nameOfWave(w)[0,strSearch(nameOfWave(w),"_reg_",0)-1]
	string/g root:packages:pig:ROIbuddy_basename = basename
	
	// took this idea from Marios' ROIbuddy
	string stimulus = "root:" + basename + ":" + basename + "_sti"
	wave ws = $stimulus
	
	// these files are different for KS
	// look for the STD and ROImask files for background
	// this assumes the processing made by the KS algorithm: 
	// registration, interpolation/squaring & bleach correction
	string std_image = basename + "_reg_isq_bc_std"
	// print "background file: " + std_image
	wave avg = $std_image
	string roin = basename + "_reg_isq_bc_roimask"
	wave roi = $roin
	// print "roi file" + roin
	
	variable/g root:packages:pig:ROI2display=0
	nvar ROI2display=root:packages:pig:ROI2display
	variable/g root:packages:pig:CompareROI=0
	nvar CompareROI=root:packages:pig:CompareROI
	
	Display/K=1 /W=(79,45,688,549)/L=DF/B=Time w[*][ROI2display]
	ModifyGraph rgb=(52171,0,5911)
	AppendImage/T avg
	AppendImage/T roi
	SetAxis/A/R left
	ModifyImage $roin ctab= {*,0,Grays,0}
	ModifyImage $roin maxRGB=nan
	ModifyImage $roin explicit=1,eval={-1,52171,0,5911} 
	//,eval={0,-1,-1,-1},eval={255,-1,-1,-1}
	ModifyGraph mirror(left)=0,mirror(top)=0
	ModifyGraph standoff(top)=0
	ModifyGraph lblPos(left)=53,lblPos(Time)=47
	ModifyGraph freePos(DF)=0
	ModifyGraph freePos(Time)=0
	ModifyGraph axisEnab(left)={0.55,1}
	ModifyGraph axisEnab(DF)={0,0.45}
	Label top "µm"
	Label Time "Time (s)"
	Label df "ÆF/F"
	ModifyGraph lblPos(DF)=65
	ControlBar 30
	// from Marios
	AppendToGraph/L=DF/C=(0,0,0) ws[][0]
	
	SetVariable ShowROI,pos={460,3},size={130,23},proc=pigShowROI,title="ShowROI"
	SetVariable ShowROI limits={0,dimsize(w,1)-1,1}
	SetVariable ShowROI,fSize=15,value=ROI2display
	
	CheckBox Compare,pos={435,7},size={16,15},proc=pigCompareCB,title=""
	CheckBox Compare,value= 0,side= 1
	SetVariable Compar,pos={256,3},size={172,23},proc=pigCompareROIsetvar,title="Compare ROI#"
	SetVariable Compar,fSize=15,value= CompareROI

end


///////////////////////////////////// 


Function pigShowROI(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	SVAR wn = root:Packages:pig:ROIbuddy_rois
	SVAR basename = root:Packages:pig:ROIbuddy_basename
	wave w = $wn
	string roin = basename + "_reg_isq_bc_roimask"
	wave roi = $roin

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			Variable/g root:packages:pig:ROI2display=dval
			nvar ROI2display=root:packages:pig:ROI2display
		
			AppendToGraph/L=DF/B=Time w[][ROI2display]
			RemoveFromGraph $wn
			ModifyGraph rgb($wn)=(52171,0,5911)
			
			AppendImage/T $roin
			RemoveImage $roin
			ModifyImage $roin ctab= {*,0,Grays,0}
			ModifyImage $roin maxRGB=nan
			ModifyImage $roin explicit=1,eval={-(roi2display+1),52171,0,5911}
					
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

////////////////////////////

Function pigCompareCB(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	
	SVAR wn = root:Packages:pig:ROIbuddy_rois
	SVAR basename = root:Packages:pig:ROIbuddy_basename
	wave w = $wn
	string roin = basename + "_reg_isq_bc_roimask"
	wave roi = $roin
	nvar CompareROI=root:packages:pig:CompareROI
	
	switch( cba.eventCode )
		case 2: // mouse up
		
			Variable/G root:packages:pig:checkBoxCompare = cba.checked
			nvar checkBoxCompare=root:packages:pig:checkBoxCompare
			
			if(checkBoxCompare==1)		
				duplicate/o roi, compareROImask
				duplicate/o w, compareData
				AppendToGraph/L=DF/B=Time compareData[][CompareROI]
				ModifyGraph rgb(compareData)=(9252,26214,42919)
				AppendImage/T compareROImask
				ModifyImage compareROImask ctab= {*,0,Grays,0}
				ModifyImage compareROImask maxRGB=nan
				ModifyImage compareROImask explicit=1,eval={-(CompareROI+1),9252,26214,42919}		
			elseif(checkBoxCompare==0)
				wave compareData,compareROImask
				RemoveFromGraph compareData
				Removeimage compareROImask
				killwaves/Z compareData,compareROImask
			endif
						
			break
		case -1: // control being killed
			break
	endswitch

	return 0
end

////////////////////////////

Function pigCompareROIsetvar(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	SVAR wn = root:Packages:pig:ROIbuddy_rois
	SVAR basename = root:Packages:pig:ROIbuddy_basename
	wave w = $wn	
	string roin = basename + "_reg_isq_bc_roimask"
	wave roi = $roin
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			
			variable/g root:packages:pig:CompareROI=dval
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
