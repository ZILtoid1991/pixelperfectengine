/*
 * Copyright (C) 2015-2018, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.transformFunctions module
 */

module PixelPerfectEngine.graphics.transformFunctions;

package static immutable uint[4] maskAC = [0, uint.max, 0, uint.max];

import PixelPerfectEngine.system.platform;

static if(USE_INTEL_INTRINSICS) import inteli.emmintrin;


/**
 * Main transform function with fixed point aritmetics. Returns the point where the pixel is needed to be read from.
 * 256 equals with 1.
 * The function reads as:
 * [x',y'] = ([A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0]))>>>8 + [x_0,y_0]
 * ABCD: 
 * A/0: Horizontal scaling. 256 means no scaling at all, negative values end up in a mirrored image.
 * B/1: Horizontal shearing. 0 means no shearing at all.
 * C/2: Vertical shearing. 0 means no shearing at all.
 * D/3: Vertical scaling. 256 means no scaling at all, negative values end up in a mirrored image.
 * </ br>
 * xy:
 * Contains the screen coordinates. x:0 y:1
 * </ br>
 * x0y0:
 * Origin point. x_0:0/2 y_0:1/3
 * </ br>
 * sXsY:
 * Scrolling point. sX:0/2 sY:1/3
 */
public @nogc int[2] transformFunctionInt(short[2] xy, short[4] ABCD, short[2] x0y0, short[2] sXsY) pure nothrow @trusted {
//public @nogc int[2] transformFunctionInt(short[4] xy, short[4] ABCD, short[4] x0y0, short[4] sXsY){
	version(DMD){
		int[2] result;
		void subfunc() pure nothrow @nogc @system {
			asm @nogc pure nothrow{
				movd	XMM0, xy;//load XY values twice
				pslldq	XMM0, 4;
				movd	XMM2, xy;
				por		XMM0, XMM2;
				movd	XMM1, sXsY;//load SxSy values twice
				pslldq	XMM1, 4;
				movd	XMM2, sXsY;
				por		XMM1, XMM2;
				paddw	XMM0, XMM1;//[x,y] + [sX,sY]
				movd	XMM1, x0y0;//load x0y0 values twice
				pslldq	XMM1, 4;
				movd	XMM2, x0y0;
				por		XMM1, XMM2;
				psubw	XMM0, XMM1;//([x,y] + [sX,sY] - [x_0,y_0])
				movq	XMM2, ABCD;//load ABCD into XMM2
				pmaddwd	XMM2, XMM0;//([A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0]))
				psrad	XMM2, 8;//divide by 256 ([A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0]))>>>8
				movq	result, XMM2;
			}
		}
		
		return [result[0] + x0y0[0], result[1] + x0y0[1]];
	} else static if (USE_INTEL_INTRINSICS) {
		__m128i result;
		short8 xy_, sXsY_, x0y0_, ABCD_;
		xy_[0] = xy[0];
		xy_[1] = xy[1];
		xy_[2] = xy[0];
		xy_[3] = xy[1];
		sXsY_[0] = sXsY[0];
		sXsY_[1] = sXsY[1];
		sXsY_[2] = sXsY[0];
		sXsY_[3] = sXsY[1];
		x0y0_[0] = x0y0[0];
		x0y0_[1] = x0y0[1];
		x0y0_[2] = x0y0[0];
		x0y0_[3] = x0y0[1];
		ABCD_[0] = ABCD[0];
		ABCD_[1] = ABCD[1];
		ABCD_[2] = ABCD[2];
		ABCD_[3] = ABCD[3];
		xy_ += sXsY_;
		xy_ -= x0y0_;
		result = _mm_madd_epi16(xy_, ABCD_);
		return [result[0] + x0y0[0], result[1] + x0y0[1]];
	} else {
		int[2] result;
		int[2] nXnY = [xy[0] + sXsY[0] - x0y0[0],  xy[1] + sXsY[1] - x0y0[1]];
		result[0] = ((ABCD[0] * nXnY[0] + ABCD[1] * nXnY[1])>>>8) + x0y0[0];
		result[1] = ((ABCD[2] * nXnY[0] + ABCD[3] * nXnY[1])>>>8) + x0y0[1];
		return result;
	}
}
/**
 * Relative rotation clockwise by given degrees. Returns the new transform points.
 * </ br>
 * theta:
 * Degrees of clockwise rotation.
 * </ br>
 * input:
 * Input of the transform points at 0 degrees.
 */
public @nogc short[4] rotateFunction(double theta, short[4] input = [256,256,256,256]){
	import std.math;
	short[4] transformPoints;
	theta *= PI / 180;
	transformPoints[0] = cast(short)(input[0] * cos(theta));
	transformPoints[1] = cast(short)(input[1] * sin(theta));
	transformPoints[2] = cast(short)(input[2] * sin(theta) * -1);
	transformPoints[3] = cast(short)(input[3] * cos(theta));
	return transformPoints;
}
/**
 * Main transform function, returns the point where the pixel is needed to be read from.
 * The function reads as:
 * [x',y'] = [A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0]) + [x_0,y_0]
 * ABCD: 
 * A/0: Horizontal scaling. 1 means no scaling at all, negative values end up in a mirrored image.
 * B/1: Horizontal shearing. 0 means no shearing at all.
 * C/2: Vertical shearing. 0 means no shearing at all.
 * D/3: Vertical scaling. 1 means no scaling at all, negative values end up in a mirrored image.
 * </ br>
 * xy:
 * Contains the screen coordinates. x:0 y:1
 * </ br>
 * x0y0:
 * Origin point. x_0:0/2 y_0:1/3
 * </ br>
 * sXsY:
 * Scrolling point. sX:0/2 sY:1/3
 */
public @nogc int[2] transformFunctionFP(int[2] xy, float[4] ABCD, float[4] x0y0, int[4] sXsY){
	version(X86){
		int[2] result;
		asm @nogc{
			movq		XMM7, xy;
			cvtdq2ps	XMM0, XMM7;	// ---- ---- yyyy xxxx
			movups		XMM1, XMM0;	// ---- ---- YYYY XXXX
			pslldq		XMM1, 8;	// YYYY XXXX ---- ----
			por			XMM0, XMM1; // YYYY XXXX yyyy xxxx
			movups		XMM7, sXsY;
			cvtdq2ps	XMM1, XMM7;
			addps		XMM0, XMM1; // [x,y] + [sX,sY]
			movups		XMM6, x0y0;
			subps		XMM0, XMM6;	// [x,y] + [sX,sY] - [x_0,y_0]
			movups		XMM2, ABCD;	// dddd cccc bbbb aaaa
			mulps		XMM2, XMM0;	//[A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0])
			movups		XMM3, XMM2; // DDDD CCCC BBBB AAAA
			psrldq		XMM3, 4;	// ---- DDDD CCCC BBBB
			pand		XMM2, maskAC;	// ---- CCCC ---- AAAA
			pand		XMM3, maskAC;	// ---- DDDD ---- BBBB
			addps		XMM2, XMM3;	// ---- c+d ---- a+b
			movups		XMM3, XMM2; // ---- C+D ---- A+B
			psrldq		XMM3, 4;	// ---- ---- C+D ----
			por			XMM2, XMM3; // ---- c+d C+D A+B
			addps		XMM2, XMM6; // [A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0]) + [x_0,y_0]
			cvttps2dq	XMM7, XMM2;
			movq		result, XMM7;
		}
		return result;
	}else version(X86_64){
		int[2] result;
		asm @nogc{
			movq		XMM7, xy;
			cvtdq2ps	XMM0, XMM7;	// ---- ---- yyyy xxxx
			movups		XMM1, XMM0;	// ---- ---- YYYY XXXX
			pslldq		XMM1, 8;	// YYYY XXXX ---- ----
			por			XMM0, XMM1; // YYYY XXXX yyyy xxxx
			movups		XMM7, sXsY;
			cvtdq2ps	XMM1, XMM7;
			addps		XMM0, XMM1; // [x,y] + [sX,sY]
			movups		XMM6, x0y0;
			subps		XMM0, XMM6;	// [x,y] + [sX,sY] - [x_0,y_0]
			movups		XMM2, ABCD;	// dddd cccc bbbb aaaa
			mulps		XMM2, XMM0;	//[A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0])
			movups		XMM3, XMM2; // DDDD CCCC BBBB AAAA
			psrldq		XMM3, 4;	// ---- DDDD CCCC BBBB
			pand		XMM2, maskAC;	// ---- CCCC ---- AAAA
			pand		XMM3, maskAC;	// ---- DDDD ---- BBBB
			addps		XMM2, XMM3;	// ---- c+d ---- a+b
			movups		XMM3, XMM2; // ---- C+D ---- A+B
			psrldq		XMM3, 4;	// ---- ---- C+D ----
			por			XMM2, XMM3; // ---- c+d C+D A+B
			addps		XMM2, XMM6; // [A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0]) + [x_0,y_0]
			cvttps2dq	XMM7, XMM2;
			movq		result, XMM7;
		}
		return result;
	}else{
			
	}
}
/**
 * Reverse transform function, returns the point where a given texel needs to be written.
 * The function reads as:
 * [x',y'] = [A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0]) + [x_0,y_0]
 * ABCD: 
 * A/0: Horizontal scaling. 1 means no scaling at all, negative values end up in a mirrored image.
 * B/1: Horizontal shearing. 0 means no shearing at all.
 * C/2: Vertical shearing. 0 means no shearing at all.
 * D/3: Vertical scaling. 1 means no scaling at all, negative values end up in a mirrored image.
 * </ br>
 * xy:
 * Contains the screen coordinates. x:0 y:1
 * </ br>
 * x0y0:
 * Origin point. x_0:0/2 y_0:1/3
 * </ br>
 * sXsY:
 * Scrolling point. sX:0/2 sY:1/3
 */
public @nogc int[2] reverseTransformFunctionFP(int[2] xy, float[4] ABCD, int[4] x0y0, float[4] sXsY){
	version(X86){
		int[2] result;
		asm @nogc{
			movq		XMM7, xy;
			cvtdq2ps	XMM0, XMM7;	// ---- ---- yyyy xxxx
			movups		XMM1, XMM0;	// ---- ---- YYYY XXXX
			pslldq		XMM1, 8;	// YYYY XXXX ---- ----
			por			XMM0, XMM1; // YYYY XXXX yyyy xxxx
			movups		XMM7, sXsY;
			cvtdq2ps	XMM1, XMM7;
			subps		XMM0, XMM1; // [x,y] - [sX,sY]
			movups		XMM6, x0y0;
			addps		XMM0, XMM6;	// [x,y] - [sX,sY] + [x_0,y_0]
			movups		XMM2, ABCD;	// dddd cccc bbbb aaaa
			divps		XMM2, XMM0;	//[A,B,C,D] / ([x,y] - [sX,sY] + [x_0,y_0])
			movups		XMM3, XMM2; // DDDD CCCC BBBB AAAA
			psrldq		XMM3, 4;	// ---- DDDD CCCC BBBB
			pand		XMM2, maskAC;	// ---- CCCC ---- AAAA
			pand		XMM3, maskAC;	// ---- DDDD ---- BBBB
			addps		XMM2, XMM3;	// ---- c+d ---- a+b
			movups		XMM3, XMM2; // ---- C+D ---- A+B
			psrldq		XMM3, 4;	// ---- ---- C+D ----
			por			XMM2, XMM3; // ---- c+d C+D A+B
			subps		XMM2, XMM6; // [A,B,C,D] / ([x,y] - [sX,sY] + [x_0,y_0]) - [x_0,y_0]
			cvttps2dq	XMM7, XMM2;
			movq		result, XMM7;
		}
		return result;
	}else version(X86_64){
		int[2] result;
		asm @nogc{
			movq		XMM7, xy;
			cvtdq2ps	XMM0, XMM7;	// ---- ---- yyyy xxxx
			movups		XMM1, XMM0;	// ---- ---- YYYY XXXX
			pslldq		XMM1, 8;	// YYYY XXXX ---- ----
			por			XMM0, XMM1; // YYYY XXXX yyyy xxxx
			movups		XMM7, sXsY;
			cvtdq2ps	XMM1, XMM7;
			subps		XMM0, XMM1; // [x,y] - [sX,sY]
			movups		XMM6, x0y0;
			addps		XMM0, XMM6;	// [x,y] - [sX,sY] + [x_0,y_0]
			movups		XMM2, ABCD;	// dddd cccc bbbb aaaa
			divps		XMM2, XMM0;	//[A,B,C,D] / ([x,y] - [sX,sY] + [x_0,y_0])
			movups		XMM3, XMM2; // DDDD CCCC BBBB AAAA
			psrldq		XMM3, 4;	// ---- DDDD CCCC BBBB
			pand		XMM2, maskAC;	// ---- CCCC ---- AAAA
			pand		XMM3, maskAC;	// ---- DDDD ---- BBBB
			addps		XMM2, XMM3;	// ---- c+d ---- a+b
			movups		XMM3, XMM2; // ---- C+D ---- A+B
			psrldq		XMM3, 4;	// ---- ---- C+D ----
			por			XMM2, XMM3; // ---- c+d C+D A+B
			subps		XMM2, XMM6; // [A,B,C,D] / ([x,y] - [sX,sY] + [x_0,y_0]) - [x_0,y_0]
			cvttps2dq	XMM7, XMM2;
			movq		result, XMM7;
		}
		return result;
	}else{
			
	}
}