#include "renderDelegate.hpp"
#include "mesh.hpp"

#include <iostream>

const PXR_NS::TfTokenVector HdMoonshineRenderDelegate::SUPPORTED_RPRIM_TYPES = {
    PXR_NS::HdPrimTypeTokens->mesh,
};

const PXR_NS::TfTokenVector HdMoonshineRenderDelegate::SUPPORTED_SPRIM_TYPES = {
};

const PXR_NS::TfTokenVector HdMoonshineRenderDelegate::SUPPORTED_BPRIM_TYPES = {
};

HdMoonshineRenderDelegate::HdMoonshineRenderDelegate() : PXR_NS::HdRenderDelegate() {
    _Initialize();
}

HdMoonshineRenderDelegate::HdMoonshineRenderDelegate(PXR_NS::HdRenderSettingsMap const& settingsMap) : PXR_NS::HdRenderDelegate(settingsMap) {
    _Initialize();
}

void HdMoonshineRenderDelegate::_Initialize() {
    _moonshine = HdMoonshineCreate();
    std::cout << "Initializing Moonshine RenderDelegate " << _moonshine << std::endl;
    _resourceRegistry = std::make_shared<PXR_NS::HdResourceRegistry>();
}

HdMoonshineRenderDelegate::~HdMoonshineRenderDelegate() {
    std::cout << "Destroying Moonshine RenderDelegate" << std::endl;
    _resourceRegistry.reset();
    HdMoonshineDestroy(_moonshine);
}

PXR_NS::TfTokenVector const& HdMoonshineRenderDelegate::GetSupportedRprimTypes() const {
    std::cout << "Queried rprim types" << std::endl;
    return SUPPORTED_RPRIM_TYPES;
}

PXR_NS::TfTokenVector const& HdMoonshineRenderDelegate::GetSupportedSprimTypes() const {
    std::cout << "Queried sprim types" << std::endl;
    return SUPPORTED_SPRIM_TYPES;
}

PXR_NS::TfTokenVector const& HdMoonshineRenderDelegate::GetSupportedBprimTypes() const {
    std::cout << "Queried bprim types" << std::endl;
    return SUPPORTED_BPRIM_TYPES;
}

PXR_NS::HdResourceRegistrySharedPtr HdMoonshineRenderDelegate::GetResourceRegistry() const {
    std::cout << "Got resource registry" << std::endl;
    return _resourceRegistry;
}

void HdMoonshineRenderDelegate::CommitResources(PXR_NS::HdChangeTracker *tracker) {
    std::cout << "=> CommitResources RenderDelegate" << std::endl;
}

PXR_NS::HdRenderPassSharedPtr HdMoonshineRenderDelegate::CreateRenderPass(PXR_NS::HdRenderIndex *index, PXR_NS::HdRprimCollection const& collection) {
    std::cout << "Create RenderPass with Collection=" << collection.GetName() << std::endl; 

    return PXR_NS::HdRenderPassSharedPtr(nullptr);
}

PXR_NS::HdRprim* HdMoonshineRenderDelegate::CreateRprim(PXR_NS::TfToken const& typeId, PXR_NS::SdfPath const& rprimId) {
    std::cout << "Create Moonshine Rprim type=" << typeId.GetText() << " id=" << rprimId << std::endl;

    if (typeId == PXR_NS::HdPrimTypeTokens->mesh) {
        return new HdMoonshineMesh(rprimId);
    } else {
        std::cerr << "Unknown Rprim type=" << typeId.GetText() << " id=" << rprimId.GetText() << std::endl;
        return nullptr;
    }
}

void HdMoonshineRenderDelegate::DestroyRprim(PXR_NS::HdRprim *rPrim) {
    std::cout << "Destroy Moonshine Rprim id=" << rPrim->GetId() << std::endl;
}

PXR_NS::HdSprim* HdMoonshineRenderDelegate::CreateSprim(PXR_NS::TfToken const& typeId, PXR_NS::SdfPath const& sprimId) {
    std::cout << "Create Moonshine Sprim" << std::endl;
    return nullptr;
}

PXR_NS::HdSprim* HdMoonshineRenderDelegate::CreateFallbackSprim(PXR_NS::TfToken const& typeId) {
    std::cout << "Create Moonshine Fallback Sprim" << std::endl;
    return nullptr;
}

void HdMoonshineRenderDelegate::DestroySprim(PXR_NS::HdSprim *sPrim) {
    std::cout << "Destroy Moonshine Sprim" << std::endl;
}

PXR_NS::HdBprim* HdMoonshineRenderDelegate::CreateBprim(PXR_NS::TfToken const& typeId, PXR_NS::SdfPath const& bprimId) {
    std::cout << "Create Moonshine Bprim" << std::endl;
    return nullptr;
}

PXR_NS::HdBprim* HdMoonshineRenderDelegate::CreateFallbackBprim(PXR_NS::TfToken const& typeId) {
    std::cout << "Create Moonshine Fallback Bprim" << std::endl;
    return nullptr;
}

void HdMoonshineRenderDelegate::DestroyBprim(PXR_NS::HdBprim *bPrim) {
    std::cout << "Destroy Moonshine Bprim" << std::endl;
}

PXR_NS::HdInstancer* HdMoonshineRenderDelegate::CreateInstancer(PXR_NS::HdSceneDelegate *delegate, PXR_NS::SdfPath const& id) {
    std::cout << "Create render instancer" << std::endl;
    return nullptr;
}

void HdMoonshineRenderDelegate::DestroyInstancer(PXR_NS::HdInstancer *instancer) {
    std::cout << "Destroy render instancer" << std::endl;
}

PXR_NS::HdRenderParam* HdMoonshineRenderDelegate::GetRenderParam() const {
    std::cout << "Get render param" << std::endl;
    return nullptr;
}
