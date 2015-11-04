/**
 * Created by Mallory on 9/18/15.
 */
package svgeditor.tools {
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.BitmapData;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.ui.Mouse;
import flash.utils.ByteArray;

import grabcut.CModule;
import scratch.ScratchCostume;

import svgeditor.ImageCanvas;

import svgeditor.ImageEdit;
import svgeditor.objs.SegmentationState;

import uiwidgets.EditableLabel;

import util.Base64Encoder;

public class BitmapBackgroundTool extends BitmapPencilTool{


	static public const GOTMASK:String='got_mask';

	static private const SCALE_FACTOR:Number = .5;
	static private var startedAsync:Boolean = false;

	private var segmentationRequired:Boolean = false;
	private var unmarkedBitmap:BitmapData = null;
	private var workingBitmap:BitmapData;

	private function get isObjectMode():Boolean{
		return editor.targetCostume.segmentationState.mode == 'object';
	}

	private function get isGreyscale():Boolean{
		if(!editor) return false;
		return editor.targetCostume.segmentationState.isGreyscale;
	}

	private function set isGreyscale(val:Boolean):void{
		if(editor){
			editor.targetCostume.segmentationState.isGreyscale = val;
		}
	}

	private function get lastMask():ByteArray{
		return editor.targetCostume.segmentationState.lastMask;
	}

	private function set lastMask(val:ByteArray):void{
		editor.targetCostume.segmentationState.lastMask = val;
	}

	private function get scribbleBitmap():BitmapData{
		return editor.targetCostume.segmentationState.scribbleBitmap;
	}

	private function set scribbleBitmap(val:BitmapData):void{
		editor.targetCostume.segmentationState.scribbleBitmap = val;
	}

	private function get xMin():int{
		return editor.targetCostume.segmentationState.xMin;
	}

	private function set xMin(val:int):void{
		editor.targetCostume.segmentationState.xMin = val;
	}

	private function get xMax():int{
		return editor.targetCostume.segmentationState.xMax;
	}

	private function set xMax(val:int):void{
		editor.targetCostume.segmentationState.xMax = val;
	}

	private function get yMin():int{
		return editor.targetCostume.segmentationState.yMin;
	}

	private function set yMin(val:int):void{
		editor.targetCostume.segmentationState.yMin = val;
	}

	private function get yMax():int{
		return editor.targetCostume.segmentationState.yMax;
	}

	private function set yMax(val:int):void{
		editor.targetCostume.segmentationState.yMax = val;
	}

	public function BitmapBackgroundTool(editor:ImageEdit){
		if(!startedAsync){
			CModule.startAsync();
			startedAsync=true;
		}
		super(editor, false)
	}

	public function loadState():void{
		workingBitmap = editor.getWorkArea().getBitmap().bitmapData;
        if(xMin < 0){
            xMin = editor.getWorkArea().width;
        }
        if(yMin < 0){
            yMin - editor.getWorkArea().height;
        }
		unmarkedBitmap = workingBitmap.clone();
		if(isGreyscale){
			setGreyscale();
		}
		else if(scribbleBitmap){
			workingBitmap.draw(scribbleBitmap);
		}
		else{
			scribbleBitmap = new BitmapData(workingBitmap.width, workingBitmap.height, true, 0x00000000);
		}
	}

	override protected function mouseUp(evt:MouseEvent):void{
		if(lastPoint && segmentationRequired && !isObjectMode){
			getObjectMask();
			segmentationRequired = false;
		}
		resetBrushes();
	}

	override protected function set lastPoint(p:Point):void{
		if(p != null){
			if(p.x > xMax){
				xMax = p.x
			}
			if(p.y > yMax){
				yMax = p.y
			}
			if(p.x < xMin){
				xMin = p.x
			}
			if(p.y < yMin){
				yMin = p.y
			}
			if(!isObjectMode){
				segmentationRequired = true;
			}
		}
		super.lastPoint = p;
	}

	override protected function drawAtPoint(p:Point, targetCanvas:BitmapData=null):void{
		targetCanvas = targetCanvas || scribbleBitmap;
		super.drawAtPoint(p, targetCanvas);
		super.drawAtPoint(p);
	}

	private function applyPreviewMask(maskBytes:ByteArray):ByteArray{
		var workingBytes:ByteArray = unmarkedBitmap.clone().getPixels(unmarkedBitmap.rect);
		for(var i:int = 0; i<workingBytes.length/4; i++){
			var pxID:int = i * 4;
			if(maskBytes[pxID] == 0){
				var average:int = (workingBytes[pxID+1] + workingBytes[pxID+2]+workingBytes[pxID+3])/3
				workingBytes[pxID] = Math.min(workingBytes[pxID], 150);
				workingBytes[pxID + 1] = average;
				workingBytes[pxID + 2] = average;
				workingBytes[pxID + 3] = average;
			}
			else{
				workingBytes[pxID + 1] = Math.min(255, workingBytes[pxID + 1] + 100);
			}
		}
		workingBytes.position = 0;
		return workingBytes;
	}

	private function applyMask(maskBytes:ByteArray):ByteArray{
		var workingBytes:ByteArray = unmarkedBitmap.clone().getPixels(unmarkedBitmap.rect);
		for(var i:int = 0; i<workingBytes.length/4; i++){
			var pxID:int = i * 4;
			if(maskBytes[pxID] == 0){
				workingBytes[pxID] = 0;
			}
		}
		workingBytes.position = 0;
		return workingBytes;
	}

	private function cropAndScale(targetBitmap:BitmapData):BitmapData{
		var cropRect:Rectangle = new Rectangle(cropX(), cropY(), cropWidth(), cropHeight());
		var croppedData:ByteArray = targetBitmap.getPixels(cropRect);
		croppedData.position = 0;
		var croppedBitmap:BitmapData = new BitmapData(cropWidth(), cropHeight(), true, 0x00ffffff);
		croppedBitmap.setPixels(croppedBitmap.rect, croppedData);
		var scaledBitmap:BitmapData = new BitmapData(croppedBitmap.width * .5, croppedBitmap.height * .5, true, 0x00ffffff);
		var m:Matrix = new Matrix();
		m.scale(SCALE_FACTOR, SCALE_FACTOR);
		scaledBitmap.draw(croppedBitmap, m);
		return scaledBitmap;
	}

	private function cropWidth():int{
		return cropX() + (xMax - xMin) + 10 < unmarkedBitmap.width ? (xMax - xMin) + 10 : unmarkedBitmap.width - xMin;
	}

	private function cropHeight():int{
		return cropY() + (yMax - yMin) + 10 < unmarkedBitmap.height ? (yMax - yMin) + 10 : unmarkedBitmap.height - yMin;
	}

	private function cropX():int{
		return Math.max(xMin - 10, 0);
	}

	private function cropY():int{
		return Math.max(yMin - 10, 0);
	}

	private function getObjectMask():void {
		var scaledWorkingBM:BitmapData = cropAndScale(unmarkedBitmap);
		var workingData:ByteArray= scaledWorkingBM.getPixels(scaledWorkingBM.rect);
		var args:Vector.<int> = new Vector.<int>();
		var imgPtr:int = CModule.malloc(workingData.length);
		workingData.position = 0;
		argbToRgba(workingData);
		CModule.writeBytes(imgPtr, workingData.length, workingData);
		var scribblePtr:int = CModule.malloc(workingData.length);
		var scaledScribbleBM:BitmapData = cropAndScale(scribbleBitmap);
		var scribbleData:ByteArray = scaledScribbleBM.getPixels(scaledScribbleBM.rect);
		scribbleData.position = 0;
		argbToRgba(scribbleData);
		CModule.writeBytes(scribblePtr, scribbleData.length, scribbleData);
	    args.push(imgPtr, scribblePtr, scaledWorkingBM.height, scaledWorkingBM.width, 1)
		var func:int = CModule.getPublicSymbol("grabCut")
		var result:int = CModule.callI(func, args);
		didGetObjectMask(result, imgPtr, workingData.length, scaledWorkingBM.width, scaledWorkingBM.height);
		CModule.free(imgPtr);
		CModule.free(scribblePtr);
	}

	private function argbToRgba(argbBytes:ByteArray):void{
		for(var i:int =0 ; i < argbBytes.length/4; i++){
			//RGBA to ARGB
			var pxID:int = i * 4;
			var alpha:int = argbBytes[pxID];
			var red:int = argbBytes[pxID + 1];
			var green:int = argbBytes[pxID + 2];
			var blue:int = argbBytes[pxID + 3];
			argbBytes[pxID] = red;
			argbBytes[pxID + 1] = green;
			argbBytes[pxID + 2] = blue;
			argbBytes[pxID + 3] = alpha;
		}

	}

	private function rgbaToArgb(rgbaBytes:ByteArray):void{
		for(var i:int =0 ; i < rgbaBytes.length/4; i++){
			//RGBA to ARGB
			var pxID:int = i * 4;
			var red:int = rgbaBytes[pxID];
			var green:int = rgbaBytes[pxID + 1];
			var blue:int = rgbaBytes[pxID + 2];
			var alpha:int = rgbaBytes[pxID + 3];
			rgbaBytes[pxID] = alpha;
			rgbaBytes[pxID + 1] = red;
			rgbaBytes[pxID + 2] = green;
			rgbaBytes[pxID + 3] = blue;
		}

	}



	private function didGetObjectMask(retVal:*, imgPtr:int, imgLength:int, width:int, height:int):void {
		var bmData:ByteArray= new ByteArray();
		CModule.readBytes(imgPtr, imgLength, bmData);
		bmData.position=0;
		rgbaToArgb(bmData);
		var scaledMaskBitmap:BitmapData = new BitmapData(width, height, true, 0x00ffffff);
		scaledMaskBitmap.setPixels(scaledMaskBitmap.rect, bmData);
		var m:Matrix = new Matrix();
		m.scale(1./SCALE_FACTOR,1./SCALE_FACTOR);
		m.tx = cropX();
		m.ty = cropY();
		var maskBitmap:BitmapData = new BitmapData(workingBitmap.width, workingBitmap.height, true, 0x00ffffff);
		maskBitmap.draw(scaledMaskBitmap, m);
		bmData.position = 0;
		lastMask = maskBitmap.getPixels(maskBitmap.rect);
		setGreyscale();
		dispatchEvent(new Event(BitmapBackgroundTool.GOTMASK));
	}

	public function refreshGreyscale():void{
		if(!lastMask) return;
		if(isGreyscale) {
			setFullColor();
		}
		else{
			setGreyscale();
		}
	}

	private function setFullColor():void{
		workingBitmap.fillRect(workingBitmap.rect, 0x00ffffff);
		workingBitmap.draw(unmarkedBitmap);
		workingBitmap.draw(scribbleBitmap);
		isGreyscale = false;
	}

	private function setGreyscale():void{
		workingBitmap.setPixels(workingBitmap.rect, applyPreviewMask(lastMask));
		isGreyscale = true;
	}

	public function restoreUnmarked():void{
		if(unmarkedBitmap){
			var unmarkedBytes:ByteArray = unmarkedBitmap.getPixels(unmarkedBitmap.rect);
			unmarkedBytes.position = 0;
			workingBitmap.setPixels(workingBitmap.rect, unmarkedBytes);
		}
	}

	public function commitMask():void{
		if(lastMask) {
			workingBitmap.setPixels(workingBitmap.rect, applyMask(lastMask));
			scribbleBitmap.fillRect(scribbleBitmap.rect, 0x00000000);
			unmarkedBitmap = workingBitmap.clone();
			lastMask = null;
			isGreyscale = false;
			editor.saveContent();
		}
	}

	public function extractState():SegmentationState{
		var state:SegmentationState = new SegmentationState();
		state.isGreyscale = isGreyscale;
		state.lastMask = lastMask;
		state.scribbleBitmap = scribbleBitmap;
		state.mode = editor.targetCostume.segmentationState.mode;
		return state;
	}
}
}
