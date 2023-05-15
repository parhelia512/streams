/**
 * A collection of compile-time functions to help in identifying stream types
 * and related flavors of them.
 *
 * Streams come in two main flavors: ${B input} and ${B output} streams.
 * 
 * ${B Input streams} are defined by the presence of a `read` function with the
 * following signature:
 * ```d
 * int read(DataType[] buffer)
 * ```
 *
 * ${B Output streams} are defined by the presence of a `write` function with
 * the following signature:
 * ```d
 * int read(DataType[] buffer)
 * ```
 *
 * Usually these functions can be used as [Template Constraints](https://dlang.org/spec/template.html#template_constraints)
 * when defining your own functions and symbols to work with streams.
 * ```d
 * void useBytes(S)(S stream) if (isInputStream!(S, ubyte)) {
 *     ubyte[] buffer = new ubyte[8192];
 *     int bytesRead = stream.read(buffer);
 *     // Do something with the data.
 * }
 * ```
 */
module streams.primitives;

import std.traits;
import std.range;

const INPUT_STREAM_METHOD = "readFromStream";
const OUTPUT_STREAM_METHOD = "writeToStream";

/** 
 * Determines if the given template argument is some form of input stream,
 * where an input stream is anything with a `read` method that takes a single
 * array parameter, and returns an integer number of elements that were read,
 * or -1 in case of error. This method does not care about the type of elements
 * that can be read by the stream.
 *
 * Returns: `true` if the given argument is an input stream type.
 */
bool isSomeInputStream(StreamType)() {
    // Note: We use a cascading static check style so the compiler runs these checks in this order.
    static if (__traits(hasMember, StreamType, INPUT_STREAM_METHOD)) {
        alias func = __traits(getMember, StreamType, INPUT_STREAM_METHOD);
        static if (isCallable!func && is(ReturnType!func == int)) {
            static if (Parameters!func.length == 1) {
                return isDynamicArray!(Parameters!func[0]);
            } else { return false; }
        } else { return false; }
    } else { return false; }
}

unittest {
    struct S1 {
        int readFromStream(ubyte[] buffer) { return 0; } // cov-ignore
    }
    assert(isSomeInputStream!S1);
    struct S2 {
        int readFromStream(bool[] buffer) { return 42; } // cov-ignore
    }
    assert(isSomeInputStream!S2);
    struct S3 {
        int readFromStream(bool[] buffer, int otherArg) { return 0; } // cov-ignore
    }
    assert(!isSomeInputStream!S3);
    struct S4 {
        void readFromStream(long[] buffer) {}
    }
    assert(!isSomeInputStream!S4);
    struct S5 {
        int readFromStream = 10;
    }
    assert(!isSomeInputStream!S5);
    struct S6 {}
    assert(!isSomeInputStream!S6);
    interface I1 {
        int readFromStream(ubyte[] buffer);
    }
    assert(isSomeInputStream!I1);
    class C1 {
        int readFromStream(ubyte[] buffer) { return 0; } // cov-ignore
    }
    assert(isSomeInputStream!C1);
}

/** 
 * Determines if the given template argument is some form of output stream,
 * where an output stream is anything with a `write` method that takes a single
 * array parameter, and returns an integer number of elements that were read,
 * or -1 in case of error. This method does not care about the type of elements
 * that can be read by the stream.
 *
 * Returns: `true` if the given argument is an output stream type.
 */
bool isSomeOutputStream(StreamType)() {
    // Note: We use a cascading static check style so the compiler runs these checks in this order.
    static if (__traits(hasMember, StreamType, OUTPUT_STREAM_METHOD)) {
        alias func = __traits(getMember, StreamType, OUTPUT_STREAM_METHOD);
        static if (isCallable!func && is(ReturnType!func == int)) {
            static if (Parameters!func.length == 1) {
                return isDynamicArray!(Parameters!func[0]);
            } else { return false; }
        } else { return false; }
    } else { return false; }
}

unittest {
    struct S1 {
        int writeToStream(ubyte[] buffer) { return 0; } // cov-ignore
    }
    assert(isSomeOutputStream!S1);
    struct S2 {
        int writeToStream(bool[] buffer) { return 42; } // cov-ignore
    }
    assert(isSomeOutputStream!S2);
    struct S3 {
        int writeToStream(bool[] buffer, int otherArg) { return 0; } // cov-ignore
    }
    assert(!isSomeOutputStream!S3);
    struct S4 {
        void writeToStream(long[] buffer) {}
    }
    assert(!isSomeOutputStream!S4);
    struct S5 {
        int writeToStream = 10;
    }
    assert(!isSomeOutputStream!S5);
    struct S6 {}
    assert(!isSomeOutputStream!S6);
}

/** 
 * A template that evaluates to the type of a given input or output stream.
 * Params:
 *   S = The stream to get the type of.
 */
template StreamType(S) if (isSomeStream!S) {
    static if (isSomeInputStream!S) {
        alias StreamType = ElementType!(Parameters!(__traits(getMember, S, INPUT_STREAM_METHOD))[0]);
    } else {
        alias StreamType = ElementType!(Parameters!(__traits(getMember, S, OUTPUT_STREAM_METHOD))[0]);
    }
}

unittest {
    import streams;
    auto sIn1 = arrayInputStreamFor!ubyte([1, 2, 3]);
    assert(is(StreamType!(typeof(sIn1)) == ubyte));
}

/** 
 * Determines if the given stream type is an input stream for reading data of
 * the given type.
 * Returns: `true` if the given stream type is an input stream.
 */
bool isInputStream(StreamType, DataType)() {
    static if (isSomeInputStream!StreamType) {
        return is(Parameters!(__traits(getMember, StreamType, INPUT_STREAM_METHOD))[0] == DataType[]);
    } else {
        return false;
    }
}

unittest {
    // Test a valid input stream.
    struct S1 {
        int read(ubyte[] buffer) {
            return 0; // cov-ignore
        }
    }
    assert(isInputStream!(S1, ubyte));

    // Test a few invalid input streams.
    struct S2 {}
    assert(!isInputStream!(S2, ubyte));
    struct S3 {
        void read(ubyte[] buffer) {
            // Invalid return type!
        }
    }
    assert(!isInputStream!(S3, ubyte));
    struct S4 {
        int read() {
            return 0; // cov-ignore
        }
    }
    assert(!isInputStream!(S4, ubyte));
    class C1 {
        int read(char[] buffer) {
            return 0; // cov-ignore
        }
    }
    assert(isInputStream!(C1, char));
}

/** 
 * Determines if the given stream type is an output stream for writing data of
 * the given type.
 * Returns: `true` if the given stream type is an output stream.
 */
bool isOutputStream(StreamType, DataType)() {
    static if (isSomeOutputStream!StreamType) {
        return is(Parameters!(__traits(getMember, StreamType, OUTPUT_STREAM_METHOD))[0] == DataType[]);
    } else {
        return false;
    }
}

unittest {
    // Test a valid output stream.
    struct S1 {
        int writeToStream(ref ubyte[] buffer) {
            return 0; // cov-ignore
        }
    }
    assert(isOutputStream!(S1, ubyte));

    // Test a few invalid output streams.
    struct S2 {}
    assert(!isOutputStream!(S2, ubyte));
    struct S3 {
        void writeToStream(ubyte[] buffer) {
            // Invalid return type!
        }
    }
    assert(!isOutputStream!(S3, ubyte));
    struct S4 {
        int writeToStream() {
            return 0; // cov-ignore
        }
    }
    assert(!isOutputStream!(S4, ubyte));
}

/** 
 * Determines if the given template argument is a stream of any kind; that is,
 * it is at least implementing the functions required to be an input or output
 * stream.
 * Returns: `true` if the given argument is some stream.
 */
bool isSomeStream(StreamType)() {
    return isSomeInputStream!StreamType || isSomeOutputStream!StreamType;
}

unittest {
    struct S1 {
        int read(ubyte[] buffer) {
            return 0; // cov-ignore
        }
    }
    assert(isSomeStream!S1);
    struct S2 {
        int write(ubyte[] buffer) {
            return 0; // cov-ignore
        }
    }
    assert(isSomeStream!S2);
    struct S3 {}
    assert(!isSomeStream!S3);
}

/** 
 * Determines if the given stream type is an input or output stream for data of
 * the given type.
 * Returns: `true` if the stream type is an input or output stream for the given data type.
 */
bool isSomeStream(StreamType, DataType)() {
    return isInputStream!(StreamType, DataType) || isOutputStream(StreamType, DataType);
}

/** 
 * Determines if the given stream type is an input stream for `ubyte` elements.
 * Returns: `true` if the stream type is a byte input stream.
 */
bool isByteInputStream(StreamType)() {
    return isInputStream!(StreamType, ubyte);
}

/** 
 * Determines if the given stream type is an output stream for `ubyte` elements.
 * Returns: `true` if the stream type is a byte output stream.
 */
bool isByteOutputStream(StreamType)() {
    return isOutputStream!(StreamType, ubyte);
}

/** 
 * Determines if the given template argument is a closable stream type, which
 * defines a `void close()` method as a means to close and/or deallocate the
 * underlying resource that the stream reads from or writes to.
 *
 * Returns: `true` if the given argument is a closable stream.
 */
bool isClosableStream(StreamType)() {
    static if (
        isSomeStream!StreamType &&
        hasMember!(StreamType, "close") &&
        isCallable!(StreamType.close)
    ) {
        alias closeFunction = StreamType.close;
        alias params = Parameters!closeFunction;
        return (
            allSameType!(void, ReturnType!closeFunction) &&
            params.length == 0
        );
    } else {
        return false;
    }
}

unittest {
    struct S1 {
        int read(ubyte[] buffer) {
            return 0; // cov-ignore
        }
        void close() {}
    }
    assert(isClosableStream!S1);
    struct S2 {
        int read(ubyte[] buffer) {
            return 0; // cov-ignore
        }
    }
    assert(!isClosableStream!S2);
    struct S3 {}
    assert(!isClosableStream!S3);
}

/** 
 * Determines if the given template argument is a flushable stream type, which
 * is any output stream that defines a `void flush()` method, which should
 * cause any data buffered by the stream or its resources to be flushed. The
 * exact nature of how a flush operates is implementation-dependent.
 *
 * Returns: `true` if the given argument is a flushable stream.
 */
bool isFlushableStream(StreamType)() {
    static if (
        isSomeOutputStream!StreamType &&
        hasMember!(StreamType, "flush") &&
        isCallable!(StreamType.flush)
    ) {
        alias flushFunction = StreamType.flush;
        alias params = Parameters!flushFunction;
        return (
            allSameType!(void, ReturnType!flushFunction) &&
            params.length == 0
        );
    } else {
        return false;
    }
}

unittest {
    struct S1 {
        int write(ubyte[] buffer) {
            return 0; // cov-ignore
        }
        void flush() {}
    }
    assert(isFlushableStream!S1);
    struct S2 {
        int write(ubyte[] buffer) {
            return 0; // cov-ignore
        }
    }
    assert(!isFlushableStream!S2);
    struct S3 {}
    assert(!isFlushableStream!S3);
}

/** 
 * An exception that may be thrown if an illegal operation or error occurs
 * while working with streams. Generally, if an exception is to be thrown while
 * reading or writing in a stream's implementation, a `StreamException` should
 * be wrapped around it to provide a common interface for error handling.
 */
class StreamException : Exception {
    import std.exception;

    mixin basicExceptionCtors;
}

/** 
 * An input stream that always reads 0 elements.
 */
struct NoOpInputStream(T) {
    int read(T[] buffer) {
        return 0;
    }
}

/** 
 * An output stream that always writes 0 elements.
 */
struct NoOpOutputStream(T) {
    int write(T[] buffer) {
        return 0;
    }
}

/** 
 * An input stream that always returns a -1 error response.
 */
struct ErrorInputStream(T) {
    int read(T[] buffer) {
        return -1;
    }
}

/** 
 * An output stream that always returns a -1 error response.
 */
struct ErrorOutputStream(T) {
    int write(T[] buffer) {
        return -1;
    }
}

unittest {
    auto s1 = NoOpInputStream!ubyte();
    ubyte[] buffer = new ubyte[3];
    assert(s1.read(buffer) == 0);
    assert(buffer == [0, 0, 0]);
    
    auto s2 = NoOpOutputStream!ubyte();
    assert(s2.write(buffer) == 0);

    auto s3 = ErrorInputStream!ubyte();
    assert(s3.read(buffer) == -1);

    auto s4 = ErrorOutputStream!ubyte();
    assert(s4.write(buffer) == -1);
}
