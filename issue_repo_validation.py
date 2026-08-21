#!/usr/bin/env python3
"""Validacao de repositorio GitLab e deteccao de duplicatas cross-repo."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from issue_keys import get_gitlab_repo, normalize_repo, repo_display_name


class MissingGitlabRepoError(ValueError):
    """Issue sem gitlab_repo / repositorio definido."""


def require_gitlab_repo(issue: dict) -> str:
    """Exige gitlab_repo explicito; nao aplica default contratos_v2."""
    repo = (issue.get("gitlab_repo") or issue.get("repositorio") or "").strip()
    if not repo:
        raise MissingGitlabRepoError(
            f"Issue IID {issue.get('id', '?')} sem gitlab_repo; sync ignorado para evitar atribuicao incorreta"
        )
    return repo


@dataclass
class IssueSourceIndex:
    """Indice das issues de origem (JSON/API) por repo e IID."""

    by_repo_iid: dict[tuple[str, int], str] = field(default_factory=dict)
    repos_by_iid: dict[int, set[str]] = field(default_factory=dict)

    @classmethod
    def from_issues(cls, issues: list[dict[str, Any]]) -> IssueSourceIndex:
        index = cls()
        for issue in issues:
            iid_raw = str(issue.get("id", "")).strip()
            if not iid_raw:
                continue
            try:
                iid = int(iid_raw)
            except ValueError:
                continue
            try:
                repo_slug = normalize_repo(require_gitlab_repo(issue))
            except MissingGitlabRepoError:
                continue
            title = (issue.get("title") or "").strip()
            index.by_repo_iid[(repo_slug, iid)] = title
            index.repos_by_iid.setdefault(iid, set()).add(repo_slug)
        return index

    def has_issue(self, repo_slug: str, iid: int) -> bool:
        return (normalize_repo(repo_slug), iid) in self.by_repo_iid

    def title_for(self, repo_slug: str, iid: int) -> str:
        return self.by_repo_iid.get((normalize_repo(repo_slug), iid), "")

    def repos_for_iid(self, iid: int) -> set[str]:
        return set(self.repos_by_iid.get(iid, set()))

    def sole_repo_for(self, iid: int, title: str) -> str | None:
        """Repo unico na fonte para IID+titulo; None se ambiguo ou ausente."""
        title = (title or "").strip()
        matches = [
            repo
            for repo in self.repos_for_iid(iid)
            if self.title_for(repo, iid) == title
        ]
        if len(matches) == 1:
            return matches[0]
        return None


def validate_record_against_source(
    record: dict[str, Any],
    source: IssueSourceIndex,
) -> str | None:
    """Retorna mensagem de erro se o registro nao bate com a fonte; None se ok."""
    iid = record.get("gitlab_iid")
    if iid is None:
        return "gitlab_iid ausente"
    try:
        iid_int = int(iid)
    except (TypeError, ValueError):
        return f"gitlab_iid invalido: {iid!r}"

    repo_label = (record.get("gitlab_repo") or "").strip()
    repo_slug = normalize_repo(repo_label)
    title = (record.get("titulo") or "").strip()

    if not source.has_issue(repo_slug, iid_int):
        return f"IID {iid_int} nao existe em {repo_label} na fonte GitLab"

    source_title = source.title_for(repo_slug, iid_int)
    if title and source_title and title != source_title:
        return (
            f"IID {iid_int} em {repo_label}: titulo diverge da fonte "
            f"({title[:40]!r} vs {source_title[:40]!r})"
        )
    return None


def filter_records_by_source(
    records: list[dict[str, Any]],
    source: IssueSourceIndex,
) -> tuple[list[dict[str, Any]], list[str]]:
    """Remove registros com repo/titulo inconsistentes com a fonte."""
    kept: list[dict[str, Any]] = []
    skipped: list[str] = []
    for record in records:
        err = validate_record_against_source(record, source)
        if err:
            skipped.append(f"{record.get('issue_key')}: {err}")
            continue
        kept.append(record)
    return kept, skipped


def reject_cross_repo_title_conflicts(
    records: list[dict[str, Any]],
    source: IssueSourceIndex,
) -> tuple[list[dict[str, Any]], list[str]]:
    """Bloqueia insert/upsert se IID+titulo na fonte pertence a outro repo."""
    kept: list[dict[str, Any]] = []
    rejected: list[str] = []
    for record in records:
        iid = int(record["gitlab_iid"])
        title = (record.get("titulo") or "").strip()
        repo_slug = normalize_repo(record.get("gitlab_repo") or "")
        canonical = source.sole_repo_for(iid, title)
        if canonical is None:
            kept.append(record)
            continue
        if normalize_repo(canonical) != repo_slug:
            rejected.append(
                f"{record.get('issue_key')}: IID {iid} com titulo duplicado pertence a "
                f"{repo_display_name(canonical)}, nao a {record.get('gitlab_repo')}"
            )
            continue
        kept.append(record)
    return kept, rejected


def find_phantom_issue_keys(
    db_rows: list[dict[str, Any]],
    source: IssueSourceIndex,
) -> list[str]:
    """Chaves com mesmo IID+titulo em repos diferentes onde a fonte confirma um unico repo."""
    by_iid: dict[int, list[dict[str, Any]]] = {}
    for row in db_rows:
        iid = row.get("gitlab_iid")
        if iid is None:
            continue
        by_iid.setdefault(int(iid), []).append(row)

    phantoms: list[str] = []
    for iid, group in by_iid.items():
        titles = {(r.get("titulo") or "").strip() for r in group if (r.get("titulo") or "").strip()}
        for title in titles:
            canonical = source.sole_repo_for(iid, title)
            if canonical is None:
                continue
            canonical_label = repo_display_name(canonical)
            same_title = [r for r in group if (r.get("titulo") or "").strip() == title]
            if len(same_title) < 2:
                continue
            for row in same_title:
                repo_label = (row.get("gitlab_repo") or "").strip()
                key = (row.get("issue_key") or "").strip()
                if repo_label != canonical_label and key:
                    phantoms.append(key)
    return sorted(set(phantoms))
