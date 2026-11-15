import SwiftUI
import AppKit
import ApplicationServices
import UniformTypeIdentifiers

enum StepKind: String, Codable { case key, text, wait, click, doubleClick, scroll }
struct KeyAction: Identifiable, Codable {
    var id = UUID()
    var title: String
    var keyCode: CGKeyCode
    var modifierRawValue: UInt64
    var text: String? = nil
    var kind: StepKind = .key
    var pause: Double = 0.12
    var enabled: Bool = true
    var modifiers: CGEventFlags { CGEventFlags(rawValue: modifierRawValue) }
    init(title:String,keyCode:CGKeyCode=0,modifiers:CGEventFlags=[],text:String?=nil,kind:StepKind = .key,pause:Double=0.12) {
        self.title=title;self.keyCode=keyCode;self.modifierRawValue=modifiers.rawValue;self.text=text;self.kind=kind;self.pause=pause
    }
    enum CodingKeys:String,CodingKey {case id,title,keyCode,modifierRawValue,text,kind,pause,enabled}
    init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        id=try c.decodeIfPresent(UUID.self,forKey:.id) ?? UUID()
        title=try c.decode(String.self,forKey:.title)
        keyCode=try c.decodeIfPresent(CGKeyCode.self,forKey:.keyCode) ?? 0
        modifierRawValue=try c.decodeIfPresent(UInt64.self,forKey:.modifierRawValue) ?? 0
        text=try c.decodeIfPresent(String.self,forKey:.text)
        kind=try c.decodeIfPresent(StepKind.self,forKey:.kind) ?? (text == nil ? .key:.text)
        pause=try c.decodeIfPresent(Double.self,forKey:.pause) ?? 0.12
        enabled=try c.decodeIfPresent(Bool.self,forKey:.enabled) ?? true
    }
}
@MainActor final class MacroModel:ObservableObject {
    @Published var actions:[KeyAction]=[]
    @Published var selected:Set<String>=[]
    @Published var isRunning=false
    @Published var loop=false
    @Published var repeats=1
    @Published var delay=0.10
    @Published var randomDelay=false
    @Published var countdown=0
    @Published var sound=true
    @Published var status="SYSTEM ONLINE"
    @Published var macroName="Untitled sequence"
    @Published var textToInsert=""
    @Published var search=""
    @Published var completed=0
    @Published var runCount=0
    @Published var elapsed=0.0
    @Published var showDisabled=true
    private var stopRequested=false
    private var started=Date()
    let mods=["⌘":CGEventFlags.maskCommand,"⇧":.maskShift,"⌥":.maskAlternate,"⌃":.maskControl]
    let keys:[String:CGKeyCode]=["A":0,"S":1,"D":2,"F":3,"H":4,"G":5,"Z":6,"X":7,"C":8,"V":9,"B":11,"Q":12,"W":13,"E":14,"R":15,"Y":16,"T":17,"1":18,"2":19,"3":20,"4":21,"6":22,"5":23,"=":24,"9":25,"7":26,"-":27,"8":28,"0":29,"]":30,"O":31,"U":32,"[":33,"I":34,"P":35,"L":37,"J":38,"'":39,"K":40,";":41,"\\":42,",":43,"/":44,"N":45,"M":46,".":47,"Space":49,"Enter":36,"Tab":48,"Delete":51,"Esc":53,"←":123,"→":124,"↓":125,"↑":126]
    var filtered:[KeyAction]{actions.filter{(search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)) && (showDisabled || $0.enabled)}}
    var activeCount:Int{actions.filter(\.enabled).count}
    var estimate:Double{actions.filter(\.enabled).reduce(0){$0+$1.pause+0.05}}
    var progress:Double{Double(completed)/Double(max(1,activeCount))}
    func toggle(_ k:String){if selected.contains(k){selected.remove(k)}else{selected.insert(k)}}
    func addKey(_ k:String){
        guard let code=keys[k] else{return}
        let flags=selected.reduce(CGEventFlags()){$0.union(mods[$1] ?? [])}
        let prefix=selected.sorted().joined()
        actions.append(KeyAction(title:prefix.isEmpty ? k:prefix+" + "+k,keyCode:code,modifiers:flags,pause:delay))
        selected=[];status="KEY ADDED"
    }
    func addText(){
        guard !textToInsert.isEmpty else{return}
        let p=textToInsert.count>24 ? String(textToInsert.prefix(24))+"…":textToInsert
        actions.append(KeyAction(title:"TEXT / "+p,text:textToInsert,kind:.text,pause:delay))
        textToInsert="";status="TEXT BLOCK ADDED"
    }
    func addWait(){actions.append(KeyAction(title:"WAIT / 1 SECOND",kind:.wait,pause:1));status="WAIT STEP ADDED"}
    func addMouse(_ kind:StepKind){let title = kind == .click ? "MOUSE / LEFT CLICK" : kind == .doubleClick ? "MOUSE / DOUBLE CLICK" : "MOUSE / SCROLL DOWN";actions.append(KeyAction(title:title,kind:kind,pause:delay));status="MOUSE ACTION ADDED"}
    func remove(_ a:KeyAction){actions.removeAll{$0.id==a.id}}
    func move(_ a:KeyAction,_ n:Int){guard let i=actions.firstIndex(where:{$0.id==a.id}),actions.indices.contains(i+n) else{return};actions.swapAt(i,i+n)}
    func duplicate(_ a:KeyAction){guard let i=actions.firstIndex(where:{$0.id==a.id})else{return};var b=a;b.id=UUID();actions.insert(b,at:i+1)}
    func toggleEnabled(_ a:KeyAction){guard let i=actions.firstIndex(where:{$0.id==a.id})else{return};actions[i].enabled.toggle()}
    func changePause(_ a:KeyAction,_ v:Double){guard let i=actions.firstIndex(where:{$0.id==a.id})else{return};actions[i].pause=v}
    func preset(_ p:String){
        let map:[String:(String,CGEventFlags)]=["Paste":("V",.maskCommand),"Copy":("C",.maskCommand),"Select All":("A",.maskCommand),"Undo":("Z",.maskCommand),"Save":("S",.maskCommand),"Find":("F",.maskCommand)]
        if let x=map[p],let code=keys[x.0]{actions.append(KeyAction(title:"⌘ + "+x.0,keyCode:code,modifiers:x.1,pause:delay))}
        else if p=="Return"{addKey("Enter")}
        status="PRESET APPENDED"
    }
    func save(){
        let p=NSSavePanel();p.allowedContentTypes=[.json];p.nameFieldStringValue=macroName+".json"
        guard p.runModal() == .OK,let u=p.url else{return}
        do{let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys];try e.encode(actions).write(to:u);status="EXPORTED SUCCESSFULLY"}catch{status="EXPORT ERROR"}
    }
    func load(){
        let p=NSOpenPanel();p.allowedContentTypes=[.json];p.allowsMultipleSelection=false
        guard p.runModal() == .OK,let u=p.url else{return}
        do{actions=try JSONDecoder().decode([KeyAction].self,from:Data(contentsOf:u));macroName=u.deletingPathExtension().lastPathComponent;status="IMPORTED SUCCESSFULLY"}catch{status="IMPORT ERROR"}
    }
    func stop(){stopRequested=true;status="STOP SIGNAL SENT"}
    func play(){
        guard !actions.isEmpty,!isRunning else{return}
        guard AXIsProcessTrusted() else{status="ACCESSIBILITY PERMISSION REQUIRED";let o=["AXTrustedCheckOptionPrompt":true] as CFDictionary;_ = AXIsProcessTrustedWithOptions(o);return}
        stopRequested=false;isRunning=true;completed=0;runCount=0;elapsed=0;started=Date();status="SEQUENCE EXECUTING";Task{await run()}
    }
    private func sendKey(_ code:CGKeyCode,_ flags:CGEventFlags) async {
        let s=CGEventSource(stateID:.hidSystemState)
        let d=CGEvent(keyboardEventSource:s,virtualKey:code,keyDown:true),u=CGEvent(keyboardEventSource:s,virtualKey:code,keyDown:false)
        d?.flags=flags;u?.flags=flags;d?.post(tap:.cghidEventTap);try? await Task.sleep(for:.milliseconds(45));u?.post(tap:.cghidEventTap)
    }
    private func sendMouse(_ type:CGEventType){let p=CGEvent(source:nil)?.location ?? .zero;let b:CGMouseButton = .left;CGEvent(mouseEventSource:nil,mouseType:type,mouseCursorPosition:p,mouseButton:b)?.post(tap:.cghidEventTap)}
    private func sendText(_ value:String){
        let all=Array(value.utf16)
        for start in stride(from:0,to:all.count,by:20){
            guard let e=CGEvent(keyboardEventSource:CGEventSource(stateID:.hidSystemState),virtualKey:0,keyDown:true)else{continue}
            var chars=Array(all[start..<min(start+20,all.count)])
            e.keyboardSetUnicodeString(stringLength:chars.count,unicodeString:&chars);e.post(tap:.cghidEventTap)
        }
    }
    private func run() async {
        if countdown>0{for n in (1...countdown).reversed(){if stopRequested{break};status="STARTING IN \(n)…";try? await Task.sleep(for:.seconds(1))}}
        var left=max(1,repeats)
        while !stopRequested {
            let list=actions.filter(\.enabled)
            for (i,a) in list.enumerated(){
                if stopRequested{break}
                switch a.kind{case .key:await sendKey(a.keyCode,a.modifiers);case .text:if let t=a.text{sendText(t)};case .wait:try? await Task.sleep(for:.seconds(max(0.05,a.pause)))
                case .click: sendMouse(.leftMouseDown);sendMouse(.leftMouseUp)
                case .doubleClick: for _ in 0..<2 {sendMouse(.leftMouseDown);sendMouse(.leftMouseUp);try? await Task.sleep(for:.milliseconds(70))}
                case .scroll: if let e=CGEvent(scrollWheelEvent2Source:nil,units:.pixel, wheelCount:1,wheel1:-260,wheel2:0,wheel3:0){e.post(tap:.cghidEventTap)}}
                completed=i+1
                let pause=randomDelay ? Double.random(in:max(0.01,a.pause*0.65)...max(0.02,a.pause*1.45)):a.pause
                try? await Task.sleep(for:.seconds(max(0.01,pause)))
            }
            if stopRequested{break};runCount+=1;if loop{continue};left-=1;if left<=0{break}
        }
        elapsed=Date().timeIntervalSince(started);isRunning=false;status=stopRequested ? "SEQUENCE HALTED":"SEQUENCE COMPLETE"
        if sound{NSSound(named:"Glass")?.play()}
    }
}

public struct KeyFlowView: View, Equatable {
    nonisolated public static func == (lhs: KeyFlowView, rhs: KeyFlowView) -> Bool { true }
    public init() {}
    @StateObject private var m=MacroModel()
    @State private var tab=0
    @State private var heroBreath = false
    @AppStorage("keyflow.language") private var language = "Русский"
    private let cyan=Color(red:0.76,green:1,blue:0.02)
    private let violet=Color(red:0.34,green:0.40,blue:0.38)
    private let rows=[["Q","W","E","R","T","Y","U","I","O","P"],["A","S","D","F","G","H","J","K","L"],["Z","X","C","V","B","N","M"]]
    public var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            // The host app owns the shared starfield and robot artwork. Keep this layer transparent.

            VStack(spacing:0) {
                topBar
                HStack(spacing:0) {
                    sidebar
                    ScrollView {
                        VStack(spacing:15) {
                            hero
                            if tab == 0 { editor; keyboard; actions }
                            else if tab == 1 { actions; keyboard }
                            else { settings; telemetry }
                        }
                        .padding(20).frame(maxWidth:950).frame(maxWidth:.infinity)
                    }
                }
            }
        }.frame(minWidth:1000,idealWidth:1120,minHeight:780,idealHeight:880).preferredColorScheme(.dark)
            .animation(.spring(response:0.42,dampingFraction:0.86),value:tab)
            .animation(.spring(response:0.34,dampingFraction:0.78),value:m.actions.count)
            .animation(.easeInOut(duration:0.22),value:m.isRunning)
            .onAppear { heroBreath = true }
    }
    private var topBar:some View {
        HStack(spacing:12){
            ZStack{RoundedRectangle(cornerRadius:11).fill(LinearGradient(colors:[cyan.opacity(0.9),Color(red:0.36,green:0.48,blue:0.38)],startPoint:.topLeading,endPoint:.bottomTrailing));Image(systemName:"command").font(.system(size:21,weight:.black)).foregroundStyle(.black)}
                .frame(width:40,height:40)
            VStack(alignment:.leading,spacing:2){Text("KEYFLOW").font(.system(size:17,weight:.black,design:.rounded)).tracking(2.8);Text("MAC AUTOMATION  /  WORKSPACE").font(.system(size:8,weight:.bold,design:.monospaced)).tracking(1).foregroundStyle(cyan.opacity(0.9))}
            Spacer()
            HStack(spacing:7){Circle().fill(m.isRunning ? cyan:Color.green).frame(width:6,height:6);Text(m.isRunning ? "EXECUTING":"SYSTEM ONLINE").font(.system(size:9,weight:.bold,design:.monospaced)).tracking(1)}
                .padding(.horizontal,12).padding(.vertical,8).background(.white.opacity(0.045),in:Capsule()).overlay(Capsule().stroke(cyan.opacity(0.25),lineWidth:1))
            Text("SCENARIO ENGINE").font(.system(size:8,weight:.bold,design:.monospaced)).foregroundStyle(.white.opacity(0.25)).padding(.leading,8)
        }.padding(.horizontal,22).padding(.vertical,13).background(.black.opacity(0.4)).overlay(alignment:.bottom){LinearGradient(colors:[.clear,cyan.opacity(0.4),violet.opacity(0.4),.clear],startPoint:.leading,endPoint:.trailing).frame(height:1)}
    }
    private var sidebar:some View {
        VStack(alignment:.leading,spacing:8){
            Text(tr("WORKSPACE")).font(.system(size:8,weight:.black,design:.monospaced)).tracking(1.6).foregroundStyle(.white.opacity(0.3)).padding(.horizontal,12).padding(.top,18)
            nav(0,"square.grid.2x2",tr("Command deck"));nav(1,"point.3.connected.trianglepath.dotted",tr("Action library"));nav(2,"slider.horizontal.3",tr("Settings"))
            Spacer()
            VStack(alignment:.leading,spacing:9){Text(tr("SESSION DATA")).font(.system(size:8,weight:.black,design:.monospaced)).foregroundStyle(.white.opacity(0.3));metric("TOTAL STEPS","\(m.actions.count)");metric("ACTIVE STEPS","\(m.activeCount)");metric("EST. CYCLE",String(format:"%.1fs",m.estimate))}
                .padding(12).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:12))
            Text("KEYFLOW  /  AUTOMATION").font(.system(size:8,weight:.bold,design:.monospaced)).foregroundStyle(cyan.opacity(0.45)).padding(12)
        }.padding(.horizontal,12).frame(width:190).background(.black.opacity(0.2)).overlay(alignment:.trailing){Rectangle().fill(.white.opacity(0.06)).frame(width:1)}
    }
    private func nav(_ i:Int,_ icon:String,_ title:String)->some View {
        Button{tab=i}label:{HStack(spacing:11){Image(systemName:icon).frame(width:17);Text(title).font(.system(size:11,weight:.semibold));Spacer();if tab==i{Circle().fill(cyan).frame(width:5,height:5)}}.foregroundStyle(tab==i ? cyan:.white.opacity(0.48)).padding(11).background(tab==i ? cyan.opacity(0.09):.clear,in:RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).stroke(tab==i ? cyan.opacity(0.24):.clear,lineWidth:1))}.buttonStyle(CyberPressStyle())
    }
    private func metric(_ a:String,_ b:String)->some View{HStack{Text(tr(a)).font(.system(size:8,weight:.bold,design:.monospaced)).foregroundStyle(.white.opacity(0.38));Spacer();Text(b).font(.system(size:10,weight:.bold,design:.monospaced)).foregroundStyle(cyan)}}
    private var hero:some View {
        HStack(spacing:15){
            VStack(alignment:.leading,spacing:9){
                HStack(spacing:7){Text(tr("AUTOMATION CORE")).font(.system(size:9,weight:.black,design:.monospaced)).tracking(2).foregroundStyle(cyan);Capsule().fill(cyan.opacity(0.5)).frame(width:26,height:2)}
                Text(tr("Design your\nnext sequence.")).font(.system(size:31,weight:.black,design:.rounded)).tracking(-0.8).lineSpacing(-2)
                Text(tr("Клавиши, текст и действия мыши — в одном сценарии.")).font(.system(size:11)).foregroundStyle(.white.opacity(0.45))
                HStack(spacing:8){
                    Button{m.play()}label:{Label(tr("RUN SEQUENCE"),systemImage:"play.fill").font(.system(size:10,weight:.black)).padding(.horizontal,14).frame(height:36)}.buttonStyle(.borderedProminent).tint(violet).disabled(m.actions.isEmpty || m.isRunning)
                    Button{m.stop()}label:{Image(systemName:"stop.fill").font(.system(size:11,weight:.bold)).frame(width:38,height:36)}.buttonStyle(.bordered).disabled(!m.isRunning)
                    Button{m.save()}label:{Image(systemName:"square.and.arrow.down").font(.system(size:11)).frame(width:38,height:36)}.buttonStyle(.bordered)
                }.padding(.top,4)
            }
            Spacer()
            ZStack{
                Circle().stroke(cyan.opacity(heroBreath ? 0.19 : 0.08),lineWidth:1).frame(width:164,height:164).scaleEffect(heroBreath ? 1.025 : 0.97)
                Circle().stroke(violet.opacity(0.2),style:StrokeStyle(lineWidth:1,dash:[3,6])).frame(width:137,height:137).rotationEffect(.degrees(25))
                Circle().trim(from:0.04,to:m.isRunning ? max(0.08,m.progress):0.73).stroke(AngularGradient(colors:[cyan,violet,cyan],center:.center),style:StrokeStyle(lineWidth:5,lineCap:.round)).frame(width:148,height:148).rotationEffect(.degrees(-90))
                VStack(spacing:4){Image(systemName:m.isRunning ? "waveform.path":"cpu").font(.system(size:25,weight:.light)).foregroundStyle(cyan);Text(m.isRunning ? "ACTIVE":"CORE").font(.system(size:9,weight:.black,design:.monospaced)).tracking(1.5);Text("\(m.completed)/\(max(1,m.activeCount))").font(.system(size:9,design:.monospaced)).foregroundStyle(.white.opacity(0.4))}
                Circle().fill(cyan).frame(width:5,height:5).offset(x:81)
            }.frame(width:175,height:175)
        }.padding(24).background(LinearGradient(colors:[Color(red:0.105,green:0.13,blue:0.12),Color(red:0.035,green:0.045,blue:0.043)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:22))
            .overlay(RoundedRectangle(cornerRadius:22).stroke(LinearGradient(colors:[.white.opacity(0.16),cyan.opacity(0.20),.white.opacity(0.035)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:1))
            .shadow(color:cyan.opacity(m.isRunning ? 0.12 : 0.035),radius:m.isRunning ? 24 : 14,y:10)
            .animation(.easeInOut(duration:2.2).repeatForever(autoreverses:true),value:heroBreath)
            .overlay(alignment:.topTrailing){Text("KEYFLOW / STUDIO").font(.system(size:8,weight:.bold,design:.monospaced)).foregroundStyle(cyan.opacity(0.5)).padding(13)}

    }
    private var editor:some View {
        VStack(alignment:.leading,spacing:12){
            section("01","SEQUENCE TIMELINE","Your macro architecture")
            HStack(spacing:8){Image(systemName:"waveform.path").foregroundStyle(cyan);TextField(tr("Sequence name"),text:$m.macroName).textFieldStyle(.plain).font(.system(size:13,weight:.semibold));Spacer();smallButton("IMPORT","folder"){m.load()};smallButton("EXPORT","square.and.arrow.up"){m.save()};smallButton("RESET","trash"){m.actions=[];m.status="TIMELINE RESET"}}
            HStack(spacing:8){Image(systemName:"magnifyingglass").foregroundStyle(.white.opacity(0.35));TextField(tr("Filter actions…"),text:$m.search).textFieldStyle(.plain).font(.system(size:10));Toggle(tr("Show disabled"),isOn:$m.showDisabled).toggleStyle(.checkbox).font(.system(size:9))}
                .padding(9).background(.black.opacity(0.2),in:RoundedRectangle(cornerRadius:8))
            if m.filtered.isEmpty{VStack(spacing:7){Image(systemName:"point.topleft.down.to.point.bottomright.curvepath").font(.system(size:23)).foregroundStyle(cyan.opacity(0.6));Text(tr("TIMELINE EMPTY")).font(.system(size:10,weight:.black,design:.monospaced)).tracking(1);Text(tr("Add a module or keyboard action below")).font(.system(size:10)).foregroundStyle(.white.opacity(0.35))}.frame(maxWidth:.infinity).padding(.vertical,23)}
            else{LazyVStack(spacing:5){ForEach(Array(m.filtered.enumerated()),id:\.element.id){idx,a in
                HStack(spacing:8){Text(String(format:"%02d",idx+1)).font(.system(size:9,weight:.bold,design:.monospaced)).foregroundStyle(cyan.opacity(0.65)).frame(width:23);RoundedRectangle(cornerRadius:2).fill(a.kind == .text ? violet:cyan).frame(width:3,height:27);Image(systemName:a.kind == .text ? "text.alignleft":a.kind == .wait ? "timer":"keyboard").font(.system(size:11)).foregroundStyle(a.kind == .text ? violet:cyan).frame(width:17)
                    VStack(alignment:.leading,spacing:2){Text(tr(a.title)).font(.system(size:10,weight:.semibold)).lineLimit(1);Text(a.kind.rawValue.uppercased()+" / "+String(format:"%.2fs",a.pause)).font(.system(size:7,weight:.bold,design:.monospaced)).foregroundStyle(.white.opacity(0.35))}
                    Slider(value:Binding(get:{a.pause},set:{m.changePause(a,$0)}),in:0.02...2,step:0.01).frame(width:65).tint(cyan).help("Pause for this step")
                    Spacer(minLength:3)
                    Toggle("",isOn:Binding(get:{a.enabled},set:{_ in m.toggleEnabled(a)})).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                    iconButton("arrow.up",disabled:idx==0){m.move(a,-1)};iconButton("arrow.down",disabled:idx==m.filtered.count-1){m.move(a,1)};iconButton("plus.square.on.square"){m.duplicate(a)};iconButton("xmark",tint:.red.opacity(0.8)){m.remove(a)}
                }.padding(.horizontal,8).padding(.vertical,7).background(a.enabled ? cyan.opacity(0.045) : .white.opacity(0.018),in:RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).stroke(a.enabled ? cyan.opacity(0.13) : .white.opacity(0.035),lineWidth:1)).opacity(a.enabled ? 1:0.48).transition(.asymmetric(insertion:.move(edge:.top).combined(with:.opacity),removal:.scale(scale:0.96).combined(with:.opacity)))
            }}}
            HStack{Text(tr("LIVE ENGINE")).font(.system(size:8,weight:.black,design:.monospaced)).foregroundStyle(.white.opacity(0.35));Spacer();Text(tr(m.status)).font(.system(size:8,weight:.bold,design:.monospaced)).foregroundStyle(cyan).lineLimit(1)}
            if m.isRunning{ProgressView(value:m.progress).tint(cyan)}
        }.padding(16).panel().animation(.spring(response:0.36,dampingFraction:0.82),value:m.actions.map(\.id))
    }
    private var keyboard:some View {
        VStack(alignment:.leading,spacing:11){
            section("02","INPUT MATRIX","Compose keyboard combinations")
            Text("Сначала выбери модификаторы, затем нажми клавишу. Комбинация добавится в сценарий.").font(.system(size:10)).foregroundStyle(.white.opacity(0.45))
            HStack(spacing:7){ForEach(["⌘","⇧","⌥","⌃"],id:\.self){k in Button{m.toggle(k)}label:{Text(k).font(.system(size:17,weight:.bold)).frame(maxWidth:.infinity).frame(height:42).background(m.selected.contains(k) ? cyan.opacity(0.18):.white.opacity(0.045),in:RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).stroke(m.selected.contains(k) ? cyan.opacity(0.65):.white.opacity(0.07),lineWidth:1))}.buttonStyle(CyberPressStyle()).foregroundStyle(m.selected.contains(k) ? cyan:.white.opacity(0.8)).scaleEffect(m.selected.contains(k) ? 1.025 : 1)}}
            VStack(spacing:5){ForEach(rows,id:\.self){r in HStack(spacing:5){ForEach(r,id:\.self){k in keyCap(k)}}};HStack(spacing:5){ForEach(["1","2","3","4","5","6","7","8","9","0"],id:\.self){k in keyCap(k)}};HStack(spacing:5){ForEach(["Space","Tab","Enter","Delete","Esc","←","↑","↓","→"],id:\.self){k in keyCap(k,true)}}}
        }.padding(16).panel()
    }
    private func keyCap(_ k:String,_ small:Bool=false)->some View {
        Button{m.addKey(k)}label:{Text(k=="Space" ? "SPACE":k=="Enter" ? "↵":k=="Delete" ? "⌫":k=="Tab" ? "⇥":k).font(.system(size:small ? 8:10,weight:.bold,design:.rounded)).frame(maxWidth:.infinity).frame(height:30).background(LinearGradient(colors:[cyan.opacity(0.12),violet.opacity(0.09),.black.opacity(0.18)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:5)).overlay(RoundedRectangle(cornerRadius:5).stroke(cyan.opacity(0.32),lineWidth:0.8))}.buttonStyle(CyberPressStyle()).foregroundStyle(.white.opacity(0.9))
    }
    private var actions:some View {
        VStack(alignment:.leading,spacing:12){
            section("03","ACTION MODULES","More than keyboard input")
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())],spacing:8){
                module("WAIT","timer","Pause / 1 sec"){m.addWait()}
                module("TEXT BLOCK","text.alignleft","Inject phrase"){m.addText()}
                module("PASTE","doc.on.clipboard","⌘ + V"){m.preset("Paste")}
                module("COPY","doc.on.doc","⌘ + C"){m.preset("Copy")}
                module("SELECT ALL","selection.pin.in.out","⌘ + A"){m.preset("Select All")}
                module("UNDO","arrow.uturn.backward","⌘ + Z"){m.preset("Undo")}
                module("MOUSE CLICK","cursorarrow.click","Current pointer position"){m.addMouse(.click)}
                module("DOUBLE CLICK","cursorarrow.click.2","Two rapid clicks"){m.addMouse(.doubleClick)}
                module("SCROLL DOWN","arrow.down.to.line","Scroll 260 px"){m.addMouse(.scroll)}
            }
            Divider().overlay(.white.opacity(0.08))
            Text(tr("TEXT PAYLOAD")).font(.system(size:8,weight:.black,design:.monospaced)).tracking(1.2).foregroundStyle(cyan)
            HStack(spacing:8){TextField(tr("Type a phrase to inject into the sequence…"),text:$m.textToInsert).textFieldStyle(.plain).font(.system(size:10)).padding(10).background(.black.opacity(0.22),in:RoundedRectangle(cornerRadius:7)).onSubmit{m.addText()};Button{m.addText()}label:{Image(systemName:"plus").font(.system(size:11,weight:.black)).frame(width:36,height:34)}.buttonStyle(.borderedProminent).tint(violet).disabled(m.textToInsert.isEmpty)}
        }.padding(16).panel()
    }
    private func module(_ title:String,_ icon:String,_ sub:String,action:@escaping()->Void)->some View {
        Button{action()}label:{HStack(spacing:9){Image(systemName:icon).font(.system(size:16)).foregroundStyle(cyan).frame(width:25);VStack(alignment:.leading,spacing:3){Text(tr(title)).font(.system(size:8,weight:.black,design:.monospaced));Text(tr(sub)).font(.system(size:8)).foregroundStyle(.white.opacity(0.35))};Spacer();Image(systemName:"plus").font(.system(size:9,weight:.bold)).foregroundStyle(violet)}.padding(10).frame(maxWidth:.infinity,minHeight:48).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).stroke(LinearGradient(colors:[cyan.opacity(0.42),violet.opacity(0.35)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:1))}.buttonStyle(CyberPressStyle())
    }
    private var settings:some View {
        VStack(alignment:.leading,spacing:14){
            section("04",tr("EXECUTION PARAMETERS"),tr("Timing, repetition and feedback"))
            VStack(alignment:.leading,spacing:8){Text(tr("INTERFACE LANGUAGE")).font(.system(size:9,weight:.black,design:.monospaced)).foregroundStyle(cyan);Picker(tr("Language"),selection:$language){ForEach(["Русский","English","Español","Français","Deutsch","Italiano","Português","Polski","Türkçe","日本語","中文"],id:\.self){Text($0).tag($0)}}.pickerStyle(.menu).frame(maxWidth:260,alignment:.leading)}
            Divider().overlay(.white.opacity(0.08))
            HStack{Text(tr("Global delay")).font(.system(size:11));Spacer();Text(String(format:"%.2f sec",m.delay)).font(.system(size:10,weight:.bold,design:.monospaced)).foregroundStyle(cyan)}
            Slider(value:$m.delay,in:0.02...2,step:0.01).tint(cyan)
            Toggle(tr("Humanized timing / random delay"),isOn:$m.randomDelay).toggleStyle(.switch).controlSize(.small)
            Toggle(tr("Infinite loop"),isOn:$m.loop).toggleStyle(.switch).controlSize(.small)
            HStack{Text(tr("Repeat count")).font(.system(size:10));Spacer();Stepper("\(m.repeats)",value:$m.repeats,in:1...999).frame(width:100).disabled(m.loop)}
            HStack{Text(tr("Pre-run countdown")).font(.system(size:10));Spacer();Stepper("\(m.countdown) sec",value:$m.countdown,in:0...10).frame(width:120)}
            Toggle(tr("Completion sound"),isOn:$m.sound).toggleStyle(.switch).controlSize(.small)
            Text(tr("Each step can be disabled, duplicated, reordered and assigned an individual pause.")).font(.system(size:9)).foregroundStyle(.white.opacity(0.38))
        }.padding(16).panel()
    }
    private var telemetry:some View {
        VStack(alignment:.leading,spacing:13){
            section("05","SYSTEM TELEMETRY","Live session statistics")
            HStack(spacing:8) { telemetryTile("ШАГИ", "\(m.actions.count)", "square.stack.3d.up"); telemetryTile("АКТИВНЫЕ", "\(m.activeCount)", "checkmark.circle"); telemetryTile("ЦИКЛЫ", "\(m.runCount)", "repeat") }
            VStack(spacing:9) {
                metric("ESTIMATED CYCLE",String(format:"%.2f sec",m.estimate))
                metric("LAST RUN DURATION",String(format:"%.2f sec",m.elapsed))
                metric("ACCESSIBILITY",AXIsProcessTrusted() ? "AUTHORIZED":"NOT AUTHORIZED")
            }.padding(12).background(.black.opacity(0.2),in:RoundedRectangle(cornerRadius:11))
            HStack(spacing:4) { ForEach(0..<24,id:\.self) { i in Capsule().fill(i < min(24,m.activeCount) ? cyan.opacity(0.85) : .white.opacity(0.08)).frame(height:5) } }
            Text("Визуальная карта активных шагов макроса").font(.system(size:9)).foregroundStyle(.white.opacity(0.38))
        }.padding(16).panel()
    }
    private func telemetryTile(_ title:String,_ value:String,_ icon:String)->some View {
        VStack(alignment:.leading,spacing:7) { Image(systemName:icon).font(.system(size:12)).foregroundStyle(cyan); Text(value).font(.system(size:20,weight:.bold,design:.rounded)).monospacedDigit().contentTransition(.numericText()); Text(title).font(.system(size:7,weight:.black,design:.monospaced)).tracking(0.8).foregroundStyle(.white.opacity(0.4)) }
            .frame(maxWidth:.infinity,alignment:.leading).padding(11).background(LinearGradient(colors:[cyan.opacity(0.10),.white.opacity(0.025)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).stroke(cyan.opacity(0.14),lineWidth:1)).animation(.spring(response:0.35,dampingFraction:0.8),value:value)
    }
    private func tr(_ key:String)->String {
        let tables:[String:[String:String]] = [
            "Русский":["Command deck":"Главная панель","Action library":"Библиотека действий","Settings":"Настройки","WORKSPACE":"РАБОЧАЯ СРЕДА","SESSION DATA":"ДАННЫЕ СЕССИИ","AUTOMATION CORE":"ЯДРО АВТОМАТИЗАЦИИ","Design your\nnext sequence.":"Создай свою\nпоследовательность.","Precision input. Infinite possibilities.":"Точный ввод. Безграничные возможности.","RUN SEQUENCE":"ЗАПУСТИТЬ","EXECUTION PARAMETERS":"ПАРАМЕТРЫ ВЫПОЛНЕНИЯ","Timing, repetition and feedback":"Тайминг, повторы и уведомления","INTERFACE LANGUAGE":"ЯЗЫК ИНТЕРФЕЙСА","Language":"Язык","Global delay":"Общая задержка","Humanized timing / random delay":"Случайные интервалы","Infinite loop":"Бесконечный цикл","Repeat count":"Количество повторов","Pre-run countdown":"Обратный отсчёт","Completion sound":"Звук завершения","Each step can be disabled, duplicated, reordered and assigned an individual pause.":"Каждый шаг можно отключить, дублировать, перемещать и настраивать задержку."],
            "English":[:],
            "Español":["Command deck":"Panel principal","Action library":"Biblioteca de acciones","Settings":"Ajustes","WORKSPACE":"ESPACIO DE TRABAJO","SESSION DATA":"DATOS DE SESIÓN","AUTOMATION CORE":"NÚCLEO DE AUTOMATIZACIÓN","Design your\nnext sequence.":"Diseña tu\nsecuencia.","Precision input. Infinite possibilities.":"Entrada precisa. Posibilidades infinitas.","RUN SEQUENCE":"EJECUTAR","EXECUTION PARAMETERS":"PARÁMETROS","Timing, repetition and feedback":"Tiempo, repetición y avisos","INTERFACE LANGUAGE":"IDIOMA DE INTERFAZ","Language":"Idioma","Global delay":"Retardo global","Infinite loop":"Bucle infinito","Repeat count":"Repeticiones","Pre-run countdown":"Cuenta atrás","Completion sound":"Sonido al terminar"],
            "Français":["Command deck":"Tableau de bord","Action library":"Bibliothèque d’actions","Settings":"Réglages","WORKSPACE":"ESPACE DE TRAVAIL","SESSION DATA":"DONNÉES DE SESSION","AUTOMATION CORE":"NOYAU D’AUTOMATISATION","Design your\nnext sequence.":"Créez votre\nséquence.","Precision input. Infinite possibilities.":"Saisie précise. Possibilités infinies.","RUN SEQUENCE":"DÉMARRER","EXECUTION PARAMETERS":"PARAMÈTRES","Timing, repetition and feedback":"Tempo, répétition et alertes","INTERFACE LANGUAGE":"LANGUE DE L’INTERFACE","Language":"Langue","Global delay":"Délai global","Infinite loop":"Boucle infinie","Repeat count":"Répétitions","Pre-run countdown":"Compte à rebours","Completion sound":"Son de fin"],
            "Deutsch":["Command deck":"Übersicht","Action library":"Aktionsbibliothek","Settings":"Einstellungen","WORKSPACE":"ARBEITSBEREICH","SESSION DATA":"SITZUNGSDATEN","AUTOMATION CORE":"AUTOMATISIERUNGSKERN","Design your\nnext sequence.":"Gestalte deine\nSequenz.","Precision input. Infinite possibilities.":"Präzise Eingabe. Unendliche Möglichkeiten.","RUN SEQUENCE":"STARTEN","EXECUTION PARAMETERS":"AUSFÜHRUNG","Timing, repetition and feedback":"Timing, Wiederholung und Feedback","INTERFACE LANGUAGE":"OBERFLÄCHENSPRACHE","Language":"Sprache","Global delay":"Globale Verzögerung","Infinite loop":"Endlosschleife","Repeat count":"Wiederholungen","Pre-run countdown":"Countdown","Completion sound":"Abschlusston"],
            "Italiano":["Command deck":"Pannello","Action library":"Libreria azioni","Settings":"Impostazioni","WORKSPACE":"AREA DI LAVORO","SESSION DATA":"DATI SESSIONE","AUTOMATION CORE":"NUCLEO AUTOMAZIONE","Design your\nnext sequence.":"Crea la tua\nsequenza.","Precision input. Infinite possibilities.":"Input preciso. Possibilità infinite.","RUN SEQUENCE":"AVVIA","EXECUTION PARAMETERS":"PARAMETRI","Timing, repetition and feedback":"Tempi, ripetizioni e avvisi","INTERFACE LANGUAGE":"LINGUA INTERFACCIA","Language":"Lingua","Global delay":"Ritardo globale","Infinite loop":"Ciclo infinito","Repeat count":"Ripetizioni","Pre-run countdown":"Conto alla rovescia","Completion sound":"Suono finale"],
            "Português":["Command deck":"Painel principal","Action library":"Biblioteca de ações","Settings":"Configurações","WORKSPACE":"ESPAÇO DE TRABALHO","SESSION DATA":"DADOS DA SESSÃO","AUTOMATION CORE":"NÚCLEO DE AUTOMAÇÃO","Design your\nnext sequence.":"Crie sua\nsequência.","Precision input. Infinite possibilities.":"Entrada precisa. Possibilidades infinitas.","RUN SEQUENCE":"EXECUTAR","EXECUTION PARAMETERS":"PARÂMETROS","Timing, repetition and feedback":"Tempo, repetição e alertas","INTERFACE LANGUAGE":"IDIOMA DA INTERFACE","Language":"Idioma","Global delay":"Atraso global","Infinite loop":"Loop infinito","Repeat count":"Repetições","Pre-run countdown":"Contagem regressiva","Completion sound":"Som de conclusão"],
            "Polski":["Command deck":"Panel główny","Action library":"Biblioteka akcji","Settings":"Ustawienia","WORKSPACE":"OBSZAR ROBOCZY","SESSION DATA":"DANE SESJI","AUTOMATION CORE":"SILNIK AUTOMATYZACJI","Design your\nnext sequence.":"Zaprojektuj\nsekwencję.","Precision input. Infinite possibilities.":"Precyzyjne wejście. Nieskończone możliwości.","RUN SEQUENCE":"URUCHOM","EXECUTION PARAMETERS":"PARAMETRY","Timing, repetition and feedback":"Czas, powtórzenia i alerty","INTERFACE LANGUAGE":"JĘZYK INTERFEJSU","Language":"Język","Global delay":"Opóźnienie","Infinite loop":"Pętla bez końca","Repeat count":"Liczba powtórzeń","Pre-run countdown":"Odliczanie","Completion sound":"Dźwięk końcowy"],
            "Türkçe":["Command deck":"Kontrol paneli","Action library":"Eylem kitaplığı","Settings":"Ayarlar","WORKSPACE":"ÇALIŞMA ALANI","SESSION DATA":"OTURUM VERİSİ","AUTOMATION CORE":"OTOMASYON ÇEKİRDEĞİ","Design your\nnext sequence.":"Sıradaki dizini\ntasarla.","Precision input. Infinite possibilities.":"Hassas giriş. Sonsuz olasılık.","RUN SEQUENCE":"BAŞLAT","EXECUTION PARAMETERS":"ÇALIŞTIRMA AYARLARI","Timing, repetition and feedback":"Zamanlama, tekrar ve bildirim","INTERFACE LANGUAGE":"ARAYÜZ DİLİ","Language":"Dil","Global delay":"Genel gecikme","Infinite loop":"Sonsuz döngü","Repeat count":"Tekrar sayısı","Pre-run countdown":"Geri sayım","Completion sound":"Tamamlanma sesi"],
            "日本語":["Command deck":"コントロールパネル","Action library":"アクションライブラリ","Settings":"設定","WORKSPACE":"ワークスペース","SESSION DATA":"セッションデータ","AUTOMATION CORE":"自動化エンジン","Design your\nnext sequence.":"次のシーケンスを\nデザイン。","Precision input. Infinite possibilities.":"正確な入力。無限の可能性。","RUN SEQUENCE":"実行","EXECUTION PARAMETERS":"実行パラメータ","Timing, repetition and feedback":"タイミング・繰り返し・通知","INTERFACE LANGUAGE":"表示言語","Language":"言語","Global delay":"全体の遅延","Infinite loop":"無限ループ","Repeat count":"繰り返し回数","Pre-run countdown":"開始カウントダウン","Completion sound":"完了音"],
            "中文":["Command deck":"控制面板","Action library":"动作库","Settings":"设置","WORKSPACE":"工作区","SESSION DATA":"会话数据","AUTOMATION CORE":"自动化核心","Design your\nnext sequence.":"设计你的\n自动化序列。","Precision input. Infinite possibilities.":"精准输入，无限可能。","RUN SEQUENCE":"运行序列","EXECUTION PARAMETERS":"执行参数","Timing, repetition and feedback":"时间、重复与反馈","INTERFACE LANGUAGE":"界面语言","Language":"语言","Global delay":"全局延迟","Infinite loop":"无限循环","Repeat count":"重复次数","Pre-run countdown":"启动倒计时","Completion sound":"完成提示音"]
        ]
        let extra: [String:String] = language == "Русский" ? [
            "ACTION MODULES":"МОДУЛИ ДЕЙСТВИЙ", "ACTIVE STEPS":"АКТИВНЫЕ ШАГИ",
            "COMPLETED CYCLES":"ЗАВЕРШЁННЫЕ ЦИКЛЫ", "ACCESSIBILITY":"УНИВЕРСАЛЬНЫЙ ДОСТУП",
            "AUTHORIZED":"РАЗРЕШЕНО", "NOT AUTHORIZED":"НЕТ РАЗРЕШЕНИЯ",
            "TOTAL ACTIONS":"ВСЕГО ДЕЙСТВИЙ", "TOTAL STEPS":"ВСЕГО ШАГОВ",
            "EST. CYCLE":"ОЦЕНКА ЦИКЛА", "ESTIMATED CYCLE":"ОЦЕНКА ЦИКЛА",
            "LAST RUN DURATION":"ВРЕМЯ ПОСЛЕДНЕГО ЗАПУСКА", "SYSTEM TELEMETRY":"СИСТЕМНАЯ СТАТИСТИКА",
            "LIVE ENGINE":"ДВИЖОК В РЕАЛЬНОМ ВРЕМЕНИ", "SEQUENCE TIMELINE":"ПОСЛЕДОВАТЕЛЬНОСТЬ",
            "Your macro architecture":"Структура макроса", "Sequence name":"Название последовательности",
            "Filter actions…":"Поиск действий…", "Show disabled":"Показывать отключённые",
            "TIMELINE EMPTY":"ПОСЛЕДОВАТЕЛЬНОСТЬ ПУСТА", "Add a module or keyboard action below":"Добавьте модуль или клавишу ниже",
            "TEXT PAYLOAD":"ТЕКСТОВЫЙ БЛОК", "Type a phrase to inject into the sequence…":"Введите текст для вставки…",
            "More than keyboard input":"Не только клавиатура", "Compose keyboard combinations":"Составляйте сочетания клавиш",
            "WAIT":"ОЖИДАНИЕ", "Pause / 1 sec":"Пауза / 1 сек.", "TEXT BLOCK":"ТЕКСТОВЫЙ БЛОК",
            "Inject phrase":"Вставить фразу", "PASTE":"ВСТАВИТЬ", "COPY":"КОПИРОВАТЬ",
            "SELECT ALL":"ВЫДЕЛИТЬ ВСЁ", "UNDO":"ОТМЕНИТЬ", "MOUSE CLICK":"КЛИК МЫШЬЮ",
            "Current pointer position":"Текущая позиция курсора", "DOUBLE CLICK":"ДВОЙНОЙ КЛИК",
            "Two rapid clicks":"Два быстрых нажатия", "SCROLL DOWN":"ПРОКРУТКА ВНИЗ",
            "Scroll 260 px":"Прокрутка на 260 пикс.", "IMPORT":"ИМПОРТ", "EXPORT":"ЭКСПОРТ",
            "RESET":"СБРОСИТЬ", "Pause for this step":"Задержка этого шага",
            "SYSTEM ONLINE":"СИСТЕМА АКТИВНА", "EXECUTING":"ВЫПОЛНЕНИЕ", "CORE":"ЯДРО",
            "ACTIVE":"АКТИВНО", "MACRO ENGINE":"ДВИЖОК МАКРОСОВ",
            "NEURAL AUTOMATION SYSTEM  /  BUILD 04.0":"СИСТЕМА АВТОМАТИЗАЦИИ / СБОРКА 04.0",
            "SEQUENCE COMPLETE":"ПОСЛЕДОВАТЕЛЬНОСТЬ ЗАВЕРШЕНА",
            "SEQUENCE HALTED":"ПОСЛЕДОВАТЕЛЬНОСТЬ ОСТАНОВЛЕНА",
            "KEY ADDED":"КЛАВИША ДОБАВЛЕНА", "TEXT BLOCK ADDED":"ТЕКСТОВЫЙ БЛОК ДОБАВЛЕН",
            "WAIT STEP ADDED":"ШАГ ОЖИДАНИЯ ДОБАВЛЕН", "MOUSE ACTION ADDED":"ДЕЙСТВИЕ МЫШИ ДОБАВЛЕНО",
            "PRESET APPENDED":"ШАБЛОН ДОБАВЛЕН", "EXPORTED SUCCESSFULLY":"ЭКСПОРТ ВЫПОЛНЕН",
            "IMPORT ERROR":"ОШИБКА ИМПОРТА", "EXPORT ERROR":"ОШИБКА ЭКСПОРТА",
            "TIMELINE RESET":"ПОСЛЕДОВАТЕЛЬНОСТЬ СБРОШЕНА",
            "ACCESSIBILITY PERMISSION REQUIRED":"ТРЕБУЕТСЯ РАЗРЕШЕНИЕ УНИВЕРСАЛЬНОГО ДОСТУПА",
            "EXECUTION PARAMETERS":"ПАРАМЕТРЫ ВЫПОЛНЕНИЯ",
            "Timing, repetition and feedback":"Тайминг, повторы и уведомления",
            "Each step can be disabled, duplicated, reordered and assigned an individual pause.":"Каждый шаг можно отключить, дублировать, перемещать и настроить индивидуальную задержку."
        ] : [:]
        return tables[language]?[key] ?? extra[key] ?? key
    }
    private func section(_ n:String,_ title:String,_ sub:String)->some View {
        HStack(alignment:.top,spacing:10){Text(n).font(.system(size:9,weight:.black,design:.monospaced)).foregroundStyle(cyan).padding(.top,2);VStack(alignment:.leading,spacing:3){Text(tr(title)).font(.system(size:11,weight:.black,design:.monospaced)).tracking(1.2);Text(tr(sub)).font(.system(size:9)).foregroundStyle(.white.opacity(0.35))};Spacer();LinearGradient(colors:[cyan.opacity(0.5),.clear],startPoint:.leading,endPoint:.trailing).frame(width:65,height:1).padding(.top,7)}
    }
    private func smallButton(_ t:String,_ i:String,action:@escaping()->Void)->some View {Button(action:action){Label(tr(t),systemImage:i).font(.system(size:8,weight:.bold,design:.monospaced)).padding(.horizontal,8).padding(.vertical,7).background(.white.opacity(0.045),in:RoundedRectangle(cornerRadius:6))}.buttonStyle(.plain).foregroundStyle(.white.opacity(0.65))}
    private func iconButton(_ i:String,disabled:Bool=false,tint:Color = .white.opacity(0.5),action:@escaping()->Void)->some View {Button(action:action){Image(systemName:i).font(.system(size:9,weight:.bold)).frame(width:21,height:21)}.buttonStyle(.plain).foregroundStyle(tint).disabled(disabled).opacity(disabled ? 0.18:1)}
}
struct CyberPressStyle: ButtonStyle {
    func makeBody(configuration:Configuration)->some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.975:1)
    }
}
private extension View {
    func panel()->some View{background(LinearGradient(colors:[Color(red:0.095,green:0.11,blue:0.105).opacity(0.96),Color(red:0.045,green:0.052,blue:0.05).opacity(0.98)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:19)).overlay(RoundedRectangle(cornerRadius:19).stroke(LinearGradient(colors:[.white.opacity(0.13),Color(red:0.76,green:1,blue:0.02).opacity(0.11),.white.opacity(0.025)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:1)).shadow(color:.black.opacity(0.16),radius:16,y:7)}
}