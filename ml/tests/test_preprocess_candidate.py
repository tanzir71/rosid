from __future__ import annotations

import hashlib
import unittest
from dataclasses import replace

from ml.rosid_ml.preprocess_reference import (
    CandidatePlane,
    PlaneReference,
    require_candidate_plane_match,
)


def _reference(
    layout: str,
    width: int,
    height: int,
    payload: bytes,
) -> PlaneReference:
    channels = 4 if layout == "rgba8" else 1
    channel_values = tuple(payload[index::channels] for index in range(channels))
    return PlaneReference(
        layout=layout,
        width=width,
        height=height,
        channels=channels,
        byte_count=len(payload),
        channel_minimums=tuple(min(values) for values in channel_values),
        channel_maximums=tuple(max(values) for values in channel_values),
        sha256=hashlib.sha256(payload).hexdigest(),
        zero_count=payload.count(0) if layout == "y8" else None,
        full_scale_count=payload.count(255) if layout == "y8" else None,
    )


_RGBA_PAYLOAD = bytes((1, 2, 3, 255, 10, 20, 30, 255))
_RGBA_REFERENCE = _reference("rgba8", 2, 1, _RGBA_PAYLOAD)
_GRAYSCALE_PAYLOAD = bytes((0, 64, 127, 255))
_GRAYSCALE_REFERENCE = _reference("y8", 2, 2, _GRAYSCALE_PAYLOAD)
_BINARY_PAYLOAD = bytes((0, 255, 255, 0))
_BINARY_REFERENCE = _reference("y8", 2, 2, _BINARY_PAYLOAD)


class CandidatePlaneTest(unittest.TestCase):
    def test_exact_tiny_rgba_grayscale_and_binary_planes_match(self) -> None:
        cases = (
            (_RGBA_REFERENCE, CandidatePlane("rgba8", 2, 1, _RGBA_PAYLOAD)),
            (
                _GRAYSCALE_REFERENCE,
                CandidatePlane("y8", 2, 2, _GRAYSCALE_PAYLOAD),
            ),
            (_BINARY_REFERENCE, CandidatePlane("y8", 2, 2, _BINARY_PAYLOAD)),
        )
        for reference, candidate in cases:
            with self.subTest(layout=reference.layout, sha256=reference.sha256):
                self.assertIsNone(require_candidate_plane_match(reference, candidate))

    def test_rejects_one_byte_mutation(self) -> None:
        changed = bytearray(_RGBA_PAYLOAD)
        changed[0] ^= 1
        candidate = CandidatePlane("rgba8", 2, 1, bytes(changed))

        with self.assertRaises(ValueError):
            require_candidate_plane_match(_RGBA_REFERENCE, candidate)

    def test_rejects_wrong_shape_or_layout_even_with_same_payload_length(self) -> None:
        cases = (
            CandidatePlane("rgba8", 1, 2, _RGBA_PAYLOAD),
            CandidatePlane("y8", 8, 1, _RGBA_PAYLOAD),
        )
        for candidate in cases:
            with self.subTest(
                layout=candidate.layout,
                width=candidate.width,
                height=candidate.height,
            ):
                with self.assertRaises(ValueError):
                    require_candidate_plane_match(_RGBA_REFERENCE, candidate)

    def test_oracle_rejects_candidate_without_immutable_exactly_sized_bytes(
        self,
    ) -> None:
        invalid_cases = (
            ("rgba8", 2, 1, bytearray(_RGBA_PAYLOAD)),
            ("rgba8", 2, 1, memoryview(_RGBA_PAYLOAD)),
            ("rgba8", 2, 1, list(_RGBA_PAYLOAD)),
            ("rgba8", 2, 1, "raw bytes"),
            ("rgba8", True, 1, _RGBA_PAYLOAD),
            ("rgba8", 2, False, _RGBA_PAYLOAD),
            ("rgba8", 0, 1, b""),
            ("rgba8", 2, -1, b""),
            ("rgba8", 2.0, 1, _RGBA_PAYLOAD),
            ("rgba8", 2, 1.0, _RGBA_PAYLOAD),
            ("rgb8", 2, 1, bytes(6)),
            (1, 2, 1, _RGBA_PAYLOAD),
            ("rgba8", 2, 1, _RGBA_PAYLOAD[:-1]),
            ("y8", 2, 2, _GRAYSCALE_PAYLOAD + b"\x00"),
        )
        for layout, width, height, payload in invalid_cases:
            with self.subTest(
                layout=layout,
                width=width,
                height=height,
                payload_type=type(payload).__name__,
            ):
                with self.assertRaises((TypeError, ValueError)):
                    require_candidate_plane_match(
                        _RGBA_REFERENCE,
                        CandidatePlane(layout, width, height, payload),
                    )

    def test_rejects_forged_reference_hash_extrema_and_counts(self) -> None:
        forged = (
            replace(_RGBA_REFERENCE, sha256="0" * 64),
            replace(_RGBA_REFERENCE, channel_minimums=(0, 2, 3, 255)),
            replace(_RGBA_REFERENCE, channel_maximums=(10, 20, 31, 255)),
            replace(_RGBA_REFERENCE, byte_count=len(_RGBA_PAYLOAD) + 1),
            replace(_RGBA_REFERENCE, channels=1),
            replace(_GRAYSCALE_REFERENCE, zero_count=1 + 1),
            replace(_GRAYSCALE_REFERENCE, full_scale_count=0),
        )
        rgba_candidate = CandidatePlane("rgba8", 2, 1, _RGBA_PAYLOAD)
        grayscale_candidate = CandidatePlane("y8", 2, 2, _GRAYSCALE_PAYLOAD)
        for reference in forged:
            candidate = (
                rgba_candidate if reference.layout == "rgba8" else grayscale_candidate
            )
            with self.subTest(reference=reference):
                with self.assertRaises(ValueError):
                    require_candidate_plane_match(reference, candidate)

    def test_reference_metadata_enforces_opacity_and_binary_semantics(self) -> None:
        translucent_payload = bytes((1, 2, 3, 254, 10, 20, 30, 255))
        translucent_reference = _reference("rgba8", 2, 1, translucent_payload)
        translucent_candidate = CandidatePlane(
            "rgba8",
            2,
            1,
            translucent_payload,
        )
        with self.assertRaises(ValueError):
            require_candidate_plane_match(
                translucent_reference,
                translucent_candidate,
            )

        nonbinary_payload = bytes((0, 1, 255))
        nonbinary_candidate = CandidatePlane("y8", 3, 1, nonbinary_payload)
        forged_binary_reference = replace(
            _reference("y8", 3, 1, nonbinary_payload),
            full_scale_count=2,
        )
        with self.assertRaises(ValueError):
            require_candidate_plane_match(
                forged_binary_reference,
                nonbinary_candidate,
            )

        # Endpoint counts below the payload length identify an ordinary
        # grayscale plane, so valid mid-scale bytes remain accepted.
        self.assertIsNone(
            require_candidate_plane_match(
                _reference("y8", 3, 1, nonbinary_payload),
                nonbinary_candidate,
            )
        )

    def test_candidate_oracle_has_no_evidence_or_serialization_surface(self) -> None:
        candidate = CandidatePlane("rgba8", 2, 1, _RGBA_PAYLOAD)
        forbidden = (
            "artifact_role",
            "artifact_type",
            "canonical_bytes",
            "commitment_sha256",
            "digest",
            "eligibility",
            "lineage_node",
            "parity_evidence",
            "production_evidence",
            "production_eligible",
            "report",
            "serialize",
            "sha256",
            "to_dict",
            "to_json",
            "to_lineage_node",
            "write",
        )
        self.assertIs(type(candidate.payload), bytes)
        self.assertNotIn("payload", repr(candidate))
        for subject in (candidate, CandidatePlane, require_candidate_plane_match):
            for attribute in forbidden:
                with self.subTest(subject=subject, attribute=attribute):
                    self.assertFalse(hasattr(subject, attribute))


if __name__ == "__main__":
    unittest.main()
