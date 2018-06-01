package Logos::KVC;
use strict;

use feature qw(say);

my $_line = '';
my $pos = 0;
my $scanned = '';

sub scanPattern {
    my $pattern = shift;
    my $skipSpaces = shift == undef;
    if ($skipSpaces) {
        if (substr($_line, $pos) =~ /^(\s*($pattern))/) {
            $pos += length($1);
            $scanned = $1;
            return 1;
        }
    } else {
        if (substr($_line, $pos) =~ /^(($pattern))/) {
            $pos += length($1);
            $scanned = $1;
            return 1;
        }
    }

    return 0;
}

sub scanUpToPattern {
    my $pattern = shift;
    if (substr($_line, $pos) =~ /^(.*?)$pattern/) {
        $pos += length($1);
        $scanned = $1;
        return 1;
    }

    return 0;
}

sub distanceToPattern {
    my $pattern = shift;
    if (substr($_line, $pos) =~ /^(.*?)$pattern/) {
        return length($1);
    }

    return -1;
}

sub scanStringLiteral {
    my $_start = $pos;

    # Scan opening quote
    unless (scanPattern('"')) { $pos = $_start; return 0; };

    # Case: has escaped quotes
    while (distanceToPattern('\\"') != -1 &&
        distanceToPattern('\\"') < distanceToPattern('[^\\]"')) {
            # Scan escaped quote
            scanUpToPattern('\\"');
            scanPattern('\\"');
        }

    # Scan closing quote
    unless (scanUpToPattern('"') && scanPattern('"')) { $pos = $_start; return 0; };

    return 1;
}

sub scanBracePair {
    my $_start = $pos;

    my $open = shift;
    my $close = shift;

    # Scan opening bracket
    unless (scanPattern($open)) { $pos = $_start; return 0; };

    # Check for inner pairs of brackets
    while (distanceToPattern($open) != -1 &&
        distanceToPattern($open) < distanceToPattern($close)) {
            # Scan inner pair of brackets
            scanMethodCall();
        }

    # Scan closing bracket
    unless (scanUpToPattern($close) && scanPattern($close)) { $pos = $_start; return 0; };

    return 1;
}

sub scanArrayBraces {
    return scanBracePair('\[', '\]');
}

sub scanDictionaryBraces {
    return scanBracePair('\{', '\}');
}

sub scanAngleBrackets {
    return scanBracePair('<', '>');
}

sub scanParenthesis {
    return scanBracePair('\(', '\)');
}

sub scanMethodCall {
    return scanArrayBraces();
}

sub scanObjectLiteral {
    my $_start = $pos;

    unless (scanPattern("@")) { $pos = $_start; return 0; };
    unless (
    scanStringLiteral() ||
    scanArrayBraces() ||
    scanDictionaryBraces() ||
    scanParenthesis() ||
    scanPattern('\d+')
    ) { $pos = $_start; return 0; };

    return 1;
}

sub scanIdentifier {
    my $_start = $pos;
    unless (
    scanPattern('[\w\$]') &&
    scanPattern('[\w\d\$]*', 1) # Do not ignore leading spaces.
                                # Avoids scanning "n foo" out of "return foo;"
    ) { $pos = $_start; return 0; };

    return 1;
}

sub scanObjectToken {
    my $_start = $pos;
    unless (
    scanObjectLiteral() ||
    scanIdentifier() ||
    scanMethodCall()
    ) { $pos = $_start; return 0; };

    # We stop at .% accesses to start the replacement
    if (distanceToPattern('\.%') == 0) {
        return 1;
    }

    # Potentially scan property access chain
    while (scanPattern('\.')) {
        # Do I need to add scanPattern('%') here?
        unless (scanIdentifier()) { $pos = $_start; return 0; };

        # We stop at .% accesses to start the replacement
        if (distanceToPattern('\.%') == 0) {
            last; # break
        }
    }

    return 1;
}

sub scanObjectBehindCursor() {
    my $_start = $pos;
    my $oldPos = $pos;

    # Start at the beginning of the line, and
    # repeatedly increment our current position, until
    # we scan a whole object token up to where we started.
    $pos = 0;
    while ($pos < $oldPos) {
        # We found an object token, but is it the right one?
        # ie, did we only find `self.foo` out of `self.foo = mop.bar.%baz`?
        # Keep going until we find the right token.
        #
        # Note: In the other direction (working backwards) we have another problem.
        # We will first find `foo.bar` out of `[foo.bar baz].%whatever`.
        # We would need to keep going back until we hit `[foo.bar baz]` entirely.
        my $preScanPos = $pos;
        if (scanObjectToken() && $pos == $oldPos) {
            my $obj = substr($_line, $preScanPos, $pos - $preScanPos);

            # Skip over leading whitespace
            while ($obj =~ /^\s/) {
                # Move forward one char...
                $preScanPos += 1;
                $pos = $preScanPos;
                # Scan again...
                scanObjectToken();
                $obj = substr($_line, $preScanPos, $pos - $preScanPos);
            }

            return $obj;
        } else {
            $pos = $preScanPos;
            $pos += 1;
        }
    }

    # Failed, reset
    { $pos = $_start; return 0; };
}

sub replaceSetters {
    $pos = 0;
    my $setterRegex = '\.%([\w\d]+) = ([^;]+);';
    while (scanUpToPattern($setterRegex)) {
        $scanned =~ s/\s*(.*)/$1/;
        $_line =~ s/($scanned)$setterRegex/[$1 setValue:$3 forKey:@"$2"];/g;
    }
}

sub replaceGetters {
    $pos = 0;
    while (scanUpToPattern('\.%([\w\d]+)')) {
        # Todo: regex escape $object and use it
        # instead of using .{$length} in the pattern
        my $object = scanObjectBehindCursor();
        my $length = length($object);
        $_line =~ s/(.{$length})\.%([\w\d]+)/[(id)$1 valueForKey:@"$2"]/;
    }
}

sub processKVC {
    $_line = shift;
    replaceSetters();
    replaceGetters();

    return $_line;
}

1;
