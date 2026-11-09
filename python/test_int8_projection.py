from software_accelerator import export_int8_matrix, quantized_projection


def test_quantized_projection_matches_expected():
    activation = [[1, -2, 3], [4, 5, -6]]
    weight = [[2, 1], [0, -3], [4, 2]]
    assert quantized_projection(
        activation, weight, [8, -8], 1, relu=True
    ) == [[11, 2], [0, 0]]


def test_int8_export_uses_twos_complement():
    assert export_int8_matrix([[-1, 0, 127, -128]]) == bytes(
        [255, 0, 127, 128]
    )
