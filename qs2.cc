#include <vector>
#include <cstdio>
#include <thread>
#include <algorithm>
#include <cmath>

#include "s2latlng.h"
#include "s2latlngrect.h"
#include "s2cap.h"
#include "s2cellid.h"
#include "s2regioncoverer.h"
#include "s2loop.h"

#include <omp.h>

#define KXVER 3
#include "k.h"

#ifndef NDEBUG
  #define DEBUGF(fmt, ...)      fprintf(stderr, fmt, ##__VA_ARGS__)
#else
  #define DEBUGF                /* nothing */
#endif

//
// Validation
//

bool is_valid_latlon(K lat, K lon)
{
    if (lat->t != KF || lon->t != KF) return false;
    if (lat->n != lon->n) return false;

    return true;
}

bool is_valid_latlon_rect(K lat, K lon)
{
    return is_valid_latlon(lat, lon) && lat->n == 2;
}

bool is_valid_latlon_loop(K lat, K lon)
{
    return is_valid_latlon(lat, lon) && lat->n >= 3;
}

//
// Convenience
//

unique_ptr<S2LatLngRect> rect_from_points(K pt_lat, K pt_lon)
{
    DEBUGF("rect_from_points\n");
    assert(is_valid_latlon_rect(pt_lat, pt_lon));

    return unique_ptr<S2LatLngRect>(S2LatLngRect::FromPointPair(S2LatLng::FromDegrees(kF(pt_lat)[0], kF(pt_lon)[0]),
                                                                S2LatLng::FromDegrees(kF(pt_lat)[1], kF(pt_lon)[1])).Clone());
}

unique_ptr<S2Loop> loop_from_points(K pt_lat, K pt_lon)
{
    DEBUGF("loop_from_points\n");
    assert(is_valid_latlon_loop(pt_lat, pt_lon));

    const int pt_n = pt_lat->n;
    std::vector<S2Point> points;
    points.reserve(pt_n);

    for (int i = 0; i < pt_n; i++)
    {
        const double lat = kF(pt_lat)[i];
        const double lon = kF(pt_lon)[i];
        DEBUGF("poly point: %f, %f\n", lat, lon);
        points.push_back(S2LatLng::FromDegrees(lat, lon).ToPoint());
    }

    return unique_ptr<S2Loop>(new S2Loop(points));
}

//
// Functions for kdb
//

// Generate cell ids for lat / long vectors (`x` and `y`)
extern "C" K cellids(K x, K y)
{
    if (! is_valid_latlon(x, y)) return krr("type");

    const int len = x->n;
    K ret = ktn(KJ, len);

    for (int i = 0; i < len; i++)
    {
        double lat = kF(x)[i];
        double lon = kF(y)[i];

        auto c = S2CellId::FromLatLng(S2LatLng::FromDegrees(lat, lon));
        kJ(ret)[i] = c.id();
    }

    return ret;
}


extern "C" K covering(K pt_lat, K pt_lon, K maxcells, K maxlevel)
{
    if (! (is_valid_latlon_rect(pt_lat, pt_lon) || is_valid_latlon_loop(pt_lat, pt_lon))) return krr("type");
    if (! (maxcells->t == (-KI) && maxlevel->t == (-KI))) return krr("type");

    const int c_max_cells = maxcells->i == ni ? 8 : maxcells->i;
    const int c_max_level = maxlevel->i == ni ? 30 : maxlevel->i;

    S2RegionCoverer c;
    c.set_max_cells(c_max_cells);
    c.set_max_level(c_max_level);
    std::vector<S2CellId> cids;

    const int pt_n = pt_lat->n;
    if (pt_n == 2)
    {
        auto rect = rect_from_points(pt_lat, pt_lon);
        c.GetCovering(*rect, &cids);
    }
    else
    {
        auto poly = loop_from_points(pt_lat, pt_lon);
        if (! poly->IsValid())
        {
            return krr("poly invalid");
        }
        c.GetCovering(*poly, &cids);
    }

    DEBUGF("cids size: %d\n", cids.size());

    K ret = ktn(KJ, cids.size());

    for (int i = 0; i < ret->n; i++)
    {
        kJ(ret)[i] = cids[i].id();
        DEBUGF("cid: %llu\n", cids[i].id());
    }

    return ret;
}


// Get cell id range for list of cell ids (`x`)
// Returns a pair of (`begin`, `end`) lists
extern "C" K cellidrange(K x)
{
    if (x->t != KJ)
    {
        return krr("type");
    }

    const int len = x->n;
    K a = ktn(KJ, len);
    K b = ktn(KJ, len);

    for (int i = 0; i < len; i++)
    {
        S2CellId id(kJ(x)[i]);
        kJ(a)[i] = id.child_begin().id();
        kJ(b)[i] = id.child_end().id();
    }

    return knk(2, a, b);
}


// Returns true if the loop of `lats`/`lons` is in clockwise order
extern "C" K clockwise(K lats, K lons)
{
    if (! is_valid_latlon_loop(lats, lons)) return krr("type");

    const int pt_n = lats->n;
    double sum = 0.0;
    for (int i = 0; i < pt_n - 1; i++)
    {
        const double x0 = kF(lons)[i];
        const double y0 = kF(lats)[i];
        const double x1 = kF(lons)[i+1];
        const double y1 = kF(lats)[i+1];
        sum += (x0 * y1) - (x1 * y0);
    }
    bool cw = sum >= 0.0;

    return kb(cw);
}
                            

extern "C" K contains(K pt_lat, K pt_lon, K lats, K lons)
{
    if (! (is_valid_latlon_rect(pt_lat, pt_lon) || is_valid_latlon_loop(pt_lat, pt_lon))) return krr("type");
    if (! is_valid_latlon(lats, lons)) return krr("type");

    const int pt_n = pt_lat->n;

    const int len = lats->n;
    K ret = ktn(KB, len);

    if (pt_n == 2) // Rectangle
    {
        auto llrect = rect_from_points(pt_lat, pt_lon);
        
        #pragma omp parallel for schedule(static) if(len >= 500000) 
        for (int i = 0; i < len; i++)
        {
            const double lat = kF(lats)[i];
            const double lon = kF(lons)[i];
            bool within = llrect->Contains(S2LatLng::FromDegrees(lat, lon).ToPoint());
            kG(ret)[i] = (unsigned char) within ? 1 : 0;
        }
    }
    else // Loop
    {
        auto poly = loop_from_points(pt_lat, pt_lon);

        if (! poly->IsValid())
        {
            r0(ret);
            return krr("poly invalid");
        }

        #pragma omp parallel for schedule(static) if(len >= 500000)
        for (int i = 0; i < len; i++)
        {
            const double lat = kF(lats)[i];
            const double lon = kF(lons)[i];
            bool within = poly->Contains(S2LatLng::FromDegrees(lat, lon).ToPoint());
            kG(ret)[i] = (unsigned char) within ? 1 : 0;
        }
    }

    return ret;
}
