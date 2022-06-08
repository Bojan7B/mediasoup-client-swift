#import <Device.hpp>
#import <api/audio_codecs/builtin_audio_encoder_factory.h>
#import <api/audio_codecs/builtin_audio_decoder_factory.h>
#import <sdk/objc/native/api/audio_device_module.h>
#import <sdk/objc/components/video_codec/RTCDefaultVideoDecoderFactory.h>
#import <sdk/objc/components/video_codec/RTCDefaultVideoEncoderFactory.h>
#import <sdk/objc/native/src/objc_video_encoder_factory.h>
#import <sdk/objc/native/src/objc_video_decoder_factory.h>
#import <peerconnection/RTCPeerConnectionFactory.h>
#import <peerconnection/RTCPeerConnectionFactoryBuilder.h>
#import <peerconnection/RTCPeerConnectionFactory+Private.h>
#import "DeviceWrapper.h"
#import "../MediasoupClientError/MediasoupClientErrorHandler.h"
#import "../Transport/SendTransportWrapper.hpp"
#import "../Transport/SendTransportListenerAdapter.hpp"
#import "../Transport/ReceiveTransportWrapper.hpp"
#import "../Transport/ReceiveTransportListenerAdapter.hpp"


@interface DeviceWrapper() {
	mediasoupclient::Device *_device;
	mediasoupclient::PeerConnection::Options *_pcOptions;
}
@property(nonatomic, strong) RTCPeerConnectionFactoryBuilder *pcFactoryBuilder;
@property(nonatomic, strong) RTCPeerConnectionFactory *pcFactory;
@property(nonatomic, assign) rtc::scoped_refptr<webrtc::AudioDeviceModule> audioDeviceModule;
@end


@implementation DeviceWrapper

- (instancetype)init {
	self = [super init];
	if (self != nil) {
		_device = new mediasoupclient::Device();

		self.audioDeviceModule = webrtc::CreateAudioDeviceModule();

		auto audioEncoderFactory = webrtc::CreateBuiltinAudioEncoderFactory();
		auto audioDecoderFactory = webrtc::CreateBuiltinAudioDecoderFactory();
		auto videoEncoderFactory = std::make_unique<webrtc::ObjCVideoEncoderFactory>(
			[[RTCDefaultVideoEncoderFactory alloc] init]
		);
		auto videoDecoderFactory = std::make_unique<webrtc::ObjCVideoDecoderFactory>(
			[[RTCDefaultVideoDecoderFactory alloc] init]
		);

		self.pcFactoryBuilder = [[RTCPeerConnectionFactoryBuilder alloc] init];
		[self.pcFactoryBuilder setAudioEncoderFactory:audioEncoderFactory];
		[self.pcFactoryBuilder setAudioDecoderFactory:audioDecoderFactory];
		[self.pcFactoryBuilder setVideoEncoderFactory:std::move(videoEncoderFactory)];
		[self.pcFactoryBuilder setVideoDecoderFactory:std::move(videoDecoderFactory)];
		[self.pcFactoryBuilder setAudioDeviceModule:self.audioDeviceModule];

		self.pcFactory = [self.pcFactoryBuilder createPeerConnectionFactory];
		_pcOptions = new mediasoupclient::PeerConnection::Options();
		_pcOptions->factory = self.pcFactory.nativeFactory;
	}
	return self;
}

- (void)dealloc {
	delete _device;
	delete _pcOptions;

	// Properties are released explicitly to manage deallocation order.
	// PeerConnection must be released before PeerConnectionBuilder.
	self.pcFactoryBuilder = nil;
	self.pcFactory = nil;
	self.audioDeviceModule = nil;
}

- (BOOL)isLoaded {
	return _device->IsLoaded();
}

- (void)loadWithRouterRTPCapabilities:(NSString *)routerRTPCapabilities
	error:(out NSError *__autoreleasing _Nullable *_Nullable)error {

	mediasoupTry(^{
		auto routerRTPCapabilitiesString = std::string(routerRTPCapabilities.UTF8String);
		auto routerRTPCapabilitiesJSON = nlohmann::json::parse(routerRTPCapabilitiesString);
		self->_device->Load(routerRTPCapabilitiesJSON, self->_pcOptions);
	}, error);
}

- (NSString *_Nullable)sctpCapabilitiesWithError:(out NSError *__autoreleasing _Nullable *_Nullable)error {
	return mediasoupTryWithResult(^ NSString * {
		nlohmann::json const capabilities = self->_device->GetSctpCapabilities();
		return [NSString stringWithCString:capabilities.dump().c_str() encoding:NSUTF8StringEncoding];
	}, nil, error);
}

- (NSString *_Nullable)rtpCapabilitiesWithError:(out NSError *__autoreleasing _Nullable *_Nullable)error {
	return mediasoupTryWithResult(^ NSString * {
		nlohmann::json const capabilities = self->_device->GetRtpCapabilities();
		return [NSString stringWithCString:capabilities.dump().c_str() encoding:NSUTF8StringEncoding];
	}, nil, error);
}

- (BOOL)canProduce:(MediasoupClientMediaKind _Nonnull)mediaKind
	error:(out NSError *__autoreleasing _Nullable *_Nullable)error {

	return mediasoupTryWithBool(^ BOOL {
		return self->_device->CanProduce(std::string([mediaKind UTF8String]));
	}, error);
}

- (SendTransportWrapper *_Nullable)createSendTransportWithId:(NSString *_Nonnull)transportId
	iceParameters:(NSString *_Nonnull)iceParameters
	iceCandidates:(NSString *_Nonnull)iceCandidates
	dtlsParameters:(NSString *_Nonnull)dtlsParameters
	sctpParameters:(NSString *_Nullable)sctpParameters
	appData:(NSString *_Nullable)appData
	error:(out NSError *__autoreleasing _Nullable *_Nullable)error {

	auto listenerAdapter = new SendTransportListenerAdapter();

	try {
		auto idString = std::string(transportId.UTF8String);
		auto iceParametersString = std::string(iceParameters.UTF8String);
		auto iceParametersJSON = nlohmann::json::parse(iceParametersString);
		auto iceCandidatesString = std::string(iceCandidates.UTF8String);
		auto iceCandidatesJSON = nlohmann::json::parse(iceCandidatesString);
		auto dtlsParametersString = std::string(dtlsParameters.UTF8String);
		auto dtlsParametersJSON = nlohmann::json::parse(dtlsParametersString);

		nlohmann::json sctpParametersJSON;
		if (sctpParameters != nil) {
			auto sctpParametersString = std::string(sctpParameters.UTF8String);
			sctpParametersJSON = nlohmann::json::parse(sctpParametersString);
		}

		nlohmann::json appDataJSON = nlohmann::json::object();
		if (appData != nil) {
			auto appDataString = std::string(appData.UTF8String);
			appDataJSON = nlohmann::json::parse(appDataString);
		}

		auto transport = _device->CreateSendTransport(
			listenerAdapter,
			idString,
			iceParametersJSON,
			iceCandidatesJSON,
			dtlsParametersJSON,
			sctpParametersJSON,
			self->_pcOptions,
			appDataJSON
		);
		auto transportWrapper = [[SendTransportWrapper alloc] initWithTransport:transport listenerAdapter:listenerAdapter];
		return transportWrapper;
	} catch(const std::exception &e) {
		delete listenerAdapter;
		*error = mediasoupError(MediasoupClientErrorCodeInvalidParameters, &e);
		return nil;
	}
}

- (ReceiveTransportWrapper *_Nullable)createReceiveTransportWithId:(NSString *_Nonnull)transportId
	iceParameters:(NSString *_Nonnull)iceParameters
	iceCandidates:(NSString *_Nonnull)iceCandidates
	dtlsParameters:(NSString *_Nonnull)dtlsParameters
	sctpParameters:(NSString *_Nullable)sctpParameters
	appData:(NSString *_Nullable)appData
	error:(out NSError *__autoreleasing _Nullable *_Nullable)error {

	auto listenerAdapter = new ReceiveTransportListenerAdapter();

	try {
		auto idString = std::string(transportId.UTF8String);
		auto iceParametersString = std::string(iceParameters.UTF8String);
		auto iceParametersJSON = nlohmann::json::parse(iceParametersString);
		auto iceCandidatesString = std::string(iceCandidates.UTF8String);
		auto iceCandidatesJSON = nlohmann::json::parse(iceCandidatesString);
		auto dtlsParametersString = std::string(dtlsParameters.UTF8String);
		auto dtlsParametersJSON = nlohmann::json::parse(dtlsParametersString);

		nlohmann::json sctpParametersJSON;
		if (sctpParameters != nil) {
			auto sctpParametersString = std::string(sctpParameters.UTF8String);
			sctpParametersJSON = nlohmann::json::parse(sctpParametersString);
		}

		nlohmann::json appDataJSON = nlohmann::json::object();
		if (appData != nil) {
			auto appDataString = std::string(appData.UTF8String);
			appDataJSON = nlohmann::json::parse(appDataString);
		}

		auto transport = _device->CreateRecvTransport(
			listenerAdapter,
			idString,
			iceParametersJSON,
			iceCandidatesJSON,
			dtlsParametersJSON,
			sctpParametersJSON,
			self->_pcOptions,
			appDataJSON
		);
		auto transportWrapper = [[ReceiveTransportWrapper alloc]
			initWithTransport:transport
			pcFactory:self.pcFactory
			listenerAdapter:listenerAdapter
		];
		return transportWrapper;
	} catch(const std::exception &e) {
		delete listenerAdapter;
		*error = mediasoupError(MediasoupClientErrorCodeInvalidParameters, &e);
		return nil;
	}
}

@end
