# Temporary Note of Debug Proposal

As discussed at https://sqlite.org/forum/forumpost/42e647999d , which also has demo code. 
When this is in SQLite, this file can be deleted. 


# Overview

This posting and the C code following in the same thread represent an approach I am volunteering to implement in SQLite, if it is agreed to be a good approach. 

Adding and using debugging code in SQLite [has some strange problems](1772cb4a37) which can be easily addressed with the changes proposed in that post, which I am also volunteering to make. But there is a much bigger scope to the problem, which I think can also be safely addressed as follows.

# Goal of This Proposal

To add a minimal superset of compile-time debug options to SQLite in sqlInt.h,
with the intention of:

* not disturbing any existing debug code anywhere

* allowing lightweight debugging such as printing only progress
statements, without the execution-time overhead of the current
DEBUG_SQLITE

* allowing only certain classes of debug options to be compiled, which
addresses the previous point but also allows for selecting just some of the
heavyweight debugging options 

* allowing existing debug code to be safely and simply upgraded to the new
discriminated debugging system, with no unexpected changes in functionality to
users of existing debug facilities

Note: Debugging is not logging. This proposal only discusses debugging, which
is enabled by developers at compiletime. SQLite has a logging system which is
available at runtime and controlled by SQLite users and applications.

# Background

[The compilation documentation](https://www.sqlite.org/compile.html#debugoptions) says:

>The SQLite source code contains literally thousands of assert() statements
used to verify internal assumptions and subroutine preconditions and
postconditions. These assert() statements are normally turned off (they
generate no code) since turning them on makes SQLite run approximately three
times slower. But for testing and analysis, it is useful to turn the assert()
statements on.

Adding thousands of assert() statements and even more thousands of lines
of non-assert debug code is not desirable when testing just one particular aspect of SQLite, or wanting to print just one debugging line in just one function. Sometimes this debug code can interfere with SQLite behaviour in addition to just making it run slowly. While it is important to be able to do global debugging, more often a developer is only working on one thing at a time. There is no need to have an entire test suite run much slower for the sake of
observing a single print statement. On resource-constrained targets or where
SQLite is part of a much larger and more complicated codebase the addition of
debugging code can have unpredictable effects.

As an example of debugging code that doesn't make sense to be always-on even
when debugging:

> When compiled with SQLITE_DEBUG, SQLite includes routines that will
print out various internal parse tree structures as ASCII-art graphs.
This can be very useful in a debugging in order to understand the
variables that SQLite is working with.

If we are not interested in these ASCII-art graphs, that's unhelpful extra code
hanging around. On the other hand, if it is a selectable debug option, it might be reasonable to enhance that feature by adding even more code, perhaps by emitting [Pikchr markup](https://pikchr.org/home/doc/trunk/homepage.md).

The goal of this proposal has already been identified as a SQLite need, as
can be seen in the [SQLIte debugging documentation](https://www.sqlite.org/debugging.html) where of the four existing debug macros, two discriminate based on debugging function:

>The SQLITE_ENABLE_SELECTTRACE and SQLITE_ENABLE_WHERETRACE options
are not documented in compile-time options document because they are
not officially supported.

# Opportunity

A common question is whether a project should implement debug levels or debug
classes. This proposal addresses both at once.

Given that there is otherwise no debugging discrimination, we have the
opportunity to assign comprehensive debug levels or classes and
gradually implement them consistently, and leave room for additional
classes and levels to be added in the future. Done well, this will
improve the speed and quality of debugging cycles, and also make it
easier to assist SQLite developers by asking domain-specific debugging
questions. It will encourage better quality thinking about the
debugging process, and be more compatible with the idea of SQLite as a
small, efficient embedded library.

# Potential Problems

* shipping debug: A better debug system might tempt some developers to ship
  some degree of debugging enabled by default in production. This would break
  the idea of debugging as a developer safespace, and potentially expose end
  users to unexpected behaviour. New SQLite debugging features need to be
  strongly documented as "unsupported for production use in all contexts."

* Booleans vs. bitmaps: This proposal uses boolean macros rather than bitmaps,
  except for DEBUG_LEVEL which is a decimal integer.
  Bitmaps would look like:
  <blockquote><tt>
        #define DEBUG_COMMANDLINE 0x00000004<br>
        #define DEBUG_PRAGMA      0x00000008<br>
  </tt></blockquote>
  etc.
  Bitmaps have the classical advantage of being able to be specify multiple
  debugging classes/levels in a single number provided at compile-time, however
  that can only guarantee 31 separate numbers as any more may break on 32-bit
  processors due to the sign bit. Furthermore there are four kinds of endianness
  and again this might break debugging on some architectures.  

* Bitmaps vs. booleans: Using boolean macros means that, say 4 debug classes plus the mandatory SQLITE_SELECTIVE_DEBUG and likely DEBUG_LEVEL, and possible SQLITE_DEBUG makes for an extremely long $CC invocation line. But this is much
  less likely to obscurely break the debug system than architecture/bitmap 
  clashes. Even though we need lots more -D / #define statements.

# How to Use the Following Code

```
compile sqlitedebug with $CC parameters as follows, then run it.
 
    -D SQLITE_DEBUG
    -D SQLITE_SELECTIVE_DEBUG -DDEBUG_LEVEL=1
    -D SQLITE_SELECTIVE_DEBUG -DDEBUG_ALL
    -D SQLITE_SELECTIVE_DEBUG -DDEBUG_VIRTUAL_MACHINE -DDEBUG_STORAGE
    -D SQLITE_SELECTIVE_DEBUG -DDEBUG_LEVEL=2 -DDEBUG_VIRTUAL_MACHINE

some combinations will halt compilation with an error, eg

    -D DEBUG_LEVEL=1                     
                        (no SQLITE_SELECTIVE_DEBUG)
    -D SQLITE_SELECTIVE_DEBUG -D DEBUG_LEVEL=4
                        (debug level out of range)
    -D DEBUG_ALL
                        (no SQLITE_SELECTIVE_DEBUG)

```

Implementation of the debug helper functions include function name and line
number.

# Todo

Agree on a larger initial/better category list

