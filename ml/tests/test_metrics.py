from __future__ import annotations

import json
import unittest

from ml.rosid_ml.metrics import (
    AmountReference,
    amount_cer,
    cer,
    compare_amount_systems,
    compare_cer_systems,
    exact_amount_cer,
    keyed_cer,
    levenshtein_distance,
    relative_error_reduction,
    ScoredText,
    validate_amount_slice,
    wer,
)


class MetricsTest(unittest.TestCase):
    def test_amount_reference_requires_explicit_audit_flag(self) -> None:
        with self.assertRaises(TypeError):
            AmountReference(  # type: ignore[call-arg]
                sample_id="amount-1",
                text="৳125",
                writer_id="writer-1",
                split_commitment="a" * 64,
            )

    def test_levenshtein_handles_insert_delete_and_substitute(self) -> None:
        self.assertEqual(levenshtein_distance(tuple("kitten"), tuple("sitting")), 3)

    def test_cer_is_nfc_normalized_and_micro_averaged(self) -> None:
        result = cer([("কো", "কো"), ("মোট", "মট")])

        self.assertEqual(result.samples, 2)
        self.assertEqual(result.edits, 1)
        self.assertEqual(result.reference_units, 5)
        self.assertAlmostEqual(result.rate, 0.2)

    def test_wer_canonicalizes_layout_whitespace(self) -> None:
        result = wer([("সর্বমোট  ১২৫", "সর্বমোট\n১২৫")])

        self.assertEqual(result.rate, 0)

    def test_amount_cer_treats_bangla_and_ascii_digits_as_equivalent(self) -> None:
        result = amount_cer([("মোট ৳১২৫", "Total ৳125")])

        self.assertEqual(result.rate, 0)
        self.assertEqual(result.reference_units, 4)

    def test_amount_cer_penalizes_missing_digit(self) -> None:
        result = amount_cer([("৳১২৫", "৳15")])

        self.assertEqual(result.edits, 1)
        self.assertEqual(result.reference_units, 4)

    def test_exact_amount_cer_preserves_numeral_script(self) -> None:
        result = exact_amount_cer([("৳১২৫", "৳125")])

        self.assertEqual(result.edits, 3)
        self.assertEqual(result.reference_units, 4)

    def test_amount_cer_rejects_empty_or_nonmonetary_evidence(self) -> None:
        with self.assertRaisesRegex(ValueError, "nonempty monetary"):
            amount_cer([])
        with self.assertRaisesRegex(ValueError, "nonempty monetary"):
            amount_cer([("মোট", "মোট")])

    def test_amount_acceptance_enforces_writer_sample_and_unit_minimums(self) -> None:
        references = [
            AmountReference(
                sample_id=f"sample-{index}",
                text="৳123456789",
                writer_id=f"writer-{index % 20}",
                split_commitment="a" * 64,
                monetary_verified=True,
            )
            for index in range(100)
        ]
        predictions = [
            ScoredText(value.sample_id, value.text) for value in references
        ]

        evidence = validate_amount_slice(references)
        comparison = compare_amount_systems(
            references,
            predictions,
            predictions,
            commitment_key=b"a" * 32,
        )

        self.assertEqual(evidence.samples, 100)
        self.assertEqual(evidence.writers, 20)
        self.assertEqual(evidence.reference_units, 1000)
        self.assertEqual(evidence.split_commitment, "a" * 64)
        self.assertEqual(comparison.candidate.rate, 0)
        with self.assertRaisesRegex(ValueError, "requires 100"):
            validate_amount_slice(references[:99])
        with self.assertRaisesRegex(ValueError, "unverified"):
            validate_amount_slice(
                [
                    AmountReference(
                        value.sample_id,
                        value.text,
                        value.writer_id,
                        split_commitment=value.split_commitment,
                        monetary_verified=value.sample_id != "sample-0",
                    )
                    for value in references
                ]
            )
        with self.assertRaisesRegex(ValueError, "portable opaque"):
            AmountReference(
                sample_id="amount-invalid",
                text="৳125",
                writer_id="   ",
                split_commitment="a" * 64,
                monetary_verified=True,
            )
        with self.assertRaisesRegex(ValueError, "one frozen split"):
            validate_amount_slice(
                [
                    AmountReference(
                        sample_id=value.sample_id,
                        text=value.text,
                        writer_id=value.writer_id,
                        split_commitment=(
                            "b" * 64 if value.sample_id == "sample-0" else "a" * 64
                        ),
                        monetary_verified=True,
                    )
                    for value in references
                ]
            )

    def test_relative_error_reduction(self) -> None:
        defined = relative_error_reduction(0.4, 0.25)
        self.assertAlmostEqual(defined.value or 0, 0.375)
        self.assertTrue(defined.passes(0.3))
        both_zero = relative_error_reduction(0, 0)
        candidate_error = relative_error_reduction(0, 0.1)
        self.assertIsNone(both_zero.value)
        self.assertIsNone(candidate_error.value)
        self.assertFalse(both_zero.passes(0.3))
        self.assertIn('"value": null', json.dumps(both_zero.to_dict()))
        with self.assertRaises(ValueError):
            relative_error_reduction(-0.1, 0.1)

    def test_keyed_metrics_require_identical_unique_ordered_ids(self) -> None:
        references = [ScoredText("a", "মোট"), ScoredText("b", "১২৫")]
        predictions = [ScoredText("a", "মোট"), ScoredText("b", "125")]

        self.assertGreater(keyed_cer(references, predictions).edits, 0)
        with self.assertRaisesRegex(ValueError, "sample order"):
            keyed_cer(references, list(reversed(predictions)))
        with self.assertRaisesRegex(ValueError, "missing"):
            keyed_cer(references, predictions[:1])
        with self.assertRaisesRegex(ValueError, "must be unique"):
            keyed_cer(
                references,
                [ScoredText("a", "মোট"), ScoredText("a", "১২৫")],
            )

    def test_system_comparison_binds_one_reference_manifest(self) -> None:
        references = [ScoredText("a", "মোট"), ScoredText("b", "১২৫")]
        baseline = [ScoredText("a", "মত"), ScoredText("b", "১২")]
        candidate = [ScoredText("a", "মোট"), ScoredText("b", "১২৫")]

        result = compare_cer_systems(
            references,
            baseline,
            candidate,
            commitment_key=b"k" * 32,
        )

        self.assertEqual(len(result.reference_commitment), 64)
        self.assertGreater(result.baseline.rate, result.candidate.rate)
        self.assertTrue(result.relative_reduction.passes(0.3))
        with self.assertRaisesRegex(ValueError, "sample order"):
            compare_cer_systems(
                references,
                baseline,
                list(reversed(candidate)),
                commitment_key=b"k" * 32,
            )
        with self.assertRaisesRegex(ValueError, "at least 32 bytes"):
            compare_cer_systems(
                references,
                baseline,
                candidate,
                commitment_key=b"short",
            )

    def test_system_comparison_rejects_vacuous_reference_units(self) -> None:
        with self.assertRaisesRegex(ValueError, "nonempty"):
            compare_cer_systems([], [], [], commitment_key=b"k" * 32)
        with self.assertRaisesRegex(ValueError, "scored character"):
            compare_cer_systems(
                [ScoredText("empty", "")],
                [ScoredText("empty", "wrong")],
                [ScoredText("empty", "")],
                commitment_key=b"k" * 32,
            )


if __name__ == "__main__":
    unittest.main()
