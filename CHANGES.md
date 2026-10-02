This file describes changes in the json package.

## 3.0.0 (2026-09-28)

- Make the kernel extension optional. Without it, the package falls back to a
  JSON parser and string escaper written in GAP.
- Add the JSONTestSuite parsing corpus.
- Add a catch for if nesting is too deep, rather than crash.
- Correctly handle infinity and nan. These are handled in the same way
  Python handles them (technically not valid JSON but a common extension).
- Validate UTF-8 in parsed strings, fix trailing-data checks for embedded NUL
  bytes, and make parse errors stable
- Write finite floats as valid JSON numbers, and reject non-real float objects
- Speed up `GapToJsonString` on floats, e.g. from 515 ms to 290 ms for a list of
  200,000 floats

## 2.5.0 (2026-09-25)

- Speed up GapToJsonString by serialising common GAP objects directly in the
  kernel.
- Fix a buffer over-read when escaping a string whose last character is a
  truncated multi-byte UTF-8 sequence, such as [ CHAR_INT(200) ]. Reading past
  the end of the string now yields 0 rather than whatever happened to follow
  it, so the sequence falls back to Latin-1 like any other malformed one
  instead of raising an error or reading out of bounds.
- Avoid format-string vulnerabilities when reporting invalid JSON.
- Remove the unnecessary run-time dependency on GAPDoc.
- Require GAP 4.15 or later.

## 2.4.0 (2026-05-08)

- Janitorial changes

## 2.3.0 (2026-05-08)

- Allow outputting 'fail', it maps to null (null was already read in as fail)

## 2.2.3 (2025-06-21)

- Internal cleanups for new GAP versions

## 2.2.2 (2024-08-27)

- Use up-to-date methods of loading packages in GAP

## 2.2.1 (2024-04-24)

- Internal cleanups for new GAP versions

## 2.2.0 (2024-01-22)

- Speed up outputting JSON, add new tests

## 2.1.1 (2022-10-18)

- Code cleanups
- Require GAP >= 4.12

## 2.1.0 (2022-02-22)

- Change: Keys in dictionaries are now always outputted in lexicographical order

## 2.0.2 (2020-04-03)

- Replace the autotools build system by one based on `gac`

## 2.0.1 (2019-11-03)

- Fix bug in JsonStringToGap, which could lead to entering the break loop.

## 2.0.0 (2018-06-08)

- The Json package now ensures it only outputs valid UTF8. GAP strings which
  contain valid UTF8 are outputted unmodified, invalid UTF8 is treated as Latin-1,
  and transformed into valid UTF8.

## 1.2.0 (2017-10-10)

- Fix compiling in recent versions of XCode on Mac OS X

## 1.1.0 (2016-11-01)

- Fix bug in handling badly formatted integers

## 1.0.1 (2016-02-15)

- Fix bug in nested structures

## 1.0.0 (2015-11-03)

- First release

## 0.8.2 (2015-02-08)

## 0.8.1 (2014-12-10)

## 0.8.0 (2014-11-20)

## 0.1 (2014-11-18)
