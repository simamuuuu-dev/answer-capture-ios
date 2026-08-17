import Foundation

public enum SlatePayloadFactory {
    public static func live(problemId: String?, strokes: [SlateStroke], deviceId: String?, captureSequence: Int64, settings: SlateGestureSettings = .init()) -> SlatePayload {
        make(problemId: problemId, pageId: "live-\(max(0,captureSequence))", deviceId: deviceId, sequence: captureSequence, strokes: strokes, settings: settings, mode: "live", stored: nil, triggerIfAccepted: "live_mode")
    }
    public static func stored(problemId: String?, page: SlateStoredPage, deviceId: String?, captureSequence: Int64, settings: SlateGestureSettings = .init(orientation: .buttonRight)) -> SlatePayload {
        let meta=SlatePayload.StoredPageMeta(byteCount:page.byteCount,magicOk:page.magicOK,strokeCount:page.strokes.count,pointCount:page.pointCount)
        return make(problemId:problemId,pageId:page.pageId,deviceId:deviceId,sequence:captureSequence,strokes:page.strokes,settings:settings,mode:nil,stored:meta,triggerIfAccepted:"stored_page_button_sync")
    }
    private static func make(problemId:String?,pageId:String,deviceId:String?,sequence:Int64,strokes:[SlateStroke],settings:SlateGestureSettings,mode:String?,stored:SlatePayload.StoredPageMeta?,triggerIfAccepted:String)->SlatePayload {
        let pid = problemId?.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty == false ? problemId!.trimmingCharacters(in:.whitespacesAndNewlines) : "YC-1A-01-EX-003"
        let detection=SlateGestureRecognizer.detect(strokes,settings:settings); let command=Set(detection.commandStrokeIds); let ps=strokes.map{ s in SlatePayload.SlatePayloadStroke(strokeId:s.strokeId,startedAtMs:s.startedAtMs,endedAtMs:s.endedAtMs,role:command.contains(s.strokeId) ? "command":"answer",commandType:command.contains(s.strokeId) ? "finalize_capture_ocr":nil,excludedFromAnswer:command.contains(s.strokeId),points:s.points.map{.init(x:Int($0.x.rounded()),y:Int($0.y.rounded()),t:$0.tMs,pressure:max(0,min(1,$0.pressure)))}) }
        return SlatePayload(problemId:pid,pageId:pageId,deviceId:deviceId?.isEmpty == false ? deviceId! : "bamboo-slate-mizuki",draftId:"SLATE-\(pid)-mizuki",captureSequence:sequence,createdAt:WireCoding.format(Date(timeIntervalSince1970:Double(sequence)/1000)),slateOrientation:settings.orientation,paperSize:.init(widthMm:settings.pageWidthMm,heightMm:settings.pageHeightMm),coordinateSpace:.init(width:settings.sourceWidth,height:settings.sourceHeight),androidCaptureMode:mode,clientPlatform:"ios",storedPage:stored,androidCommandDetection:.init(accepted:detection.accepted,kind:detection.kind,reason:detection.reason,commandStrokeIds:detection.commandStrokeIds),trigger:detection.accepted ? "bottom_right_corner_gesture":triggerIfAccepted,commandType:detection.accepted ? "finalize_capture_ocr":"",strokes:ps)
    }
}
