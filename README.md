# Bencode

A Janet library for decoding data in the [Bencode][0] format.

I read through the source code of several Bencode libraries but I spent the most
time with the [nREPL/bencode][1] project, I used a lot of their test strings to
verify that this implementation was working correctly.

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

We provide three functions to make it easier to consume data in the Bencode 
format. The easiest case is when you have one a string with one data structure.

```janet
(import bencode)

(var data (bencode/read-buffer "d3:ham4:eggs4:costi5ee"))
```

The `read-buffer` function reads the first structure from the buffer and returns
it. If you have more than one structure, you will want to wrap a reader around
your buffer.

```janet
(import bencode)

(var reader (bencode/reader "d3:ham4:eggs4:costi5eed3:ham4:eggse"))
(var item1 (bencode/read reader))
(var item2 (bencode/read reader))
```

The `reader` function returns a map that includes that buffer of data and keeps
track of what data has been read from the buffer. The `read` function accepts a
reader and returns the next data structure in the buffer.

When we read a map from the buffer, the keys are turned into keywords by 
default. You can change this behavior by passing a `false` after the reader.

## Writing

We provide two function you may use to encode Janet data structures into the
bencode format. The easiest case is when you have a data structure and would
like a buffer with the same data in the bencode format.

When a map is encoded, the keys are encoded as strings.

```janet
(import bencode)

(var buffer-out (bencode/write {:name "Emily" :job "Student"}))
```

The `write-buffer` function accepts a buffer and a data structure and appends
that data in the bencode format.

```janet
(import bencode)

(let [buffer-out @""]
  (bencode/write-buffer buffer-out {:name "Emily" :job "Student"})
  (bencode/write-buffer buffer-out {:name "Joanna" :job "Career Advisor"}))
```

The buffer will now contain two data structures in the bencode format.

----

[0]: https://en.wikipedia.org/wiki/Bencode
[1]: https://github.com/nrepl/bencode
