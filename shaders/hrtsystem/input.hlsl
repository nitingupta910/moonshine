struct ClickData {
    int instance_index; // -1 if invalid
    uint geometry_index;
    uint primitive_index;
    float2 barycentrics;
};

[[vk::binding(0, 0)]] RWStructuredBuffer<ClickData> click_data;
[[vk::binding(0, 1)]] RaytracingAccelerationStructure TLAS;

struct [raypayload] Payload {
    ClickData click_data : read(caller) : write(closesthit, miss);
};

struct Camera {
    float3 origin;
    float3 lower_left_corner;
    float3 horizontal;
    float3 vertical;
};

struct PushConsts {
	Camera camera;
	float2 coords;
};
[[vk::push_constant]] PushConsts pushConsts;

RayDesc generateDir(Camera camera) {
    float2 uv = pushConsts.coords;
    uv.y -= 1;
    uv.y *= -1;

    RayDesc rayDesc;
	rayDesc.Origin = camera.origin;
	rayDesc.Direction = normalize(camera.lower_left_corner + uv.x * camera.horizontal + uv.y * camera.vertical - camera.origin);
	rayDesc.TMin = 0.0001;
	rayDesc.TMax = 10000.0;

    return rayDesc;
}

[shader("raygeneration")]
void raygen() {
    RayDesc ray = generateDir(pushConsts.camera);

    Payload payload;
    TraceRay(TLAS, RAY_FLAG_FORCE_OPAQUE, 0xFF, 0, 0, 0, ray, payload);

    click_data[0] = payload.click_data;
}

[shader("miss")]
void miss(inout Payload payload) {
    payload.click_data.instance_index = -1;
}

struct Attributes
{
    float2 barycentrics;
};

[shader("closesthit")]
void closesthit(inout Payload payload, in Attributes attribs) {
    payload.click_data.instance_index = InstanceIndex();
    payload.click_data.primitive_index = PrimitiveIndex();
    payload.click_data.geometry_index = GeometryIndex();
    payload.click_data.barycentrics = attribs.barycentrics;
}
