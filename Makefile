CC = gcc
CFLAGS = -std=c2x -Wall -Wextra -Wno-deprecated-declarations
FRAMEWORKS = -framework Cocoa
TARGET = MarkdownAtlas
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(TARGET).app
ICON_FILE = $(BUILD_DIR)/icons/AppIcon.icns

all: build run

build: $(APP_BUNDLE)

$(APP_BUNDLE): main.m Info.plist $(ICON_FILE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	$(CC) $(CFLAGS) $(FRAMEWORKS) -o $(APP_BUNDLE)/Contents/MacOS/$(TARGET) main.m
	cp Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp $(ICON_FILE) $(APP_BUNDLE)/Contents/Resources/AppIcon.icns

# Generate icon from SVG
$(ICON_FILE): icons/icon.svg icons/generate_icon.sh
	cd icons && ./generate_icon.sh icon.svg

clean:
	rm -rf $(BUILD_DIR)

run: $(APP_BUNDLE)
	open $(APP_BUNDLE)

.PHONY: all build clean run
