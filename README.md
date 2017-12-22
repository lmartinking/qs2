qs2
===

Google S2 geometry library extension for kdb+/q.

## Get

You may need to init git submodules:

```
    git submodule update --init --recursive
```

## Build

* Requires `libcrypto` to be installed (eg: `brew install openssl` or `apt-get install libssl-dev`)

```
    $ make {m32,m64,l32,l64} [USE_CLANG=1] [NO_OPENMP=1]
    $ cp qrapidjson_{m32,m64,l32,l64}.so /path/to/q/bin
```

* `USE_CLANG` will use Clang instead of GCC-7 on MacOS. OpenMP will be disabled.
* `NO_OPENMP` will disable OpenMP (not recommended).

NOTE: By default, on MacOS, `qs2` will use `gcc-7` in order to get the performance benefits of OpenMP.
You will need to: `brew install gcc-7`.

## Use

    q) \l s2.q

NOTE: You might need to set `DYLD_LIBRARY_PATH` or `LD_LIBRARY_PATH` environment variables
(Mac and Linux respectively) to the directory where the `.so` lives before running `q`.

### Tables

The `x{name}` family of functions provided by `qs2` work with tables.

Tables must have `lat`, `lon` and can have `cid` columns.

The `cid` column can be generated from `lat`/`lon` using `.s2.xcid` and
arranged for optimal lookup using `.s2.xcidpart`.

If for some reason you do not wish to part your table by `cid` (or even have `cid` present),
you should only use `.s2.xcontains`. This will perform a bounding clip without culling via `cid`.

### Parameters

`plat` and `plon` parameters to functions represent `lat` and `lon` points respectively.
That is, a single list of latitudes and a single list of longitudes. A single point could be `(lat[0], lon[0])`.

### Lat/lon rectangles

When a `plat`/`plon` pair has exactly 2 points, it will be interpreted to be a rectangle,
with the first point representing the top-left and the second point representing the bottom-right of the rectangle.

### Polygons

A `plat`/`plon` pair is considered to be a polygon when it has 3 or more points.
Because it is treated as a closed loop, the last point must not be the same as the first point.

Be aware that polygon lookup is **fairly slow** compared to `lat`/`lon` rectangles.

NOTE: Polygon point order **must** be counter clockwise ordering. Use `.s2.clockwise` to check this.

### Lookup

To lookup all entries in a table which are within a rectangle:

```
// Define rectangle (in this case, Australia)
rect: flip ((-10.349484; 111.297704); (-44.269108; 154.888309));
// Lookup
.s2.lookup[rect 0;rect 1;] table
```

To increase performance, pass through a table containing only the columns you need, for example:

```
.s2.lookup[rect 0;rect 1;] select lat, lon, cid, blah from table
```

This techique is particularly performant when the rectangle or polygon has a small area (eg: a few square kilometres).

When the bounds is large (eg: the size of Victoria or greater), it may be faster to use `.s2.contains` directly (no pre-cull).

## Licence

LGPLv3. See `LICENSE` and `COPYING.LESSER`.

Copyright (c) 2016 Lucas Martin-King.

Other parts of this software (eg: RapidJSON) are covered by other licences.

