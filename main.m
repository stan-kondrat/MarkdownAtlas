#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate>
@property (strong) NSWindow *window;
@property (strong) NSOutlineView *outlineView;
@property (strong) NSMutableArray *rootItems;
@property (strong) NSTextView *textView;
@property (strong) NSString *initialPath;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self setupMenu];

    if (self.initialPath) {
        NSURL *folderURL = [NSURL fileURLWithPath:self.initialPath];
        NSNumber *isDirectory;
        [folderURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

        if ([isDirectory boolValue]) {
            [self setupWindowWithFolder:folderURL];
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
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 250, contentRect.size.height)];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutohidesScrollers:YES];
    [scrollView setAutoresizingMask:NSViewHeightSizable];

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

    self.rootItems = [NSMutableArray arrayWithObject:folderURL];

    NSScrollView *mainScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(250, 0, contentRect.size.width - 250, contentRect.size.height)];
    [mainScrollView setHasVerticalScroller:YES];
    [mainScrollView setAutohidesScrollers:YES];
    [mainScrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    self.textView = [[NSTextView alloc] initWithFrame:mainScrollView.bounds];
    [self.textView setEditable:NO];
    [self.textView setRichText:YES];
    [self.textView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [[self.textView textContainer] setContainerSize:NSMakeSize(contentRect.size.width - 250 - 20, CGFLOAT_MAX)];
    [[self.textView textContainer] setWidthTracksTextView:YES];
    [self.textView setTextContainerInset:NSMakeSize(10, 10)];

    [mainScrollView setDocumentView:self.textView];

    [[self.window contentView] addSubview:scrollView];
    [[self.window contentView] addSubview:mainScrollView];
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
        cellView = [[NSTableCellView alloc] init];
        [cellView setIdentifier:@"cell"];
        NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 20)];
        [textField setBordered:NO];
        [textField setDrawsBackground:NO];
        [textField setEditable:NO];
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
            [[cellView textField] setTextColor:[NSColor controlTextColor]];
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
    NSInteger selectedRow = [self.outlineView selectedRow];
    if (selectedRow < 0) return;

    id item = [self.outlineView itemAtRow:selectedRow];
    if (![self isMarkdownFile:item]) return;

    NSURL *fileURL = (NSURL *)item;
    [self loadMarkdownFile:fileURL];
}

- (void)loadMarkdownFile:(NSURL *)fileURL {
    NSError *error = nil;
    NSString *markdown = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"Error reading file: %@", error);
        return;
    }

    NSAttributedString *attributed = [self renderMarkdown:markdown];
    [[self.textView textStorage] setAttributedString:attributed];
}

- (NSAttributedString *)renderMarkdown:(NSString *)markdown {
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    NSArray *lines = [markdown componentsSeparatedByString:@"\n"];

    NSFont *normalFont = [NSFont systemFontOfSize:14];
    NSFont *boldFont = [NSFont boldSystemFontOfSize:14];
    NSFont *italicFont = [[NSFontManager sharedFontManager] fontWithFamily:@"Helvetica" traits:NSItalicFontMask weight:5 size:14];
    NSFont *codeFont = [NSFont fontWithName:@"Menlo" size:13];

    for (NSString *line in lines) {
        NSMutableAttributedString *lineAttr = [[NSMutableAttributedString alloc] init];

        if ([line hasPrefix:@"# "]) {
            NSString *text = [line substringFromIndex:2];
            NSDictionary *attrs = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:28]};
            lineAttr = [[NSMutableAttributedString alloc] initWithString:[text stringByAppendingString:@"\n"] attributes:attrs];
        } else if ([line hasPrefix:@"## "]) {
            NSString *text = [line substringFromIndex:3];
            NSDictionary *attrs = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:22]};
            lineAttr = [[NSMutableAttributedString alloc] initWithString:[text stringByAppendingString:@"\n"] attributes:attrs];
        } else if ([line hasPrefix:@"### "]) {
            NSString *text = [line substringFromIndex:4];
            NSDictionary *attrs = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:18]};
            lineAttr = [[NSMutableAttributedString alloc] initWithString:[text stringByAppendingString:@"\n"] attributes:attrs];
        } else if ([line hasPrefix:@"#### "]) {
            NSString *text = [line substringFromIndex:5];
            NSDictionary *attrs = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:16]};
            lineAttr = [[NSMutableAttributedString alloc] initWithString:[text stringByAppendingString:@"\n"] attributes:attrs];
        } else if ([line hasPrefix:@"##### "]) {
            NSString *text = [line substringFromIndex:6];
            NSDictionary *attrs = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:14]};
            lineAttr = [[NSMutableAttributedString alloc] initWithString:[text stringByAppendingString:@"\n"] attributes:attrs];
        } else if ([line hasPrefix:@"###### "]) {
            NSString *text = [line substringFromIndex:7];
            NSDictionary *attrs = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:12]};
            lineAttr = [[NSMutableAttributedString alloc] initWithString:[text stringByAppendingString:@"\n"] attributes:attrs];
        } else if ([line hasPrefix:@"```"]) {
            lineAttr = [[NSMutableAttributedString alloc] initWithString:[line stringByAppendingString:@"\n"]
                attributes:@{NSFontAttributeName: codeFont, NSBackgroundColorAttributeName: [NSColor colorWithWhite:0.95 alpha:1.0]}];
        } else if ([line hasPrefix:@"> "]) {
            NSString *text = [line substringFromIndex:2];
            NSDictionary *attrs = @{NSFontAttributeName: italicFont, NSForegroundColorAttributeName: [NSColor grayColor]};
            lineAttr = [[NSMutableAttributedString alloc] initWithString:[text stringByAppendingString:@"\n"] attributes:attrs];
        } else if ([line hasPrefix:@"- "] || [line hasPrefix:@"* "]) {
            NSString *text = [line substringFromIndex:2];
            NSString *bullet = [@"• " stringByAppendingString:text];
            lineAttr = [[NSMutableAttributedString alloc] initWithString:[bullet stringByAppendingString:@"\n"]
                attributes:@{NSFontAttributeName: normalFont}];
        } else if ([line hasPrefix:@"---"]) {
            lineAttr = [[NSMutableAttributedString alloc] initWithString:@"━━━━━━━━━━━━━━━━━━━━\n"
                attributes:@{NSFontAttributeName: normalFont, NSForegroundColorAttributeName: [NSColor grayColor]}];
        } else {
            lineAttr = [[NSMutableAttributedString alloc] initWithString:[line stringByAppendingString:@"\n"]
                attributes:@{NSFontAttributeName: normalFont}];

            [self applyInlineFormatting:lineAttr boldFont:boldFont italicFont:italicFont codeFont:codeFont];
        }

        [result appendAttributedString:lineAttr];
    }

    return result;
}

- (void)applyInlineFormatting:(NSMutableAttributedString *)attrString boldFont:(NSFont *)boldFont italicFont:(NSFont *)italicFont codeFont:(NSFont *)codeFont {
    NSString *string = [attrString string];
    NSRegularExpression *boldRegex = [NSRegularExpression regularExpressionWithPattern:@"\\*\\*(.+?)\\*\\*|__(.+?)__" options:0 error:nil];
    NSRegularExpression *italicRegex = [NSRegularExpression regularExpressionWithPattern:@"\\*(.+?)\\*|_(.+?)_" options:0 error:nil];
    NSRegularExpression *codeRegex = [NSRegularExpression regularExpressionWithPattern:@"`(.+?)`" options:0 error:nil];

    NSArray *boldMatches = [boldRegex matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    for (NSTextCheckingResult *match in [boldMatches reverseObjectEnumerator]) {
        NSRange contentRange = [match rangeAtIndex:1].location != NSNotFound ? [match rangeAtIndex:1] : [match rangeAtIndex:2];
        NSString *content = [string substringWithRange:contentRange];
        [attrString replaceCharactersInRange:match.range withString:content];
        [attrString addAttribute:NSFontAttributeName value:boldFont range:NSMakeRange(match.range.location, content.length)];
    }

    string = [attrString string];
    NSArray *codeMatches = [codeRegex matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    for (NSTextCheckingResult *match in [codeMatches reverseObjectEnumerator]) {
        NSRange contentRange = [match rangeAtIndex:1];
        NSString *content = [string substringWithRange:contentRange];
        [attrString replaceCharactersInRange:match.range withString:content];
        [attrString addAttribute:NSFontAttributeName value:codeFont range:NSMakeRange(match.range.location, content.length)];
        [attrString addAttribute:NSBackgroundColorAttributeName value:[NSColor colorWithWhite:0.95 alpha:1.0] range:NSMakeRange(match.range.location, content.length)];
    }

    string = [attrString string];
    NSArray *italicMatches = [italicRegex matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    for (NSTextCheckingResult *match in [italicMatches reverseObjectEnumerator]) {
        NSRange contentRange = [match rangeAtIndex:1].location != NSNotFound ? [match rangeAtIndex:1] : [match rangeAtIndex:2];
        NSString *content = [string substringWithRange:contentRange];
        [attrString replaceCharactersInRange:match.range withString:content];
        [attrString addAttribute:NSFontAttributeName value:italicFont range:NSMakeRange(match.range.location, content.length)];
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
