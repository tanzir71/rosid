from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from ml.rosid_ml.lineage import (
    ArtifactType,
    DataPartition,
    LineageGraph,
    LineageNode,
    SynthesisTier,
)
from ml.rosid_ml.provenance import (
    AcquisitionRecord,
    Eligibility,
    SourceEvidence,
)


def digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def evidence(
    evidence_id: str,
    *,
    eligibility: Eligibility = Eligibility.PRODUCTION,
    artifact_type: ArtifactType = ArtifactType.DATASET,
    artifact_role: str | None = None,
) -> SourceEvidence:
    dataset_id = evidence_id if artifact_type == ArtifactType.DATASET else None
    return SourceEvidence(
        schema_version=2,
        evidence_id=evidence_id,
        dataset_id=dataset_id,
        doi=f"10.0000/{evidence_id}" if dataset_id is not None else None,
        source_manifest_sha256=(
            digest(f"manifest:{evidence_id}") if dataset_id is not None else None
        ),
        source_url=f"https://example.test/{evidence_id}",
        version="1",
        license_id="CC-BY-4.0",
        content_sha256=digest(f"content:{evidence_id}"),
        artifact_type=artifact_type.value,
        artifact_role=artifact_role
        or ("source_archive" if artifact_type == ArtifactType.DATASET else artifact_type.value),
        eligibility=eligibility,
        attribution="Synthetic unit-test evidence.",
        rights_notes="No real external bytes.",
    )


def acquisition(source: SourceEvidence) -> AcquisitionRecord:
    return AcquisitionRecord(
        schema_version=2,
        record_id=f"acquired:{source.evidence_id}",
        source_evidence_sha256=source.commitment_sha256,
        content_sha256=source.content_sha256,
        artifact_sha256=source.content_sha256,
        inventory_sha256=digest(f"inventory:{source.evidence_id}"),
        acquired_at_utc="2026-07-18T00:00:00Z",
        accepted_by="unit-test",
        terms_accepted=True,
        extractor="unit-test/1",
        eligibility=source.eligibility,
    )


def node(
    artifact_id: str,
    artifact_type: ArtifactType,
    *,
    parents: tuple[str, ...] = (),
    eligibility: Eligibility = Eligibility.PRODUCTION,
    partition: DataPartition = DataPartition.NONE,
    role: str | None = None,
    sha256: str | None = None,
    synthesis_tier: SynthesisTier = SynthesisTier.NONE,
    external_source: SourceEvidence | None = None,
    external_acquisition: AcquisitionRecord | None = None,
) -> LineageNode:
    if external_source is not None:
        if external_acquisition is None:
            raise AssertionError("external test node requires acquisition")
        source = external_source.source_url
        version = external_source.version
        license_id = external_source.license_id
        sha256 = external_acquisition.artifact_sha256
        eligibility = external_acquisition.eligibility
        source_commitment = external_source.commitment_sha256
        acquisition_commitment = external_acquisition.commitment_sha256
    else:
        source = "git:rosid"
        version = "unit-test"
        license_id = "repository-license"
        source_commitment = None
        acquisition_commitment = None
    return LineageNode(
        artifact_id=artifact_id,
        artifact_type=artifact_type,
        sha256=sha256 or digest(artifact_id),
        eligibility=eligibility,
        partition=partition,
        source=source,
        version=version,
        license_id=license_id,
        role=role
        or (
            external_source.artifact_role
            if external_source is not None
            else artifact_type.value
        ),
        transformation="unit-test",
        source_evidence_sha256=source_commitment,
        acquisition_sha256=acquisition_commitment,
        synthesis_tier=synthesis_tier,
        parents=parents,
    )


def graph(
    nodes: list[LineageNode],
    sources: tuple[SourceEvidence, ...] = (),
    acquisitions: tuple[AcquisitionRecord, ...] = (),
) -> LineageGraph:
    return LineageGraph(
        nodes,
        source_evidence=sources,
        acquisitions=acquisitions,
    )


def full_float16_graph() -> tuple[
    list[LineageNode], tuple[SourceEvidence, ...], tuple[AcquisitionRecord, ...]
]:
    dataset_source = evidence("real-lines")
    dataset_acquisition = acquisition(dataset_source)
    ben_source = evidence(
        "tesseract-ben",
        artifact_type=ArtifactType.PRETRAINED_WEIGHTS,
        artifact_role="tesseract-ben",
    )
    ben_acquisition = acquisition(ben_source)
    eng_source = evidence(
        "tesseract-eng",
        artifact_type=ArtifactType.PRETRAINED_WEIGHTS,
        artifact_role="tesseract-eng",
    )
    eng_acquisition = acquisition(eng_source)
    model_sha = digest("float16-model")
    nodes = [
        node(
            "dataset-archive",
            ArtifactType.DATASET,
            external_source=dataset_source,
            external_acquisition=dataset_acquisition,
        ),
        node("split-code", ArtifactType.CODE),
        node("split-config", ArtifactType.CONFIG),
        node(
            "split-manifest",
            ArtifactType.SPLIT_MANIFEST,
            parents=("dataset-archive", "split-code", "split-config"),
        ),
        node(
            "train-data",
            ArtifactType.DATA_PARTITION,
            parents=("split-manifest",),
            partition=DataPartition.TRAIN,
            role="train",
        ),
        node(
            "test-data",
            ArtifactType.DATA_PARTITION,
            parents=("split-manifest",),
            partition=DataPartition.TEST,
            role="test",
        ),
        node("training-code", ArtifactType.CODE),
        node("training-config", ArtifactType.CONFIG),
        node(
            "checkpoint",
            ArtifactType.MODEL_CHECKPOINT,
            parents=("train-data", "training-code", "training-config"),
        ),
        node(
            "vocabulary",
            ArtifactType.VOCABULARY,
            parents=("train-data", "training-code", "training-config"),
        ),
        node(
            "model-contract",
            ArtifactType.MODEL_CONTRACT,
            parents=("training-code", "training-config"),
        ),
        node("converter-code", ArtifactType.CODE),
        node("converter-config", ArtifactType.CONFIG),
        node(
            "conversion-export",
            ArtifactType.CONVERSION_EXPORT,
            parents=("checkpoint", "converter-code", "converter-config"),
            role="float16",
            sha256=model_sha,
        ),
        node(
            "mobile-model",
            ArtifactType.MOBILE_MODEL,
            parents=("conversion-export", "vocabulary", "model-contract"),
            role="float16",
            sha256=model_sha,
        ),
        node(
            "tesseract-ben",
            ArtifactType.PRETRAINED_WEIGHTS,
            external_source=ben_source,
            external_acquisition=ben_acquisition,
        ),
        node(
            "tesseract-eng",
            ArtifactType.PRETRAINED_WEIGHTS,
            external_source=eng_source,
            external_acquisition=eng_acquisition,
        ),
        node(
            "test-set",
            ArtifactType.EVALUATION_SET,
            parents=("test-data", "inference-code", "inference-config"),
            partition=DataPartition.TEST,
        ),
        node("inference-code", ArtifactType.CODE),
        node("inference-config", ArtifactType.CONFIG),
        node(
            "raw-htr-predictions",
            ArtifactType.PREDICTIONS,
            parents=(
                "mobile-model",
                "test-set",
                "inference-code",
                "inference-config",
            ),
            partition=DataPartition.TEST,
            role="raw_htr",
        ),
        node(
            "tesseract-predictions",
            ArtifactType.PREDICTIONS,
            parents=(
                "test-set",
                "tesseract-ben",
                "tesseract-eng",
                "inference-code",
                "inference-config",
            ),
            partition=DataPartition.TEST,
            role="tesseract_baseline",
        ),
        node("scorer-code", ArtifactType.CODE),
        node("scorer-config", ArtifactType.CONFIG),
        node(
            "final-metrics",
            ArtifactType.METRICS,
            parents=(
                "mobile-model",
                "test-set",
                "raw-htr-predictions",
                "tesseract-predictions",
                "scorer-code",
                "scorer-config",
            ),
            role="final",
        ),
    ]
    return (
        nodes,
        (dataset_source, ben_source, eng_source),
        (dataset_acquisition, ben_acquisition, eng_acquisition),
    )


class LineageTest(unittest.TestCase):
    def test_accepts_evidence_bound_conversion_and_final_metrics(self) -> None:
        nodes, sources, acquisitions = full_float16_graph()

        value = graph(nodes, sources, acquisitions)

        value.assert_production_eligible("mobile-model")
        value.assert_final_metrics("final-metrics")
        self.assertIn("test-data", value.ancestors("final-metrics"))

    def test_external_evidence_binds_type_role_and_extracted_bytes(self) -> None:
        source = evidence("font-source", artifact_type=ArtifactType.FONT)
        acquired = AcquisitionRecord(
            **{
                **acquisition(source).__dict__,
                "artifact_sha256": digest("extracted-font-file"),
            }
        )
        font = node(
            "font-file",
            ArtifactType.FONT,
            external_source=source,
            external_acquisition=acquired,
        )

        graph([font], (source,), (acquired,)).assert_production_eligible("font-file")
        self.assertEqual(font.sha256, acquired.artifact_sha256)

        relabeled = LineageNode(
            **{**font.__dict__, "artifact_type": ArtifactType.TEXTURE}
        )
        with self.assertRaisesRegex(ValueError, "artifact type"):
            graph([relabeled], (source,), (acquired,))

        wrong_role = LineageNode(**{**font.__dict__, "role": "texture"})
        with self.assertRaisesRegex(ValueError, "artifact role"):
            graph([wrong_role], (source,), (acquired,))

    def test_evaluation_set_must_bind_matching_partition_sources(self) -> None:
        source = evidence("evaluation-source")
        acquired = acquisition(source)
        archive = node(
            "evaluation-archive",
            ArtifactType.DATASET,
            external_source=source,
            external_acquisition=acquired,
        )
        split_code = node("evaluation-split-code", ArtifactType.CODE)
        split_config = node("evaluation-split-config", ArtifactType.CONFIG)
        manifest = node(
            "evaluation-split",
            ArtifactType.SPLIT_MANIFEST,
            parents=(
                "evaluation-archive",
                "evaluation-split-code",
                "evaluation-split-config",
            ),
        )
        train_data = node(
            "train-evaluation-data",
            ArtifactType.DATA_PARTITION,
            parents=("evaluation-split",),
            partition=DataPartition.TRAIN,
            role="train",
        )
        validation_data = node(
            "validation-evaluation-data",
            ArtifactType.DATA_PARTITION,
            parents=("evaluation-split",),
            partition=DataPartition.VALIDATION,
            role="validation",
        )

        with self.assertRaisesRegex(ValueError, "outside its test partition"):
            graph(
                [
                    archive,
                    split_code,
                    split_config,
                    manifest,
                    train_data,
                    node(
                        "test-set",
                        ArtifactType.EVALUATION_SET,
                        parents=(
                            "train-evaluation-data",
                            "evaluation-split-code",
                            "evaluation-split-config",
                        ),
                        partition=DataPartition.TEST,
                    ),
                ],
                (source,),
                (acquired,),
            )

        with self.assertRaisesRegex(ValueError, "outside its validation partition"):
            graph(
                [
                    archive,
                    split_code,
                    split_config,
                    manifest,
                    train_data,
                    validation_data,
                    node(
                        "mixed-validation-set",
                        ArtifactType.EVALUATION_SET,
                        parents=(
                            "train-evaluation-data",
                            "validation-evaluation-data",
                            "evaluation-split-code",
                            "evaluation-split-config",
                        ),
                        partition=DataPartition.VALIDATION,
                    ),
                ],
                (source,),
                (acquired,),
            )

        with self.assertRaisesRegex(ValueError, "source archive"):
            graph(
                [
                    node(
                        "relabeled-archive",
                        ArtifactType.DATASET,
                        partition=DataPartition.TEST,
                        external_source=source,
                        external_acquisition=acquired,
                    )
                ],
                (source,),
                (acquired,),
            )

    def test_external_eligibility_cannot_be_self_attested_or_upgraded(self) -> None:
        source = evidence("conditional", eligibility=Eligibility.CONDITIONAL)
        acquired = acquisition(source)
        external = node(
            "data",
            ArtifactType.DATASET,
            external_source=source,
            external_acquisition=acquired,
        )

        with self.assertRaisesRegex(ValueError, "unknown evidence"):
            graph([external])

        relabeled = LineageNode(
            **{**external.__dict__, "eligibility": Eligibility.PRODUCTION}
        )
        with self.assertRaisesRegex(ValueError, "contradicts evidence"):
            graph([relabeled], (source,), (acquired,))

        upgraded = AcquisitionRecord(
            **{**acquired.__dict__, "eligibility": Eligibility.PRODUCTION}
        )
        upgraded_node = LineageNode(
            **{
                **external.__dict__,
                "eligibility": Eligibility.PRODUCTION,
                "acquisition_sha256": upgraded.commitment_sha256,
            }
        )
        with self.assertRaisesRegex(ValueError, "cannot upgrade"):
            graph([upgraded_node], (source,), (upgraded,))

    def test_incomplete_artifacts_fail_even_when_asserted_directly(self) -> None:
        for artifact_type, message in (
            (ArtifactType.GENERATOR_CHECKPOINT, "generator checkpoint"),
            (ArtifactType.MODEL_CHECKPOINT, "model checkpoint"),
            (ArtifactType.VOCABULARY, "vocabulary"),
            (ArtifactType.MODEL_CONTRACT, "model contract"),
            (ArtifactType.REPRESENTATIVE_SET, "representative set"),
            (ArtifactType.CONVERSION_EXPORT, "conversion export"),
            (ArtifactType.MOBILE_MODEL, "mobile model"),
        ):
            with self.subTest(artifact_type=artifact_type):
                kwargs: dict[str, object] = {}
                if artifact_type == ArtifactType.REPRESENTATIVE_SET:
                    kwargs["partition"] = DataPartition.TRAIN
                if artifact_type in {
                    ArtifactType.CONVERSION_EXPORT,
                    ArtifactType.MOBILE_MODEL,
                }:
                    kwargs["role"] = "float16"
                with self.assertRaisesRegex(ValueError, message):
                    graph([node("artifact", artifact_type, **kwargs)])

    def test_training_artifacts_require_direct_role_appropriate_inputs(self) -> None:
        nodes, sources, acquisitions = full_float16_graph()
        checkpoint_index = next(
            index
            for index, value in enumerate(nodes)
            if value.artifact_id == "checkpoint"
        )
        nodes[checkpoint_index] = LineageNode(
            **{**nodes[checkpoint_index].__dict__, "parents": ("vocabulary",)}
        )

        with self.assertRaisesRegex(ValueError, "model checkpoint.*direct lineage"):
            graph(nodes, sources, acquisitions)

        nodes, sources, acquisitions = full_float16_graph()
        nodes.append(
            node(
                "validation-data",
                ArtifactType.DATA_PARTITION,
                parents=("split-manifest",),
                partition=DataPartition.VALIDATION,
                role="validation",
            )
        )
        vocabulary_index = next(
            index
            for index, value in enumerate(nodes)
            if value.artifact_id == "vocabulary"
        )
        vocabulary = nodes[vocabulary_index]
        nodes[vocabulary_index] = LineageNode(
            **{
                **vocabulary.__dict__,
                "parents": (*vocabulary.parents, "validation-data"),
            }
        )

        with self.assertRaisesRegex(ValueError, "non-train data"):
            graph(nodes, sources, acquisitions)

        nodes, sources, acquisitions = full_float16_graph()
        nodes.extend(
            [
                node(
                    "validation-data",
                    ArtifactType.DATA_PARTITION,
                    parents=("split-manifest",),
                    partition=DataPartition.VALIDATION,
                    role="validation",
                ),
                node("validation-code", ArtifactType.CODE),
                node("validation-config", ArtifactType.CONFIG),
                node(
                    "validation-set",
                    ArtifactType.EVALUATION_SET,
                    parents=(
                        "validation-data",
                        "validation-code",
                        "validation-config",
                    ),
                    partition=DataPartition.VALIDATION,
                ),
            ]
        )
        vocabulary_index = next(
            index
            for index, value in enumerate(nodes)
            if value.artifact_id == "vocabulary"
        )
        vocabulary = nodes[vocabulary_index]
        nodes[vocabulary_index] = LineageNode(
            **{
                **vocabulary.__dict__,
                "parents": (*vocabulary.parents, "validation-set"),
            }
        )

        with self.assertRaisesRegex(ValueError, "non-training partition"):
            graph(nodes, sources, acquisitions)

    def test_partition_artifact_cannot_bypass_its_split_manifest(self) -> None:
        nodes, sources, acquisitions = full_float16_graph()
        test_index = next(
            index
            for index, value in enumerate(nodes)
            if value.artifact_id == "test-data"
        )
        test_data = nodes[test_index]
        nodes[test_index] = LineageNode(
            **{
                **test_data.__dict__,
                "parents": ("split-manifest", "dataset-archive"),
            }
        )

        with self.assertRaisesRegex(ValueError, "only one split manifest"):
            graph(nodes, sources, acquisitions)

    def test_final_metrics_bind_scorer_and_both_prediction_streams(self) -> None:
        nodes, sources, acquisitions = full_float16_graph()
        metrics_index = next(
            index
            for index, value in enumerate(nodes)
            if value.artifact_id == "final-metrics"
        )
        metrics = nodes[metrics_index]
        nodes[metrics_index] = LineageNode(
            **{
                **metrics.__dict__,
                "parents": tuple(
                    value
                    for value in metrics.parents
                    if value != "tesseract-predictions"
                ),
            }
        )

        with self.assertRaisesRegex(ValueError, "prediction stream"):
            graph(nodes, sources, acquisitions)

        nodes, sources, acquisitions = full_float16_graph()
        other_source = evidence(
            "other-engine",
            artifact_type=ArtifactType.PRETRAINED_WEIGHTS,
            artifact_role="other-engine",
        )
        other_acquisition = acquisition(other_source)
        nodes.append(
            node(
                "other-engine",
                ArtifactType.PRETRAINED_WEIGHTS,
                external_source=other_source,
                external_acquisition=other_acquisition,
            )
        )
        prediction_index = next(
            index
            for index, value in enumerate(nodes)
            if value.artifact_id == "tesseract-predictions"
        )
        prediction = nodes[prediction_index]
        nodes[prediction_index] = LineageNode(
            **{
                **prediction.__dict__,
                "parents": (*prediction.parents, "other-engine"),
            }
        )

        with self.assertRaisesRegex(ValueError, "exactly one ben"):
            graph(
                nodes,
                (*sources, other_source),
                (*acquisitions, other_acquisition),
            )

        nodes, sources, acquisitions = full_float16_graph()
        metrics_index = next(
            index
            for index, value in enumerate(nodes)
            if value.artifact_id == "final-metrics"
        )
        metrics = nodes[metrics_index]
        nodes[metrics_index] = LineageNode(
            **{
                **metrics.__dict__,
                "role": "release-candidate",
                "parents": tuple(
                    value
                    for value in metrics.parents
                    if value != "tesseract-predictions"
                ),
            }
        )

        with self.assertRaisesRegex(ValueError, "role must be validation or final"):
            graph(nodes, sources, acquisitions)

    def test_final_metrics_require_one_global_writer_split(self) -> None:
        nodes, sources, acquisitions = full_float16_graph()
        nodes.extend(
            [
                node("second-split-code", ArtifactType.CODE),
                node("second-split-config", ArtifactType.CONFIG),
                node(
                    "second-split",
                    ArtifactType.SPLIT_MANIFEST,
                    parents=(
                        "dataset-archive",
                        "second-split-code",
                        "second-split-config",
                    ),
                ),
            ]
        )
        test_index = next(
            index
            for index, value in enumerate(nodes)
            if value.artifact_id == "test-data"
        )
        test_data = nodes[test_index]
        nodes[test_index] = LineageNode(
            **{**test_data.__dict__, "parents": ("second-split",)}
        )

        with self.assertRaisesRegex(ValueError, "one global writer-split"):
            graph(nodes, sources, acquisitions)

    def test_mobile_and_conversion_dependencies_are_unambiguous(self) -> None:
        nodes, sources, acquisitions = full_float16_graph()
        nodes.extend(
            [
                node(
                    "second-vocabulary",
                    ArtifactType.VOCABULARY,
                    parents=("train-data", "training-code", "training-config"),
                ),
                node(
                    "second-contract",
                    ArtifactType.MODEL_CONTRACT,
                    parents=("training-code", "training-config"),
                ),
            ]
        )
        mobile_index = next(
            index
            for index, value in enumerate(nodes)
            if value.artifact_id == "mobile-model"
        )
        mobile = nodes[mobile_index]
        nodes[mobile_index] = LineageNode(
            **{
                **mobile.__dict__,
                "parents": (
                    *mobile.parents,
                    "second-vocabulary",
                    "second-contract",
                ),
            }
        )

        with self.assertRaisesRegex(ValueError, "exactly one vocabulary"):
            graph(nodes, sources, acquisitions)

        nodes, sources, acquisitions = full_float16_graph()
        nodes.append(
            node(
                "second-checkpoint",
                ArtifactType.MODEL_CHECKPOINT,
                parents=("train-data", "training-code", "training-config"),
            )
        )
        export_index = next(
            index
            for index, value in enumerate(nodes)
            if value.artifact_id == "conversion-export"
        )
        export = nodes[export_index]
        nodes[export_index] = LineageNode(
            **{
                **export.__dict__,
                "parents": (*export.parents, "second-checkpoint"),
            }
        )

        with self.assertRaisesRegex(ValueError, "exactly one model checkpoint"):
            graph(nodes, sources, acquisitions)

    def test_tier1_and_tier2_do_not_require_a_learned_generator(self) -> None:
        sources = (
            evidence("font", artifact_type=ArtifactType.FONT),
            evidence("texture", artifact_type=ArtifactType.TEXTURE),
            evidence("text", artifact_type=ArtifactType.TEXT_CORPUS),
        )
        acquisitions = tuple(acquisition(value) for value in sources)
        external_nodes = [
            node(
                "font",
                ArtifactType.FONT,
                external_source=sources[0],
                external_acquisition=acquisitions[0],
            ),
            node(
                "texture",
                ArtifactType.TEXTURE,
                external_source=sources[1],
                external_acquisition=acquisitions[1],
            ),
            node(
                "text",
                ArtifactType.TEXT_CORPUS,
                partition=DataPartition.TRAIN,
                external_source=sources[2],
                external_acquisition=acquisitions[2],
            ),
            node("generator-code", ArtifactType.CODE),
            node("generator-config", ArtifactType.CONFIG),
        ]
        tier1 = node(
            "tier1",
            ArtifactType.GENERATED_CORPUS,
            parents=("font", "texture", "text", "generator-code", "generator-config"),
            partition=DataPartition.TRAIN,
            synthesis_tier=SynthesisTier.TIER_1,
        )
        tier2 = node(
            "tier2",
            ArtifactType.GENERATED_CORPUS,
            parents=("font", "text", "generator-code", "generator-config"),
            partition=DataPartition.TRAIN,
            synthesis_tier=SynthesisTier.TIER_2,
        )

        value = graph(
            [*external_nodes, tier1, tier2],
            sources,
            acquisitions,
        )

        value.assert_production_eligible("tier1")
        value.assert_production_eligible("tier2")

    def test_tier2_cannot_use_an_unsplit_dataset_as_writer_style(self) -> None:
        dataset_source = evidence("styles")
        text_source = evidence("style-text", artifact_type=ArtifactType.TEXT_CORPUS)
        sources = (dataset_source, text_source)
        acquisitions = tuple(acquisition(value) for value in sources)
        nodes = [
            node(
                "style-archive",
                ArtifactType.DATASET,
                external_source=dataset_source,
                external_acquisition=acquisitions[0],
            ),
            node(
                "style-text",
                ArtifactType.TEXT_CORPUS,
                external_source=text_source,
                external_acquisition=acquisitions[1],
            ),
            node("style-code", ArtifactType.CODE),
            node("style-config", ArtifactType.CONFIG),
            node(
                "tier2",
                ArtifactType.GENERATED_CORPUS,
                parents=(
                    "style-archive",
                    "style-text",
                    "style-code",
                    "style-config",
                ),
                partition=DataPartition.TRAIN,
                synthesis_tier=SynthesisTier.TIER_2,
            ),
        ]

        with self.assertRaisesRegex(ValueError, "lacks a style source"):
            graph(nodes, sources, acquisitions)

    def test_tier3_requires_a_complete_learned_generator(self) -> None:
        text_source = evidence("text", artifact_type=ArtifactType.TEXT_CORPUS)
        text_acquisition = acquisition(text_source)
        nodes = [
            node(
                "text",
                ArtifactType.TEXT_CORPUS,
                partition=DataPartition.TRAIN,
                external_source=text_source,
                external_acquisition=text_acquisition,
            ),
            node("code", ArtifactType.CODE),
            node("config", ArtifactType.CONFIG),
            node("generator", ArtifactType.GENERATOR_CHECKPOINT),
            node(
                "tier3",
                ArtifactType.GENERATED_CORPUS,
                parents=("generator", "text", "code", "config"),
                partition=DataPartition.TRAIN,
                synthesis_tier=SynthesisTier.TIER_3,
            ),
        ]

        with self.assertRaisesRegex(ValueError, "generator checkpoint"):
            graph(nodes, (text_source,), (text_acquisition,))

    def test_conversion_requires_its_own_code_config_and_int8_sample(self) -> None:
        source = evidence("train")
        acquired = acquisition(source)
        base = [
            node(
                "archive",
                ArtifactType.DATASET,
                external_source=source,
                external_acquisition=acquired,
            ),
            node("split-code", ArtifactType.CODE),
            node("split-config", ArtifactType.CONFIG),
            node(
                "split",
                ArtifactType.SPLIT_MANIFEST,
                parents=("archive", "split-code", "split-config"),
            ),
            node(
                "train",
                ArtifactType.DATA_PARTITION,
                parents=("split",),
                partition=DataPartition.TRAIN,
                role="train",
            ),
            node("training-code", ArtifactType.CODE),
            node("training-config", ArtifactType.CONFIG),
            node(
                "checkpoint",
                ArtifactType.MODEL_CHECKPOINT,
                parents=("train", "training-code", "training-config"),
            ),
        ]
        float_export = node(
            "export",
            ArtifactType.CONVERSION_EXPORT,
            parents=("checkpoint",),
            role="float16",
        )
        with self.assertRaisesRegex(ValueError, "direct lineage"):
            graph([*base, float_export], (source,), (acquired,))

        int8_export = node(
            "export",
            ArtifactType.CONVERSION_EXPORT,
            parents=("checkpoint", "training-code", "training-config"),
            role="int8",
        )
        with self.assertRaisesRegex(ValueError, "representative_set"):
            graph([*base, int8_export], (source,), (acquired,))

    def test_restricted_input_and_test_data_cannot_leak(self) -> None:
        source = evidence("restricted", eligibility=Eligibility.RESEARCH_ONLY)
        acquired = acquisition(source)
        archive = node(
            "restricted-archive",
            ArtifactType.DATASET,
            external_source=source,
            external_acquisition=acquired,
        )
        with self.assertRaisesRegex(ValueError, "launders"):
            graph(
                [
                    archive,
                    node("split-code", ArtifactType.CODE),
                    node("split-config", ArtifactType.CONFIG),
                    node(
                        "split",
                        ArtifactType.SPLIT_MANIFEST,
                        parents=(
                            "restricted-archive",
                            "split-code",
                            "split-config",
                        ),
                        eligibility=Eligibility.RESEARCH_ONLY,
                    ),
                    node(
                        "train",
                        ArtifactType.DATA_PARTITION,
                        parents=("split",),
                        partition=DataPartition.TRAIN,
                        role="train",
                        eligibility=Eligibility.RESEARCH_ONLY,
                    ),
                    node("code", ArtifactType.CODE),
                    node("config", ArtifactType.CONFIG),
                    node(
                        "checkpoint",
                        ArtifactType.MODEL_CHECKPOINT,
                        parents=("train", "code", "config"),
                    ),
                ],
                (source,),
                (acquired,),
            )

        test_source = evidence("test")
        test_acquired = acquisition(test_source)
        with self.assertRaisesRegex(ValueError, "sealed test"):
            graph(
                [
                    node(
                        "test-archive",
                        ArtifactType.DATASET,
                        external_source=test_source,
                        external_acquisition=test_acquired,
                    ),
                    node("test-split-code", ArtifactType.CODE),
                    node("test-split-config", ArtifactType.CONFIG),
                    node(
                        "test-split",
                        ArtifactType.SPLIT_MANIFEST,
                        parents=(
                            "test-archive",
                            "test-split-code",
                            "test-split-config",
                        ),
                    ),
                    node(
                        "test",
                        ArtifactType.DATA_PARTITION,
                        parents=("test-split",),
                        partition=DataPartition.TEST,
                        role="test",
                    ),
                    node("code", ArtifactType.CODE),
                    node("config", ArtifactType.CONFIG),
                    node(
                        "vocabulary",
                        ArtifactType.VOCABULARY,
                        parents=("test", "code", "config"),
                    ),
                ],
                (test_source,),
                (test_acquired,),
            )

    def test_canonical_schema_rejects_duplicate_keys_and_noncanonical_bytes(self) -> None:
        code = node("code", ArtifactType.CODE)
        value = graph([code])
        with tempfile.TemporaryDirectory() as directory:
            canonical = Path(directory) / "canonical.json"
            canonical.write_bytes(value.canonical_bytes())
            parsed = LineageGraph.from_json_file(canonical)
            self.assertEqual(parsed.nodes, value.nodes)

            noncanonical = Path(directory) / "noncanonical.json"
            noncanonical.write_text(json.dumps(value.to_dict()), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "not canonical"):
                LineageGraph.from_json_file(noncanonical)

            duplicate = Path(directory) / "duplicate.json"
            duplicate.write_text('{"schema_version":2,"schema_version":2,"nodes":[]}')
            with self.assertRaisesRegex(ValueError, "duplicate JSON key"):
                LineageGraph.from_json_file(duplicate)

    def test_parent_order_has_one_canonical_graph_commitment(self) -> None:
        first = graph(
            [
                node("a", ArtifactType.CODE),
                node("b", ArtifactType.CONFIG),
                node(
                    "derived",
                    ArtifactType.MODEL_CONTRACT,
                    parents=("b", "a"),
                ),
            ]
        )
        second = graph(
            [
                node("a", ArtifactType.CODE),
                node("b", ArtifactType.CONFIG),
                node(
                    "derived",
                    ArtifactType.MODEL_CONTRACT,
                    parents=("a", "b"),
                ),
            ]
        )

        self.assertEqual(first.canonical_bytes(), second.canonical_bytes())

    def test_rejects_cycles_and_unknown_parents(self) -> None:
        with self.assertRaisesRegex(ValueError, "unknown parents"):
            graph([node("model", ArtifactType.CODE, parents=("missing",))])
        with self.assertRaisesRegex(ValueError, "cycle"):
            graph(
                [
                    node("a", ArtifactType.CODE, parents=("b",)),
                    node("b", ArtifactType.CODE, parents=("a",)),
                ]
            )


if __name__ == "__main__":
    unittest.main()
