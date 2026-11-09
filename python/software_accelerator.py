"""Host-side model and register-level driver for the software accelerator."""

from __future__ import annotations

from dataclasses import dataclass
import mmap
import os
import struct
import time
from typing import Callable, Iterable, Sequence


Matrix = list[list[int]]


def clamp_int8(value: int, relu: bool = False) -> int:
    """Apply optional ReLU and signed INT8 saturation."""
    if relu and value < 0:
        return 0
    return max(-128, min(127, value))


def quantized_projection(
    activation: Sequence[Sequence[int]],
    weight: Sequence[Sequence[int]],
    bias: Sequence[int],
    requant_shift: int,
    relu: bool = False,
) -> Matrix:
    """Reference X*W+bias with arithmetic requantization to signed INT8."""
    accum = matmul_reference(activation, weight)
    if len(bias) != len(weight[0]):
        raise ValueError("bias width does not match projection output width")
    return [
        [
            clamp_int8((accum[row][col] + bias[col]) >> requant_shift, relu)
            for col in range(len(weight[0]))
        ]
        for row in range(len(activation))
    ]


def export_int8_matrix(matrix: Sequence[Sequence[int]]) -> bytes:
    """Serialize a signed INT8 matrix in row-major two's-complement form."""
    if any(value < -128 or value > 127 for row in matrix for value in row):
        raise ValueError("matrix contains a value outside signed INT8 range")
    return bytes(value & 0xFF for row in matrix for value in row)


def matmul_reference(a: Sequence[Sequence[int]],
                     b: Sequence[Sequence[int]]) -> Matrix:
    """Compute signed integer GEMM with explicit dimension validation."""
    if not a or not b or not a[0] or not b[0]:
        raise ValueError("matrices must be non-empty")
    k = len(a[0])
    if any(len(row) != k for row in a):
        raise ValueError("A is not rectangular")
    if any(len(row) != len(b[0]) for row in b):
        raise ValueError("B is not rectangular")
    if len(b) != k:
        raise ValueError("inner dimensions do not match")
    return [
        [sum(a[row][inner] * b[inner][col] for inner in range(k))
         for col in range(len(b[0]))]
        for row in range(len(a))
    ]


@dataclass(frozen=True)
class RegisterMap:
    control: int = 0x0
    status: int = 0x1
    dimensions: int = 0x2
    cycles: int = 0x3
    macs: int = 0x4
    dma_mode: int = 0x5
    dma_data_in: int = 0x6
    dma_data_out: int = 0x7
    dma_data_out_hi: int = 0x8


class DevMemTransport:
    """Linux /dev/mem transport for a bus-mapped accelerator peripheral.

    ``base_address`` is the physical byte address assigned by the FPGA
    system's Avalon-MM interconnect. Register offsets are word offsets.
    """

    def __init__(
        self,
        base_address: int,
        span: int = 0x1000,
        device: str = "/dev/mem",
    ) -> None:
        if base_address < 0 or span <= 0:
            raise ValueError("base_address must be non-negative and span positive")
        page_size = mmap.PAGESIZE
        self._page_base = base_address - (base_address % page_size)
        self._page_offset = base_address - self._page_base
        self._span = self._page_offset + span
        self._fd = os.open(device, os.O_RDWR | os.O_SYNC)
        try:
            self._mapping = mmap.mmap(
                self._fd, self._span, mmap.MAP_SHARED,
                mmap.PROT_READ | mmap.PROT_WRITE, offset=self._page_base
            )
        except Exception:
            os.close(self._fd)
            raise

    def close(self) -> None:
        self._mapping.close()
        os.close(self._fd)

    def __enter__(self) -> "DevMemTransport":
        return self

    def __exit__(self, _type, _value, _traceback) -> None:
        self.close()

    def _offset(self, word_address: int) -> int:
        if word_address < 0:
            raise ValueError("register address must be non-negative")
        offset = self._page_offset + word_address * 4
        if offset + 4 > self._span:
            raise ValueError("register address is outside mapped span")
        return offset

    def read(self, word_address: int) -> int:
        self._mapping.seek(self._offset(word_address))
        return struct.unpack("<I", self._mapping.read(4))[0]

    def write(self, word_address: int, value: int) -> None:
        if not 0 <= value <= 0xFFFFFFFF:
            raise ValueError("register value must fit in 32 bits")
        self._mapping.seek(self._offset(word_address))
        self._mapping.write(struct.pack("<I", value))

    def send(self, values: Iterable[int]) -> None:
        for value in values:
            self.write(RegisterMap.dma_data_in, value & 0xFFFF)

    def receive(self, count: int, timeout: float = 1.0) -> list[int]:
        if count < 0:
            raise ValueError("receive count must be non-negative")
        result = []
        deadline = time.monotonic() + timeout
        while len(result) < count:
            if self.read(RegisterMap.status) & (1 << 4):
                low = self.read(RegisterMap.dma_data_out)
                high = self.read(RegisterMap.dma_data_out_hi) & 0x7
                raw = low | (high << 32)
                if raw & (1 << 34):
                    raw -= 1 << 35
                result.append(raw)
            elif time.monotonic() >= deadline:
                raise TimeoutError("timed out waiting for accelerator output")
            else:
                time.sleep(0.000001)
        return result


class SoftwareAcceleratorDriver:
    """Transport-independent register and DMA driver.

    ``read`` and ``write`` accept register offsets. ``send`` and ``receive``
    represent a DMA transport and are intentionally injectable for FPGA or
    simulation backends.
    """

    def __init__(
        self,
        read: Callable[[int], int],
        write: Callable[[int, int], None],
        send: Callable[[Iterable[int]], None],
        receive: Callable[[int], list[int]],
    ) -> None:
        self.read = read
        self.write = write
        self.send = send
        self.receive = receive
        self.regs = RegisterMap()

    @classmethod
    def from_devmem(cls, base_address: int, span: int = 0x1000) -> "SoftwareAcceleratorDriver":
        """Create a driver backed by a Linux physical memory mapping."""
        transport = DevMemTransport(base_address, span)
        driver = cls(
            transport.read, transport.write, transport.send, transport.receive
        )
        driver._transport = transport
        return driver

    def close(self) -> None:
        """Close an owned hardware transport, if one exists."""
        transport = getattr(self, "_transport", None)
        if transport is not None:
            transport.close()

    def load_matrices(self, a: Sequence[Sequence[int]],
                      b: Sequence[Sequence[int]]) -> None:
        self.write(self.regs.dma_mode, 1)
        self.send(value for row in a for value in row)
        self.write(self.regs.dma_mode, 2)
        self.send(value for row in b for value in row)

    def start(self) -> None:
        self.write(self.regs.control, 0x1)

    def read_result(self, count: int) -> list[int]:
        self.write(self.regs.dma_mode, 3)
        return self.receive(count)

    def run(self, a: Sequence[Sequence[int]],
            b: Sequence[Sequence[int]]) -> Matrix:
        self.load_matrices(a, b)
        self.start()
        result = self.read_result(len(a) * len(b[0]))
        columns = len(b[0])
        return [result[row * columns:(row + 1) * columns]
                for row in range(len(a))]


def verify_against_reference(driver: SoftwareAcceleratorDriver,
                             a: Sequence[Sequence[int]],
                             b: Sequence[Sequence[int]]) -> None:
    """Run the device and raise AssertionError on any mismatched element."""
    expected = matmul_reference(a, b)
    actual = driver.run(a, b)
    if actual != expected:
        raise AssertionError(f"accelerator result {actual} != {expected}")
