#include "ops/linear/nvfp4/nvfp4_w4a4_tma_launch.h"
#include "ops/linear_swiglu/nvfp4/nvfp4_linear_swiglu_w4a4_tma_launch.h"

#include <stdexcept>

namespace ninfer::ops::detail {
namespace {
[[noreturn]] void unavailable() {
    throw std::logic_error("NVFP4 TMA/W4A4 non-RDC kernels are unavailable on Volta sm_70");
}
} // namespace

void launch_nvfp4_w4a4_tma_linear(Nvfp4GeometryId,
                                  const std::uint8_t*, const std::uint8_t*,
                                  const std::uint8_t*, const std::uint8_t*,
                                  __nv_bfloat16*, std::int32_t, float, cudaStream_t) {
    unavailable();
}

void launch_nvfp4_w4a4_tma_attention(const std::uint8_t*, const std::uint8_t*,
                                     const std::uint8_t*, const std::uint8_t*,
                                     __nv_bfloat16*, __nv_bfloat16*, __nv_bfloat16*,
                                     __nv_bfloat16*, std::int32_t, float, cudaStream_t) {
    unavailable();
}

void launch_nvfp4_w4a4_tma_gdn(const std::uint8_t*, const std::uint8_t*,
                               const std::uint8_t*, const std::uint8_t*,
                               __nv_bfloat16*, __nv_bfloat16*,
                               std::int32_t, float, cudaStream_t) {
    unavailable();
}

void launch_nvfp4_w4a4_tma_linear_add(Nvfp4GeometryId,
                                      const std::uint8_t*, const std::uint8_t*,
                                      const std::uint8_t*, const std::uint8_t*,
                                      __nv_bfloat16*, std::int32_t, float, cudaStream_t) {
    unavailable();
}

void launch_nvfp4_linear_swiglu_w4a4_tma(const std::uint8_t*, const std::uint8_t*,
                                         const std::uint8_t*, const std::uint8_t*,
                                         __nv_bfloat16*, std::int32_t, float, cudaStream_t) {
    unavailable();
}

} // namespace ninfer::ops::detail
