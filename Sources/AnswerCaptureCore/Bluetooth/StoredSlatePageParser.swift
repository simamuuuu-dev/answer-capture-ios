import Foundation

/// Port of Android `StoredSlatePageParser` (including its bit-mask delta codec).
public enum StoredSlatePageParser {
    private static let magic: [UInt8] = [0x62, 0x38, 0x62, 0x74]
    public static func parse(_ data: [UInt8], pageId: String, baseTimeMs: Int64) -> SlateStoredPage {
        let id = pageId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "stored-page" : pageId.replacingOccurrences(of: "[^0-9A-Za-z_.-]+", with: "_", options: .regularExpression)
        var p = Parser(data: data, pageId: id, baseTimeMs: baseTimeMs); return p.parse()
    }
    private struct Axis { let ok: Bool; let value: Int; let accumulator: Int; let offset: Int }
    private struct Decoded { let ok: Bool; let x: Int; let y: Int; let pressure: Int; let dx: Int; let dy: Int; let dp: Int }
    private struct Parser {
        let data: [UInt8]; let pageId: String; let baseTimeMs: Int64; var pos = 0; var pointIndex = 0; var strokeIndex = 0; var lastX=0; var lastY=0; var lastPressure=0; var accDx=0; var accDy=0; var accDp=0; var current=[SlatePoint](); var strokes=[SlateStroke]()
        mutating func parse() -> SlateStoredPage {
            let magicOK = data.starts(with: StoredSlatePageParser.magic); pos = min(4, data.count)
            while pos < data.count { let header=data[pos]; pos += 1; let n=header.nonzeroBitCount; if n == 0 { continue }; if pos+n > data.count { break }; let start=pos; pos += n; let all=data[start..<pos].allSatisfy{$0 == 0xff}
                if (n == 7 && data[start] == 0xfc && data[start+1..<pos].allSatisfy{$0 == 0xff}) || (n == 6 && all) { finish(); reset(); continue }
                if n == 8 && all { break }
                if n >= 3 && data[start] == 0xff && data[start+1] == 0xee { finish(); reset(); continue }
                if n >= 4 && data[start] == 0xff && data[start+1] == 0xff { append(decode(header, start: start+2, length: n-2, bx: 0, by: 0, bp: 0, ax: 0, ay: 0, ap: 0)); continue }
                if header & 0x03 == 0 { append(decode(header, start: start, length: n, bx: lastX, by: lastY, bp: lastPressure, ax: accDx, ay: accDy, ap: accDp)) }
            }
            finish(); return SlateStoredPage(pageId: pageId, strokes: strokes, magicOK: magicOK, byteCount: data.count)
        }
        func axis(_ mask: Int, _ start: Int, _ length: Int, _ off: Int, _ last: Int, _ acc: Int) -> Axis { if mask == 2 { guard off < length else { return Axis(ok:false,value:0,accumulator:0,offset:0) }; let a=acc+Int(Int8(bitPattern:data[start+off])); return Axis(ok:true,value:last+a,accumulator:a,offset:off+1) }; if mask == 3 { guard off+2 <= length else { return Axis(ok:false,value:0,accumulator:0,offset:0) }; return Axis(ok:true,value:Int(data[start+off])|Int(data[start+off+1])<<8,accumulator:0,offset:off+2) }; return Axis(ok:true,value:last,accumulator:acc,offset:off) }
        func decode(_ h: UInt8, start: Int, length: Int, bx: Int, by: Int, bp: Int, ax: Int, ay: Int, ap: Int) -> Decoded { let xr=axis(Int((h>>2)&3),start,length,0,bx,ax); guard xr.ok else {return Decoded(ok:false,x:0,y:0,pressure:0,dx:0,dy:0,dp:0)}; let yr=axis(Int((h>>4)&3),start,length,xr.offset,by,ay); guard yr.ok else {return Decoded(ok:false,x:0,y:0,pressure:0,dx:0,dy:0,dp:0)}; let pr=axis(Int((h>>6)&3),start,length,yr.offset,bp,ap); guard pr.ok else {return Decoded(ok:false,x:0,y:0,pressure:0,dx:0,dy:0,dp:0)}; return Decoded(ok:true,x:min(SlateConstants.coordinateWidth,max(0,xr.value)),y:min(SlateConstants.coordinateHeight,max(0,yr.value)),pressure:min(SlateConstants.pressureMax,max(0,pr.value)),dx:xr.accumulator,dy:yr.accumulator,dp:pr.accumulator) }
        mutating func append(_ d: Decoded) { guard d.ok else {return}; lastX=d.x;lastY=d.y;lastPressure=d.pressure;accDx=d.dx;accDy=d.dy;accDp=d.dp; current.append(SlatePoint(x:Double(d.x),y:Double(d.y),tMs:baseTimeMs+Int64(pointIndex*5),pressure:Double(d.pressure)/Double(SlateConstants.pressureMax))); pointIndex += 1 }
        mutating func finish() { guard !current.isEmpty else {return}; strokeIndex += 1; strokes.append(SlateStroke(strokeId: "\(pageId)-stroke-\(String(format: "%03d", strokeIndex))", points: current, startedAtMs: current[0].tMs, endedAtMs: current[current.count-1].tMs)); current=[]; pointIndex += 8 }
        mutating func reset() { lastX=0;lastY=0;lastPressure=0;accDx=0;accDy=0;accDp=0 }
    }
}
