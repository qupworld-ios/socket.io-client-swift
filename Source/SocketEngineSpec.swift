//
//  SocketEngineSpec.swift
//  Socket.IO-Client-Swift
//
//  Created by Erik Little on 10/7/15.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

/// Specifies a SocketEngine.
@objc public protocol SocketEngineSpecV1 {
    /// The client for this engine.
    weak var client: SocketEngineClientV1? { get set }

    /// `true` if this engine is closed.
    var closed: Bool { get }

    /// `true` if this engine is connected. Connected means that the initial poll connect has succeeded.
    var connected: Bool { get }

    /// The connect parameters sent during a connect.
    var connectParams: [String: Any]? { get set }

    /// Set to `true` if using the node.js version of socket.io. The node.js version of socket.io
    /// handles utf8 incorrectly.
    var doubleEncodeUTF8: Bool { get }

    /// An array of HTTPCookies that are sent during the connection.
    var cookies: [HTTPCookie]? { get }

    /// The queue that all engine actions take place on.
    var engineQueue: DispatchQueue { get }

    /// A dictionary of extra http headers that will be set during connection.
    var extraHeaders: [String: String]? { get }

    /// When `true`, the engine is in the process of switching to WebSockets.
    var fastUpgrade: Bool { get }

    /// When `true`, the engine will only use HTTP long-polling as a transport.
    var forcePolling: Bool { get }

    /// When `true`, the engine will only use WebSockets as a transport.
    var forceWebsockets: Bool { get }

    /// If `true`, the engine is currently in HTTP long-polling mode.
    var polling: Bool { get }

    /// If `true`, the engine is currently seeing whether it can upgrade to WebSockets.
    var probing: Bool { get }

    /// The session id for this engine.
    var sid: String { get }

    /// The path to engine.io.
    var socketPath: String { get }

    /// The url for polling.
    var urlPolling: URL { get }

    /// The url for WebSockets.
    var urlWebSocket: URL { get }

    /// If `true`, then the engine is currently in WebSockets mode.
    var websocket: Bool { get }

    /// The WebSocket for this engine.
    var ws: WebSocketV1? { get }

    /// Creates a new engine.
    ///
    /// - parameter client: The client for this engine.
    /// - parameter url: The url for this engine.
    /// - parameter options: The options for this engine.
    init(client: SocketEngineClientV1, url: URL, options: NSDictionary?)

    /// Starts the connection to the server.
    func connect()

    /// Called when an error happens during execution. Causes a disconnection.
    func didError(reason: String)

    /// Disconnects from the server.
    ///
    /// - parameter reason: The reason for the disconnection. This is communicated up to the client.
    func disconnect(reason: String)

    /// Called to switch from HTTP long-polling to WebSockets. After calling this method the engine will be in
    /// WebSocket mode.
    ///
    /// **You shouldn't call this directly**
    func doFastUpgrade()

    /// Causes any packets that were waiting for POSTing to be sent through the WebSocket. This happens because when
    /// the engine is attempting to upgrade to WebSocket it does not do any POSTing.
    ///
    /// **You shouldn't call this directly**
    func flushWaitingForPostToWebSocket()

    /// Parses raw binary received from engine.io.
    ///
    /// - parameter data: The data to parse.
    func parseEngineData(_ data: Data)

    /// Parses a raw engine.io packet.
    ///
    /// - parameter message: The message to parse.
    /// - parameter fromPolling: Whether this message is from long-polling.
    ///                          If `true` we might have to fix utf8 encoding.
    func parseEngineMessage(_ message: String, fromPolling: Bool)

    /// Writes a message to engine.io, independent of transport.
    ///
    /// - parameter msg: The message to send.
    /// - parameter withType: The type of this message.
    /// - parameter withData: Any data that this message has.
    func write(_ msg: String, withType type: SocketEnginePacketTypeV1, withData data: [Data])
}

extension SocketEngineSpecV1 {
    var urlPollingWithSid: URL {
        var com = URLComponents(url: urlPolling, resolvingAgainstBaseURL: false)!
        com.percentEncodedQuery = com.percentEncodedQuery! + "&sid=\(sid.urlEncode()!)"

        return com.url!
    }

    var urlWebSocketWithSid: URL {
        var com = URLComponents(url: urlWebSocket, resolvingAgainstBaseURL: false)!
        com.percentEncodedQuery = com.percentEncodedQuery! + (sid == "" ? "" : "&sid=\(sid.urlEncode()!)")

        return com.url!
    }

    func createBinaryDataForSend(using data: Data) -> Either<Data, String> {
        if websocket {
            var byteArray = [UInt8](repeating: 0x4, count: 1)
            let mutData = NSMutableData(bytes: &byteArray, length: 1)

            mutData.append(data)

            return .left(mutData as Data)
        } else {
            let str = "b4" + data.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))

            return .right(str)
        }
    }

    func doubleEncodeUTF8(_ string: String) -> String {
        if let latin1 = string.data(using: String.Encoding.utf8),
            let utf8 = NSString(data: latin1, encoding: String.Encoding.isoLatin1.rawValue) {
                return utf8 as String
        } else {
            return string
        }
    }

    func fixDoubleUTF8(_ string: String) -> String {
        if let utf8 = string.data(using: String.Encoding.isoLatin1),
            let latin1 = NSString(data: utf8, encoding: String.Encoding.utf8.rawValue) {
                return latin1 as String
        } else {
            return string
        }
    }

    /// Send an engine message (4)
    func send(_ msg: String, withData datas: [Data]) {
        write(msg, withType: .message, withData: datas)
    }
}
