struct Filter {
    color: vec4<f32>,
    strength: f32,
    inner: u32,
    knockout: u32,
    _pad: f32,
}

@group(0) @binding(0) var texture: texture_2d<f32>;
@group(0) @binding(1) var texture_sampler: sampler;
@group(0) @binding(2) var<uniform> filter_args: Filter;
@group(0) @binding(3) var blurred: texture_2d<f32>;

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) source_uv: vec2<f32>,
    @location(1) blur_uv: vec2<f32>,
};

struct VertexInput {
    /// The position of the vertex in texture space (topleft 0,0, bottomright 1,1)
    @location(0) position: vec2<f32>,

    /// The coordinate of the source texture to sample in texture space (topleft 0,0, bottomright 1,1)
    @location(1) source_uv: vec2<f32>,

    /// The coordinate of the blur texture to sample in texture space (topleft 0,0, bottomright 1,1)
    @location(2) blur_uv: vec2<f32>,
};

@vertex
fn main_vertex(in: VertexInput) -> VertexOutput {
    // Convert texture space (topleft 0,0 to bottomright 1,1) to render space (topleft -1,1 to bottomright 1,-1)
    let pos = vec4<f32>((in.position.x * 2.0 - 1.0), (1.0 - in.position.y * 2.0), 0.0, 1.0);
    return VertexOutput(pos, in.source_uv, in.blur_uv);
}

@fragment
fn main_fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    let inner = filter_args.inner > 0u;
    let knockout = filter_args.knockout > 0u;
    let blur = textureSample(blurred, texture_sampler, in.blur_uv).a;
    let dest = textureSample(texture, texture_sampler, in.source_uv);

    // [NA] It'd be nice to use hardware blending but the operation is too complex :( Only knockouts would work.

    // Start with 1 alpha because we'll be multiplying the whole thing
    var color = vec4<f32>(filter_args.color.r, filter_args.color.g, filter_args.color.b, 1.0);
    if (inner) {
        let alpha = filter_args.color.a * saturate((1.0 - blur) * filter_args.strength);
        if (knockout) {
            color = color * alpha * dest.a;
        } else {
            color = color * alpha * dest.a + dest * (1.0 - alpha);
        }
    } else {
        let alpha = filter_args.color.a * saturate(blur * filter_args.strength);
        if (knockout) {
            color = color * alpha * (1.0 - dest.a);
        } else {
            color = color * alpha * (1.0 - dest.a) + dest;
        }
    }

    return color;
}