#version 460
#extension GL_EXT_ray_tracing : require
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_buffer_reference2 : require
#extension GL_EXT_nonuniform_qualifier : require

#include "common.glsl"

struct Mesh {
    uint64_t vertexAddress;
    uint64_t indexAddress;
};

struct Instance {
    uint materialIndex;
};

struct Vertex {
    vec3 position;
    vec2 texcoord;
};

layout(buffer_reference, scalar) readonly buffer Indices { ivec3 i[]; };
layout(buffer_reference, scalar) readonly buffer Vertices { Vertex v[]; };
layout(binding = 1, set = 0) uniform sampler textureSampler;
layout(binding = 5, set = 0) uniform texture2D normalTextures[];
layout(binding = 6, set = 0, scalar) readonly buffer Meshes { Mesh meshes[]; };
layout(binding = 7, set = 0, scalar) readonly buffer Instances { Instance instances[]; };

layout(location = 0) rayPayloadInEXT Payload payload;

hitAttributeEXT vec2 attribs;

mat3 createTBNMatrix(vec3 normal, vec3 edge0, vec3 edge1, vec2 t0, vec2 t1, vec2 t2) {
    vec2 deltaUV1 = t1 - t0;
    vec2 deltaUV2 = t2 - t0;

    float f = deltaUV1.x * deltaUV2.y - deltaUV2.x * deltaUV1.y;

    vec3 tangent = vec3(
        (deltaUV2.y * edge0.x - deltaUV1.y * edge1.x) / f,
        (deltaUV2.y * edge0.y - deltaUV1.y * edge1.y) / f,
        (deltaUV2.y * edge0.z - deltaUV1.y * edge1.z) / f
    );
    
    vec3 bitangent = vec3(
        (-deltaUV2.x * edge0.x + deltaUV1.x * edge1.x) / f,
        (-deltaUV2.x * edge0.y + deltaUV1.x * edge1.y) / f,
        (-deltaUV2.x * edge0.z + deltaUV1.x * edge1.z) / f
    );

    return mat3(normalize(tangent), normalize(bitangent), normal);
}

vec3 calculateNormal(Vertex v0, Vertex v1, Vertex v2, vec2 texcoords, uint textureIndex) {
    vec3 edge0 = v1.position - v0.position;
    vec3 edge1 = v2.position - v0.position;
    vec3 vertexNormalObjectSpace = normalize(cross(edge0, edge1));

    mat3 tangentToObjectMat = createTBNMatrix(vertexNormalObjectSpace, edge0, edge1, v0.texcoord, v1.texcoord, v2.texcoord);
    vec2 textureNormal = (texture(sampler2D(normalTextures[nonuniformEXT(textureIndex)], textureSampler), texcoords).rg * 2.0) - 1.0;
    vec3 normalTangentSpace = vec3(textureNormal, sqrt(1.0 - pow(textureNormal.r, 2) - pow(textureNormal.g, 2)));
    return normalize((gl_WorldToObject3x4EXT * tangentToObjectMat * normalTangentSpace).xyz);
}

vec3 calculateHitPoint(vec3 barycentrics, vec3 v0, vec3 v1, vec3 v2) {
    vec3 hitObjectSpace = barycentrics.x * v0 + barycentrics.y * v1 + barycentrics.z * v2;
    return gl_ObjectToWorldEXT * vec4(hitObjectSpace, 1.0);
}

vec2 calculateTexcoord(vec3 barycentrics, vec2 t0, vec2 t1, vec2 t2) {
    return barycentrics.x * t0 + barycentrics.y * t1 + barycentrics.z * t2;
}

void main() {
    Mesh mesh = meshes[gl_InstanceCustomIndexEXT];
    uint materialIndex = instances[gl_InstanceID].materialIndex;
    
    Indices indices = Indices(mesh.indexAddress);
    ivec3 ind = indices.i[gl_PrimitiveID];
    
    Vertices vertices = Vertices(mesh.vertexAddress);
    Vertex v0 = vertices.v[ind.x];
    Vertex v1 = vertices.v[ind.y];
    Vertex v2 = vertices.v[ind.z];

    vec3 p0 = v0.position;
    vec3 p1 = v1.position;
    vec3 p2 = v2.position;

    vec2 t0 = v0.texcoord;
    vec2 t1 = v1.texcoord;
    vec2 t2 = v2.texcoord;

    vec3 barycentrics = vec3(1.0 - attribs.x - attribs.y, attribs.x, attribs.y);

    payload.texcoord = calculateTexcoord(barycentrics, t0, t1, t2);
    payload.normal = calculateNormal(v0, v1, v2, payload.texcoord, materialIndex);
    payload.point = calculateHitPoint(barycentrics, p0, p1, p2);

    payload.done = false;
    payload.materialIndex = materialIndex;
    payload.index = gl_InstanceID;
}
