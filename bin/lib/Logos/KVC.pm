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
        distanceToPattern('\\"') < distanceToPattern('[^\\]]"')) {
            # Scan escaped quote
            scanUpToPattern('\\"');
            scanPattern('\\"');
        }

    # Scan closing quote
    unless (scanUpToPattern('"') && scanPattern('"')) { $pos = $_start; return 0; };

    return 1;
}

sub insideString {
    my $_start = $pos;
    $pos = 0;

    # While we're behind our spot...
    while ($pos++ < $_start) {
        # Can we scan a string and moved past our spot?
        if (scanStringLiteral() && $pos >= $_start) {
            $pos = $_start;
            return 1;
        }
    }

    { $pos = $_start; return 0; };
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
            scanUpToPattern($open);
            scanBracePair($open, $close);
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
        if ((scanObjectToken() || scanParenthesis()) && $pos == $oldPos) {
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

# Leaves cursor just before the .%
# Returns (key, object, range.loc, range.length)
sub scanKVCKeyAndObjectAndLengths() {
    my $postKVCPos = $pos;
    my $preKVCPos = $pos - 2;
    my $key = undef;
    my $keyLength = undef;

    # Case: foo.%bar
    if (scanIdentifier()) {
        # Scan the "key" and surround it in @"" quotes
        $key = substr($_line, $postKVCPos, $pos - $postKVCPos);
        $keyLength = length($key); # for range to replace
        $key = '@"' . $key . '"';
    }
    # Case: foo.%(...)
    elsif (scanParenthesis()) {
        # Scan the "key" which could be anything
        $key = substr($_line, $postKVCPos, $pos - $postKVCPos);
        $keyLength = length($key);
    }

    # Case: setter syntax: ' = (stuff);'
    my $setterPattern = '\s*=\s*([^;]+);';
    my $val = undef;
    my $setterLength = 0;
    if (scanUpToPattern($setterPattern)) {
        if (substr($_line, $pos) =~ /^($setterPattern)/) {
            $val = $2;
            $setterLength = length($1) - 1; # we don't want the ';'
        }
    }

    # Back up to before the key
    $pos = $preKVCPos;

    # Scan the "object"
    my $object = scanObjectBehindCursor();
    my $objLength = length($object);

    # Compute range to replace (loc, len)
    # Length is target.length + len(".%") + key.length
    my $loc = $pos - $objLength;
    my $len = $objLength + 2 + $keyLength + $setterLength;

    # Scan past the .%
    $pos = $postKVCPos;

    return ($key, $object, $val, $loc, $len);
}

sub replaceSetters {
    $pos = 0;

    while (scanUpToPattern('\.%') && scanPattern('\.%')) {
        if (!insideString()) {
            # Get associated variables
            my ($key, $object, $val, $loc, $len) = scanKVCKeyAndObjectAndLengths();

            if ($val) {
                # Replace the range with the KVC setter
                substr($_line, $loc, $len) = "[(id)$object setValue:$val forKey:$key]";

                # Continue scanning from the start of the new code,
                # as the key may contain more .% calls inside it
                $pos = $loc;
            } else {
                
            }
        }
    }
}

sub replaceGetters {
    $pos = 0;

    while (scanUpToPattern('\.%') && scanPattern('\.%')) {
        if (!insideString()) {
            # Get associated variables
            my ($key, $object, $val, $loc, $len) = scanKVCKeyAndObjectAndLengths();

            # Replace the range with the KVC getter
            substr($_line, $loc, $len) = "[(id)$object valueForKey:$key]";

            # Continue scanning from the start of the new code,
            # as the key may contain more .% calls inside it
            $pos = $loc;
        }
    }
}

sub processKVC {
    $_line = shift;
    replaceSetters();
    replaceGetters();

    return $_line;
}

1;
