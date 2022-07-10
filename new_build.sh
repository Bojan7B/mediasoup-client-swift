# Stop script on errors.
set -e

# Define working directories.
export PROJECT_DIR=$(pwd)
echo "PROJECT_DIR = $PROJECT_DIR"
export WORK_DIR=$PROJECT_DIR/Mediasoup/dependencies
echo "WORK_DIR = $WORK_DIR"
export BUILD_DIR=$(pwd)/build
echo "BUILD_DIR = $BUILD_DIR"
export OUTPUT_DIR=$(pwd)/bin
echo "OUTPUT_DIR = $OUTPUT_DIR"
export PATCHES_DIR=$(pwd)/patches
echo "PATCHES_DIR = $PATCHES_DIR"
export WEBRTC_DIR=$PROJECT_DIR/Mediasoup/dependencies/webrtc/src
echo "WEBRTC_DIR = $WEBRTC_DIR"

cd $WORK_DIR

# Build mediasoup-client-ios
cmake . -B$BUILD_DIR/libmediasoupclient/device/arm64 \
        -DLIBWEBRTC_INCLUDE_PATH=$WEBRTC_DIR \
        -DLIBWEBRTC_BINARY_PATH=$BUILD_DIR/WebRTC/device/arm64/WebRTC.framework/WebRTC \
        -DMEDIASOUP_LOG_TRACE=ON \
        -DMEDIASOUP_LOG_DEV=ON \
        -DCMAKE_CXX_FLAGS="-fvisibility=hidden" \
        -DLIBSDPTRANSFORM_BUILD_TESTS=OFF \
        -DIOS_SDK=iphone \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=14 \
        -DIOS_ARCHS="arm64" \
        -DPLATFORM=OS64 \
        -DCMAKE_OSX_SYSROOT="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"

cmake . -B$BUILD_DIR/libmediasoupclient/simulator/x64 \
        -DLIBWEBRTC_INCLUDE_PATH=$WEBRTC_DIR \
        -DLIBWEBRTC_BINARY_PATH=$BUILD_DIR/WebRTC/simulator/x64/WebRTC.framework/WebRTC \
        -DMEDIASOUP_LOG_TRACE=ON \
        -DMEDIASOUP_LOG_DEV=ON \
        -DCMAKE_CXX_FLAGS="-fvisibility=hidden" \
        -DLIBSDPTRANSFORM_BUILD_TESTS=OFF \
        -DIOS_SDK=iphonesimulator \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=14 \
        -DIOS_ARCHS="x86_64" \
        -DPLATFORM=SIMULATOR64 \
        -DCMAKE_OSX_SYSROOT="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
make -C $BUILD_DIR/libmediasoupclient/simulator/x64

cmake . -B$BUILD_DIR/libmediasoupclient/simulator/arm64 \
        -DLIBWEBRTC_INCLUDE_PATH=$WEBRTC_DIR \
        -DLIBWEBRTC_BINARY_PATH=$BUILD_DIR/WebRTC/simulator/arm64/WebRTC.framework/WebRTC \
        -DMEDIASOUP_LOG_TRACE=ON \
        -DMEDIASOUP_LOG_DEV=ON \
        -DCMAKE_CXX_FLAGS="-fvisibility=hidden" \
        -DLIBSDPTRANSFORM_BUILD_TESTS=OFF \
        -DIOS_SDK=iphonesimulator \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=14 \
        -DIOS_ARCHS="arm64"\
        -DPLATFORM=SIMULATORARM64 \
        -DCMAKE_OSX_SYSROOT="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
make -C $BUILD_DIR/libmediasoupclient/simulator/arm64

# Create a FAT libmediasoup / libsdptransform library
mkdir -p $BUILD_DIR/libmediasoupclient/simulator/fat
lipo -create \
        $BUILD_DIR/libmediasoupclient/simulator/x64/libmediasoupclient/libmediasoupclient.a \
        $BUILD_DIR/libmediasoupclient/simulator/arm64/libmediasoupclient/libmediasoupclient.a \
        -output $BUILD_DIR/libmediasoupclient/simulator/fat/libmediasoupclient.a
lipo -create \
        $BUILD_DIR/libmediasoupclient/simulator/x64/libmediasoupclient/libsdptransform/libsdptransform.a \
        $BUILD_DIR/libmediasoupclient/simulator/arm64/libmediasoupclient/libsdptransform/libsdptransform.a \
        -output $BUILD_DIR/libmediasoupclient/simulator/fat/libsdptransform.a
xcodebuild -create-xcframework \
        -library $BUILD_DIR/libmediasoupclient/device/arm64/libmediasoupclient/libmediasoupclient.a \
        -library $BUILD_DIR/libmediasoupclient/simulator/fat/libmediasoupclient.a \
        -output $OUTPUT_DIR/mediasoupclient.xcframework
xcodebuild -create-xcframework \
        -library $BUILD_DIR/libmediasoupclient/device/arm64/libmediasoupclient/libsdptransform/libsdptransform.a \
        -library $BUILD_DIR/libmediasoupclient/simulator/fat/libsdptransform.a \
        -output $OUTPUT_DIR/sdptransform.xcframework

cp $PATCHES_DIR/byte_order.h $WORK_DIR/webrtc/src/rtc_base/
open $PROJECT_DIR/Mediasoup.xcodeproj
