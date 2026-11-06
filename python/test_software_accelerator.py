from software_accelerator import (
    SoftwareAcceleratorDriver,
    matmul_reference,
    verify_against_reference,
)


def test_reference_model():
    assert matmul_reference([[1, 2], [3, 4]], [[1, 2], [3, 4]]) == [
        [7, 10], [15, 22]
    ]


def test_driver_against_python_backend():
    registers = {}
    input_mode = 0
    input_values = []
    output_values = []

    def read(address):
        return registers.get(address, 0)

    def write(address, value):
        nonlocal input_mode, output_values
        registers[address] = value
        if address == 0x5:
            input_mode = value
        if address == 0x0 and value & 1:
            a = input_values[:6]
            b = input_values[6:]
            result = matmul_reference(
                [a[0:3], a[3:6]], [b[0:2], b[2:4], b[4:6]]
            )
            output_values = [value for row in result for value in row]

    def send(values):
        input_values.extend(values)

    def receive(count):
        return output_values[:count]

    driver = SoftwareAcceleratorDriver(read, write, send, receive)
    a = [[1, -2, 3], [4, 5, -6]]
    b = [[2, 1], [0, -3], [4, 2]]
    verify_against_reference(driver, a, b)
