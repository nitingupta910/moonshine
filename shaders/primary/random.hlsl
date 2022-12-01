#include "math.hlsl"

struct Rng {
    uint state;

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

Rng InitRng(uint initialState) {
    Rng rng;
    rng.state = initialState;
    return rng;
}

float2 squareToGaussian(float2 square) {
    const float u1 = max(1e-38, square.x);
    const float u2 = square.y;
    const float r = sqrt(-2.0 * log(u1));
    const float theta = 2 * PI * u2;
    return r * float2(cos(theta), sin(theta));
}

float2 squareToUniformDiskConcentric(float2 square) {
    float r1 = 2.0 * square.x - 1.0;
    float r2 = 2.0 * square.y - 1.0;
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
