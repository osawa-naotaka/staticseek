@group(0) @binding(0) var<storage, read> data: array<u32>;
@group(0) @binding(2) var<storage, read_write> result: array<u32>;
@group(0) @binding(3) var<storage, read_write> pointer: atomic<u32>;
@group(0) @binding(8) var<uniform> end_mask: vec4u;
@group(0) @binding(9) var<uniform> bitap_dict: array<vec4u, 16>;
@group(0) @binding(10) var<uniform> keyword_len: u32;
@group(0) @binding(11) var<uniform> bitap_dict_len: u32;


@compute @workgroup_size(256) fn cs(
    @builtin(global_invocation_id) id: vec3u
) {
    const vec_zero = vec4u(0u, 0u, 0u, 0u);
    const vec_one  = vec4u(1u, 1u, 1u, 1u);
    var state = vec_zero;

    let end_pos = id.x + keyword_len + 3; // 3 means distance 3
    var dist = 4u;
    var tail_pos = 0u;
    for(var pos = id.x; pos < end_pos; pos++) {
        var mask = 0u;
        for(var i = 0u; i < bitap_dict_len; i++) {
            mask = select(mask, bitap_dict[i][1], bitap_dict[i][0] == data[pos]);
            mask = select(mask, bitap_dict[i][3], bitap_dict[i][2] == data[pos]);
        }

        // calc all next state candidates
        let next_state_candidate = (state << vec_one) | vec_one;
        let next_state_candidate_mask = next_state_candidate & vec4u(mask, mask, mask, mask);

        let deletion = (next_state_candidate_mask << vec_one) | vec_one;
        let insertion = state;

        let replace_1 = next_state_candidate[0];
        let replace_2 = next_state_candidate[1];
        let replace_3 = next_state_candidate[2];

        // state update
        state[0] = next_state_candidate_mask[0];
        state[1] = next_state_candidate_mask[1] | replace_1 | insertion[0] | deletion[0];
        state[2] = next_state_candidate_mask[2] | replace_2 | insertion[1] | deletion[1];
        state[3] = next_state_candidate_mask[3] | replace_3 | insertion[2] | deletion[2];

        // mach check
        let matches = (state & end_mask) != vec_zero;
        if(any(matches)) {
            let d = select(select(select(3u, 2u, matches[2]), 1u, matches[1]), 0u, matches[0]);
            if(d < dist) {
                tail_pos = pos;
                dist = d;
            }
        }
    }

    if(dist < 4u) {
        let ptr_pos = atomicAdd(&pointer, 1u);
        result[ptr_pos * 2] = tail_pos;
        result[ptr_pos * 2 + 1] = dist;
    }
}
