import Foundation
import Mediasoup_Private
import WebRTC


public class Device {
	private let device: DeviceWrapper

	public init() {
		self.device = DeviceWrapper()
	}

	public func isLoaded() -> Bool {
		return device.isLoaded()
	}

	public func load(with routerRTPCapabilities: String) throws {
		try convertMediasoupErrors {
			try device.load(with: routerRTPCapabilities)
		}
	}

	public func rtpCapabilities() throws -> String {
		try convertMediasoupErrors {
			try device.rtpCapabilities()
		}
	}

	public func sctpCapabilities() throws -> String {
		try convertMediasoupErrors {
			try device.sctpCapabilities()
		}
	}

	public func canProduce(_ mediaKind: MediaKind) throws -> Bool {
		try convertMediasoupErrors {
			try device.canProduce(mediaKind.mediaClientValue)
		}
	}

	public func createSendTransport(id: String, iceParameters: String, iceCandidates: String,
                                    dtlsParameters: String, sctpParameters: String?, appData: String?, config: RTCConfiguration) throws -> SendTransport {

		return try convertMediasoupErrors {
			let transport = try device.createSendTransport(withId: id, iceParameters: iceParameters,
				iceCandidates: iceCandidates, dtlsParameters: dtlsParameters,
                                                           sctpParameters: sctpParameters, appData: appData,
                                                           config: config)

			return SendTransport(transport: transport)
		}
	}
    
    public func testBla() {
        print("bla")
    }

	public func createReceiveTransport(id: String, iceParameters: String, iceCandidates: String,
		dtlsParameters: String, sctpParameters: String? = nil, appData: String? = nil, config: RTCConfiguration)
		throws -> ReceiveTransport {

		return try convertMediasoupErrors {
			let transport = try device.createReceiveTransport(withId: id, iceParameters: iceParameters,
				iceCandidates: iceCandidates, dtlsParameters: dtlsParameters,
                                                              sctpParameters: sctpParameters, appData: appData, config: config)

			return ReceiveTransport(transport: transport)
		}
	}
}
