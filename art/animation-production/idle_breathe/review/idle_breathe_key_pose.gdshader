shader_type canvas_item;

uniform float pose_amount : hint_range(0.0, 1.0) = 0.0;
uniform float foot_anchor_y : hint_range(0.0, 1.0) = 0.96;

void fragment() {
	vec2 source_uv = UV;
	float amount = clamp(pose_amount, 0.0, 1.0);

	// A tiny inhale stretch around the foot pivot keeps both soles visually planted.
	float vertical_scale = 1.0 + 0.010 * amount;
	source_uv.y = foot_anchor_y + (source_uv.y - foot_anchor_y) / vertical_scale;

	// Shift the upper body toward viewer-left while leaving the feet effectively fixed.
	float upper_influence = clamp((foot_anchor_y - UV.y) / foot_anchor_y, 0.0, 1.0);
	source_uv.x += 0.004 * amount * upper_influence;

	// Let the chest open by less than a pixel at final 512 px resolution.
	float torso_mask = smoothstep(0.18, 0.30, UV.y) * (1.0 - smoothstep(0.58, 0.72, UV.y));
	float chest_scale = 1.0 + 0.010 * amount * torso_mask;
	source_uv.x = 0.5 + (source_uv.x - 0.5) / chest_scale;

	if (source_uv.x < 0.0 || source_uv.x > 1.0 || source_uv.y < 0.0 || source_uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, source_uv);
	}
}
