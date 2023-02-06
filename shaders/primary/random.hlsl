#pragma once

#include "math.hlsl"

struct Rng {
    uint state;

    static Rng fromSeed(uint seed) {
        Rng rng;
        rng.state = seed;
        return rng;
    }

    void stepState() {
        this.state = this.state * 747796405 + 1;
    }

    float getFloat() {
        this.stepState();

        uint word = ((this.state >> ((this.state >> 28) + 4)) ^ this.state) * 277803737;
        word = (word >> 22) ^ word;
        return float(word) / 4294967295.0;
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
// returns total weight in alias table, zero if no entries and then e is invalid
template <class Data, class Entry>
void sampleAlias(StructuredBuffer<Entry> entries, uint entryCount, uint offset, inout float rand, out uint idx, out Data d) {
    float scaled = rand * entryCount;
    idx = uint(scaled);
    rand = scaled - idx;
    Entry e = entries[offset + idx];
    if (!coinFlipRemap(e.select, rand)) {
        idx = e.alias;
        e = entries[offset + e.alias];
    }
    d = e.data;
}

float2 squareToTriangle(float2 square) {
    float a = 1 - sqrt(1 - square.x);
    float b = square.y * sqrt(1 - square.x);
    return float2(a, b);
}

float2 squareToGaussian(float2 square) {
    const float u1 = max(1e-38, square.x);
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

    return float3(d.x, z, d.y);
}

float3 squareToUniformHemisphere(float2 square) {
    float z = square.x;
    float r = sqrt(max(0.0, 1.0 - z * z));
    float phi = 2 * PI * square.y;
    return float3(r * cos(phi), z, r * sin(phi));
}
