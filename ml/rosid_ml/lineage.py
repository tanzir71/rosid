"""Evidence-bound, type-complete artifact-lineage validation."""

from __future__ import annotations

import json
import re
from collections import defaultdict
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Iterable

from ml.rosid_ml.provenance import (
    AcquisitionRecord,
    Eligibility,
    SourceEvidence,
    canonical_json_bytes,
    eligibility_restrictiveness,
)


_SHA256 = re.compile(r"[0-9a-f]{64}\Z")


class ArtifactType(StrEnum):
    DATASET = "dataset"
    SPLIT_MANIFEST = "split_manifest"
    DATA_PARTITION = "data_partition"
    FONT = "font"
    TEXTURE = "texture"
    TEXT_CORPUS = "text_corpus"
    CODE = "code"
    CONFIG = "config"
    PRETRAINED_WEIGHTS = "pretrained_weights"
    GENERATOR_CHECKPOINT = "generator_checkpoint"
    GENERATED_CORPUS = "generated_corpus"
    MODEL_CHECKPOINT = "model_checkpoint"
    VOCABULARY = "vocabulary"
    MODEL_CONTRACT = "model_contract"
    REPRESENTATIVE_SET = "representative_set"
    CONVERSION_EXPORT = "conversion_export"
    MOBILE_MODEL = "mobile_model"
    EVALUATION_SET = "evaluation_set"
    PREDICTIONS = "predictions"
    METRICS = "metrics"


class DataPartition(StrEnum):
    NONE = "none"
    TRAIN = "train"
    VALIDATION = "validation"
    TEST = "test"


class SynthesisTier(StrEnum):
    NONE = "none"
    TIER_1 = "tier_1"
    TIER_2 = "tier_2"
    TIER_3 = "tier_3"


_EXTERNAL_TYPES = {
    ArtifactType.DATASET,
    ArtifactType.FONT,
    ArtifactType.TEXTURE,
    ArtifactType.TEXT_CORPUS,
    ArtifactType.PRETRAINED_WEIGHTS,
}


@dataclass(frozen=True)
class LineageNode:
    artifact_id: str
    artifact_type: ArtifactType
    sha256: str
    eligibility: Eligibility
    partition: DataPartition
    source: str
    version: str
    license_id: str
    role: str
    transformation: str
    source_evidence_sha256: str | None = None
    acquisition_sha256: str | None = None
    synthesis_tier: SynthesisTier = SynthesisTier.NONE
    parents: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        if not self.artifact_id or any(
            character.isspace() for character in self.artifact_id
        ):
            raise ValueError("artifact ID must be nonempty and contain no whitespace")
        if not _SHA256.fullmatch(self.sha256):
            raise ValueError("artifact SHA-256 must be 64 lowercase hex digits")
        for value, label in (
            (self.source, "source"),
            (self.version, "version"),
            (self.license_id, "license"),
            (self.role, "role"),
            (self.transformation, "transformation"),
        ):
            if not value.strip():
                raise ValueError(f"artifact {label} must be nonempty")
        for value, label in (
            (self.source_evidence_sha256, "source-evidence SHA-256"),
            (self.acquisition_sha256, "acquisition SHA-256"),
        ):
            if value is not None and not _SHA256.fullmatch(value):
                raise ValueError(f"artifact {label} must be 64 lowercase hex digits")
        if len(self.parents) != len(set(self.parents)):
            raise ValueError(f"artifact has duplicate parents: {self.artifact_id}")
        object.__setattr__(self, "parents", tuple(sorted(self.parents)))
        if self.artifact_type == ArtifactType.GENERATED_CORPUS:
            if self.synthesis_tier == SynthesisTier.NONE:
                raise ValueError("generated corpus must declare a synthesis tier")
        elif self.synthesis_tier != SynthesisTier.NONE:
            raise ValueError("only generated corpora may declare a synthesis tier")

    def to_dict(self) -> dict[str, object]:
        return {
            "acquisition_sha256": self.acquisition_sha256,
            "artifact_id": self.artifact_id,
            "artifact_type": self.artifact_type.value,
            "eligibility": self.eligibility.value,
            "license_id": self.license_id,
            "parents": list(self.parents),
            "partition": self.partition.value,
            "role": self.role,
            "sha256": self.sha256,
            "source": self.source,
            "source_evidence_sha256": self.source_evidence_sha256,
            "synthesis_tier": self.synthesis_tier.value,
            "transformation": self.transformation,
            "version": self.version,
        }

    @classmethod
    def from_dict(cls, value: dict[str, object]) -> LineageNode:
        expected = {
            "acquisition_sha256",
            "artifact_id",
            "artifact_type",
            "eligibility",
            "license_id",
            "parents",
            "partition",
            "role",
            "sha256",
            "source",
            "source_evidence_sha256",
            "synthesis_tier",
            "transformation",
            "version",
        }
        if set(value) != expected:
            raise ValueError("lineage node keys differ from schema")
        string_fields = (
            "artifact_id",
            "artifact_type",
            "eligibility",
            "license_id",
            "partition",
            "role",
            "sha256",
            "source",
            "synthesis_tier",
            "transformation",
            "version",
        )
        if any(type(value[field]) is not str for field in string_fields):
            raise ValueError("lineage node scalar fields must be strings")
        for field in ("source_evidence_sha256", "acquisition_sha256"):
            if value[field] is not None and type(value[field]) is not str:
                raise ValueError(f"lineage node {field} must be a string or null")
        parents = value["parents"]
        if not isinstance(parents, list) or any(
            type(parent) is not str for parent in parents
        ):
            raise ValueError("lineage node parents must be a string array")
        return cls(
            artifact_id=value["artifact_id"],
            artifact_type=ArtifactType(value["artifact_type"]),
            sha256=value["sha256"],
            eligibility=Eligibility(value["eligibility"]),
            partition=DataPartition(value["partition"]),
            source=value["source"],
            version=value["version"],
            license_id=value["license_id"],
            role=value["role"],
            transformation=value["transformation"],
            source_evidence_sha256=value["source_evidence_sha256"],
            acquisition_sha256=value["acquisition_sha256"],
            synthesis_tier=SynthesisTier(value["synthesis_tier"]),
            parents=tuple(parents),
        )


class LineageGraph:
    def __init__(
        self,
        nodes: Iterable[LineageNode],
        *,
        source_evidence: Iterable[SourceEvidence] = (),
        acquisitions: Iterable[AcquisitionRecord] = (),
    ) -> None:
        materialized = list(nodes)
        self._nodes = {node.artifact_id: node for node in materialized}
        if len(self._nodes) != len(materialized):
            raise ValueError("lineage artifact IDs must be unique")
        evidence_values = list(source_evidence)
        self._source_evidence = {
            value.commitment_sha256: value for value in evidence_values
        }
        if len(self._source_evidence) != len(evidence_values):
            raise ValueError("source-evidence commitments must be unique")
        acquisition_values = list(acquisitions)
        self._acquisitions = {
            value.commitment_sha256: value for value in acquisition_values
        }
        if len(self._acquisitions) != len(acquisition_values):
            raise ValueError("acquisition commitments must be unique")
        self._validate_references_and_cycles()
        self._validate_external_evidence()
        self._validate_test_isolation()
        self._validate_transitive_eligibility()
        self._validate_type_completeness()

    @property
    def nodes(self) -> tuple[LineageNode, ...]:
        return tuple(self._nodes[key] for key in sorted(self._nodes))

    def ancestors(self, artifact_id: str) -> set[str]:
        if artifact_id not in self._nodes:
            raise ValueError(f"unknown artifact: {artifact_id}")
        result: set[str] = set()
        pending = list(self._nodes[artifact_id].parents)
        while pending:
            parent = pending.pop()
            if parent in result:
                continue
            result.add(parent)
            pending.extend(self._nodes[parent].parents)
        return result

    def assert_production_eligible(self, artifact_id: str) -> None:
        if artifact_id not in self._nodes:
            raise ValueError(f"unknown artifact: {artifact_id}")
        lineage = {artifact_id, *self.ancestors(artifact_id)}
        blocked = sorted(
            key
            for key in lineage
            if self._nodes[key].eligibility != Eligibility.PRODUCTION
        )
        if blocked:
            raise ValueError(
                f"artifact {artifact_id} has non-production lineage: {blocked}"
            )

    def assert_final_metrics(self, artifact_id: str) -> None:
        if artifact_id not in self._nodes:
            raise ValueError(f"unknown artifact: {artifact_id}")
        node = self._nodes[artifact_id]
        if node.artifact_type != ArtifactType.METRICS or node.role != "final":
            raise ValueError("release evidence must be a final metrics artifact")
        self.assert_production_eligible(artifact_id)

    def to_dict(self) -> dict[str, object]:
        return {
            "nodes": [node.to_dict() for node in self.nodes],
            "schema_version": 2,
        }

    def canonical_bytes(self) -> bytes:
        return canonical_json_bytes(self.to_dict())

    @classmethod
    def from_dict(
        cls,
        value: dict[str, object],
        *,
        source_evidence: Iterable[SourceEvidence] = (),
        acquisitions: Iterable[AcquisitionRecord] = (),
    ) -> LineageGraph:
        if set(value) != {"schema_version", "nodes"}:
            raise ValueError("lineage graph keys differ from schema")
        if type(value["schema_version"]) is not int or value["schema_version"] != 2:
            raise ValueError("unsupported lineage schema version")
        nodes = value["nodes"]
        if not isinstance(nodes, list) or any(
            not isinstance(node, dict) for node in nodes
        ):
            raise ValueError("lineage nodes must be an object array")
        return cls(
            (LineageNode.from_dict(node) for node in nodes),
            source_evidence=source_evidence,
            acquisitions=acquisitions,
        )

    @classmethod
    def from_json_file(
        cls,
        path: Path,
        *,
        source_evidence: Iterable[SourceEvidence] = (),
        acquisitions: Iterable[AcquisitionRecord] = (),
    ) -> LineageGraph:
        def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
            result: dict[str, object] = {}
            for key, value in pairs:
                if key in result:
                    raise ValueError(f"duplicate JSON key: {key}")
                result[key] = value
            return result

        try:
            raw = path.read_bytes()
            value = json.loads(
                raw.decode("utf-8"),
                object_pairs_hook=unique_object,
            )
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            raise ValueError(f"cannot read lineage manifest {path}: {error}") from error
        if not isinstance(value, dict):
            raise ValueError("lineage manifest root must be an object")
        graph = cls.from_dict(
            value,
            source_evidence=source_evidence,
            acquisitions=acquisitions,
        )
        if raw != graph.canonical_bytes():
            raise ValueError("lineage manifest is not canonical UTF-8/LF JSON")
        return graph

    def _validate_references_and_cycles(self) -> None:
        for node in self._nodes.values():
            unknown = sorted(set(node.parents) - set(self._nodes))
            if unknown:
                raise ValueError(
                    f"artifact {node.artifact_id} has unknown parents: {unknown}"
                )

        state: dict[str, int] = defaultdict(int)

        def visit(artifact_id: str) -> None:
            if state[artifact_id] == 1:
                raise ValueError(f"lineage contains a cycle at {artifact_id}")
            if state[artifact_id] == 2:
                return
            state[artifact_id] = 1
            for parent in self._nodes[artifact_id].parents:
                visit(parent)
            state[artifact_id] = 2

        for artifact_id in sorted(self._nodes):
            visit(artifact_id)

    def _validate_external_evidence(self) -> None:
        for node in self._nodes.values():
            is_external = node.artifact_type in _EXTERNAL_TYPES
            if not is_external:
                if (
                    node.source_evidence_sha256 is not None
                    or node.acquisition_sha256 is not None
                ):
                    raise ValueError(
                        f"derived artifact {node.artifact_id} cannot claim source "
                        "or acquisition evidence"
                    )
                continue
            if (
                node.source_evidence_sha256 is None
                or node.acquisition_sha256 is None
            ):
                raise ValueError(
                    f"external artifact {node.artifact_id} lacks reviewed "
                    "source/acquisition evidence"
                )
            source = self._source_evidence.get(node.source_evidence_sha256)
            acquisition = self._acquisitions.get(node.acquisition_sha256)
            if source is None or acquisition is None:
                raise ValueError(
                    f"external artifact {node.artifact_id} references unknown evidence"
                )
            acquisition.validate_source(source)
            mismatches = []
            if node.sha256 != acquisition.artifact_sha256:
                mismatches.append("content")
            if node.artifact_type.value != source.artifact_type:
                mismatches.append("artifact type")
            if node.role != source.artifact_role:
                mismatches.append("artifact role")
            if node.source != source.source_url:
                mismatches.append("source")
            if node.version != source.version:
                mismatches.append("version")
            if node.license_id != source.license_id:
                mismatches.append("license")
            if node.eligibility != acquisition.eligibility:
                mismatches.append("eligibility")
            if mismatches:
                raise ValueError(
                    f"external artifact {node.artifact_id} contradicts evidence: "
                    f"{mismatches}"
                )

    def _validate_test_isolation(self) -> None:
        for node in self._nodes.values():
            if node.artifact_type in {
                ArtifactType.EVALUATION_SET,
                ArtifactType.PREDICTIONS,
                ArtifactType.METRICS,
            }:
                continue
            test_ancestors = sorted(
                parent
                for parent in self.ancestors(node.artifact_id)
                if self._nodes[parent].partition == DataPartition.TEST
            )
            if test_ancestors:
                raise ValueError(
                    f"non-metric artifact {node.artifact_id} depends on sealed test "
                    f"artifacts: {test_ancestors}"
                )

    def _validate_transitive_eligibility(self) -> None:
        for node in self._nodes.values():
            ancestors = self.ancestors(node.artifact_id)
            if not ancestors:
                continue
            required_restrictiveness = max(
                eligibility_restrictiveness(self._nodes[parent].eligibility)
                for parent in ancestors
            )
            if eligibility_restrictiveness(node.eligibility) < required_restrictiveness:
                blocked = sorted(
                    parent
                    for parent in ancestors
                    if eligibility_restrictiveness(self._nodes[parent].eligibility)
                    > eligibility_restrictiveness(node.eligibility)
                )
                raise ValueError(
                    f"artifact {node.artifact_id} launders less-eligible ancestors: "
                    f"{blocked}"
                )

    def _validate_type_completeness(self) -> None:
        for node in self._nodes.values():
            self._validate_node_type(node)

    def _validate_node_type(self, node: LineageNode) -> None:
        direct_nodes = [self._nodes[value] for value in node.parents]
        direct_types = {value.artifact_type for value in direct_nodes}

        def require_direct(required: set[ArtifactType], label: str) -> None:
            missing = sorted(value.value for value in required - direct_types)
            if missing:
                raise ValueError(
                    f"{label} {node.artifact_id} has incomplete direct lineage; "
                    f"missing={missing}"
                )

        def require_direct_partition_data(
            partition: DataPartition,
            label: str,
        ) -> None:
            partition_inputs = [
                value
                for value in direct_nodes
                if value.artifact_type
                in {ArtifactType.DATA_PARTITION, ArtifactType.GENERATED_CORPUS}
            ]
            if not any(
                value.artifact_type
                in {ArtifactType.DATA_PARTITION, ArtifactType.GENERATED_CORPUS}
                and value.partition == partition
                for value in partition_inputs
            ):
                raise ValueError(
                    f"{label} {node.artifact_id} lacks direct "
                    f"{partition.value} data"
                )
            mismatched = sorted(
                value.artifact_id
                for value in partition_inputs
                if value.partition != partition
            )
            if mismatched:
                raise ValueError(
                    f"{label} {node.artifact_id} includes non-{partition.value} "
                    f"data: {mismatched}"
                )

        def require_train_only_lineage(label: str) -> None:
            non_train = sorted(
                artifact_id
                for artifact_id in self.ancestors(node.artifact_id)
                if self._nodes[artifact_id].partition
                not in {DataPartition.NONE, DataPartition.TRAIN}
            )
            if non_train:
                raise ValueError(
                    f"{label} {node.artifact_id} has non-training partition "
                    f"ancestors: {non_train}"
                )

        def require_direct_real_train_data(label: str) -> None:
            if not any(
                value.artifact_type == ArtifactType.DATA_PARTITION
                and value.partition == DataPartition.TRAIN
                for value in direct_nodes
            ):
                raise ValueError(
                    f"{label} {node.artifact_id} lacks direct real training data"
                )
        if node.artifact_type in _EXTERNAL_TYPES:
            if direct_nodes:
                raise ValueError("external artifacts cannot have lineage parents")
            if node.artifact_type == ArtifactType.DATASET:
                if node.partition != DataPartition.NONE:
                    raise ValueError(
                        "external dataset is a source archive, not a split partition"
                    )
            return
        if node.artifact_type in {ArtifactType.CODE, ArtifactType.CONFIG}:
            if node.partition != DataPartition.NONE or direct_nodes:
                raise ValueError("code/config artifacts must be standalone and unpartitioned")
            return
        if node.artifact_type == ArtifactType.SPLIT_MANIFEST:
            if node.partition != DataPartition.NONE:
                raise ValueError("split manifest cannot claim one data partition")
            require_direct(
                {ArtifactType.DATASET, ArtifactType.CODE, ArtifactType.CONFIG},
                "split manifest",
            )
            unexpected = sorted(
                value.artifact_id
                for value in direct_nodes
                if value.artifact_type
                not in {ArtifactType.DATASET, ArtifactType.CODE, ArtifactType.CONFIG}
            )
            if unexpected:
                raise ValueError(
                    f"split manifest has invalid direct inputs: {unexpected}"
                )
            return
        if node.artifact_type == ArtifactType.DATA_PARTITION:
            if node.partition not in {
                DataPartition.TRAIN,
                DataPartition.VALIDATION,
                DataPartition.TEST,
            }:
                raise ValueError("data partition must be train, validation, or test")
            if node.role != node.partition.value:
                raise ValueError("data-partition role must match its partition")
            require_direct({ArtifactType.SPLIT_MANIFEST}, "data partition")
            if (
                len(direct_nodes) != 1
                or direct_nodes[0].artifact_type != ArtifactType.SPLIT_MANIFEST
            ):
                raise ValueError(
                    "data partition must bind only one split manifest"
                )
            return
        if node.artifact_type == ArtifactType.GENERATOR_CHECKPOINT:
            require_direct(
                {ArtifactType.CODE, ArtifactType.CONFIG},
                "generator checkpoint",
            )
            require_direct_partition_data(DataPartition.TRAIN, "generator checkpoint")
            require_direct_real_train_data("generator checkpoint")
            return
        if node.artifact_type == ArtifactType.GENERATED_CORPUS:
            if node.partition not in {DataPartition.TRAIN, DataPartition.VALIDATION}:
                raise ValueError("generated corpus must be train or validation data")
            require_direct(
                {ArtifactType.CODE, ArtifactType.CONFIG, ArtifactType.TEXT_CORPUS},
                "generated corpus",
            )
            if node.synthesis_tier == SynthesisTier.TIER_1:
                require_direct(
                    {ArtifactType.FONT, ArtifactType.TEXTURE},
                    "Tier-1 corpus",
                )
                allowed_direct = {
                    ArtifactType.CODE,
                    ArtifactType.CONFIG,
                    ArtifactType.TEXT_CORPUS,
                    ArtifactType.FONT,
                    ArtifactType.TEXTURE,
                }
            elif node.synthesis_tier == SynthesisTier.TIER_2:
                style_types = {
                    ArtifactType.DATA_PARTITION,
                    ArtifactType.FONT,
                    ArtifactType.PRETRAINED_WEIGHTS,
                }
                if not direct_types & style_types:
                    raise ValueError(
                        f"Tier-2 corpus {node.artifact_id} lacks a style source"
                    )
                invalid_style_partitions = sorted(
                    value.artifact_id
                    for value in direct_nodes
                    if value.artifact_type == ArtifactType.DATA_PARTITION
                    and value.partition != DataPartition.TRAIN
                )
                if invalid_style_partitions:
                    raise ValueError(
                        f"Tier-2 corpus {node.artifact_id} uses non-training "
                        f"style data: {invalid_style_partitions}"
                    )
                allowed_direct = {
                    ArtifactType.CODE,
                    ArtifactType.CONFIG,
                    ArtifactType.TEXT_CORPUS,
                    ArtifactType.DATA_PARTITION,
                    ArtifactType.FONT,
                    ArtifactType.TEXTURE,
                    ArtifactType.PRETRAINED_WEIGHTS,
                }
            else:
                require_direct(
                    {ArtifactType.GENERATOR_CHECKPOINT},
                    "Tier-3 corpus",
                )
                allowed_direct = {
                    ArtifactType.CODE,
                    ArtifactType.CONFIG,
                    ArtifactType.TEXT_CORPUS,
                    ArtifactType.GENERATOR_CHECKPOINT,
                }
            unexpected = sorted(
                value.artifact_id
                for value in direct_nodes
                if value.artifact_type not in allowed_direct
            )
            if unexpected:
                raise ValueError(
                    f"generated corpus {node.artifact_id} has invalid direct "
                    f"inputs: {unexpected}"
                )
            return
        if node.artifact_type == ArtifactType.MODEL_CHECKPOINT:
            require_direct(
                {ArtifactType.CODE, ArtifactType.CONFIG},
                "model checkpoint",
            )
            require_direct_partition_data(DataPartition.TRAIN, "model checkpoint")
            require_direct_real_train_data("model checkpoint")
            return
        if node.artifact_type == ArtifactType.VOCABULARY:
            require_direct(
                {ArtifactType.CODE, ArtifactType.CONFIG},
                "vocabulary",
            )
            require_direct_partition_data(DataPartition.TRAIN, "vocabulary")
            require_direct_real_train_data("vocabulary")
            require_train_only_lineage("vocabulary")
            unexpected = sorted(
                value.artifact_id
                for value in direct_nodes
                if value.artifact_type
                not in {
                    ArtifactType.DATA_PARTITION,
                    ArtifactType.GENERATED_CORPUS,
                    ArtifactType.CODE,
                    ArtifactType.CONFIG,
                }
            )
            if unexpected:
                raise ValueError(
                    f"vocabulary {node.artifact_id} has invalid direct inputs: "
                    f"{unexpected}"
                )
            return
        if node.artifact_type == ArtifactType.MODEL_CONTRACT:
            require_direct(
                {ArtifactType.CODE, ArtifactType.CONFIG},
                "model contract",
            )
            if direct_types - {ArtifactType.CODE, ArtifactType.CONFIG}:
                raise ValueError("model contract has invalid direct inputs")
            return
        if node.artifact_type == ArtifactType.REPRESENTATIVE_SET:
            if node.partition != DataPartition.TRAIN:
                raise ValueError("representative set must use the training partition")
            require_direct(
                {ArtifactType.CODE, ArtifactType.CONFIG},
                "representative set",
            )
            require_direct_partition_data(DataPartition.TRAIN, "representative set")
            require_direct_real_train_data("representative set")
            require_train_only_lineage("representative set")
            unexpected = sorted(
                value.artifact_id
                for value in direct_nodes
                if value.artifact_type
                not in {
                    ArtifactType.DATA_PARTITION,
                    ArtifactType.GENERATED_CORPUS,
                    ArtifactType.CODE,
                    ArtifactType.CONFIG,
                }
            )
            if unexpected:
                raise ValueError(
                    f"representative set {node.artifact_id} has invalid direct "
                    f"inputs: {unexpected}"
                )
            return
        if node.artifact_type == ArtifactType.CONVERSION_EXPORT:
            if node.role not in {"float32", "float16", "int8"}:
                raise ValueError("conversion export role must name its quantization")
            require_direct(
                {ArtifactType.MODEL_CHECKPOINT, ArtifactType.CODE, ArtifactType.CONFIG},
                "conversion export",
            )
            if sum(
                value.artifact_type == ArtifactType.MODEL_CHECKPOINT
                for value in direct_nodes
            ) != 1:
                raise ValueError(
                    "conversion export must bind exactly one model checkpoint"
                )
            representative_count = sum(
                value.artifact_type == ArtifactType.REPRESENTATIVE_SET
                for value in direct_nodes
            )
            if node.role == "int8":
                require_direct(
                    {ArtifactType.REPRESENTATIVE_SET},
                    "int8 conversion export",
                )
                if representative_count != 1:
                    raise ValueError(
                        "int8 conversion export must bind exactly one "
                        "representative set"
                    )
            elif representative_count:
                raise ValueError(
                    "non-int8 conversion export cannot bind a representative set"
                )
            return
        if node.artifact_type == ArtifactType.MOBILE_MODEL:
            if node.role not in {"float32", "float16", "int8"}:
                raise ValueError("mobile model role must name its quantization")
            require_direct(
                {
                    ArtifactType.CONVERSION_EXPORT,
                    ArtifactType.VOCABULARY,
                    ArtifactType.MODEL_CONTRACT,
                },
                "mobile model",
            )
            exports = [
                value
                for value in direct_nodes
                if value.artifact_type == ArtifactType.CONVERSION_EXPORT
            ]
            if len(exports) != 1 or exports[0].role != node.role:
                raise ValueError("mobile model must bind one matching conversion export")
            if exports[0].sha256 != node.sha256:
                raise ValueError("mobile model bytes differ from conversion export")
            for artifact_type, label in (
                (ArtifactType.VOCABULARY, "vocabulary"),
                (ArtifactType.MODEL_CONTRACT, "model contract"),
            ):
                if sum(
                    value.artifact_type == artifact_type for value in direct_nodes
                ) != 1:
                    raise ValueError(f"mobile model must bind exactly one {label}")
            return
        if node.artifact_type == ArtifactType.EVALUATION_SET:
            if node.partition not in {DataPartition.VALIDATION, DataPartition.TEST}:
                raise ValueError("evaluation set must be validation or test data")
            source_data = [
                value
                for value in direct_nodes
                if value.artifact_type
                in {ArtifactType.DATA_PARTITION, ArtifactType.GENERATED_CORPUS}
            ]
            if not source_data:
                raise ValueError(
                    f"evaluation set {node.artifact_id} lacks direct source data"
                )
            require_direct(
                {ArtifactType.CODE, ArtifactType.CONFIG},
                "evaluation set",
            )
            allowed_direct = {
                ArtifactType.DATA_PARTITION,
                ArtifactType.GENERATED_CORPUS,
                ArtifactType.CODE,
                ArtifactType.CONFIG,
            }
            unexpected = sorted(
                value.artifact_id
                for value in direct_nodes
                if value.artifact_type not in allowed_direct
            )
            if unexpected:
                raise ValueError(
                    f"evaluation set {node.artifact_id} has invalid direct inputs: "
                    f"{unexpected}"
                )
            mismatched = sorted(
                value.artifact_id
                for value in source_data
                if value.partition != node.partition
            )
            if mismatched:
                raise ValueError(
                    f"evaluation set {node.artifact_id} has source data outside "
                    f"its {node.partition.value} partition: {mismatched}"
                )
            if node.partition == DataPartition.TEST and any(
                value.artifact_type != ArtifactType.DATA_PARTITION
                for value in source_data
            ):
                raise ValueError("sealed test evaluation requires real partition data")
            return
        if node.artifact_type == ArtifactType.PREDICTIONS:
            if node.partition not in {DataPartition.VALIDATION, DataPartition.TEST}:
                raise ValueError("predictions must be validation or test data")
            require_direct(
                {ArtifactType.EVALUATION_SET, ArtifactType.CODE, ArtifactType.CONFIG},
                "predictions",
            )
            evaluation_sets = [
                value
                for value in direct_nodes
                if value.artifact_type == ArtifactType.EVALUATION_SET
            ]
            if len(evaluation_sets) != 1 or evaluation_sets[0].partition != node.partition:
                raise ValueError("predictions must bind one matching evaluation set")
            if node.role == "raw_htr":
                require_direct({ArtifactType.MOBILE_MODEL}, "raw HTR predictions")
                if sum(
                    value.artifact_type == ArtifactType.MOBILE_MODEL
                    for value in direct_nodes
                ) != 1:
                    raise ValueError(
                        "raw HTR predictions must bind exactly one mobile model"
                    )
                allowed_direct = {
                    ArtifactType.EVALUATION_SET,
                    ArtifactType.CODE,
                    ArtifactType.CONFIG,
                    ArtifactType.MOBILE_MODEL,
                }
            elif node.role == "tesseract_baseline":
                traineddata = [
                    value
                    for value in direct_nodes
                    if value.artifact_type == ArtifactType.PRETRAINED_WEIGHTS
                ]
                traineddata_roles = [
                    value.role
                    for value in traineddata
                ]
                if len(traineddata) != 2 or sorted(traineddata_roles) != [
                    "tesseract-ben",
                    "tesseract-eng",
                ]:
                    raise ValueError(
                        "Tesseract baseline predictions must bind exactly one ben "
                        "and one eng traineddata artifact"
                    )
                allowed_direct = {
                    ArtifactType.EVALUATION_SET,
                    ArtifactType.CODE,
                    ArtifactType.CONFIG,
                    ArtifactType.PRETRAINED_WEIGHTS,
                }
            else:
                raise ValueError("prediction role must be raw_htr or tesseract_baseline")
            unexpected = sorted(
                value.artifact_id
                for value in direct_nodes
                if value.artifact_type not in allowed_direct
            )
            if unexpected:
                raise ValueError(
                    f"predictions {node.artifact_id} have invalid direct inputs: "
                    f"{unexpected}"
                )
            return
        if node.artifact_type == ArtifactType.METRICS:
            if node.role not in {"validation", "final"}:
                raise ValueError("metrics role must be validation or final")
            require_direct(
                {
                    ArtifactType.MOBILE_MODEL,
                    ArtifactType.EVALUATION_SET,
                    ArtifactType.PREDICTIONS,
                    ArtifactType.CODE,
                    ArtifactType.CONFIG,
                },
                "metrics",
            )
            unexpected = sorted(
                value.artifact_id
                for value in direct_nodes
                if value.artifact_type
                not in {
                    ArtifactType.MOBILE_MODEL,
                    ArtifactType.EVALUATION_SET,
                    ArtifactType.PREDICTIONS,
                    ArtifactType.CODE,
                    ArtifactType.CONFIG,
                }
            )
            if unexpected:
                raise ValueError(
                    f"metrics {node.artifact_id} have invalid direct inputs: "
                    f"{unexpected}"
                )
            evaluation_sets = [
                value
                for value in direct_nodes
                if value.artifact_type == ArtifactType.EVALUATION_SET
            ]
            if len(evaluation_sets) != 1:
                raise ValueError("metrics must bind exactly one evaluation set")
            evaluation = evaluation_sets[0]
            mobile_models = [
                value
                for value in direct_nodes
                if value.artifact_type == ArtifactType.MOBILE_MODEL
            ]
            if len(mobile_models) != 1:
                raise ValueError("metrics must bind exactly one mobile model")
            predictions = [
                value
                for value in direct_nodes
                if value.artifact_type == ArtifactType.PREDICTIONS
            ]
            if any(
                value.partition != evaluation.partition
                or evaluation.artifact_id not in value.parents
                for value in predictions
            ):
                raise ValueError(
                    "metrics predictions must bind the same evaluation partition"
                )
            if node.role == "final":
                if evaluation.partition != DataPartition.TEST:
                    raise ValueError("final metrics require a sealed test evaluation set")
                predictions_by_role = {
                    role: [value for value in predictions if value.role == role]
                    for role in ("raw_htr", "tesseract_baseline")
                }
                invalid_counts = {
                    role: len(values)
                    for role, values in predictions_by_role.items()
                    if len(values) != 1
                }
                if invalid_counts:
                    raise ValueError(
                        "final metrics require exactly one prediction stream per role: "
                        f"{invalid_counts}"
                    )
                raw_htr = predictions_by_role["raw_htr"][0]
                if mobile_models[0].artifact_id not in raw_htr.parents:
                    raise ValueError(
                        "final metrics mobile model differs from raw HTR predictions"
                    )
                partition_ancestors = [
                    self._nodes[artifact_id]
                    for artifact_id in self.ancestors(node.artifact_id)
                    if self._nodes[artifact_id].artifact_type
                    == ArtifactType.DATA_PARTITION
                ]
                split_manifests = {
                    value.parents[0] for value in partition_ancestors
                }
                if len(split_manifests) != 1:
                    raise ValueError(
                        "final metrics must bind one global writer-split manifest"
                    )
                partition_roles = {value.partition for value in partition_ancestors}
                if not {DataPartition.TRAIN, DataPartition.TEST}.issubset(
                    partition_roles
                ):
                    raise ValueError(
                        "final metrics require real train and sealed-test partitions"
                    )
            elif evaluation.partition != DataPartition.VALIDATION:
                raise ValueError("non-final metrics require a validation evaluation set")
            return
        raise AssertionError(f"unhandled artifact type: {node.artifact_type}")
