This file describes changes in the json package.

## 3.0.0 (2026-09-28)

- Make the kernel extension optional by adding pure GAP parsing and string
  escaping; the kernel extension still speeds up common cases
- Harden parsing: limit nesting to 1024 containers (deeper input used to
  overflow the stack), validate UTF-8 in parsed strings, fix trailing-data
  checks for embedded NUL bytes, and make parse errors stable
- Write finite floats as valid JSON numbers, and non-finite floats with
  Python's `NaN` and `Infinity` spellings, which are now also accepted on
  input alongside the lowercase spellings of earlier releases
- Reject non-real float objects explicitly
- Speed up `GapToJsonString` on floats, e.g. from 515 ms to 290 ms for a list of
  200,000 floats

## 2.5.0 (2026-09-25)

- Speed up `GapToJsonString` by serialising integers, booleans, strings, lists
  and records directly in the kernel
- Fix `GapToJsonString` failing on strings ending in a truncated multi-byte
  sequence, e.g. `[ CHAR_INT(200) ]`
- Avoid format-string vulnerabilities (#35)
- Drop the dependency on GAPDoc (#37)

## 2.4.0 (2026-05-08)

- Janitorial changes

## 2.3.0 (2026-05-08)

- Encode `fail` as JSON `null` in `GapToJsonString`, which used to raise an
  "Invalid Boolean" error

## 2.2.3 (2025-06-21)

- Janitorial changes

## 2.2.2 (2024-08-27)

- Load the kernel extension via `LoadKernelExtension`

## 2.2.1 (2024-04-24)

- Fix compiler warnings

## 2.2.0 (2024-01-22)

- Speed up JSON output

## 2.1.1 (2022-10-18)

- Require GAP >= 4.12

## 2.1.0 (2022-02-22)

- Output record components in sorted order
- Include `compiled.h` instead of `src/compiled.h`, for compatibility with
  future GAP versions

## 2.0.2 (2020-04-03)

- Replace the autotools build system by one based on `gac`

## 2.0.1 (2019-11-03)

## 2.0.0 (2018-06-08)

## 1.2.0 (2017-10-10)

## 1.1.0 (2016-11-01)

## 1.0.1 (2016-02-15)

## 1.0.0 (2015-11-03)

## 0.8.2 (2015-02-08)

## 0.8.1 (2014-12-10)

## 0.8.0 (2014-11-20)

## 0.1 (2014-11-18)
