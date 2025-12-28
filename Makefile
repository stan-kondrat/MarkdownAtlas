CC = gcc
CFLAGS = -std=c2x -Wall -Wextra -Wno-deprecated-declarations
FRAMEWORKS = -framework Cocoa
TARGET = MarkdownAtlas

all: $(TARGET)

$(TARGET): main.m
	$(CC) $(CFLAGS) $(FRAMEWORKS) -o $(TARGET) main.m

clean:
	rm -f $(TARGET)

run: $(TARGET)
	./$(TARGET)

.PHONY: all clean run
