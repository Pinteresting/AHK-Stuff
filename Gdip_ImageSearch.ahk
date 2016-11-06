;**********************************************************************************
;
; Gdip_ImageSearch()
; by Pinteresting, based on oringal work by MasterFocus
; Thanks to guest3456 for helping me ponder some ideas
; Requires GDIP, Gdip_SetBitmapTransColor() and Gdip_MultiLockedBitsSearch()
; http://www.autohotkey.com/board/topic/71100-gdip-imagesearch/
;
; Licensed under CC BY-SA 3.0 -> http://creativecommons.org/licenses/by-sa/3.0/
; I waive compliance with the "Share Alike" condition of the license EXCLUSIVELY
; for these users: tic , Rseding91 , guest3456
;
;==================================================================================
;
; This function searches for pBitmapNeedle within pBitmapHaystack
; The returned value is the number of instances found (negative = error)
;
; ++ PARAMETERS ++
;
; pBitmapHaystack and pBitmapNeedle
;   Self-explanatory bitmap pointers, are the only required parameters
;
; OutputList
;   ByRef variable to store the list of coordinates where a match was found
;
; OuterX1, OuterY1, OuterX2, OuterY2
;   Equivalent to ImageSearch's X1,Y1,X2,Y2
;   Default: 0 for all (which searches the whole haystack area)
;
; Variation
;   Just like ImageSearch, a value from 0 to 255
;   Default: 0
;
; Trans
;   Needle RGB transparent color, should be a numerical value from 0 to 0xFFFFFF
;   Default: blank (does not use transparency)
;
; SearchDirection
;   Haystack search direction
;     Vertical preference:
;       1 = top->left->right->bottom [default]
;       2 = bottom->left->right->top
;       3 = bottom->right->left->top
;       4 = top->right->left->bottom
;     Horizontal preference:
;       5 = left->top->bottom->right
;       6 = left->bottom->top->right
;       7 = right->bottom->top->left
;       8 = right->top->bottom->left
;
; Instances
;   Maximum number of instances to find when searching (0 = find all)
;   Default: 1 (stops after one match is found)
;
; LineDelim and CoordDelim
;   Outer and inner delimiters for the list of coordinates (OutputList)
;   Defaults: "`n" and ","
;
; ++ RETURN VALUES ++
;
; -1001 ==> invalid haystack and/or needle bitmap pointer
; -1002 ==> invalid variation value
; -1003 ==> X1 and Y1 cannot be negative
; -1004 ==> unable to lock haystack bitmap bits
; -1005 ==> unable to lock needle bitmap bits
; any non-negative value ==> the number of instances found
;
;==================================================================================
;
;**********************************************************************************

Gdip_ImageSearch(pBitmapHaystack,pBitmapNeedle,ByRef OutputList=""
,OuterX1=0,OuterY1=0,OuterX2=0,OuterY2=0,Variation=0,Trans=""
,SearchDirection=1,Instances=1,channel=-1,a=0,LineDelim="`n",CoordDelim=",") {

    ; Some validations that can be done before proceeding any further
    If !( pBitmapHaystack && pBitmapNeedle )
        Return -1001
    If Variation not between 0 and 255
        return -1002
    If ( ( OuterX1 < 0 ) || ( OuterY1 < 0 ) )
        return -1003
    If SearchDirection not between 1 and 8
        SearchDirection := 1
    If ( Instances < 0 )
        Instances := 0

    ; Getting the dimensions and locking the bits [haystack]
    Gdip_GetImageDimensions(pBitmapHaystack,hWidth,hHeight)
    ; Last parameter being 1 says the LockMode flag is "READ only"
    If Gdip_LockBits(pBitmapHaystack,0,0,hWidth,hHeight,hStride,hScan,hBitmapData,1)
    OR !(hWidth := NumGet(hBitmapData,0))
    OR !(hHeight := NumGet(hBitmapData,4))
        Return -1004

    ; Careful! From this point on, we must do the following before returning:
    ; - unlock haystack bits

    ; Getting the dimensions and locking the bits [needle]
    Gdip_GetImageDimensions(pBitmapNeedle,nWidth,nHeight)
    ; If Trans is correctly specified, create a backup of the original needle bitmap
    ; and modify the current one, setting the desired color as transparent.
    ; Also, since a copy is created, we must remember to dispose the new bitmap later.
    ; This whole thing has to be done before locking the bits.
    If Trans between 0 and 0xFFFFFF
    {
        pOriginalBmpNeedle := pBitmapNeedle
        pBitmapNeedle := Gdip_CloneBitmapArea(pOriginalBmpNeedle,0,0,nWidth,nHeight)
        Gdip_SetBitmapTransColor(pBitmapNeedle,Trans)
        DumpCurrentNeedle := true
    }

    ; Careful! From this point on, we must do the following before returning:
    ; - unlock haystack bits
    ; - dispose current needle bitmap (if necessary)

    If Gdip_LockBits(pBitmapNeedle,0,0,nWidth,nHeight,nStride,nScan,nBitmapData)
    OR !(nWidth := NumGet(nBitmapData,0))
    OR !(nHeight := NumGet(nBitmapData,4))
    {
        If ( DumpCurrentNeedle )
            Gdip_DisposeImage(pBitmapNeedle)
        Gdip_UnlockBits(pBitmapHaystack,hBitmapData)
        Return -1005
    }
    
    ; Careful! From this point on, we must do the following before returning:
    ; - unlock haystack bits
    ; - unlock needle bits
    ; - dispose current needle bitmap (if necessary)

    ; Adjust the search box. "OuterX2,OuterY2" will be the last pixel evaluated
    ; as possibly matching with the needle's first pixel. So, we must avoid going
    ; beyond this maximum final coordinate.
    OuterX2 := ( !OuterX2 ? hWidth-nWidth+1 : OuterX2-nWidth+1 )
    OuterY2 := ( !OuterY2 ? hHeight-nHeight+1 : OuterY2-nHeight+1 )

    OutputCount := Gdip_MultiLockedBitsSearch(hStride,hScan,hWidth,hHeight
    ,nStride,nScan,nWidth,nHeight,OutputList,OuterX1,OuterY1,OuterX2,OuterY2
    ,Variation,SearchDirection,Instances,LineDelim,CoordDelim,channel,a)

    Gdip_UnlockBits(pBitmapHaystack,hBitmapData)
    Gdip_UnlockBits(pBitmapNeedle,nBitmapData)
    If ( DumpCurrentNeedle )
        Gdip_DisposeImage(pBitmapNeedle)

    Return OutputCount
}


;///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

;**********************************************************************************
;
; Gdip_SetBitmapTransColorVariation();
;**********************************************************************************

;==================================================================================
;
; This function modifies the Alpha component for all pixels of a certain color to 0
; The returned value is 0 in case of success, or a negative number otherwise
;
; ++ PARAMETERS ++
;
; pBitmap
;   A valid pointer to the bitmap that will be modified
;
; TransColor
;   The color to become transparent
;   Should range from 0 (black) to 0xFFFFFF (white)
;
; Variation
; like with image search between 0 and 255

; ++ RETURN VALUES ++
;
; -2001 ==> invalid bitmap pointer
; -2002 ==> invalid TransColor
; -2003 ==> unable to retrieve bitmap positive dimensions
; -2004 ==> unable to lock bitmap bits
; -2005 ==> DllCall failed (see ErrorLevel)
; any non-negative value ==> the number of pixels modified by this function
;
;==================================================================================

Gdip_SetBitmapTransColorVariation(pBitmap,TransColor, Variation) {
    static _SetBmpTransV, Ptr, PtrA
    if !( _SetBmpTransV ) {
        Ptr := A_PtrSize ? "UPtr" : "UInt"
        PtrA := Ptr . "*"
        MCode_SetBmpTransV := "
            (LTrim Join 
			5557565383EC0C8B5424288B4424348B7C24308B74243885D2C700000000000F8E970000008B442420C70424000000
			00894424048B442424C1E00289442408908B44242485C07E5F8B4424048B6C240801C50FB657020FB648028D1C3239
			D97F3F29F239D17C390FB657010FB648018D1C3239D97F2A29F239D17C240FB6170FB6088D1C3239D97F1729F239D1
			7C118B5C2434C64003008303018DB60000000083C00439E875AB830424018B4C242C8B0424014C24043B4424287584
			83C40C31C05B5E5F5DC3
            )"
        if ( A_PtrSize == 8 ) ; x64, after comma
            MCode_SetBmpTransV := SubStr(MCode_SetBmpTransV,InStr(MCode_SetBmpTransV,",")+1)
        else ; x86, before comma
            MCode_SetBmpTransV := SubStr(MCode_SetBmpTransV,1,InStr(MCode_SetBmpTransV,",")-1)
        VarSetCapacity(_SetBmpTransV, LEN := StrLen(MCode_SetBmpTransV)//2, 0)
        Loop, %LEN%
            NumPut("0x" . SubStr(MCode_SetBmpTransV,(2*A_Index)-1,2), _SetBmpTransV, A_Index-1, "uchar")
        MCode_SetBmpTransV := ""
        DllCall("VirtualProtect", Ptr,&_SetBmpTransV, Ptr,VarSetCapacity(_SetBmpTransV), "uint",0x40, PtrA,0)
    }
    If !pBitmap
        Return -2001
    If TransColor not between 0 and 0xFFFFFF
        Return -2002
    Gdip_GetImageDimensions(pBitmap,W,H)
    If !(W && H)
        Return -2003
    If Gdip_LockBits(pBitmap,0,0,W,H,Stride,Scan,BitmapData)
        Return -2004
    ; The following code should be slower than using the MCode approach,
    ; but will the kept here for now, just for reference.
    /*
    Count := 0
    Loop, %H% {
        Y := A_Index-1
        Loop, %W% {
            X := A_Index-1
            CurrentColor := Gdip_GetLockBitPixel(Scan,X,Y,Stride)
            If ( (CurrentColor & 0xFFFFFF) == TransColor )
                Gdip_SetLockBitPixel(TransColor,Scan,X,Y,Stride), Count++
        }
    }
    */
    ; Thanks guest3456 for helping with the initial solution involving NumPut
    Gdip_FromARGB(TransColor,A,R,G,B), VarSetCapacity(TransColor,0), VarSetCapacity(TransColor,3,255)
    NumPut(B,TransColor,0,"UChar"), NumPut(G,TransColor,1,"UChar"), NumPut(R,TransColor,2,"UChar")
    MCount := 0
    E := DllCall(&_SetBmpTransV, Ptr,Scan, "int",W, "int",H, "int",Stride, Ptr,&TransColor, "int*",MCount, "int", Variation, "cdecl int")
    Gdip_UnlockBits(pBitmap,BitmapData)
    If ( E != 0 ) {
        ErrorLevel := E
        Return -2005
    }
    Return MCount
}


;///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

;**********************************************************************************
;
; Gdip_SetBitmapTransColor()
; by MasterFocus - 02/APRIL/2013 00:30h BRT
; Requires GDIP
; http://www.autohotkey.com/board/topic/71100-gdip-imagesearch/
;
; Licensed under CC BY-SA 3.0 -> http://creativecommons.org/licenses/by-sa/3.0/
; I waive compliance with the "Share Alike" condition of the license EXCLUSIVELY
; for these users: tic , Rseding91 , guest3456
;
;**********************************************************************************

;==================================================================================
;
; This function modifies the Alpha component for all pixels of a certain color to 0
; The returned value is 0 in case of success, or a negative number otherwise
;
; ++ PARAMETERS ++
;
; pBitmap
;   A valid pointer to the bitmap that will be modified
;
; TransColor
;   The color to become transparent
;   Should range from 0 (black) to 0xFFFFFF (white)
;
; Variation
; like with image search between 0 and 255

; ++ RETURN VALUES ++
;
; -2001 ==> invalid bitmap pointer
; -2002 ==> invalid TransColor
; -2003 ==> unable to retrieve bitmap positive dimensions
; -2004 ==> unable to lock bitmap bits
; -2005 ==> DllCall failed (see ErrorLevel)
; any non-negative value ==> the number of pixels modified by this function
;
;==================================================================================

Gdip_SetBitmapTransColor(pBitmap,TransColor) {
    static _SetBmpTrans, Ptr, PtrA
    if !( _SetBmpTrans ) {
        Ptr := A_PtrSize ? "UPtr" : "UInt"
        PtrA := Ptr . "*"
        MCode_SetBmpTrans := "
            (LTrim Join 
			8b44240c558b6c241cc745000000000085c07e77538b5c2410568b74242033c9578b7c2414894c24288da424000000
            0085db7e458bc18d1439b9020000008bff8a0c113a4e0275178a4c38013a4e01750e8a0a3a0e7508c644380300ff450083c0
            0483c204b9020000004b75d38b4c24288b44241c8b5c2418034c242048894c24288944241c75a85f5e5b33c05dc3,405
            34c8b5424388bda41c702000000004585c07e6448897c2410458bd84c8b4424304963f94c8d49010f1f800000000085db7e3
            8498bc1488bd3660f1f440000410fb648023848017519410fb6480138087510410fb6083848ff7507c640020041ff024883c
            00448ffca75d44c03cf49ffcb75bc488b7c241033c05bc3
            )"
        if ( A_PtrSize == 8 ) ; x64, after comma
            MCode_SetBmpTrans := SubStr(MCode_SetBmpTrans,InStr(MCode_SetBmpTrans,",")+1)
        else ; x86, before comma
            MCode_SetBmpTrans := SubStr(MCode_SetBmpTrans,1,InStr(MCode_SetBmpTrans,",")-1)
        VarSetCapacity(_SetBmpTrans, LEN := StrLen(MCode_SetBmpTrans)//2, 0)
        Loop, %LEN%
            NumPut("0x" . SubStr(MCode_SetBmpTrans,(2*A_Index)-1,2), _SetBmpTrans, A_Index-1, "uchar")
        MCode_SetBmpTrans := ""
        DllCall("VirtualProtect", Ptr,&_SetBmpTrans, Ptr,VarSetCapacity(_SetBmpTrans), "uint",0x40, PtrA,0)
    }
    If !pBitmap
        Return -2001
    If TransColor not between 0 and 0xFFFFFF
        Return -2002
    Gdip_GetImageDimensions(pBitmap,W,H)
    If !(W && H)
        Return -2003
    If Gdip_LockBits(pBitmap,0,0,W,H,Stride,Scan,BitmapData)
        Return -2004
    ; The following code should be slower than using the MCode approach,
    ; but will the kept here for now, just for reference.
    /*
    Count := 0
    Loop, %H% {
        Y := A_Index-1
        Loop, %W% {
            X := A_Index-1
            CurrentColor := Gdip_GetLockBitPixel(Scan,X,Y,Stride)
            If ( (CurrentColor & 0xFFFFFF) == TransColor )
                Gdip_SetLockBitPixel(TransColor,Scan,X,Y,Stride), Count++
        }
    }
    */
    ; Thanks guest3456 for helping with the initial solution involving NumPut
    Gdip_FromARGB(TransColor,A,R,G,B), VarSetCapacity(TransColor,0), VarSetCapacity(TransColor,3,255)
    NumPut(B,TransColor,0,"UChar"), NumPut(G,TransColor,1,"UChar"), NumPut(R,TransColor,2,"UChar")
    MCount := 0
    E := DllCall(&_SetBmpTrans, Ptr,Scan, "int",W, "int",H, "int",Stride, Ptr,&TransColor, "int*",MCount, "cdecl int")
    Gdip_UnlockBits(pBitmap,BitmapData)
    If ( E != 0 ) {
        ErrorLevel := E
        Return -2005
    }
    Return MCount
}

;///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

;**********************************************************************************
;
; Gdip_MultiLockedBitsSearch()
; by MasterFocus - 24/MARCH/2013 06:20h BRT
; Requires GDIP and Gdip_LockedBitsSearch()
; http://www.autohotkey.com/board/topic/71100-gdip-imagesearch/
;
; Licensed under CC BY-SA 3.0 -> http://creativecommons.org/licenses/by-sa/3.0/
; I waive compliance with the "Share Alike" condition of the license EXCLUSIVELY
; for these users: tic , Rseding91 , guest3456
;
;**********************************************************************************

;==================================================================================
;
; This function returns the number of instances found
; The 8 first parameters are the same as in Gdip_LockedBitsSearch()
; The other 10 parameters are the same as in Gdip_ImageSearch()
; Note: the default for the Intances parameter here is 0 (find all matches)
;
;==================================================================================

Gdip_MultiLockedBitsSearch(hStride,hScan,hWidth,hHeight,nStride,nScan,nWidth,nHeight
,ByRef OutputList="",OuterX1=0,OuterY1=0,OuterX2=0,OuterY2=0,Variation=0
,SearchDirection=1,Instances=0,LineDelim="`n",CoordDelim=",",channel=-1,a=0)
{
    OutputList := ""
    OutputCount := !Instances
    InnerX1 := OuterX1 , InnerY1 := OuterY1
    InnerX2 := OuterX2 , InnerY2 := OuterY2

    ; The following part is a rather ugly but working hack that I
    ; came up with to adjust the variables and their increments
    ; according to the specified Haystack Search Direction
    /*
    Mod(SD,4) = 0 --> iX = 2 , stepX = +0 , iY = 1 , stepY = +1
    Mod(SD,4) = 1 --> iX = 1 , stepX = +1 , iY = 1 , stepY = +1
    Mod(SD,4) = 2 --> iX = 1 , stepX = +1 , iY = 2 , stepY = +0
    Mod(SD,4) = 3 --> iX = 2 , stepX = +0 , iY = 2 , stepY = +0
    SD <= 4   ------> Vertical preference
    SD > 4    ------> Horizontal preference
    */
    ; Set the index and the step (for both X and Y) to +1
    iX := 1, stepX := 1, iY := 1, stepY := 1
    ; Adjust Y variables if SD is 2, 3, 6 or 7
    Modulo := Mod(SearchDirection,4)
    If ( Modulo > 1 )
        iY := 2, stepY := 0
    ; adjust X variables if SD is 3, 4, 7 or 8
    If !Mod(Modulo,3)
        iX := 2, stepX := 0
    ; Set default Preference to vertical and Nonpreference to horizontal
    P := "Y", N := "X"
    ; adjust Preference and Nonpreference if SD is 5, 6, 7 or 8
    If ( SearchDirection > 4 )
        P := "X", N := "Y"
    ; Set the Preference Index and the Nonpreference Index
    iP := i%P%, iN := i%N%

	if(channel = -1)
	{
		While (!(OutputCount == Instances) && (0 == Gdip_LockedBitsSearch(hStride,hScan,hWidth,hHeight,nStride
		,nScan,nWidth,nHeight,FoundX,FoundY,OuterX1,OuterY1,OuterX2,OuterY2,Variation,SearchDirection)))
		{
			OutputCount++
			OutputList .= LineDelim FoundX CoordDelim FoundY
			Outer%P%%iP% := Found%P%+step%P%
			Inner%N%%iN% := Found%N%+step%N%
			Inner%P%1 := Found%P%
			Inner%P%2 := Found%P%+1
			While (!(OutputCount == Instances) && (0 == Gdip_LockedBitsSearch(hStride,hScan,hWidth,hHeight,nStride
			,nScan,nWidth,nHeight,FoundX,FoundY,InnerX1,InnerY1,InnerX2,InnerY2,Variation,SearchDirection)))
			{
				OutputCount++
				OutputList .= LineDelim FoundX CoordDelim FoundY
				Inner%N%%iN% := Found%N%+step%N%
			}
		}
	}
	else
	{
		if(a = 0)
		{
			While (!(OutputCount == Instances) && (0 == Gdip_LockedBitsSearchChannel(hStride,hScan,hWidth,hHeight,nStride
			,nScan,nWidth,nHeight,FoundX,FoundY,OuterX1,OuterY1,OuterX2,OuterY2,Variation,SearchDirection,channel)))
			{
				OutputCount++
				OutputList .= LineDelim FoundX CoordDelim FoundY
				Outer%P%%iP% := Found%P%+step%P%
				Inner%N%%iN% := Found%N%+step%N%
				Inner%P%1 := Found%P%
				Inner%P%2 := Found%P%+1
				While (!(OutputCount == Instances) && (0 == Gdip_LockedBitsSearchChannel(hStride,hScan,hWidth,hHeight,nStride
				,nScan,nWidth,nHeight,FoundX,FoundY,InnerX1,InnerY1,InnerX2,InnerY2,Variation,SearchDirection,channel)))
				{
					OutputList .= LineDelim FoundX CoordDelim FoundY
					OutputCount++
					Inner%N%%iN% := Found%N%+step%N%
				}
			}
		}
		else
		{
			while (!(OutputCount == Instances) && (0 == Gdip_LockedBitsSearchChannelAlpha(hStride,hScan,hWidth,hHeight,nStride
			,nScan,nWidth,nHeight,FoundX,FoundY,OuterX1,OuterY1,OuterX2,OuterY2,Variation,SearchDirection,channel)))
			{
				OutputCount++
				OutputList .= LineDelim FoundX CoordDelim FoundY
				Outer%P%%iP% := Found%P%+step%P%
				Inner%N%%iN% := Found%N%+step%N%
				Inner%P%1 := Found%P%
				Inner%P%2 := Found%P%+1
				While (!(OutputCount == Instances) && (0 == Gdip_LockedBitsSearchChannelAlpha(hStride,hScan,hWidth,hHeight,nStride
				,nScan,nWidth,nHeight,FoundX,FoundY,InnerX1,InnerY1,InnerX2,InnerY2,Variation,SearchDirection,channel)))
				{
					OutputList .= LineDelim FoundX CoordDelim FoundY
					OutputCount++
					Inner%N%%iN% := Found%N%+step%N%
				}
			}
		}

	}
    OutputList := SubStr(OutputList,1+StrLen(LineDelim))
    OutputCount -= !Instances	
    Return OutputCount
}

;///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
;///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

;**********************************************************************************
;
; Gdip_LockedBitsSearch()
; by MasterFocus - 24/MARCH/2013 06:20h BRT
; Mostly adapted from previous work by tic and Rseding91
;
; Requires GDIP
; http://www.autohotkey.com/board/topic/71100-gdip-imagesearch/
;
; Licensed under CC BY-SA 3.0 -> http://creativecommons.org/licenses/by-sa/3.0/
; I waive compliance with the "Share Alike" condition of the license EXCLUSIVELY
; for these users: tic , Rseding91 , guest3456
;
;**********************************************************************************

;==================================================================================
;
; This function searches for a single match of nScan within hScan
;
; ++ PARAMETERS ++
;
; hStride, hScan, hWidth and hHeight
;   Haystack stuff, extracted from a BitmapData, extracted from a Bitmap
;
; nStride, nScan, nWidth and nHeight
;   Needle stuff, extracted from a BitmapData, extracted from a Bitmap
;
; x and y
;   ByRef variables to store the X and Y coordinates of the image if it's found
;   Default: "" for both
;
; sx1, sy1, sx2 and sy2
;   These can be used to crop the search area within the haystack
;   Default: "" for all (does not crop)
;
; Variation
;   Same as the builtin ImageSearch command
;   Default: 0
;
; sd
;   Haystack search direction
;     Vertical preference:
;       1 = top->left->right->bottom [default]
;       2 = bottom->left->right->top
;       3 = bottom->right->left->top
;       4 = top->right->left->bottom
;     Horizontal preference:
;       5 = left->top->bottom->right
;       6 = left->bottom->top->right
;       7 = right->bottom->top->left
;       8 = right->top->bottom->left
;   This value is passed to the internal MCoded function
;
; ++ RETURN VALUES ++
;
; -3001 to -3006 ==> search area incorrectly defined
; -3007 ==> DllCall returned blank
; 0 ==> DllCall succeeded and a match was found
; -4001 ==> DllCall succeeded but a match was not found
; anything else ==> the error value returned by the unsuccessful DllCall
;
;==================================================================================

Gdip_LockedBitsSearch(hStride,hScan,hWidth,hHeight,nStride,nScan,nWidth,nHeight
,ByRef x="",ByRef y="",sx1=0,sy1=0,sx2=0,sy2=0,Variation=0,sd=1)
{
    static _ImageSearch, Ptr, PtrA

    ; Initialize all MCode stuff, if necessary
    if !( _ImageSearch ) {
        Ptr := A_PtrSize ? "UPtr" : "UInt"
        PtrA := Ptr . "*"

        MCode_ImageSearch := "
            (LTrim Join
            8b44243883ec205355565783f8010f857a0100008b7c2458897c24143b7c24600f8db50b00008b44244c8b5c245c8b
            4c24448b7424548be80fafef896c242490897424683bf30f8d0a0100008d64240033c033db8bf5896c241c895c2420894424
            183b4424480f8d0401000033c08944241085c90f8e9d0000008b5424688b7c24408beb8d34968b54246403df8d4900b80300
            0000803c18008b442410745e8b44243c0fb67c2f020fb64c06028d04113bf87f792bca3bf97c738b44243c0fb64c06018b44
            24400fb67c28018d04113bf87f5a2bca3bf97c548b44243c0fb63b0fb60c068d04113bf87f422bca3bf97c3c8b4424108b7c
            24408b4c24444083c50483c30483c604894424103bc17c818b5c24208b74241c0374244c8b44241840035c24508974241ce9
            2dffffff8b6c24688b5c245c8b4c244445896c24683beb8b6c24240f8c06ffffff8b44244c8b7c24148b7424544703e8897c
            2414896c24243b7c24600f8cd5feffffe96b0a00008b4424348b4c246889088b4424388b4c24145f5e5d890833c05b83c420
            c383f8020f85870100008b7c24604f897c24103b7c24580f8c310a00008b44244c8b5c245c8b4c24448bef0fafe8f7d88944
            24188b4424548b742418896c24288d4900894424683bc30f8d0a0100008d64240033c033db8bf5896c2420895c241c894424
            243b4424480f8d0401000033c08944241485c90f8e9d0000008b5424688b7c24408beb8d34968b54246403df8d4900b80300
            0000803c03008b442414745e8b44243c0fb67c2f020fb64c06028d04113bf87f792bca3bf97c738b44243c0fb64c06018b44
            24400fb67c28018d04113bf87f5a2bca3bf97c548b44243c0fb63b0fb60c068d04113bf87f422bca3bf97c3c8b4424148b7c
            24408b4c24444083c50483c30483c604894424143bc17c818b5c241c8b7424200374244c8b44242440035c245089742420e9
            2dffffff8b6c24688b5c245c8b4c244445896c24683beb8b6c24280f8c06ffffff8b7c24108b4424548b7424184f03ee897c
            2410896c24283b7c24580f8dd5feffffe9db0800008b4424348b4c246889088b4424388b4c24105f5e5d890833c05b83c420
            c383f8030f85650100008b7c24604f897c24103b7c24580f8ca10800008b44244c8b6c245c8b5c24548b4c24448bf70faff0
            4df7d8896c242c897424188944241c8bff896c24683beb0f8c020100008d64240033c033db89742424895c2420894424283b
            4424480f8d76ffffff33c08944241485c90f8e9f0000008b5424688b7c24408beb8d34968b54246403dfeb038d4900b80300
            0000803c03008b442414745e8b44243c0fb67c2f020fb64c06028d04113bf87f752bca3bf97c6f8b44243c0fb64c06018b44
            24400fb67c28018d04113bf87f562bca3bf97c508b44243c0fb63b0fb60c068d04113bf87f3e2bca3bf97c388b4424148b7c
            24408b4c24444083c50483c30483c604894424143bc17c818b5c24208b7424248b4424280374244c40035c2450e92bffffff
            8b6c24688b5c24548b4c24448b7424184d896c24683beb0f8d0affffff8b7c24108b44241c4f03f0897c2410897424183b7c
            24580f8c580700008b6c242ce9d4feffff83f8040f85670100008b7c2458897c24103b7c24600f8d340700008b44244c8b6c
            245c8b5c24548b4c24444d8bf00faff7896c242c8974241ceb098da424000000008bff896c24683beb0f8c020100008d6424
            0033c033db89742424895c2420894424283b4424480f8d06feffff33c08944241485c90f8e9f0000008b5424688b7c24408b
            eb8d34968b54246403dfeb038d4900b803000000803c03008b442414745e8b44243c0fb67c2f020fb64c06028d04113bf87f
            752bca3bf97c6f8b44243c0fb64c06018b4424400fb67c28018d04113bf87f562bca3bf97c508b44243c0fb63b0fb60c068d
            04113bf87f3e2bca3bf97c388b4424148b7c24408b4c24444083c50483c30483c604894424143bc17c818b5c24208b742424
            8b4424280374244c40035c2450e92bffffff8b6c24688b5c24548b4c24448b74241c4d896c24683beb0f8d0affffff8b4424
            4c8b7c24104703f0897c24108974241c3b7c24600f8de80500008b6c242ce9d4feffff83f8050f85890100008b7c2454897c
            24683b7c245c0f8dc40500008b5c24608b6c24588b44244c8b4c2444eb078da42400000000896c24103beb0f8d200100008b
            e80faf6c2458896c241c33c033db8bf5896c2424895c2420894424283b4424480f8d0d01000033c08944241485c90f8ea600
            00008b5424688b7c24408beb8d34968b54246403dfeb0a8da424000000008d4900b803000000803c03008b442414745e8b44
            243c0fb67c2f020fb64c06028d04113bf87f792bca3bf97c738b44243c0fb64c06018b4424400fb67c28018d04113bf87f5a
            2bca3bf97c548b44243c0fb63b0fb60c068d04113bf87f422bca3bf97c3c8b4424148b7c24408b4c24444083c50483c30483
            c604894424143bc17c818b5c24208b7424240374244c8b44242840035c245089742424e924ffffff8b7c24108b6c241c8b44
            244c8b5c24608b4c24444703e8897c2410896c241c3bfb0f8cf3feffff8b7c24688b6c245847897c24683b7c245c0f8cc5fe
            ffffe96b0400008b4424348b4c24688b74241089088b4424385f89305e5d33c05b83c420c383f8060f85670100008b7c2454
            897c24683b7c245c0f8d320400008b6c24608b5c24588b44244c8b4c24444d896c24188bff896c24103beb0f8c1a0100008b
            f50faff0f7d88974241c8944242ceb038d490033c033db89742424895c2420894424283b4424480f8d06fbffff33c0894424
            1485c90f8e9f0000008b5424688b7c24408beb8d34968b54246403dfeb038d4900b803000000803c03008b442414745e8b44
            243c0fb67c2f020fb64c06028d04113bf87f752bca3bf97c6f8b44243c0fb64c06018b4424400fb67c28018d04113bf87f56
            2bca3bf97c508b44243c0fb63b0fb60c068d04113bf87f3e2bca3bf97c388b4424148b7c24408b4c24444083c50483c30483
            c604894424143bc17c818b5c24208b7424248b4424280374244c40035c2450e92bffffff8b6c24108b74241c0374242c8b5c
            24588b4c24444d896c24108974241c3beb0f8d02ffffff8b44244c8b7c246847897c24683b7c245c0f8de60200008b6c2418
            e9c2feffff83f8070f85670100008b7c245c4f897c24683b7c24540f8cc10200008b6c24608b5c24588b44244c8b4c24444d
            896c241890896c24103beb0f8c1a0100008bf50faff0f7d88974241c8944242ceb038d490033c033db89742424895c242089
            4424283b4424480f8d96f9ffff33c08944241485c90f8e9f0000008b5424688b7c24408beb8d34968b54246403dfeb038d49
            00b803000000803c18008b442414745e8b44243c0fb67c2f020fb64c06028d04113bf87f752bca3bf97c6f8b44243c0fb64c
            06018b4424400fb67c28018d04113bf87f562bca3bf97c508b44243c0fb63b0fb60c068d04113bf87f3e2bca3bf97c388b44
            24148b7c24408b4c24444083c50483c30483c604894424143bc17c818b5c24208b7424248b4424280374244c40035c2450e9
            2bffffff8b6c24108b74241c0374242c8b5c24588b4c24444d896c24108974241c3beb0f8d02ffffff8b44244c8b7c24684f
            897c24683b7c24540f8c760100008b6c2418e9c2feffff83f8080f85640100008b7c245c4f897c24683b7c24540f8c510100
            008b5c24608b6c24588b44244c8b4c24448d9b00000000896c24103beb0f8d200100008be80faf6c2458896c241c33c033db
            8bf5896c2424895c2420894424283b4424480f8d9dfcffff33c08944241485c90f8ea60000008b5424688b7c24408beb8d34
            968b54246403dfeb0a8da424000000008d4900b803000000803c03008b442414745e8b44243c0fb67c2f020fb64c06028d04
            113bf87f792bca3bf97c738b44243c0fb64c06018b4424400fb67c28018d04113bf87f5a2bca3bf97c548b44243c0fb63b0f
            b604068d0c103bf97f422bc23bf87c3c8b4424148b7c24408b4c24444083c50483c30483c604894424143bc17c818b5c2420
            8b7424240374244c8b44242840035c245089742424e924ffffff8b7c24108b6c241c8b44244c8b5c24608b4c24444703e889
            7c2410896c241c3bfb0f8cf3feffff8b7c24688b6c24584f897c24683b7c24540f8dc5feffff8b4424345fc700ffffffff8b
            4424345e5dc700ffffffffb85ff0ffff5b83c420c3,4c894c24204c89442418488954241048894c24085355565741544
            155415641574883ec188b8424c80000004d8bd94d8bd0488bda83f8010f85b3010000448b8c24a800000044890c24443b8c2
            4b80000000f8d66010000448bac24900000008b9424c0000000448b8424b00000008bbc2480000000448b9424a0000000418
            bcd410fafc9894c24040f1f84000000000044899424c8000000453bd00f8dfb000000468d2495000000000f1f80000000003
            3ed448bf933f6660f1f8400000000003bac24880000000f8d1701000033db85ff7e7e458bf4448bce442bf64503f7904d63c
            14d03c34180780300745a450fb65002438d040e4c63d84c035c2470410fb64b028d0411443bd07f572bca443bd17c50410fb
            64b01450fb650018d0411443bd07f3e2bca443bd17c37410fb60b450fb6108d0411443bd07f272bca443bd17c204c8b5c247
            8ffc34183c1043bdf7c8fffc54503fd03b42498000000e95effffff8b8424c8000000448b8424b00000008b4c24044c8b5c2
            478ffc04183c404898424c8000000413bc00f8c20ffffff448b0c24448b9424a000000041ffc14103cd44890c24894c24044
            43b8c24b80000000f8cd8feffff488b5c2468488b4c2460b85ff0ffffc701ffffffffc703ffffffff4883c418415f415e415
            d415c5f5e5d5bc38b8424c8000000e9860b000083f8020f858c010000448b8c24b800000041ffc944890c24443b8c24a8000
            0007cab448bac2490000000448b8424c00000008b9424b00000008bbc2480000000448b9424a0000000418bc9410fafcd418
            bc5894c2404f7d8894424080f1f400044899424c8000000443bd20f8d02010000468d2495000000000f1f80000000004533f
            6448bf933f60f1f840000000000443bb424880000000f8d56ffffff33db85ff0f8e81000000418bec448bd62bee4103ef496
            3d24903d3807a03007460440fb64a02418d042a4c63d84c035c2470410fb64b02428d0401443bc87f5d412bc8443bc97c554
            10fb64b01440fb64a01428d0401443bc87f42412bc8443bc97c3a410fb60b440fb60a428d0401443bc87f29412bc8443bc97
            c214c8b5c2478ffc34183c2043bdf7c8a41ffc64503fd03b42498000000e955ffffff8b8424c80000008b9424b00000008b4
            c24044c8b5c2478ffc04183c404898424c80000003bc20f8c19ffffff448b0c24448b9424a0000000034c240841ffc9894c2
            40444890c24443b8c24a80000000f8dd0feffffe933feffff83f8030f85c4010000448b8c24b800000041ffc944898c24c80
            00000443b8c24a80000000f8c0efeffff8b842490000000448b9c24b0000000448b8424c00000008bbc248000000041ffcb4
            18bc98bd044895c24080fafc8f7da890c24895424048b9424a0000000448b542404458beb443bda0f8c13010000468d249d0
            000000066660f1f84000000000033ed448bf933f6660f1f8400000000003bac24880000000f8d0801000033db85ff0f8e960
            00000488b4c2478458bf4448bd6442bf64503f70f1f8400000000004963d24803d1807a03007460440fb64a02438d04164c6
            3d84c035c2470410fb64b02428d0401443bc87f63412bc8443bc97c5b410fb64b01440fb64a01428d0401443bc87f48412bc
            8443bc97c40410fb60b440fb60a428d0401443bc87f2f412bc8443bc97c27488b4c2478ffc34183c2043bdf7c8a8b8424900
            00000ffc54403f803b42498000000e942ffffff8b9424a00000008b8424900000008b0c2441ffcd4183ec04443bea0f8d11f
            fffff448b8c24c8000000448b542404448b5c240841ffc94103ca44898c24c8000000890c24443b8c24a80000000f8dc2fef
            fffe983fcffff488b4c24608b8424c8000000448929488b4c2468890133c0e981fcffff83f8040f857f010000448b8c24a80
            0000044890c24443b8c24b80000000f8d48fcffff448bac2490000000448b9424b00000008b9424c0000000448b8424a0000
            0008bbc248000000041ffca418bcd4489542408410fafc9894c2404669044899424c8000000453bd00f8cf8000000468d249
            5000000000f1f800000000033ed448bf933f6660f1f8400000000003bac24880000000f8df7fbffff33db85ff7e7e458bf44
            48bce442bf64503f7904d63c14d03c34180780300745a450fb65002438d040e4c63d84c035c2470410fb64b028d0411443bd
            07f572bca443bd17c50410fb64b01450fb650018d0411443bd07f3e2bca443bd17c37410fb60b450fb6108d0411443bd07f2
            72bca443bd17c204c8b5c2478ffc34183c1043bdf7c8fffc54503fd03b42498000000e95effffff8b8424c8000000448b842
            4a00000008b4c24044c8b5c2478ffc84183ec04898424c8000000413bc00f8d20ffffff448b0c24448b54240841ffc14103c
            d44890c24894c2404443b8c24b80000000f8cdbfeffffe9defaffff83f8050f85ab010000448b8424a000000044890424443
            b8424b00000000f8dc0faffff8b9424c0000000448bac2498000000448ba424900000008bbc2480000000448b8c24a800000
            0428d0c8500000000898c24c800000044894c2404443b8c24b80000000f8d09010000418bc4410fafc18944240833ed448bf
            833f6660f1f8400000000003bac24880000000f8d0501000033db85ff0f8e87000000448bf1448bce442bf64503f74d63c14
            d03c34180780300745d438d040e4c63d84d03da450fb65002410fb64b028d0411443bd07f5f2bca443bd17c58410fb64b014
            50fb650018d0411443bd07f462bca443bd17c3f410fb60b450fb6108d0411443bd07f2f2bca443bd17c284c8b5c24784c8b5
            42470ffc34183c1043bdf7c8c8b8c24c8000000ffc54503fc4103f5e955ffffff448b4424048b4424088b8c24c80000004c8
            b5c24784c8b54247041ffc04103c4448944240489442408443b8424b80000000f8c0effffff448b0424448b8c24a80000004
            1ffc083c10444890424898c24c8000000443b8424b00000000f8cc5feffffe946f9ffff488b4c24608b042489018b4424044
            88b4c2468890133c0e945f9ffff83f8060f85aa010000448b8c24a000000044894c2404443b8c24b00000000f8d0bf9ffff8
            b8424b8000000448b8424c0000000448ba424900000008bbc2480000000428d0c8d00000000ffc88944240c898c24c800000
            06666660f1f840000000000448be83b8424a80000000f8c02010000410fafc4418bd4f7da891424894424084533f6448bf83
            3f60f1f840000000000443bb424880000000f8df900000033db85ff0f8e870000008be9448bd62bee4103ef4963d24903d38
            07a03007460440fb64a02418d042a4c63d84c035c2470410fb64b02428d0401443bc87f64412bc8443bc97c5c410fb64b014
            40fb64a01428d0401443bc87f49412bc8443bc97c41410fb60b440fb60a428d0401443bc87f30412bc8443bc97c284c8b5c2
            478ffc34183c2043bdf7c8a8b8c24c800000041ffc64503fc03b42498000000e94fffffff8b4424088b8c24c80000004c8b5
            c247803042441ffcd89442408443bac24a80000000f8d17ffffff448b4c24048b44240c41ffc183c10444894c2404898c24c
            8000000443b8c24b00000000f8ccefeffffe991f7ffff488b4c24608b4424048901488b4c246833c0448929e992f7ffff83f
            8070f858d010000448b8c24b000000041ffc944894c2404443b8c24a00000000f8c55f7ffff8b8424b8000000448b8424c00
            00000448ba424900000008bbc2480000000428d0c8d00000000ffc8890424898c24c8000000660f1f440000448be83b8424a
            80000000f8c02010000410fafc4418bd4f7da8954240c8944240833ed448bf833f60f1f8400000000003bac24880000000f8
            d4affffff33db85ff0f8e89000000448bf1448bd6442bf64503f74963d24903d3807a03007460440fb64a02438d04164c63d
            84c035c2470410fb64b02428d0401443bc87f63412bc8443bc97c5b410fb64b01440fb64a01428d0401443bc87f48412bc84
            43bc97c40410fb60b440fb60a428d0401443bc87f2f412bc8443bc97c274c8b5c2478ffc34183c2043bdf7c8a8b8c24c8000
            000ffc54503fc03b42498000000e94fffffff8b4424088b8c24c80000004c8b5c24780344240c41ffcd89442408443bac24a
            80000000f8d17ffffff448b4c24048b042441ffc983e90444894c2404898c24c8000000443b8c24a00000000f8dcefeffffe
            9e1f5ffff83f8080f85ddf5ffff448b8424b000000041ffc84489442404443b8424a00000000f8cbff5ffff8b9424c000000
            0448bac2498000000448ba424900000008bbc2480000000448b8c24a8000000428d0c8500000000898c24c800000044890c2
            4443b8c24b80000000f8d08010000418bc4410fafc18944240833ed448bf833f6660f1f8400000000003bac24880000000f8
            d0501000033db85ff0f8e87000000448bf1448bce442bf64503f74d63c14d03c34180780300745d438d040e4c63d84d03da4
            50fb65002410fb64b028d0411443bd07f5f2bca443bd17c58410fb64b01450fb650018d0411443bd07f462bca443bd17c3f4
            10fb603450fb6108d0c10443bd17f2f2bc2443bd07c284c8b5c24784c8b542470ffc34183c1043bdf7c8c8b8c24c8000000f
            fc54503fc4103f5e955ffffff448b04248b4424088b8c24c80000004c8b5c24784c8b54247041ffc04103c44489042489442
            408443b8424b80000000f8c10ffffff448b442404448b8c24a800000041ffc883e9044489442404898c24c8000000443b842
            4a00000000f8dc6feffffe946f4ffff8b442404488b4c246089018b0424488b4c2468890133c0e945f4ffff
            )"
        if ( A_PtrSize == 8 ) ; x64, after comma
            MCode_ImageSearch := SubStr(MCode_ImageSearch,InStr(MCode_ImageSearch,",")+1)
        else ; x86, before comma
            MCode_ImageSearch := SubStr(MCode_ImageSearch,1,InStr(MCode_ImageSearch,",")-1)
        VarSetCapacity(_ImageSearch, LEN := StrLen(MCode_ImageSearch)//2, 0)
        Loop, %LEN%
            NumPut("0x" . SubStr(MCode_ImageSearch,(2*A_Index)-1,2), _ImageSearch, A_Index-1, "uchar")
        MCode_ImageSearch := ""
        DllCall("VirtualProtect", Ptr,&_ImageSearch, Ptr,VarSetCapacity(_ImageSearch), "uint",0x40, PtrA,0)
    }

    ; Abort if an initial coordinates is located before a final coordinate
    If ( sx2 < sx1 )
        return -3001
    If ( sy2 < sy1 )
        return -3002

    ; Check the search box. "sx2,sy2" will be the last pixel evaluated
    ; as possibly matching with the needle's first pixel. So, we must
    ; avoid going beyond this maximum final coordinate.
    If ( sx2 > (hWidth-nWidth+1) )
        return -3003
    If ( sy2 > (hHeight-nHeight+1) )
        return -3004

    ; Abort if the width or height of the search box is 0
    If ( sx2-sx1 == 0 )
        return -3005
    If ( sy2-sy1 == 0 )
        return -3006

    ; The DllCall parameters are the same for easier C code modification,
    ; even though they aren't all used on the _ImageSearch version
    x := 0, y := 0
    , E := DllCall( &_ImageSearch, "int*",x, "int*",y, Ptr,hScan, Ptr,nScan, "int",nWidth, "int",nHeight
    , "int",hStride, "int",nStride, "int",sx1, "int",sy1, "int",sx2, "int",sy2, "int",Variation
    , "int",sd, "cdecl int")
    Return ( E == "" ? -3007 : E )
}


Gdip_LockedBitsSearchChannel(hStride,hScan,hWidth,hHeight,nStride,nScan,nWidth,nHeight
,ByRef x="",ByRef y="",sx1=0,sy1=0,sx2=0,sy2=0,Variation=0,sd=1, ch=0)
{
    static _ImageSearchCh, Ptr, PtrA

    ; Initialize all MCode stuff, if necessary
    if !( _ImageSearchCh ) {
        Ptr := A_PtrSize ? "UPtr" : "UInt"
        PtrA := Ptr . "*"

        MCode_ImageSearchCh := "
            (LTrim Join			
			5557565383EC248B44246C8B6C24488B7C246883F8010F842F01000083F8020F844B02000083F8030F842C03000083
			F8040F84D905000083F8050F84E006000083F8060F84E803000083F8070F84DE07000083F8080F85FA0100008B44246083E8
			0139442458894424140F8FE50100008B5C24708D14838B44245C0FAF44245001D003442440894424188B4424643944245C0F
			8D130500008B442418894424108B44245C8944240C908DB426000000008B44244C85C07E758B4424108B5C2444C744240800
			000000894424048B4C247031C001D985ED890C247E37908D742600807C83030074248B7424048B0C240FB614860FB60C818D
			343A39F10F8F8F04000029FA39D10F8C8504000083C00139E875CE8344240801035C24548B4424088B742450017424043B44
			244C759F8B4424388B7C241489388B44243C8B7C240C893883C42431C05B5E5F5DC38B4424643944245C0F8DFC0000008B44
			24708B5C24588D14988B44245C0FAF44245001D003442440894424148B442414894424108B4424588944240C8B4424603944
			24580F8DA50000008B44244C85C07E678B4424108B5C2444C7442408000000008904248B4C247031C001D985ED894C24047E
			2A807C830300741C8B7424040FB60C868B34240FB614868D343A39F17F4529FA39D17C3F83C00139E875D68344240801035C
			24548B4424088B4C2450010C243B44244C75AC8B4424388B7C240C89388B44243C8B7C245C893831C083C4245B5E5F5DC383
			44240C0183442410048B44240C3B4424600F855BFFFFFF8344245C018B5C24508B442464015C24143944245C0F8522FFFFFF
			8B442438C700FFFFFFFF8B44243CC700FFFFFFFFB85FF0FFFFEBAA8B44246483E8013944245C894424147FD48B5C24508B74
			24580FAF442450F7DB895C241C8B5C24708D14B301D003442440894424188B442418894424108B4424588944240C8B442460
			394424580F8D650200008B44244C85C07E718B4424108B5C2444C7442408000000008904248B4C247031C001D985ED894C24
			047E346690807C83030074248B34248B4C24040FB614860FB60C818D343A39F10F8FFF01000029FA39D10F8CF501000083C0
			0139E875CE8344240801035C24548B4424088B4C2450010C243B44244C75A28B4424388B7C240C89388B44243C8B7C241489
			3883C42431C05B5E5F5DC38B44246483E8013944245C894424140F8FE6FEFFFF8B7424508B5C24600FAF442450F7DE83EB01
			8974241C8B742470895C24208D149E01D003442440894424188B442418894424108B442420394424588944240C0F8FB40100
			008B44244C85C07E808B4424108B5C2444C7442408000000008904248B74247031C001DE85ED897424047E3390807C830300
			74248B34248B4C24040FB614860FB60C818D343A39F10F8F4F01000029FA39D10F8C4501000083C00139E875CE8344240801
			035C24548B4424088B4C2450010C243B44244C75A3E90BFFFFFF8B442460394424580F8D16FEFFFF8B4424648B5C24708B74
			245883E8018944241C8D14B30FAF44245001D003442440894424188B442450F7D8894424148B44241C3944245C0F8F6F0100
			008B5C24188944240C895C24108B4C244C85C97E6F8B4424108B5C2444C7442408000000008904248B74247031C001DE85ED
			897424047E32807C83030074248B34248B4C24040FB614860FB60C818D343A39F10F8FFC00000029FA39D10F8CF200000083
			C00139E875CE8344240801035C24548B4424088B7424500134243B44244C75A48B4424388B7C2458E929FCFFFF8D74260083
			44240C0183442410048B44240C3B4424600F859BFDFFFF836C2414018B4C241C8B442414014C24183944245C0F8E62FDFFFF
			E90DFDFFFF908DB42600000000836C240C01836C2410048B44240C394424580F8E4CFEFFFF836C2414018B4C241C8B442414
			014C24183944245C0F8E17FEFFFFE9CDFCFFFF908DB426000000008344240C018B4C24508B44240C014C24103B4424640F85
			05FBFFFF836C241401836C2418048B442414394424580F8EC7FAFFFFE98DFCFFFF908DB42600000000836C240C018B4C2414
			8B44240C014C24103944245C0F8E9DFEFFFF834424580183442418048B442460394424580F856BFEFFFFE94DFCFFFF908DB4
			26000000008B4424643944245C0F8D37FCFFFF8B4424608B5C247083E8018D1483894424188B44245C0FAF44245001D00344
			2440894424148B442414894424108B442418394424588944240C0F8F9B0000008D76008B74244C85F60F8E98FBFFFF8B4424
			108B5C2444C7442408000000008904248B4C247031C001D985ED894C24047E2B90807C830300741C8B34248B4C24040FB614
			860FB60C818D343A39F17F3329FA39D17C2D83C00139E875D68344240801035C24548B4424088B7424500134243B44244C75
			ABE92BFBFFFF8DB42600000000836C240C01836C2410048B44240C394424580F8E68FFFFFF8344245C018B5C24508B442464
			015C24143944245C0F8530FFFFFFE93DFBFFFF908DB426000000008B442460394424580F8D27FBFFFF8B4424708B5C24588D
			14988B44245C0FAF44245001D003442440894424148B4424643944245C0F8DB10000008B442414894424108B44245C894424
			0C8DB6000000008B5C244C85DB0F8E83FDFFFF8B4424108B5C2444C744240800000000894424048B74247031C001DE85ED89
			34247E2B90807C830300741C8B7424048B0C240FB614860FB60C818D343A39F17F3329FA39D17C2D83C00139E875D6834424
			0801035C24548B4424088B4C2450014C24043B44244C75ABE915FDFFFF8DB6000000008344240C018B7424508B44240C0174
			24103B4424640F8565FFFFFF834424580183442414048B442460394424580F8529FFFFFFE92DFAFFFF908DB426000000008B
			44246083E80139442458894424140F8F10FAFFFF8B4C24708B5C24648D14818B44245083EB01895C24200FAFC301D0034424
			408944241C8B442450F7D8894424188B4424203944245C0F8FAB0000008B5C241C8944240C895C24108B54244C85D20F8E95
			F8FFFF8B4424108B5C2444C7442408000000008904248B74247031C001DE85ED897424047E2F908D742600807C830300741C
			8B34248B4C24040FB614860FB60C818D343A39F17F3329FA39D17C2D83C00139E875D68344240801035C24548B4424088B4C
			2450010C243B44244C75A7E924F8FFFF8DB42600000000836C240C018B4C24188B44240C014C24103944245C0F8E61FFFFFF
			836C241401836C241C048B442414394424580F8E2FFFFFFFE90DF9FFFF			
            )"
        if ( A_PtrSize == 8 ) ; x64, after comma
            MCode_ImageSearchCh := SubStr(MCode_ImageSearchCh,InStr(MCode_ImageSearchCh,",")+1)
        else ; x86, before comma
            MCode_ImageSearchCh := SubStr(MCode_ImageSearchCh,1,InStr(MCode_ImageSearchCh,",")-1)
        VarSetCapacity(_ImageSearchCh, LEN := StrLen(MCode_ImageSearchCh)//2, 0)
        Loop, %LEN%
            NumPut("0x" . SubStr(MCode_ImageSearchCh,(2*A_Index)-1,2), _ImageSearchCh, A_Index-1, "uchar")
        MCode_ImageSearchCh := ""
        DllCall("VirtualProtect", Ptr,&_ImageSearchCh, Ptr,VarSetCapacity(_ImageSearchCh), "uint",0x40, PtrA,0)
    }

    ; Abort if an initial coordinates is located before a final coordinate
    If ( sx2 < sx1 )
        return -3001
    If ( sy2 < sy1 )
        return -3002

    ; Check the search box. "sx2,sy2" will be the last pixel evaluated
    ; as possibly matching with the needle's first pixel. So, we must
    ; avoid going beyond this maximum final coordinate.
    If ( sx2 > (hWidth-nWidth+1) )
        return -3003
    If ( sy2 > (hHeight-nHeight+1) )
        return -3004

    ; Abort if the width or height of the search box is 0
    If ( sx2-sx1 == 0 )
        return -3005
    If ( sy2-sy1 == 0 )
        return -3006

    ; The DllCall parameters are the same for easier C code modification,
    ; even though they aren't all used on the _ImageSearch version
    x := 0, y := 0
    , E := DllCall( &_ImageSearchCh, "int*",x, "int*",y, Ptr,hScan, Ptr,nScan, "int",nWidth, "int",nHeight
    , "int",hStride, "int",nStride, "int",sx1, "int",sy1, "int",sx2, "int",sy2, "int",Variation
    , "int",sd,"int",ch, "cdecl int")
    Return ( E == "" ? -3007 : E )
}


Gdip_LockedBitsSearchChannelAlpha(hStride,hScan,hWidth,hHeight,nStride,nScan,nWidth,nHeight
,ByRef x="",ByRef y="",sx1=0,sy1=0,sx2=0,sy2=0,Variation=0,sd=1, ch=0)
{
    static _ImageSearchChAlpha, Ptr, PtrA

    ; Initialize all MCode stuff, if necessary
    if !( _ImageSearchChAlpha ) {
        Ptr := A_PtrSize ? "UPtr" : "UInt"
        PtrA := Ptr . "*"

        MCode_ImageSearchChAlpha := "
            (LTrim Join		

			5557565383EC248B44246C8B5424408B6C244883F8010F842C01000083F8020F845B02000083F8030F848203000083
			F8040F841907000083F8050F840006000083F8060F845104000083F8070F840E08000083F8080F850A0200008B44246083E8
			013944245889C7894424140F8FF30100008B44245C0FAF4424508D04B801D0894424188B4424643944245C0F8D4B0500008B
			44241889EF894424108B44245C8944240C8B44244C85C07E7E8B4C24448B6C2410C7442408000000008B5C247031C001CB89
			1C248B5C247001EB85FF895C24047E3E807C8103007430807C85030074298B5424048B1C248B7424680FB614820FB61C8301
			D639F30F8FC00400002B54246839D30F8CB404000083C00139F875C28344240801036C24508B442408034C24543B44244C75
			928B4424388B7C241489388B44243C8B7C240C893883C42431C05B5E5F5DC38B4424643944245C0F8D0F0100008B44245C8B
			7C24580FAF4424508D04B801D0894424148B44241489EF894424108B4424588944240C8B442460394424580F8DBE0000008D
			7426008B44244C85C07E768B4C24448B6C2410C7442408000000008B5C247031C001CB891C248B5C247001EB85FF895C2404
			7E36807C8103007428807C85030074218B7424048B1C240FB614860FB61C838B74246801D639F37F482B54246839D37C4083
			C00139F875CA8344240801036C24508B442408034C24543B44244C759A8B4424388B7C240C89388B44243C8B7C245C893831
			C083C4245B5E5F5DC38D7426008344240C0183442410048B44240C3B4424600F8548FFFFFF89FD8344245C018B7C24508B44
			2464017C24143944245C0F8507FFFFFF8B442438C700FFFFFFFF8B44243CC700FFFFFFFFB85FF0FFFFEBA48B44246483E801
			3944245C894424147FD48B7C24500FAF442450F7DF897C241C8B7C24588D04B801D0894424188B44241889EF894424108B44
			24588944240C8B442460394424580F8DBD0000008D76008B44244C85C07E768B4C24448B6C2410C7442408000000008B5C24
			7031C001CB891C248B5C247001EB85FF895C24047E36807C8103007428807C85030074218B7424048B1C240FB614860FB61C
			838B74246801D639F37F482B54246839D37C4083C00139F875CA8344240801036C24508B442408034C24543B44244C759A8B
			4424388B7C240C89388B44243C8B7C2414893883C42431C05B5E5F5DC38D7426008344240C0183442410048B44240C3B4424
			600F8548FFFFFF89FD836C2414018B4C241C8B442414014C24183944245C0F8E08FFFFFFE9BBFEFFFF8DB6000000008B4424
			6483E8013944245C894424140F8FA0FEFFFF0FAF4424508B7C24608B4C245083EF01F7D9897C2420894C241C8D04B801D089
			4424188B44241889EF894424108B442420394424588944240C0F8F980100008B6C244C85ED0F8E3EFFFFFF8B4C24448B6C24
			10C7442408000000008B5C247031C001CB891C248B5C247001EB85FF895C24047E458DB42600000000807C8103007430807C
			85030074298B5424048B1C248B7424680FB614820FB61C8301D639F30F8F170100002B54246839D30F8C0B01000083C00139
			F875C28344240801036C24508B442408034C24543B44244C758BE9B4FEFFFF8B442460394424580F8DBDFDFFFF8B4424648B
			7C245883E8018944241C0FAF4424508D04B801D0894424188B442450F7D8894424148B44241C3944245C0F8F400100008B7C
			24188944240C897C241089EF8B4C244C85C90F8E7E0000008B4C24448B6C2410C7442408000000008B7424708B5C247031C0
			01CE01EB85FF893424895C24047E3E807C8103007430807C85030074298B5424048B1C248B7424680FB614820FB61C8301D6
			39F30F8FB50000002B54246839D30F8CA900000083C00139F875C28344240801036C24508B442408034C24543B44244C7592
			8B4424388B7C2458E9B0FBFFFF836C240C01836C2410048B44240C394424580F8E6AFEFFFF89FD836C2414018B4C241C8B44
			2414014C24183944245C0F8E31FEFFFFE9A9FCFFFF8D7426008344240C018B7424508B44240C017424103B4424640F85C9FA
			FFFF89FD836C241401836C2418048B442414394424580F8E8FFAFFFFE96BFCFFFF8DB600000000836C240C018B5C24148B44
			240C015C24103944245C0F8ED0FEFFFF89FD834424580183442418048B442460394424580F859AFEFFFFE92BFCFFFF8DB600
			0000008B442460394424580F8D17FCFFFF8B44245C8B7C24580FAF4424508D04B801D0894424148B4424643944245C0F8DBD
			0000008B44241489EF894424108B44245C8944240C8B5C244C85DB0F8EE5FEFFFF8B4C24448B6C2410C7442408000000008B
			5C247031C001CB891C248B5C247001EB85FF895C24047E3D8DB42600000000807C8103007428807C85030074218B5424048B
			1C248B7424680FB614820FB61C8301D639F37F2B2B54246839D37C2383C00139F875CA8344240801036C24508B442408034C
			24543B44244C7593E963FEFFFF8344240C018B5424508B44240C015424103B4424640F8557FFFFFF89FD8344245801834424
			14048B442460394424580F851DFFFFFFE919FBFFFF8D7426008B4424643944245C0F8D07FBFFFF8B44246083E80189C78944
			24188B44245C0FAF4424508D04B801D0894424148B44241489EF894424108B442418394424588944240C0F8FA30000008B74
			244C85F60F8E69FAFFFF8B4C24448B6C2410C7442408000000008B5C247031C001CB891C248B5C247001EB85FF895C24047E
			386690807C8103007428807C85030074218B5424048B1C248B7424680FB614820FB61C8301D639F37F2B2B54246839D37C23
			83C00139F875CA8344240801036C24508B442408034C24543B44244C7598E9ECF9FFFF836C240C01836C2410048B44240C39
			4424580F8E5FFFFFFF89FD8344245C018B7C24508B442464017C24143944245C0F8526FFFFFFE909FAFFFF8D7426008B4424
			6083E8013944245889C7894424100F8FEEF9FFFF8B44246483E801894424200FAF4424508D04B801D0894424188B442450F7
			D88944241C8B4424203944245C0F8FC50000008B7C24188944240C897C241489EF8B54244C85D27E7F8B4C24448B6C2414C7
			442408000000008B7424708B5C247031C001CE01EB85FF893424895C24047E3F89F68DBC2700000000807C8103007428807C
			85030074218B5424048B1C248B7424680FB614820FB61C8301D639F37F392B54246839D37C3183C00139F875CA8344240801
			036C24508B442408034C24543B44244C75918B4424388B7C2410E9E8F7FFFF8DB600000000836C240C018B74241C8B44240C
			017424143944245C0F8E4BFFFFFF89FD836C241001836C2418048B442410394424580F8E15FFFFFFE9DBF8FFFF
            )"
        if ( A_PtrSize == 8 ) ; x64, after comma
            MCode_ImageSearchChAlpha := SubStr(MCode_ImageSearchChAlpha,InStr(MCode_ImageSearchChAlpha,",")+1)
        else ; x86, before comma
            MCode_ImageSearchChAlpha := SubStr(MCode_ImageSearchChAlpha,1,InStr(MCode_ImageSearchChAlpha,",")-1)
        VarSetCapacity(_ImageSearchChAlpha, LEN := StrLen(MCode_ImageSearchChAlpha)//2, 0)
        Loop, %LEN%
            NumPut("0x" . SubStr(MCode_ImageSearchChAlpha,(2*A_Index)-1,2), _ImageSearchChAlpha, A_Index-1, "uchar")
        MCode_ImageSearchChAlpha := ""
        DllCall("VirtualProtect", Ptr,&_ImageSearchChAlpha, Ptr,VarSetCapacity(_ImageSearchChAlpha), "uint",0x40, PtrA,0)
    }

    ; Abort if an initial coordinates is located before a final coordinate
    If ( sx2 < sx1 )
        return -3001
    If ( sy2 < sy1 )
        return -3002

    ; Check the search box. "sx2,sy2" will be the last pixel evaluated
    ; as possibly matching with the needle's first pixel. So, we must
    ; avoid going beyond this maximum final coordinate.
    If ( sx2 > (hWidth-nWidth+1) )
        return -3003
    If ( sy2 > (hHeight-nHeight+1) )
        return -3004

    ; Abort if the width or height of the search box is 0
    If ( sx2-sx1 == 0 )
        return -3005
    If ( sy2-sy1 == 0 )
        return -3006

    ; The DllCall parameters are the same for easier C code modification,
    ; even though they aren't all used on the _ImageSearch version
    x := 0, y := 0
    , E := DllCall( &_ImageSearchChAlpha, "int*",x, "int*",y, Ptr,hScan, Ptr,nScan, "int",nWidth, "int",nHeight
    , "int",hStride, "int",nStride, "int",sx1, "int",sy1, "int",sx2, "int",sy2, "int",Variation
    , "int",sd,"int",ch, "cdecl int")
    Return ( E == "" ? -3007 : E )
}