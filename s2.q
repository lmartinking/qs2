.s2.load: {
  .s2.cellids:: (`$"qs2") 2:(`cellids;2);
  .s2.covering_ex:: (`$"qs2") 2:(`covering;4);        // rect -> cell ids
  .s2.covering2_ex:: (`$"qs2") 2:(`covering2;4);      // poly -> cell ids
  .s2.covering:: { .s2.covering_ex[x;y;16i;30i] };    
  .s2.covering2:: { .s2.covering2_ex[x;y;16i;30i] };
  .s2.contains:: (`$"qs2") 2:(`contains;4);           // rect
  .s2.contains2:: (`$"qs2") 2:(`contains2;4);         // poly
  .s2.cellidrange:: (`$"qs2") 2:(`cellidrange;1);

  .s2.clockwise:: (`$"qs2") 2:(`clockwise;2);

  .s2.area: (`$"qs2") 2:(`area;2);
  };

// Generate Cell IDs
.s2.xcid: { update cid: .s2.cellids[lat; lon] from x };
// Arrange for optimal lookup via `cid`
.s2.xcidpart: { update cid: `p# cid from `cid xasc x };

.s2.ptokm: {[p]
  lat: p 0;
  lon: p 1;
  latkm: 110.574 * lat;
  lonkm: lon * 111.320 * cos 0.0174533 * lat;
  (latkm;lonkm)
  };

// Get list of (index;count) rows which are covered by
// cells of rectangle (lat lon) p1/p2
// These can be used as paramaters to select[x]...
.s2.xcoveredrows: {[p1;p2;t]
  cidsr: .s2.cellidrange .s2.covering[p1;p2];
  rowparams: flip deltas t[`cid] binr/:cidsr;
  show "size(km): ","," sv string each reverse .s2.ptokm (p1[0] - p2[0]; p2[1] - p1[1]);
  show "xcoveredrows: ", string sum last flip rowparams;
  rowparams
  };

// Get cols `c` from table `t` as specified
// via `r` (from .s2.coveredrows)
.s2.xgetrows: {[t;c;r]
  raze {[c;t;x] ?[t;();0b;c!c;x]}[c;t;] each r
  };

// Get all cols of rows covered by p1/p2 from t
.s2.xcovered: {[p1;p2;t]
  c: cols t;
  c: c where c <> `cid;
  .s2.xgetrows[t;c;] .s2.xcoveredrows[p1;p2;t]
  };

// As above, but `maxcells` is maximum coverage for the rect
// and `maxdepth` is maximum s2 cell depth of any cell
.s2.xcovered_ex: {[p1;p2;t;maxcells;maxdepth]
  cidsr: .s2.cellidrange .s2.covering_ex[p1;p2;maxcells;maxdepth];
  raze {select[x] from y}[;t] each flip deltas t[`cid] binr/:cidsr
  };

// Get from `t` using a proper lat/lon rect clip check (p1/p2)
.s2.xcontains: {[p1;p2;t]
  r: select from t where .s2.contains[p1; p2; lat; lon];
  show "xcontains: ",string count r;
  r
  };

// Works well for small rectangles as majority are
// culled before proper clipping
.s2.lookup: {[rect;t]
  p1: rect 0; p2: rect 1;
  .s2.xcontains[p1;p2;] .s2.xcovered[p1;p2;] t
  };

.s2.lookup2: {[rect;t]
  p1: rect 0; p2: rect 1;
  cidsr: .s2.cellidrange .s2.covering[p1;p2];
  raze {[p1;p2;x;y] select from (select[x] from y) where .s2.contains[p1; p2; lat; lon]}[p1;p2;;t] each flip deltas t[`cid] binr/:cidsr
  };

.s2.lookup_ex: {[rect;t;maxcells;maxdepth]
  p1: rect 0; p2: rect 1;
  .s2.xcontains[p1;p2;] .s2.xcovered_ex[p1;p2;;`int$maxcells;`int$maxdepth] t
  };


.s2.xcovered2_ex: {[plat;plon;t;maxcells;maxdepth]
  cidsr: .s2.cellidrange .s2.covering2_ex[plat;plon;maxcells;maxdepth];
  raze {select[x] from y}[;t] each flip deltas t[`cid] binr/:cidsr
  };

// Get from `t` using a proper polyline clip check (plat/plon)
// plat/plon points must be in CCW order.
.s2.xcontains2: {[plat;plon;t]
  r: select from t where .s2.contains2[plat; plon; lat; lon];
  show "xcontains: ",string count r;
  r
  };
