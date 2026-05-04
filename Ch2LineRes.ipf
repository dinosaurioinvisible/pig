#pragma rtGlobals=3		// Use modern global access method and strict wave access.


function waveCh2lineRes(w)
	
	wave w
	
	string notes=note(w)
		
	string ms=notes[(strsearch(notes,"state.acq.msPerLine=",0)+20),(strsearch(notes,"state.acq.fillFraction=",0)-2) ]
	variable msPline=str2num(ms)
	
	duplicate/o/FREE w, temp
	
	matrixop/o/FREE trans=transposevol(temp,5)
	matrixop/o/FREE lines=sumrows(trans)
	
	variable xx=dimsize(lines,0), zz=dimsize(lines,2)
	
	redimension/N=(xx*zz) lines
	
	setscale/P x,0,(mspline/1000), lines
	
	duplicate/o lines, timewave
	
end