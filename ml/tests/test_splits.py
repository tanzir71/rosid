from __future__ import annotations

import hashlib
import unittest

from ml.rosid_ml.splits import (
    SampleKey,
    Split,
    assert_writer_disjoint,
    assign_writer_splits,
    validate_release_split,
)


class WriterSplitTest(unittest.TestCase):
    def test_rejects_whitespace_or_nonportable_identity_keys(self) -> None:
        with self.assertRaisesRegex(ValueError, "portable opaque"):
            self.sample("sample", "   ")

    def sample(
        self,
        sample_id: str,
        writer_id: str,
        dataset_id: str = "bn-htrd-v4",
    ) -> SampleKey:
        return SampleKey(
            sample_id=sample_id,
            dataset_id=dataset_id,
            writer_id=writer_id,
            image_sha256=hashlib.sha256(f"image:{sample_id}".encode()).hexdigest(),
            reference_sha256=hashlib.sha256(
                f"reference:{sample_id}".encode()
            ).hexdigest(),
        )

    def samples(self) -> list[SampleKey]:
        return [
            self.sample(f"sample-{writer}-{line}", f"writer-{writer}")
            for writer in range(20)
            for line in range(3)
        ]

    def test_split_is_order_independent_and_writer_disjoint(self) -> None:
        samples = self.samples()
        forward = assign_writer_splits(samples, seed="frozen-v1")
        reverse = assign_writer_splits(reversed(samples), seed="frozen-v1")

        self.assertEqual(forward, reverse)
        assert_writer_disjoint(samples, forward)
        self.assertEqual(set(forward.values()), set(Split))

    def test_every_line_from_a_writer_has_one_split(self) -> None:
        samples = self.samples()
        assignments = assign_writer_splits(samples, seed="frozen-v1")

        for writer in range(20):
            writer_assignments = {
                assignments[f"sample-{writer}-{line}"] for line in range(3)
            }
            self.assertEqual(len(writer_assignments), 1)

    def test_different_seed_changes_the_frozen_assignment(self) -> None:
        samples = self.samples()

        self.assertNotEqual(
            assign_writer_splits(samples, seed="one"),
            assign_writer_splits(samples, seed="two"),
        )

    def test_leakage_and_unknown_assignment_are_rejected(self) -> None:
        samples = [
            self.sample("a", "writer"),
            self.sample("b", "writer"),
        ]
        with self.assertRaisesRegex(ValueError, "cross split"):
            assert_writer_disjoint(samples, {"a": Split.TRAIN, "b": Split.TEST})
        with self.assertRaisesRegex(ValueError, "unknown"):
            assert_writer_disjoint(
                samples,
                {"a": Split.TRAIN, "b": Split.TRAIN, "c": Split.TEST},
            )
        with self.assertRaisesRegex(ValueError, "invalid split value"):
            assert_writer_disjoint(samples, {"a": "train", "b": "train"})

    def test_explicit_empty_or_invalid_ratios_do_not_use_defaults(self) -> None:
        with self.assertRaisesRegex(ValueError, "must define"):
            assign_writer_splits(self.samples(), seed="seed", ratios={})
        with self.assertRaisesRegex(ValueError, "sum to one"):
            assign_writer_splits(
                self.samples(),
                seed="seed",
                ratios={
                    Split.TRAIN: 0.5,
                    Split.VALIDATION: 0.1,
                    Split.TEST: 0.1,
                },
            )
        with self.assertRaisesRegex(ValueError, "must define"):
            assign_writer_splits([], seed="seed", ratios={})

    def test_identical_image_content_cannot_cross_splits(self) -> None:
        first = self.sample("a", "writer-a")
        second = SampleKey(
            sample_id="b",
            dataset_id="bn-htrd-v4",
            writer_id="writer-b",
            image_sha256=first.image_sha256,
            reference_sha256=first.reference_sha256,
        )

        with self.assertRaisesRegex(ValueError, "image content"):
            assert_writer_disjoint(
                [first, second],
                {"a": Split.TRAIN, "b": Split.TEST},
            )

    def test_release_holdouts_cannot_inflate_counts_with_duplicate_images(self) -> None:
        train = self.sample("train", "writer-train")
        validation = self.sample("validation", "writer-validation")
        test_a = self.sample("test-a", "writer-test-a")
        test_b = SampleKey(
            sample_id="test-b",
            dataset_id=test_a.dataset_id,
            writer_id="writer-test-b",
            image_sha256=test_a.image_sha256,
            reference_sha256=test_a.reference_sha256,
        )

        with self.assertRaisesRegex(ValueError, "repeated within test"):
            validate_release_split(
                [train, validation, test_a, test_b],
                {
                    "train": Split.TRAIN,
                    "validation": Split.VALIDATION,
                    "test-a": Split.TEST,
                    "test-b": Split.TEST,
                },
            )

    def test_writer_group_is_global_across_datasets(self) -> None:
        samples = [
            self.sample("a", "shared-writer", "dataset-a"),
            self.sample("b", "shared-writer", "dataset-b"),
        ]

        assignments = assign_writer_splits(samples, seed="global-writers")

        self.assertEqual(assignments["a"], assignments["b"])
        with self.assertRaisesRegex(ValueError, "cross split"):
            assert_writer_disjoint(
                samples,
                {"a": Split.TRAIN, "b": Split.TEST},
            )

    def test_release_validation_rejects_vacuous_partitions(self) -> None:
        with self.assertRaisesRegex(ValueError, "train has 0 samples"):
            validate_release_split([], {})

        samples = self.samples()
        assignments = assign_writer_splits(samples, seed="release")
        evidence = validate_release_split(samples, assignments)
        self.assertGreaterEqual(evidence.writer_counts[Split.TEST], 1)
        self.assertEqual(
            evidence.unique_image_counts[Split.TEST],
            evidence.sample_counts[Split.TEST],
        )

        train_only = {sample.sample_id: Split.TRAIN for sample in samples}
        with self.assertRaisesRegex(ValueError, "validation has 0 samples"):
            validate_release_split(samples, train_only)


if __name__ == "__main__":
    unittest.main()
