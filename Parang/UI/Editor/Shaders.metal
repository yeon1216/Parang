// Metal 표준 라이브러리 포함
#include <metal_stdlib>
using namespace metal;

// 버텍스 셰이더의 입력 데이터 구조체
struct VertexIn {
    // 3D 공간의 정점 위치 (x, y, z, w)
    // attribute(0)은 버텍스 버퍼의 첫 번째 속성임을 나타냄
    float4 position [[attribute(0)]];
    
    // 텍스처 좌표 (u, v)
    // attribute(1)은 버텍스 버퍼의 두 번째 속성임을 나타냄
    float2 texCoord [[attribute(1)]];
};

// 버텍스 셰이더에서 프래그먼트 셰이더로 전달되는 데이터 구조체
struct VertexOut {
    // [[position]]은 이 값이 화면 공간의 정점 위치임을 나타냄
    float4 position [[position]];
    
    // 프래그먼트 셰이더에서 텍스처 샘플링에 사용될 텍스처 좌표
    float2 texCoord;
};

// 버텍스 셰이더: 각 정점의 위치와 텍스처 좌표를 처리
vertex VertexOut vertexShader(
    // 현재 처리 중인 정점의 인덱스
    uint vertexID [[vertex_id]],
    // 정점 데이터 배열, buffer(0)은 첫 번째 버퍼를 의미
    constant VertexIn* vertices [[buffer(0)]]
) {
    VertexOut out;
    // 현재 정점의 데이터를 가져옴
    VertexIn in = vertices[vertexID];
    // 위치와 텍스처 좌표를 출력 구조체로 복사
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

// 프래그먼트 셰이더: 각 픽셀의 최종 색상을 결정
fragment float4 fragmentShader(
    // 버텍스 셰이더에서 보간된 데이터
    VertexOut in [[stage_in]],
    // 비디오 프레임 텍스처, texture(0)은 첫 번째 텍스처를 의미
    texture2d<float> videoTexture [[texture(0)]]
) {
    // 텍스처 샘플링 방법 정의
    // linear: 선형 보간으로 부드러운 확대/축소
    // clamp_to_edge: 텍스처 경계를 벗어난 좌표 처리 방법
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    
    // 텍스처에서 현재 픽셀의 색상을 샘플링하여 반환
    return videoTexture.sample(textureSampler, in.texCoord);
}
