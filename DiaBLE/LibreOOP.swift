import Foundation

// https://github.com/bubbledevteam/xdripswift/commit/07135da


struct OOPServer {
    var siteURL: String
    var token: String
    var calibrationEndpoint: String
    var historyEndpoint: String

    static let `default`: OOPServer = OOPServer(siteURL: "https://www.glucose.space",
                                                token: "bubble-201907",
                                                calibrationEndpoint: "calibrateSensor",
                                                historyEndpoint: "libreoop2")
}


struct HistoricGlucose: Codable {
    let dataQuality: Int
    let id: Int
    let value: Int
}

struct OOPHistoryData: Codable {
    var alarm: String
    var esaMinutesToWait: Int
    var historicGlucose: [HistoricGlucose]
    var isActionable: Bool
    var lsaDetected: Bool
    var realTimeGlucose: HistoricGlucose
    var trendArrow: String

    func glucoseData(sensorAge: Int, readingDate: Date) -> [Glucose] {
        var array = [Glucose]()
        var sensorAge = sensorAge
        if sensorAge == 0 { // encrpyted FRAM of the Libre 2
            sensorAge = realTimeGlucose.id // FIXME: can differ from 1 minute from the real age
        }
        let startDate = readingDate - Double(sensorAge) * 60
        // let current = Glucose(realTimeGlucose.value, id: realTimeGlucose.id, date: startDate + Double(realTimeGlucose.id * 60))
        var history = historicGlucose
        if (history.first?.id ?? 0) < (history.last?.id ?? 0) {
            history = history.reversed()
        }
        for g in history {
            let glucose = Glucose(g.value, id: g.id, date: startDate + Double(g.id * 60), source: "LibreOOP" )
            array.append(glucose)
        }
        return array
    }
}

struct OOPCalibrationResponse: Codable {
    let errcode: Int
    let parameters: Calibration
    enum CodingKeys: String, CodingKey {
        case errcode
        case parameters = "slope"
    }
}


func postToLibreOOP(server: OOPServer, bytes: Data = Data(), date: Date = Date(), patchUid: Data? = nil, patchInfo: Data? = nil, handler: @escaping (Data?, URLResponse?, Error?, [String: String]) -> Void) {
    let url = server.siteURL + "/" + (patchInfo == nil ? server.calibrationEndpoint : server.historyEndpoint)
    let date = Int64((date.timeIntervalSince1970 * 1000.0).rounded())
    var parameters = ["content": "\(bytes.hex)"]
    if let patchInfo = patchInfo {
        parameters["accesstoken"] = server.token
        parameters["patchUid"] = patchUid!.hex
        parameters["patchInfo"] = patchInfo.hex
    } else {
        parameters["token"] = server.token
        parameters["timestamp"] = "\(date)"
    }
    let request = NSMutableURLRequest(url: URL(string: url)!)
    request.httpMethod = "POST"
    request.httpBody = parameters.map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)" }.joined(separator: "&").data(using: .utf8)
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
        DispatchQueue.main.async {
            handler(data, response, error, parameters)
        }
    }.resume()
}


struct OOP {
    static func trendSymbol(for trend: String) -> String {
        switch trend {
        case "RISING_QUICKLY":  return "↑"
        case "RISING":          return "↗︎"
        case "STABLE":          return "→"
        case "FALLING":         return "↘︎"
        case "FALLING_QUICKLY": return "↓"
        default:                return "---" // NOT_DETERMINED
        }
    }
    static func alarmDescription(for alarm: String) -> String {
        switch alarm {
        case "PROJECTED_HIGH_GLUCOSE": return "VERY HIGH"
        case "HIGH_GLUCOSE":           return "HIGH"
        case "GLUCOSE_OK":             return "OK"
        case "LOW_GLUCOSE":            return "LOW"
        case "PROJECTED_LOW_GLUCOSE":  return "VERY LOW"
        default:                       return "" // NOT_DETERMINED
        }
    }
}
