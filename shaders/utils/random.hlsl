#pragma once

#include "math.hlsl"

// https://www.reedbeta.com/blog/hash-functions-for-gpu-rendering/
// https://jcgt.org/published/0009/03/02/
namespace Hash {
    uint lcg(uint a) {
        const uint multiplier = 747796405u;
        const uint increment = 2891336453u;
        return a * multiplier + increment;
    }

    // RXS-M-XS PCG permutation function
    uint rxs_m_xs(uint a) {
        const uint b = ((a >> ((a >> 28u) + 4u)) ^ a) * 277803737u;
        return (b >> 22u) ^ b;
    }

    uint pcg(uint a) {
        return rxs_m_xs(lcg(a));
    }
}

struct Rng {
    uint state;

    static Rng fromSeed(uint3 seed) {
        Rng rng;
        rng.state = Hash::pcg(seed.x + Hash::pcg(seed.y + Hash::pcg(seed.z)));
        return rng;
    }

    void stepState() {
        state = Hash::lcg(state);
    }

    float getFloat() {
        stepState();

        uint hashed_uint = Hash::rxs_m_xs(state);

        // convert to float [0-1)
        // https://pharr.org/matt/blog/2022/03/05/sampling-fp-unit-interval
        return float(hashed_uint >> 8) * 0x1p-24f;
    }
};

// selects true with probability p (false otherwise),
// remapping rand back into (0..1)
bool coinFlipRemap(float p, inout float rand) {
    if (rand < p) {
        rand /= p;
        return true;
    } else {
        rand = (rand - p) / (1.0 - p);
        return false;
    }
}

// samples from an alias table, remaps rand
template <class Data, class Entry>
Data sampleAlias(StructuredBuffer<Entry> entries, uint entryCount, uint offset, inout float rand, inout uint idx) {
    float scaled = rand * entryCount;
    idx = uint(scaled);
    rand = frac(scaled);
    
    Entry e = entries[offset + idx];
    if (!coinFlipRemap(e.select, rand)) {
        idx = e.alias;
        e = entries[offset + idx];
    }
    return e.data;
}

float2 squareToTriangle(float2 square) {
    float a = 1 - sqrt(1 - square.x);
    float b = square.y * sqrt(1 - square.x);
    return float2(a, b);
}

float2 squareToGaussian(float2 square) {
    const float u1 = 1.0 - square.x;
    const float u2 = square.y;
    const float r = sqrt(-2.0 * log(u1));
    const float theta = 2 * PI * u2;
    return r * float2(cos(theta), sin(theta));
}

float2 squareToUniformDiskConcentric(float2 square) {
    float2 uOffset = 2.0 * square - float2(1.0, 1.0);

    if (all(uOffset == float2(0.0, 0.0))) {
        return float2(0.0, 0.0);
    }

    float theta, r;

    if (abs(uOffset.x) > abs(uOffset.y)) {
        r = uOffset.x;
        theta = (PI / 4) * (uOffset.y / uOffset.x);
    } else {
        r = uOffset.y;
        theta = (PI / 2) - (PI / 4) * (uOffset.x / uOffset.y);
    }

    return r * float2(cos(theta), sin(theta));
}

float3 squareToCosineHemisphere(float2 square) {
    float2 d = squareToUniformDiskConcentric(square);
    float z = sqrt(max(0.0, 1.0 - dot(d, d)));

    return float3(d.x, d.y, z);
}

float3 squareToUniformHemisphere(float2 square) {
    float z = square.x;
    float r = sqrt(max(0.0, 1.0 - z * z));
    float phi = 2 * PI * square.y;
    return float3(r * cos(phi), r * sin(phi), z);
}

float2 uniformIntervalToUniformDirection(float val) {
    return float2(cos(val * 2 * PI), sin(val * 2 * PI));
}

float2 uniformIntervalToUniformUpDirection(float val) {
    return float2(cos(val * PI), sin(val * PI));
}
