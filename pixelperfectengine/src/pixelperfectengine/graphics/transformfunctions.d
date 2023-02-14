/*
 * Copyright (C) 2015-2018, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.transformFunctions module
 */

module pixelperfectengine.graphics.transformfunctions;

package static immutable uint[4] maskAC = [0, uint.max, 0, uint.max];

import pixelperfectengine.system.platform;

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
	static if (USE_INTEL_INTRINSICS) {
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
		result = _mm_madd_epi16(cast(__m128i)xy_, cast(__m128i)ABCD_);
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