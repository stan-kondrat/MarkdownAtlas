CC = gcc
CFLAGS = -std=c2x -Wall -Wextra -Wno-deprecated-declarations
FRAMEWORKS = -framework Cocoa
TARGET = MarkdownAtlas
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(TARGET).app
ICON_FILE = $(BUILD_DIR)/icons/AppIcon.icns

MACOSX_TARGET_ARM64  = 11.0
MACOSX_TARGET_X86_64 = 10.6
MACOSX_TARGET_I386   = 10.4

all: build run

build: $(APP_BUNDLE)

$(APP_BUNDLE): main.m Info.plist $(ICON_FILE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	$(CC) $(CFLAGS) $(FRAMEWORKS) -o $(APP_BUNDLE)/Contents/MacOS/$(TARGET) main.m
	cp Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp $(ICON_FILE) $(APP_BUNDLE)/Contents/Resources/AppIcon.icns

# ARM64 (Apple Silicon) — macOS 11.0 Big Sur and later
build-arm64: $(ICON_FILE)
	mkdir -p build-arm64/$(TARGET).app/Contents/MacOS
	mkdir -p build-arm64/$(TARGET).app/Contents/Resources
	$(CC) $(CFLAGS) $(FRAMEWORKS) -arch arm64 \
		-mmacosx-version-min=$(MACOSX_TARGET_ARM64) \
		-DMARKDOWNATLAS_ARCH_ARM64 \
		-o build-arm64/$(TARGET).app/Contents/MacOS/$(TARGET) main.m
	cp Info.plist build-arm64/$(TARGET).app/Contents/Info.plist
	cp $(ICON_FILE) build-arm64/$(TARGET).app/Contents/Resources/AppIcon.icns

# x86_64 (Intel 64-bit) — macOS 10.6 Snow Leopard and later
build-x86_64: $(ICON_FILE)
	mkdir -p build-x86_64/$(TARGET).app/Contents/MacOS
	mkdir -p build-x86_64/$(TARGET).app/Contents/Resources
	$(CC) $(CFLAGS) $(FRAMEWORKS) -arch x86_64 \
		-mmacosx-version-min=$(MACOSX_TARGET_X86_64) \
		-DMARKDOWNATLAS_ARCH_X86_64 \
		-o build-x86_64/$(TARGET).app/Contents/MacOS/$(TARGET) main.m
	cp Info.plist build-x86_64/$(TARGET).app/Contents/Info.plist
	cp $(ICON_FILE) build-x86_64/$(TARGET).app/Contents/Resources/AppIcon.icns

# i386 (Intel 32-bit) — macOS 10.4 Tiger through 10.14 Mojave only
# Requires Xcode 11 or earlier (i386 toolchain dropped in Xcode 12/macOS 11 SDK)
build-i386: $(ICON_FILE)
	mkdir -p build-i386/$(TARGET).app/Contents/MacOS
	mkdir -p build-i386/$(TARGET).app/Contents/Resources
	$(CC) $(CFLAGS) $(FRAMEWORKS) -arch i386 \
		-mmacosx-version-min=$(MACOSX_TARGET_I386) \
		-DMARKDOWNATLAS_ARCH_I386 \
		-o build-i386/$(TARGET).app/Contents/MacOS/$(TARGET) main.m
	cp Info.plist build-i386/$(TARGET).app/Contents/Info.plist
	cp $(ICON_FILE) build-i386/$(TARGET).app/Contents/Resources/AppIcon.icns

build-all: build-arm64 build-x86_64 build-i386

# Generate icon from SVG
$(ICON_FILE): icons/icon.svg icons/generate_icon.sh
	cd icons && ./generate_icon.sh icon.svg

clean:
	rm -rf $(BUILD_DIR) build-arm64 build-x86_64 build-i386

run: $(APP_BUNDLE)
	open $(APP_BUNDLE)

.PHONY: all build build-arm64 build-x86_64 build-i386 build-all clean run
