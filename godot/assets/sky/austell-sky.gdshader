shader_type sky;
uniform sampler2D panorama : source_color, repeat_enable, filter_linear_mipmap;
// The generated photograph's horizon is below centre. Map it to the skydome horizon.
uniform float horizon_scale = 1.32;
uniform float heading_offset = -0.20;
void sky() {
 vec2 uv=vec2(fract(SKY_COORDS.x+heading_offset),clamp(SKY_COORDS.y*horizon_scale,0.0,1.0));
 COLOR=texture(panorama,uv).rgb;
}
