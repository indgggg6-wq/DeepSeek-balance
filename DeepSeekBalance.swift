#!/usr/bin/env swift

import Cocoa
import Foundation

// MARK: - 模型
struct Config: Codable {
    var api_key: String = ""
    var base_url: String = "https://api.deepseek.com"
    var poll_interval_minutes: Int = 5
}

struct BalanceInfo: Codable {
    let currency: String
    let total_balance: String
    let granted_balance: String
    let topped_up_balance: String
}

struct BalanceResponse: Codable {
    let is_available: Bool
    let balance_infos: [BalanceInfo]
}

struct HistoryRecord: Codable {
    var timestamp: String
    var total: Double
}

// MARK: - Path helpers
let appDir = FileManager.default.currentDirectoryPath
func path(_ name: String) -> String {
    return (appDir as NSString).appendingPathComponent(name)
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var config = Config()
    var history: [HistoryRecord] = []
    let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; return f
    }()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        loadConfig()
        loadHistory()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "..."

        if let img = NSImage(contentsOfFile: path("icon.png")) {
            img.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = img
            statusItem.button?.imagePosition = .imageLeading
        }

        buildDefaultMenu()
        statusItem.menu = buildDefaultMenu()

        Timer.scheduledTimer(withTimeInterval: TimeInterval(config.poll_interval_minutes * 60), repeats: true) { _ in
            self.fetch()
        }
        fetch()
    }

    // MARK: - Menu
    func buildDefaultMenu() -> NSMenu {
        let m = NSMenu()
        m.autoenablesItems = false
        let r = addItem(m, "🔄 立即刷新", #selector(refresh))
        let s = addItem(m, "⚙️ 设置...", #selector(settings))
        m.addItem(.separator())
        let q = addItem(m, "❌ 退出", #selector(quitApp))
        return m
    }

    func buildFullMenu(_ info: BalanceInfo) -> NSMenu {
        let m = NSMenu()
        m.autoenablesItems = false
        let s = info.currency == "CNY" ? "¥" : "$"
        let t = Float(info.total_balance) ?? 0
        let g = Float(info.granted_balance) ?? 0
        let p = Float(info.topped_up_balance) ?? 0

        addDisabled(m, "📊 总余额: \(s)\(String(format: "%.2f", t))")
        addDisabled(m, "🎁 赠送余额: \(s)\(String(format: "%.2f", g))")
        addDisabled(m, "💳 充值余额: \(s)\(String(format: "%.2f", p))")
        m.addItem(.separator())
        let usage = todayUsage()
        if usage > 0 {
            addDisabled(m, "📉 今日使用: -\(s)\(String(format: "%.2f", usage))")
        }
        m.addItem(.separator())
        addItem(m, "🔄 立即刷新", #selector(refresh))
        addItem(m, "⚙️ 设置...", #selector(settings))
        m.addItem(.separator())
        addItem(m, "❌ 退出", #selector(quitApp))
        return m
    }

    func addDisabled(_ menu: NSMenu, _ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    func addItem(_ menu: NSMenu, _ title: String, _ sel: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    // MARK: - Config
    func loadConfig() {
        if let d = try? Data(contentsOf: URL(fileURLWithPath: path("config.json"))),
           let c = try? JSONDecoder().decode(Config.self, from: d) {
            config = c
        }
    }

    func saveConfig() {
        if let d = try? JSONEncoder().encode(config) {
            try? d.write(to: URL(fileURLWithPath: path("config.json")))
        }
    }

    // MARK: - History (JSON file)
    func loadHistory() {
        if let d = try? Data(contentsOf: URL(fileURLWithPath: path("data/history.json"))),
           let h = try? JSONDecoder().decode([HistoryRecord].self, from: d) {
            history = h
        }
    }

    func saveHistory() {
        let dir = path("data")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(history) {
            try? d.write(to: URL(fileURLWithPath: path("data/history.json")))
        }
    }

    func todayUsage() -> Float {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())
        let todayRecords = history.filter { $0.timestamp.hasPrefix(today) }
        guard let first = todayRecords.first, let last = todayRecords.last else { return 0 }
        return Float(first.total - last.total)
    }

    // MARK: - API
    func fetch() {
        guard !config.api_key.isEmpty else {
            DispatchQueue.main.async { self.showError("请先设置 API Key") }
            return
        }
        let url = URL(string: "\(config.base_url)/user/balance")!
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(config.api_key)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, resp, error in
            if let e = error {
                DispatchQueue.main.async { self.showError(e.localizedDescription) }
                return
            }
            guard let d = data, let http = resp as? HTTPURLResponse else {
                DispatchQueue.main.async { self.showError("无响应") }
                return
            }
            if http.statusCode == 401 {
                DispatchQueue.main.async { self.showError("API Key 无效") }
                return
            }
            guard http.statusCode == 200,
                  let bal = try? JSONDecoder().decode(BalanceResponse.self, from: d),
                  let info = bal.balance_infos.first else {
                DispatchQueue.main.async { self.showError("解析失败") }
                return
            }
            DispatchQueue.main.async { self.update(info: info) }

            // 保存历史
            let rec = HistoryRecord(
                timestamp: self.dateFmt.string(from: Date()),
                total: Double(info.total_balance) ?? 0
            )
            self.history.append(rec)
            if self.history.count > 10000 { self.history.removeFirst(1000) }
            self.saveHistory()
        }.resume()
    }

    func update(info: BalanceInfo) {
        let s = info.currency == "CNY" ? "¥" : "$"
        let t = Float(info.total_balance) ?? 0
        statusItem.button?.title = "\(s)\(String(format: "%.2f", t))"
        statusItem.menu = buildFullMenu(info)
    }

    func showError(_ msg: String) {
        statusItem.button?.title = "⚠️"
        let m = NSMenu()
        m.autoenablesItems = false
        addDisabled(m, "❌ \(msg)")
        m.addItem(.separator())
        addItem(m, "🔄 重试", #selector(refresh))
        addItem(m, "⚙️ 设置...", #selector(settings))
        m.addItem(.separator())
        addItem(m, "❌ 退出", #selector(quitApp))
        statusItem.menu = m
    }

    @objc func refresh() {
        statusItem.button?.title = "..."
        fetch()
    }

    @objc func settings() {
        let alert = NSAlert()
        alert.messageText = "设置 API Key"
        alert.informativeText = "请输入 DeepSeek API Key："
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        tf.placeholderString = "sk-..."
        tf.stringValue = config.api_key
        alert.accessoryView = tf

        if alert.runModal() == .alertFirstButtonReturn {
            let key = tf.stringValue.trimmingCharacters(in: .whitespaces)
            if !key.isEmpty {
                config.api_key = key
                saveConfig()
                refresh()
            }
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
