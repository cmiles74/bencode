# Bencode

A Janet library for decoding data in the [Bencode][0] format.

![Continuous Integration](https://github.com/cmiles74/bencode/workflows/Continuous%20Integration/badge.svg)

I read through the source code of several Bencode libraries but I spent the most
time with the [nREPL/bencode][1] project, I used a lot of their test strings to
verify that this implementation was working correctly.

If you find this code useful in any way, please feel free to...

<a href="https://www.buymeacoffee.com/cmiles74" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Coffee" style="height: 41px !important;width: 174px !important;box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;-webkit-box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;" ></a>

# Installation

Add the dependency to your project...

```janet
(declare-project
  :dependencies ["https://github.com/cmiles74/bencode"])
```

# Usage

This library provides functions for reading and writing data in the bencode 
format.

## Reading

We provide two functions to make it easier to consume data in the Bencode
format: `read-buffer` and `read-stream`. The easiest case is when you have one a
string with one data structure, you may pass the string to `read-buffer` and get
your ben-decoded data.

```janet
> (import bencode)
> (bencode/read-buffer "d3:ham4:eggs4:costi5ee")
{:cost 5 :ham @"eggs"}
```

Here the "buffer" is the string with the bencoded data. We read the first and
only item from the buffer and return it.

If you have more than one structure, you will want to wrap a reader around your
buffer with the `reader` function.

```janet
> (import bencode)
> (def rdr (bencode/reader "d3:ham4:eggs4:costi5eed3:ham4:eggse"))
@{:buffer "d3:ham4:eggs4:costi5eed3:ham4:eggse" :index 0}
> (bencode/read rdr)
{:cost 5 :ham @"eggs"}
> (bencode/read rdr)
{:ham @"eggs"}
> (bencode/read rdr)
nil
```

If you are reading data from a stream then clearly `read-stream` is the function
for you. You pass it the stream and it reads the next chunk of data, if no data
has yet been written to the stream then it will block until some data is
available. You may also create a reader around your stream with `reader-stream`
and then perform successive read operations.

The `reader` and `reader-stream` functions returns a table includes the buffer
or stream of data and keeps track of what data has been read from the buffer.
The `read` function accepts a reader and returns the next data structure in the
buffer.

The `read-buffer` and `read-stream` functions are for your convenience, they
accept a stream or buffer and then return the next data item from the stream or
buffer. Only one item may be read in this way with `read-buffer`, each call will
create a new reader around the same buffer and will return the same data.

The `read`, `read-buffer` and `read-stream` methods accept the following
keyword-style options:

- When we read a map from the buffer, the keys are turned into keywords by 
  default. You can change this behavior by passing a `:keyword-dicts false`.

- Newlines between the consecutive values can be ignored by passing
  `:ignore-newlines true`.

- By default returned values are immutable: structs, tuples and strings.
  To return mutable values: tables, arrays and buffers - pass
  `:return-mutable true`.

## Writing

We provide two functions you may use to encode Janet data structures into the
bencode format. The easiest case is when you have a data structure and would
like a buffer with the same data in the bencode format.

When a map is encoded, the keys are encoded as strings.

```janet
> (import bencode)
> (def buffer-out (bencode/write {:name "Emily" :job "Student"}))
@"d3:job7:Student4:name5:Emilye"
```

The `write` function accepts a buffer and a data structure and returns a buffer
with the bencoded data.

```janet
> (import bencode)
> (def buffer-out @"")
> (bencode/write {:name "Emily" :job "Student"})
@"d3:job7:Student4:name5:Emilye"
```

The `write-buffer` function accepts a buffer and writes the bencoded value into
that buffer. In the example below we write two items to the buffer.

```janet
> (import bencode)
> (def buffer-out @"")
> (bencode/write-buffer {:name "Emily" :job "Student"})
@"d3:job7:Student4:name5:Emilye"
> (bencode/write-buffer buffer-out {:name "Joanna" :job "Career Advisor"})
@"d3:job7:Student4:name5:Emilyed3:job14:Career Advisor4:name6:Joannae"
```

If you need to write to a stream, you can always write to a buffer and then
write the buffer to the stream. Or you may use the `write-stream` function.

```janet
> (import bencode)
> (def s (net/connect "someserver.com" "8080"))
> (bencode/write-stream s {:name "Emily" :job "Student"})
> (:close s)
```

These functions also accepts some keyword-style options:

- By default the conversion of data is lax which means that for keyword or
  symbol values the type information is lost upon conversion, they are converted
  to strings. If you need to keep the strict invariant `(= str (decode (encode
  str)))`, pass `:strict-conversion true`. This will throw an exception for data
  that cannot be encoded.

# Building

This library uses [JPM][2] to manage dependencies, run tests, etc. If you plan
on hacking away at this library you will need to get JPM installed. With that
out of the way, you may clone the project and pull in the dependencies the 
project needs (at this time, only the testing library).

```shell
$ cd bencode
$ jpm deps
```

The dependencies will be installed and now you can run the test suite.

```shell
$ jpm test
```

The tests should run quickly and they all should pass. If you have a pull 
request, please make sure the tests are passing. `;-)`

----

[0]: https://en.wikipedia.org/wiki/Bencode
[1]: https://github.com/nrepl/bencode
[2]: https://github.com/janet-lang/jpm
