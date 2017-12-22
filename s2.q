// s2.q - s2 geospatial functions

// Load all functions
.s2.load: {
  .s2.cellids:: (`$"qs2") 2:(`cellids;2);
  .s2.cellidrange:: (`$"qs2") 2:(`cellidrange;1);
  .s2.covering_ex:: (`$"qs2") 2:(`covering;4);        // get cell ids
  .s2.covering:: { .s2.covering_ex[x;y;16i;30i] };    
  .s2.contains:: (`$"qs2") 2:(`contains;4);           // poly/rect contains
  .s2.clockwise:: (`$"qs2") 2:(`clockwise;2);         // are poly points clockwise?
  };

// NOTE - tables are expected to have `cid`, `lat` and `lon` columns for many functions.

// Generate Cell IDs
.s2.xcid: { update cid: .s2.cellids[lat; lon] from x };

// Arrange table for optimal lookup via `cid`
.s2.xcidpart: { update cid: `p# cid from `cid xasc x };

// Very approximate conversion of a lat/lon pair (eg: distance) to kilometres
// NOTE: Does not take into account that lat distances change the further away from the equator you are...
.s2.ptokm: {[p]
  lat: p 0;
  lon: p 1;
  latkm: 110.574 * lat;
  lonkm: lon * 111.320 * cos 0.0174533 * lat;
  (latkm;lonkm)
  };

// NOTE - where parameters are named `plat`/`plon`, the function can accept either:
//  * a rectangle (2 entries per list)
//  * a polyline loop (3 or more entries per list)

// Get list of (index;count) rows which are covered by
// cells of rectangle or loop plat/plon
// These can be used as paramaters to select[x]...
.s2.xcoveredrows: {[plat;plon;t]
  cidsr: .s2.cellidrange .s2.covering[plat;plon];
  rowparams: flip deltas t[`cid] binr/:cidsr;
  rowparams
  };

// Get cols `c` from table `t` as specified
// via `r` (from .s2.coveredrows)
.s2.xgetrows: {[t;c;r]
  raze {[c;t;x] ?[t;();0b;c!c;x]}[c;t;] each r
  };

// Get all cols of rows covered by cells from plat/plon from t
.s2.xcovered: {[plat;plon;t]
  c: cols t;
  c: c where c <> `cid;
  .s2.xgetrows[t;c;] .s2.xcoveredrows[plat;plon;t]
  };

// As above, but `maxcells` is maximum coverage for the rect
// and `maxdepth` is maximum s2 cell depth of any cell
.s2.xcovered_ex: {[plan;plon;t;maxcells;maxdepth]
  cidsr: .s2.cellidrange .s2.covering_ex[plat;plon;maxcells;maxdepth];
  raze {select[x] from y}[;t] each flip deltas t[`cid] binr/:cidsr
  };

// Get from `t` using a proper lat/lon rect clip check (plat/plat) where len == 2
// Get from `t` using a proper polyline clip check (plat/plon) where len >= 3
// For polyline, plat/plon points must be in CCW order.
.s2.xcontains: {[plat;plon;t]
  r: select from t where .s2.contains[plat; plon; lat; lon];
  r
  };

// Easy Lookup
// Works well for small rectangles as majority of points are
// culled before proper clipping
.s2.lookup: {[plat;plon;t]
  .s2.xcontains[plat;plon;] .s2.xcovered[plat;plon;] t
  };
