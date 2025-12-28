#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextViewDelegate>
@property (strong) NSWindow *window;
@property (strong) NSOutlineView *outlineView;
@property (strong) NSMutableArray *rootItems;
@property (strong) NSTextView *textView;
@property (strong) NSString *initialPath;
@property (strong) NSURL *currentFileURL;
@property (assign) BOOL isUpdatingSelection;
@property (strong) NSMutableArray *navigationHistory;
@property (strong) NSMutableArray *scrollPositions;
@property (assign) NSInteger navigationIndex;
@property (strong) NSButton *backButton;
@property (strong) NSButton *forwardButton;
@property (strong) NSButton *viewModeButton;
@property (strong) NSButton *openButton;
@property (strong) NSButton *sidebarToggleButton;
@property (assign) BOOL isRawMode;
@property (strong) NSString *currentMarkdownContent;
@property (strong) NSView *sidebarContainer;
@property (strong) NSView *toolbarView;
@property (strong) NSScrollView *mainScrollView;
@property (assign) BOOL isSidebarVisible;
@end

@implementation AppDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        self.navigationHistory = [NSMutableArray array];
        self.scrollPositions = [NSMutableArray array];
        self.navigationIndex = -1;
        self.isRawMode = NO;
        self.isSidebarVisible = YES;
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self setupMenu];

    if (self.initialPath) {
        NSURL *fileURL = [NSURL fileURLWithPath:self.initialPath];
        NSNumber *isDirectory;
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

        if ([isDirectory boolValue]) {
            [self setupWindowWithFolder:fileURL];
        } else if ([[fileURL pathExtension] isEqualToString:@"md"]) {
            // Open single file with hidden sidebar
            NSURL *folderURL = [fileURL URLByDeletingLastPathComponent];
            self.isSidebarVisible = NO;
            [self setupWindowWithFolder:folderURL];
            [self loadMarkdownFile:fileURL];
        } else {
            [self openFolder];
        }
    } else {
        [self openFolder];
    }
}

- (void)setupMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];

    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:appMenuItem];

    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenuItem setSubmenu:appMenu];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenu addItem:quitItem];

    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
    [mainMenu addItem:fileMenuItem];

    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenuItem setSubmenu:fileMenu];

    NSMenuItem *openItem = [[NSMenuItem alloc] initWithTitle:@"Open Folder..." action:@selector(openFolder) keyEquivalent:@"o"];
    [openItem setTarget:self];
    [fileMenu addItem:openItem];

    [fileMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *exitItem = [[NSMenuItem alloc] initWithTitle:@"Exit" action:@selector(terminate:) keyEquivalent:@""];
    [fileMenu addItem:exitItem];

    [NSApp setMainMenu:mainMenu];
}

- (void)openFolder {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:NO];
    [panel setCanChooseDirectories:YES];
    [panel setAllowsMultipleSelection:NO];
    [panel setPrompt:@"Select Folder"];

    NSModalResponse response = [panel runModal];
    if (response != NSModalResponseOK) {
        if (self.window == nil) {
            [NSApp terminate:nil];
        }
        return;
    }

    NSURL *folderURL = [[panel URLs] firstObject];

    if (self.window == nil) {
        [self setupWindowWithFolder:folderURL];
    } else {
        self.rootItems = [NSMutableArray arrayWithObject:folderURL];
        [self.window setTitle:[folderURL lastPathComponent]];
        [self.outlineView reloadData];
        [self.outlineView expandItem:[self.rootItems firstObject]];
        [[self.textView textStorage] setAttributedString:[[NSAttributedString alloc] initWithString:@""]];
    }
}

- (void)setupWindowWithFolder:(NSURL *)folderURL {
    self.window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 800, 600)
        styleMask:NSWindowStyleMaskTitled |
                  NSWindowStyleMaskClosable |
                  NSWindowStyleMaskMiniaturizable |
                  NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered
        defer:NO];

    [self.window setTitle:[folderURL lastPathComponent]];
    [self.window center];

    NSRect contentRect = [[self.window contentView] bounds];
    CGFloat sidebarWidth = 250;
    CGFloat leftMargin = self.isSidebarVisible ? sidebarWidth : 0;

    // Create sidebar container
    CGFloat sidebarX = self.isSidebarVisible ? 0 : -sidebarWidth;
    self.sidebarContainer = [[NSView alloc] initWithFrame:NSMakeRect(sidebarX, 0, sidebarWidth, contentRect.size.height)];
    [self.sidebarContainer setAutoresizingMask:NSViewHeightSizable];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:[self.sidebarContainer bounds]];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutohidesScrollers:YES];
    [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    self.outlineView = [[NSOutlineView alloc] initWithFrame:scrollView.bounds];
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"files"];
    [column setWidth:230];
    [self.outlineView addTableColumn:column];
    [self.outlineView setOutlineTableColumn:column];
    [self.outlineView setHeaderView:nil];
    [self.outlineView setDataSource:self];
    [self.outlineView setDelegate:self];
    [self.outlineView setRowSizeStyle:NSTableViewRowSizeStyleDefault];

    [scrollView setDocumentView:self.outlineView];
    [self.sidebarContainer addSubview:scrollView];

    self.rootItems = [NSMutableArray arrayWithObject:folderURL];

    // Create toolbar
    CGFloat toolbarHeight = 40;
    self.toolbarView = [[NSView alloc] initWithFrame:NSMakeRect(leftMargin, contentRect.size.height - toolbarHeight, contentRect.size.width - leftMargin, toolbarHeight)];
    [self.toolbarView setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [self.toolbarView setWantsLayer:YES];
    [[self.toolbarView layer] setBackgroundColor:[[NSColor controlBackgroundColor] CGColor]];

    // Sidebar toggle button
    self.sidebarToggleButton = [[NSButton alloc] initWithFrame:NSMakeRect(10, 8, 90, 24)];
    [self.sidebarToggleButton setTitle:@"≡ Sidebar"];
    [self.sidebarToggleButton setBezelStyle:NSBezelStyleRounded];
    [self.sidebarToggleButton setTarget:self];
    [self.sidebarToggleButton setAction:@selector(toggleSidebar:)];
    [self.toolbarView addSubview:self.sidebarToggleButton];

    // Back button
    self.backButton = [[NSButton alloc] initWithFrame:NSMakeRect(110, 8, 70, 24)];
    [self.backButton setTitle:@"◀ Back"];
    [self.backButton setBezelStyle:NSBezelStyleRounded];
    [self.backButton setTarget:self];
    [self.backButton setAction:@selector(navigateBack:)];
    [self.backButton setEnabled:NO];
    [self.toolbarView addSubview:self.backButton];

    // Forward button
    self.forwardButton = [[NSButton alloc] initWithFrame:NSMakeRect(190, 8, 90, 24)];
    [self.forwardButton setTitle:@"Forward ▶"];
    [self.forwardButton setBezelStyle:NSBezelStyleRounded];
    [self.forwardButton setTarget:self];
    [self.forwardButton setAction:@selector(navigateForward:)];
    [self.forwardButton setEnabled:NO];
    [self.toolbarView addSubview:self.forwardButton];

    // View mode toggle button
    self.viewModeButton = [[NSButton alloc] initWithFrame:NSMakeRect(contentRect.size.width - leftMargin - 220, 8, 100, 24)];
    [self.viewModeButton setTitle:@"</> Raw"];
    [self.viewModeButton setBezelStyle:NSBezelStyleRounded];
    [self.viewModeButton setTarget:self];
    [self.viewModeButton setAction:@selector(toggleViewMode:)];
    [self.viewModeButton setAutoresizingMask:NSViewMinXMargin];
    [self.toolbarView addSubview:self.viewModeButton];

    // Open button
    self.openButton = [[NSButton alloc] initWithFrame:NSMakeRect(contentRect.size.width - leftMargin - 110, 8, 100, 24)];
    [self.openButton setTitle:@"↗ Open"];
    [self.openButton setBezelStyle:NSBezelStyleRounded];
    [self.openButton setTarget:self];
    [self.openButton setAction:@selector(openInDefaultApp:)];
    [self.openButton setAutoresizingMask:NSViewMinXMargin];
    [self.toolbarView addSubview:self.openButton];

    self.mainScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(leftMargin, 0, contentRect.size.width - leftMargin, contentRect.size.height - toolbarHeight)];
    [self.mainScrollView setHasVerticalScroller:YES];
    [self.mainScrollView setAutohidesScrollers:YES];
    [self.mainScrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    self.textView = [[NSTextView alloc] initWithFrame:self.mainScrollView.bounds];
    [self.textView setEditable:NO];
    [self.textView setRichText:YES];
    [self.textView setSelectable:YES];
    [self.textView setDelegate:self];
    [self.textView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [[self.textView textContainer] setContainerSize:NSMakeSize(contentRect.size.width - 250 - 20, CGFLOAT_MAX)];
    [[self.textView textContainer] setWidthTracksTextView:YES];
    [self.textView setTextContainerInset:NSMakeSize(10, 10)];

    // Enable link detection and clicking
    [self.textView setLinkTextAttributes:@{
        NSForegroundColorAttributeName: [NSColor blueColor],
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
        NSCursorAttributeName: [NSCursor pointingHandCursor]
    }];

    [self.mainScrollView setDocumentView:self.textView];

    [[self.window contentView] addSubview:self.sidebarContainer];
    [[self.window contentView] addSubview:self.toolbarView];
    [[self.window contentView] addSubview:self.mainScrollView];
    [self.outlineView reloadData];
    [self.outlineView expandItem:[self.rootItems firstObject]];
    [self.window makeKeyAndOrderFront:nil];
}

- (NSArray *)filteredContentsOfURL:(NSURL *)url {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtURL:url
                          includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                          options:NSDirectoryEnumerationSkipsHiddenFiles
                          error:nil];
    return contents;
}

- (BOOL)isMarkdownFile:(NSURL *)url {
    NSNumber *isDirectory;
    [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
    return ![isDirectory boolValue] && [[url pathExtension] isEqualToString:@"md"];
}

- (BOOL)directoryContainsMarkdown:(NSURL *)url {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtURL:url
                                 includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                                               errorHandler:nil];

    for (NSURL *fileURL in enumerator) {
        if ([self isMarkdownFile:fileURL]) {
            return YES;
        }
    }
    return NO;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item == nil) {
        return [self.rootItems count];
    }

    NSURL *url = (NSURL *)item;
    NSArray *filtered = [self filteredContentsOfURL:url];
    return [filtered count];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        return self.rootItems[index];
    }

    NSURL *url = (NSURL *)item;
    NSArray *filtered = [self filteredContentsOfURL:url];
    return filtered[index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    NSURL *url = (NSURL *)item;
    NSNumber *isDirectory;
    [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
    return [isDirectory boolValue];
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSTableCellView *cellView = [outlineView makeViewWithIdentifier:@"cell" owner:self];
    if (!cellView) {
        cellView = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 200, 20)];
        [cellView setIdentifier:@"cell"];
        NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 20)];
        [textField setBordered:NO];
        [textField setDrawsBackground:NO];
        [textField setEditable:NO];
        [textField setAutoresizingMask:NSViewWidthSizable];
        [cellView setTextField:textField];
        [cellView addSubview:textField];
    }

    NSURL *url = (NSURL *)item;
    [[cellView textField] setStringValue:[url lastPathComponent]];

    if ([self isMarkdownFile:url]) {
        [[cellView textField] setTextColor:[NSColor controlTextColor]];
    } else {
        NSNumber *isDirectory;
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if ([isDirectory boolValue]) {
            // Only highlight folders that contain markdown files
            if ([self directoryContainsMarkdown:url]) {
                [[cellView textField] setTextColor:[NSColor controlTextColor]];
            } else {
                [[cellView textField] setTextColor:[NSColor disabledControlTextColor]];
            }
        } else {
            [[cellView textField] setTextColor:[NSColor disabledControlTextColor]];
        }
    }

    return cellView;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    NSURL *url = (NSURL *)item;
    NSNumber *isDirectory;
    [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
    return ![isDirectory boolValue] && [self isMarkdownFile:url];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    // Skip if we're programmatically updating the selection
    if (self.isUpdatingSelection) {
        return;
    }

    NSInteger selectedRow = [self.outlineView selectedRow];
    if (selectedRow < 0) return;

    id item = [self.outlineView itemAtRow:selectedRow];
    if (![self isMarkdownFile:item]) return;

    NSURL *fileURL = (NSURL *)item;
    [self loadMarkdownFile:fileURL];
}

- (void)selectItemInOutlineView:(NSURL *)fileURL {
    // Set flag to prevent triggering loadMarkdownFile again
    self.isUpdatingSelection = YES;

    // Find and select the item in the outline view
    for (NSURL *rootItem in self.rootItems) {
        NSInteger row = [self findRowForURL:fileURL inItem:rootItem];
        if (row != -1) {
            [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [self.outlineView scrollRowToVisible:row];
            break;
        }
    }

    // Reset flag
    self.isUpdatingSelection = NO;
}

- (NSInteger)findRowForURL:(NSURL *)targetURL inItem:(id)item {
    // Recursively search for the URL in the outline view
    if ([item isEqual:targetURL]) {
        return [self.outlineView rowForItem:item];
    }

    NSNumber *isDirectory;
    [(NSURL *)item getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

    if ([isDirectory boolValue]) {
        // Expand this item to search its children
        [self.outlineView expandItem:item];

        NSArray *children = [self filteredContentsOfURL:item];
        for (NSURL *child in children) {
            NSInteger row = [self findRowForURL:targetURL inItem:child];
            if (row != -1) {
                return row;
            }
        }
    }

    return -1;
}

- (void)loadMarkdownFile:(NSURL *)fileURL {
    [self loadMarkdownFile:fileURL addToHistory:YES];
}

- (void)loadMarkdownFile:(NSURL *)fileURL addToHistory:(BOOL)addToHistory {
    NSError *error = nil;
    NSString *markdown = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"Error reading file: %@", error);
        return;
    }

    NSPoint scrollPoint = NSMakePoint(0, 0);

    // Add to navigation history
    if (addToHistory) {
        [self saveCurrentScrollPosition];

        // Remove all items after current index (when navigating to a new file while in history)
        if (self.navigationIndex < (NSInteger)[self.navigationHistory count] - 1) {
            NSRange rangeToRemove = NSMakeRange(self.navigationIndex + 1, [self.navigationHistory count] - self.navigationIndex - 1);
            [self.navigationHistory removeObjectsInRange:rangeToRemove];
            [self.scrollPositions removeObjectsInRange:rangeToRemove];
        }

        [self.navigationHistory addObject:fileURL];
        [self.scrollPositions addObject:[NSValue valueWithPoint:scrollPoint]];
        self.navigationIndex = (NSInteger)[self.navigationHistory count] - 1;
        [self updateNavigationButtons];
    } else {
        // Navigating from history - restore scroll position
        if (self.navigationIndex >= 0 && self.navigationIndex < (NSInteger)[self.scrollPositions count]) {
            scrollPoint = [self.scrollPositions[self.navigationIndex] pointValue];
        }
    }

    self.currentFileURL = fileURL;
    self.currentMarkdownContent = markdown;

    // Display based on current mode
    if (self.isRawMode) {
        [self showRawText];
    } else {
        [self showMarkdownPreview];
    }

    // Scroll to the appropriate position
    [[self.mainScrollView contentView] scrollToPoint:scrollPoint];
    [self.mainScrollView reflectScrolledClipView:[self.mainScrollView contentView]];

    // Update the outline view selection
    [self selectItemInOutlineView:fileURL];
}

- (void)showMarkdownPreview {
    NSAttributedString *attributed = [self renderMarkdown:self.currentMarkdownContent];
    [[self.textView textStorage] setAttributedString:attributed];
}

- (void)showRawText {
    NSFont *monoFont = [NSFont fontWithName:@"Menlo" size:13];
    NSDictionary *attrs = @{NSFontAttributeName: monoFont};
    NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:self.currentMarkdownContent attributes:attrs];
    [[self.textView textStorage] setAttributedString:attributed];
}

- (void)saveCurrentScrollPosition {
    if (self.currentFileURL && self.navigationIndex >= 0 && self.navigationIndex < (NSInteger)[self.scrollPositions count]) {
        NSPoint scrollPoint = [[self.mainScrollView contentView] bounds].origin;
        self.scrollPositions[self.navigationIndex] = [NSValue valueWithPoint:scrollPoint];
    }
}

- (void)updateNavigationButtons {
    [self.backButton setEnabled:(self.navigationIndex > 0)];
    [self.forwardButton setEnabled:(self.navigationIndex < (NSInteger)[self.navigationHistory count] - 1)];
}

- (void)navigateBack:(id)sender {
    if (self.navigationIndex > 0) {
        [self saveCurrentScrollPosition];
        self.navigationIndex--;
        NSURL *fileURL = self.navigationHistory[self.navigationIndex];
        [self loadMarkdownFile:fileURL addToHistory:NO];
        [self updateNavigationButtons];
    }
}

- (void)navigateForward:(id)sender {
    if (self.navigationIndex < (NSInteger)[self.navigationHistory count] - 1) {
        [self saveCurrentScrollPosition];
        self.navigationIndex++;
        NSURL *fileURL = self.navigationHistory[self.navigationIndex];
        [self loadMarkdownFile:fileURL addToHistory:NO];
        [self updateNavigationButtons];
    }
}

- (void)toggleViewMode:(id)sender {
    self.isRawMode = !self.isRawMode;

    if (self.isRawMode) {
        [self.viewModeButton setTitle:@"◧ Preview"];
        [self showRawText];
    } else {
        [self.viewModeButton setTitle:@"</> Raw"];
        [self showMarkdownPreview];
    }
}

- (void)openInDefaultApp:(id)sender {
    if (self.currentFileURL) {
        [[NSWorkspace sharedWorkspace] openURL:self.currentFileURL];
    }
}

- (void)toggleSidebar:(id)sender {
    self.isSidebarVisible = !self.isSidebarVisible;

    NSRect contentRect = [[self.window contentView] bounds];
    CGFloat sidebarWidth = 250;
    CGFloat toolbarHeight = 40;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [context setDuration:0.25];

        if (self.isSidebarVisible) {
            // Show sidebar
            [[self.sidebarContainer animator] setFrame:NSMakeRect(0, 0, sidebarWidth, contentRect.size.height)];
            [[self.toolbarView animator] setFrame:NSMakeRect(sidebarWidth, contentRect.size.height - toolbarHeight, contentRect.size.width - sidebarWidth, toolbarHeight)];
            [[self.mainScrollView animator] setFrame:NSMakeRect(sidebarWidth, 0, contentRect.size.width - sidebarWidth, contentRect.size.height - toolbarHeight)];
        } else {
            // Hide sidebar
            [[self.sidebarContainer animator] setFrame:NSMakeRect(-sidebarWidth, 0, sidebarWidth, contentRect.size.height)];
            [[self.toolbarView animator] setFrame:NSMakeRect(0, contentRect.size.height - toolbarHeight, contentRect.size.width, toolbarHeight)];
            [[self.mainScrollView animator] setFrame:NSMakeRect(0, 0, contentRect.size.width, contentRect.size.height - toolbarHeight)];
        }
    } completionHandler:nil];
}

- (NSMutableAttributedString *)renderHeading:(NSString *)line prefix:(NSString *)prefix fontSize:(CGFloat)size italicFont:(NSFont *)italicFont codeFont:(NSFont *)codeFont {
    NSString *text = [line substringFromIndex:[prefix length]];
    NSFont *headingFont = [NSFont boldSystemFontOfSize:size];
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:[text stringByAppendingString:@"\n"] attributes:@{NSFontAttributeName: headingFont}];
    [self applyInlineFormatting:attr boldFont:headingFont italicFont:italicFont codeFont:codeFont];
    return attr;
}

- (NSAttributedString *)renderMarkdown:(NSString *)markdown {
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    NSArray *lines = [markdown componentsSeparatedByString:@"\n"];

    NSFont *normalFont = [NSFont systemFontOfSize:14];
    NSFont *boldFont = [NSFont boldSystemFontOfSize:14];
    NSFont *italicFont = [[NSFontManager sharedFontManager] fontWithFamily:@"Helvetica" traits:NSItalicFontMask weight:5 size:14];
    if (!italicFont) italicFont = [NSFont systemFontOfSize:14];
    NSFont *codeFont = [NSFont fontWithName:@"Menlo" size:13];
    if (!codeFont) codeFont = [NSFont userFixedPitchFontOfSize:13];

    BOOL inCodeBlock = NO;
    NSInteger i = 0;
    while (i < (NSInteger)[lines count]) {
        NSString *line = lines[i];
        NSMutableAttributedString *lineAttr = [[NSMutableAttributedString alloc] init];

        if ([line hasPrefix:@"###### "]) {
            lineAttr = [self renderHeading:line prefix:@"###### " fontSize:12 italicFont:italicFont codeFont:codeFont];
        } else if ([line hasPrefix:@"##### "]) {
            lineAttr = [self renderHeading:line prefix:@"##### " fontSize:14 italicFont:italicFont codeFont:codeFont];
        } else if ([line hasPrefix:@"#### "]) {
            lineAttr = [self renderHeading:line prefix:@"#### " fontSize:16 italicFont:italicFont codeFont:codeFont];
        } else if ([line hasPrefix:@"### "]) {
            lineAttr = [self renderHeading:line prefix:@"### " fontSize:18 italicFont:italicFont codeFont:codeFont];
        } else if ([line hasPrefix:@"## "]) {
            lineAttr = [self renderHeading:line prefix:@"## " fontSize:22 italicFont:italicFont codeFont:codeFont];
        } else if ([line hasPrefix:@"# "]) {
            lineAttr = [self renderHeading:line prefix:@"# " fontSize:28 italicFont:italicFont codeFont:codeFont];
        } else if ([line hasPrefix:@"```"]) {
            inCodeBlock = !inCodeBlock;
            lineAttr = [[NSMutableAttributedString alloc] initWithString:[line stringByAppendingString:@"\n"]
                attributes:@{NSFontAttributeName: codeFont, NSBackgroundColorAttributeName: [NSColor colorWithWhite:0.95 alpha:1.0]}];
        } else if (inCodeBlock) {
            // Inside code block - apply code styling
            lineAttr = [[NSMutableAttributedString alloc] initWithString:[line stringByAppendingString:@"\n"]
                attributes:@{NSFontAttributeName: codeFont, NSBackgroundColorAttributeName: [NSColor colorWithWhite:0.95 alpha:1.0]}];
        } else if ([line hasPrefix:@"> "]) {
            NSString *text = [line substringFromIndex:2];
            NSDictionary *attrs = @{NSFontAttributeName: italicFont, NSForegroundColorAttributeName: [NSColor grayColor]};
            lineAttr = [[NSMutableAttributedString alloc] initWithString:[text stringByAppendingString:@"\n"] attributes:attrs];
            [self applyInlineFormatting:lineAttr boldFont:boldFont italicFont:italicFont codeFont:codeFont];
        } else if ([line hasPrefix:@"- "] || [line hasPrefix:@"* "]) {
            NSString *text = [line substringFromIndex:2];
            NSString *bullet = nil;

            // Check for checkboxes - [ ] or [x] or [X]
            if ([text hasPrefix:@"[ ] "]) {
                // Unchecked checkbox
                bullet = [@"☐ " stringByAppendingString:[text substringFromIndex:4]];
            } else if ([text hasPrefix:@"[x] "] || [text hasPrefix:@"[X] "]) {
                // Checked checkbox
                bullet = [@"☑ " stringByAppendingString:[text substringFromIndex:4]];
            } else {
                // Regular bullet
                bullet = [@"• " stringByAppendingString:text];
            }

            lineAttr = [[NSMutableAttributedString alloc] initWithString:[bullet stringByAppendingString:@"\n"]
                attributes:@{NSFontAttributeName: normalFont}];
            [self applyInlineFormatting:lineAttr boldFont:boldFont italicFont:italicFont codeFont:codeFont];
        } else if ([line hasPrefix:@"---"]) {
            lineAttr = [[NSMutableAttributedString alloc] initWithString:@"━━━━━━━━━━━━━━━━━━━━\n"
                attributes:@{NSFontAttributeName: normalFont, NSForegroundColorAttributeName: [NSColor grayColor]}];
        } else {
            lineAttr = [[NSMutableAttributedString alloc] initWithString:[line stringByAppendingString:@"\n"]
                attributes:@{NSFontAttributeName: normalFont}];

            [self applyInlineFormatting:lineAttr boldFont:boldFont italicFont:italicFont codeFont:codeFont];
        }

        // Check if this might be a table header (contains |)
        if ([line containsString:@"|"] && i + 1 < (NSInteger)[lines count]) {
            NSString *nextLine = lines[i + 1];
            // Check if next line is a table separator (like |---|---|)
            if ([self isTableSeparator:nextLine]) {
                // Process the table
                NSMutableAttributedString *tableAttr = [self renderTable:lines startIndex:i endIndex:&i fonts:@{
                    @"normal": normalFont,
                    @"bold": boldFont,
                    @"italic": italicFont,
                    @"code": codeFont
                }];
                [result appendAttributedString:tableAttr];
                i++; // Skip to next line after table
                continue;
            }
        }

        [result appendAttributedString:lineAttr];
        i++;
    }

    return result;
}

- (BOOL)isTableSeparator:(NSString *)line {
    // Table separator looks like: |---|---|---| or |:---|:---:|---:|
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (![trimmed containsString:@"|"]) {
        return NO;
    }

    // Remove all valid table separator characters
    NSString *cleaned = [trimmed stringByReplacingOccurrencesOfString:@"|" withString:@""];
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@"-" withString:@""];
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@":" withString:@""];
    cleaned = [cleaned stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    // If nothing left, it's a valid separator
    return [cleaned length] == 0 && [trimmed containsString:@"-"];
}

- (NSTextTableBlock *)createTableBlock:(NSTextTable *)table row:(NSInteger)row col:(NSInteger)col {
    NSTextTableBlock *block = [[NSTextTableBlock alloc] initWithTable:table startingRow:row rowSpan:1 startingColumn:col columnSpan:1];
    [block setWidth:0.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMinXEdge];
    [block setWidth:10.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMaxXEdge];
    [block setWidth:3.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMinYEdge];
    [block setWidth:3.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMaxYEdge];
    [block setBorderColor:[NSColor gridColor]];
    [block setWidth:0.5 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockBorder];
    return block;
}

- (NSMutableAttributedString *)renderTable:(NSArray *)lines startIndex:(NSInteger)startIndex endIndex:(NSInteger *)endIndex fonts:(NSDictionary *)fonts {
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    NSFont *tableFont = [NSFont systemFontOfSize:13];
    NSFont *tableBoldFont = [NSFont boldSystemFontOfSize:13];
    NSFont *codeFont = fonts[@"code"];

    NSArray *headers = [self parseTableRow:lines[startIndex]];
    NSInteger numCols = [headers count];
    NSInteger tableEnd = startIndex + 2;
    while (tableEnd < (NSInteger)[lines count] && [lines[tableEnd] containsString:@"|"] && [lines[tableEnd] length] > 0) {
        tableEnd++;
    }

    NSTextTable *textTable = [[NSTextTable alloc] init];
    [textTable setNumberOfColumns:numCols];
    [textTable setLayoutAlgorithm:NSTextTableAutomaticLayoutAlgorithm];

    // Render header
    for (NSInteger col = 0; col < numCols; col++) {
        NSString *header = [headers[col] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSTextTableBlock *block = [self createTableBlock:textTable row:0 col:col];
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        [style setTextBlocks:@[block]];
        NSDictionary *attrs = @{NSFontAttributeName: tableBoldFont, NSParagraphStyleAttributeName: style};
        NSMutableAttributedString *cellStr = [[NSMutableAttributedString alloc] initWithString:header attributes:attrs];
        [cellStr appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:attrs]];
        [result appendAttributedString:cellStr];
    }

    // Render rows
    NSInteger rowNum = 1;
    for (NSInteger row = startIndex + 2; row < tableEnd; row++, rowNum++) {
        NSArray *cells = [self parseTableRow:lines[row]];
        for (NSInteger col = 0; col < numCols; col++) {
            NSString *cell = col < (NSInteger)[cells count] ? [cells[col] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] : @"";
            NSTextTableBlock *block = [self createTableBlock:textTable row:rowNum col:col];
            NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
            [style setTextBlocks:@[block]];
            NSDictionary *attrs = @{NSFontAttributeName: tableFont, NSParagraphStyleAttributeName: style};
            NSMutableAttributedString *cellStr = [[NSMutableAttributedString alloc] initWithString:cell attributes:attrs];
            [self applyInlineFormatting:cellStr boldFont:tableBoldFont italicFont:tableFont codeFont:codeFont];
            [cellStr appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:attrs]];
            [result appendAttributedString:cellStr];
        }
    }

    [result appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    *endIndex = tableEnd - 1;
    return result;
}

- (NSArray *)parseTableRow:(NSString *)row {
    NSString *trimmed = [row stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    // Remove leading and trailing pipes
    if ([trimmed hasPrefix:@"|"]) {
        trimmed = [trimmed substringFromIndex:1];
    }
    if ([trimmed hasSuffix:@"|"]) {
        trimmed = [trimmed substringToIndex:[trimmed length] - 1];
    }

    // Split by |
    NSArray *cells = [trimmed componentsSeparatedByString:@"|"];
    return cells;
}

- (void)applyInlineFormatting:(NSMutableAttributedString *)attrString boldFont:(NSFont *)boldFont italicFont:(NSFont *)italicFont codeFont:(NSFont *)codeFont {
    NSString *string = [attrString string];

    // First, handle escape sequences by replacing them with placeholders
    NSString *escapeMarker = @"\u{FFFC}ESC"; // Object replacement character as marker
    NSMutableDictionary *escapedChars = [NSMutableDictionary dictionary];
    NSInteger escapeIndex = 0;

    // Find all escaped characters
    NSRegularExpression *escapeRegex = [NSRegularExpression regularExpressionWithPattern:@"\\\\(.)" options:0 error:nil];
    NSArray *escapeMatches = [escapeRegex matchesInString:string options:0 range:NSMakeRange(0, string.length)];

    // Replace escaped characters with markers (in reverse to maintain positions)
    for (NSTextCheckingResult *match in [escapeMatches reverseObjectEnumerator]) {
        NSRange escapedCharRange = [match rangeAtIndex:1];
        NSString *escapedChar = [string substringWithRange:escapedCharRange];
        NSString *marker = [NSString stringWithFormat:@"%@%ld", escapeMarker, (long)escapeIndex];
        escapedChars[marker] = escapedChar;
        [attrString replaceCharactersInRange:match.range withString:marker];
        escapeIndex++;
    }

    string = [attrString string];
    NSRegularExpression *imageRegex = [NSRegularExpression regularExpressionWithPattern:@"!\\[([^\\]]*)\\]\\(([^\\)]+)\\)" options:0 error:nil];
    NSRegularExpression *linkRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[([^\\]]+)\\]\\(([^\\)]+)\\)" options:0 error:nil];
    NSRegularExpression *boldRegex = [NSRegularExpression regularExpressionWithPattern:@"\\*\\*(.+?)\\*\\*|__(.+?)__" options:0 error:nil];
    NSRegularExpression *italicRegex = [NSRegularExpression regularExpressionWithPattern:@"\\*(.+?)\\*|_(.+?)_" options:0 error:nil];
    NSRegularExpression *codeRegex = [NSRegularExpression regularExpressionWithPattern:@"`([^`\n]+)`" options:0 error:nil];

    // Process inline code FIRST using placeholders to protect from other processing
    NSString *codeMarker = @"\u{FFFC}CODE";
    NSMutableDictionary *codeBlocks = [NSMutableDictionary dictionary];
    NSInteger codeIndex = 0;

    NSArray *codeMatches = [codeRegex matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    for (NSTextCheckingResult *match in [codeMatches reverseObjectEnumerator]) {
        NSRange contentRange = [match rangeAtIndex:1];
        NSString *content = [string substringWithRange:contentRange];
        NSString *marker = [NSString stringWithFormat:@"%@%ld", codeMarker, (long)codeIndex];
        codeBlocks[marker] = content;
        [attrString replaceCharactersInRange:match.range withString:marker];
        codeIndex++;
    }

    string = [attrString string];
    // Process images (before links since they have similar syntax)
    NSArray *imageMatches = [imageRegex matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    for (NSTextCheckingResult *match in [imageMatches reverseObjectEnumerator]) {
        NSRange altTextRange = [match rangeAtIndex:1];
        NSRange imagePathRange = [match rangeAtIndex:2];
        NSString *altText = [string substringWithRange:altTextRange];
        NSString *imagePath = [string substringWithRange:imagePathRange];

        // Resolve image path relative to current file
        NSURL *imageURL = nil;
        if (self.currentFileURL) {
            NSURL *baseURL = [self.currentFileURL URLByDeletingLastPathComponent];

            // Handle both relative paths starting with ./ and plain paths
            if ([imagePath hasPrefix:@"./"]) {
                imagePath = [imagePath substringFromIndex:2];
            } else if ([imagePath hasPrefix:@"../"]) {
                // Keep ../ for parent directory navigation
            }

            imageURL = [baseURL URLByAppendingPathComponent:imagePath];
        }

        if (imageURL) {
            NSFileManager *fm = [NSFileManager defaultManager];
            if ([fm fileExistsAtPath:[imageURL path]]) {
                NSImage *image = [[NSImage alloc] initWithContentsOfFile:[imageURL path]];
                if (image) {
                    // Create text attachment for image
                    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
                    [attachment setImage:image];

                    // Resize image if too large (max width 600px)
                    NSSize imageSize = [image size];
                    CGFloat maxWidth = 600.0;
                    if (imageSize.width > maxWidth) {
                        CGFloat scale = maxWidth / imageSize.width;
                        imageSize = NSMakeSize(maxWidth, imageSize.height * scale);
                    }
                    [attachment setBounds:NSMakeRect(0, 0, imageSize.width, imageSize.height)];

                    NSAttributedString *imageString = [NSAttributedString attributedStringWithAttachment:attachment];
                    NSMutableAttributedString *imageWithNewline = [[NSMutableAttributedString alloc] initWithAttributedString:imageString];
                    [imageWithNewline appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];

                    [attrString replaceCharactersInRange:match.range withAttributedString:imageWithNewline];
                } else {
                    // Image couldn't be loaded, show alt text
                    NSString *replacement = [NSString stringWithFormat:@"[Image: %@]\n", altText.length > 0 ? altText : @"broken"];
                    [attrString replaceCharactersInRange:match.range withString:replacement];
                }
            } else {
                // Image file not found, show alt text
                NSString *replacement = [NSString stringWithFormat:@"[Image not found: %@]\n", altText.length > 0 ? altText : imagePath];
                [attrString replaceCharactersInRange:match.range withString:replacement];
            }
        }
    }

    string = [attrString string];
    // Process links
    NSArray *linkMatches = [linkRegex matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    for (NSTextCheckingResult *match in [linkMatches reverseObjectEnumerator]) {
        NSRange textRange = [match rangeAtIndex:1];
        NSRange urlRange = [match rangeAtIndex:2];
        NSString *linkText = [string substringWithRange:textRange];
        NSString *urlString = [string substringWithRange:urlRange];

        [attrString replaceCharactersInRange:match.range withString:linkText];

        NSURL *url = [NSURL URLWithString:urlString];
        if (!url) {
            url = [NSURL fileURLWithPath:urlString];
        }

        NSRange linkRange = NSMakeRange(match.range.location, linkText.length);
        [attrString addAttribute:NSLinkAttributeName value:url range:linkRange];
        [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:linkRange];
        [attrString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:linkRange];
    }

    string = [attrString string];
    NSArray *boldMatches = [boldRegex matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    for (NSTextCheckingResult *match in [boldMatches reverseObjectEnumerator]) {
        NSRange contentRange = [match rangeAtIndex:1].location != NSNotFound ? [match rangeAtIndex:1] : [match rangeAtIndex:2];
        NSString *content = [string substringWithRange:contentRange];
        [attrString replaceCharactersInRange:match.range withString:content];
        [attrString addAttribute:NSFontAttributeName value:boldFont range:NSMakeRange(match.range.location, content.length)];
    }

    string = [attrString string];
    NSArray *italicMatches = [italicRegex matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    for (NSTextCheckingResult *match in [italicMatches reverseObjectEnumerator]) {
        NSRange contentRange = [match rangeAtIndex:1].location != NSNotFound ? [match rangeAtIndex:1] : [match rangeAtIndex:2];
        NSString *content = [string substringWithRange:contentRange];
        [attrString replaceCharactersInRange:match.range withString:content];
        [attrString addAttribute:NSFontAttributeName value:italicFont range:NSMakeRange(match.range.location, content.length)];
    }

    // Restore code blocks with proper formatting
    string = [attrString string];
    for (NSString *marker in codeBlocks) {
        NSString *content = codeBlocks[marker];
        NSRange markerRange = [string rangeOfString:marker];
        while (markerRange.location != NSNotFound) {
            [attrString replaceCharactersInRange:markerRange withString:content];
            [attrString addAttribute:NSFontAttributeName value:codeFont range:NSMakeRange(markerRange.location, content.length)];
            [attrString addAttribute:NSBackgroundColorAttributeName value:[NSColor colorWithWhite:0.95 alpha:1.0] range:NSMakeRange(markerRange.location, content.length)];
            string = [attrString string];
            markerRange = [string rangeOfString:marker];
        }
    }

    // Finally, restore escaped characters
    string = [attrString string];
    for (NSString *marker in escapedChars) {
        NSString *replacement = escapedChars[marker];
        NSRange markerRange = [string rangeOfString:marker];
        while (markerRange.location != NSNotFound) {
            [attrString replaceCharactersInRange:markerRange withString:replacement];
            string = [attrString string];
            markerRange = [string rangeOfString:marker];
        }
    }
}

- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex {
    NSString *linkString = nil;

    if ([link isKindOfClass:[NSURL class]]) {
        NSURL *url = (NSURL *)link;
        if ([url isFileURL]) {
            linkString = [url path];
        } else {
            linkString = [url absoluteString];
        }
    } else if ([link isKindOfClass:[NSString class]]) {
        linkString = (NSString *)link;
    }

    if (!linkString) {
        return NO;
    }

    // Check if it's an HTTP/HTTPS URL
    if ([linkString hasPrefix:@"http://"] || [linkString hasPrefix:@"https://"]) {
        NSURL *webURL = [NSURL URLWithString:linkString];
        if (webURL) {
            [[NSWorkspace sharedWorkspace] openURL:webURL];
            return YES;
        }
        return NO;
    }

    // It's a file path - resolve it relative to the current file
    if (!self.currentFileURL) {
        return NO;
    }

    NSURL *baseURL = [self.currentFileURL URLByDeletingLastPathComponent];
    NSURL *targetURL = [baseURL URLByAppendingPathComponent:linkString];

    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:[targetURL path]]) {
        // Check if it's a markdown file
        if ([[targetURL pathExtension] isEqualToString:@"md"]) {
            [self loadMarkdownFile:targetURL];
        } else {
            // Open other files with default system app
            [[NSWorkspace sharedWorkspace] openURL:targetURL];
        }
        return YES;
    } else {
        NSLog(@"File not found: %@", [targetURL path]);
        return NO;
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];

        if (argc > 1) {
            delegate.initialPath = [NSString stringWithUTF8String:argv[1]];
        }

        [app setDelegate:delegate];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
