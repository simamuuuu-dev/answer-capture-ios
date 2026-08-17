import Foundation

public enum SlateGestureRecognizer {
    public static func normalize(_ point: SlatePoint, settings: SlateGestureSettings) -> SlatePoint {
        var x = min(1,max(0, point.x <= 1 ? point.x : point.x/settings.sourceWidth)); var y=min(1,max(0,point.y <= 1 ? point.y : point.y/settings.sourceHeight))
        switch settings.orientation { case .buttonTop: break; case .buttonBottom: x=1-x;y=1-y; case .buttonLeft: (x,y)=(y,1-x); case .buttonRight: (x,y)=(1-y,x) }
        return SlatePoint(x:x,y:y,tMs:point.tMs,pressure:point.pressure)
    }
    public static func detect(_ raw: [SlateStroke], settings: SlateGestureSettings = .init()) -> SlateDetection {
        let strokes=raw.map { SlateStroke(strokeId:$0.strokeId,points:$0.points.map{normalize($0,settings:settings)},startedAtMs:$0.startedAtMs,endedAtMs:$0.endedAtMs) }.filter{!$0.points.isEmpty}; guard !strokes.isEmpty else{return .init(accepted:false,kind:"",reason:"no_strokes",commandStrokeIds:[])}; let last=strokes[strokes.count-1]
        if one(last,settings) { return acceptedIfAnswerExists(strokes, kind:"one_stroke_l", commandStrokeIds:[last.strokeId]) }
        if strokes.count >= 2 { let v=strokes[strokes.count-2], h=last; if two(v,h,settings) { return acceptedIfAnswerExists(strokes, kind:"two_stroke_l", commandStrokeIds:[v.strokeId,h.strokeId]) } }
        return .init(accepted:false,kind:"",reason:"no_finalize_command",commandStrokeIds:[])
    }
    private static func acceptedIfAnswerExists(_ strokes:[SlateStroke], kind:String, commandStrokeIds:[String]) -> SlateDetection {
        let command = Set(commandStrokeIds)
        guard strokes.contains(where: { !command.contains($0.strokeId) && !$0.points.isEmpty }) else {
            return .init(accepted:false,kind:"",reason:"empty_answer",commandStrokeIds:commandStrokeIds)
        }
        return .init(accepted:true,kind:kind,reason:"",commandStrokeIds:commandStrokeIds)
    }
    public static func answerStrokesOnly(_ strokes:[SlateStroke], detection:SlateDetection) -> [SlateStroke] { strokes.filter{!detection.commandStrokeIds.contains($0.strokeId)} }
    private static func bounds(_ ss:[SlateStroke])->(minX:Double,minY:Double,maxX:Double,maxY:Double)? { let p=ss.flatMap{$0.points}; guard let f=p.first else{return nil}; return p.dropFirst().reduce((f.x,f.y,f.x,f.y)){(min($0.0,$1.x),min($0.1,$1.y),max($0.2,$1.x),max($0.3,$1.y))} }
    private static func corner(_ ss:[SlateStroke],_ s:SlateGestureSettings)->Bool { guard let b=bounds(ss) else{return false}; let x0=1-38/s.pageWidthMm,y0=1-38/s.pageHeightMm; return b.minX >= x0-0.015 && b.minY >= y0-0.015 && b.maxX >= x0 && b.maxY >= y0 }
    private static func size(_ ss:[SlateStroke],_ s:SlateGestureSettings)->Bool { guard let b=bounds(ss) else{return false}; let w=(b.maxX-b.minX)*s.pageWidthMm,h=(b.maxY-b.minY)*s.pageHeightMm; return w >= 3 && w <= 20 && h >= 6 && h <= 28 }
    private static func one(_ st:SlateStroke,_ s:SlateGestureSettings)->Bool { guard st.points.count >= 4, corner([st],s), size([st],s) else{return false}; let d=st.endedAtMs>=0 && st.startedAtMs>=0 ? st.endedAtMs-st.startedAtMs : -1; guard d<0 || (d>=100 && d<=2000) else{return false}; guard let b=bounds([st]) else{return false}; let w=max(0.0001,b.maxX-b.minX),h=max(0.0001,b.maxY-b.minY),f=st.points[0],l=st.points.last!; return st.points.dropFirst().dropLast().contains{ t in let vd=t.y-f.y >= h*0.45 && abs(t.x-f.x)<=w*0.8; let hr=l.x-t.x>=w*0.45 && abs(l.y-t.y)<=h*0.6 && l.x>=f.x-w*0.2; let hl=t.x-l.x>=w*0.45 && abs(l.y-t.y)<=h*0.6 && l.x<=f.x+w*0.2; return vd && t.y>=b.minY+h*0.45 && (hr || hl) }
    }
    private static func two(_ v:SlateStroke,_ h:SlateStroke,_ s:SlateGestureSettings)->Bool { guard corner([v,h],s),size([v,h],s) else{return false}; if v.endedAtMs>=0 && h.startedAtMs>=0 && h.startedAtMs-v.endedAtMs>700{return false}; guard let v0=v.points.first,v1=v.points.last,h0=h.points.first,h1=h.points.last else{return false}; let vdx=abs(v1.x-v0.x)*s.pageWidthMm,vdy=(v1.y-v0.y)*s.pageHeightMm,hdx=abs(h1.x-h0.x)*s.pageWidthMm,hdy=abs(h1.y-h0.y)*s.pageHeightMm,join=hypot((h0.x-v1.x)*s.pageWidthMm,(h0.y-v1.y)*s.pageHeightMm); return vdy>=8 && vdy>=vdx*1.2 && hdx>=4 && hdx>=hdy*1.2 && join<=10 }
}
