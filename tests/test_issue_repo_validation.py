"""Testes de validacao de repositorio e duplicatas cross-repo."""

from __future__ import annotations

from issue_repo_validation import (
    IssueSourceIndex,
    MissingGitlabRepoError,
    filter_records_by_source,
    find_phantom_issue_keys,
    reject_cross_repo_title_conflicts,
    require_gitlab_repo,
    validate_record_against_source,
)


def _source_issues():
    return [
        {"id": "10", "gitlab_repo": "contratos", "title": "Issue v1 only"},
        {"id": "20", "gitlab_repo": "contratos_v2", "title": "Issue v2 A"},
        {"id": "20", "gitlab_repo": "contratos", "title": "Issue v1 B"},
    ]


def test_require_gitlab_repo_exige_campo():
    try:
        require_gitlab_repo({"id": "1"})
        assert False, "deveria falhar"
    except MissingGitlabRepoError:
        pass


def test_validate_record_ok():
    source = IssueSourceIndex.from_issues(_source_issues())
    record = {
        "issue_key": "Contratos v1:10",
        "gitlab_repo": "Contratos v1",
        "gitlab_iid": 10,
        "titulo": "Issue v1 only",
    }
    assert validate_record_against_source(record, source) is None


def test_validate_record_repo_inexistente_na_fonte():
    source = IssueSourceIndex.from_issues(_source_issues())
    record = {
        "issue_key": "Contratos v2:10",
        "gitlab_repo": "Contratos v2",
        "gitlab_iid": 10,
        "titulo": "Issue v1 only",
    }
    assert validate_record_against_source(record, source) is not None


def test_reject_cross_repo_title_conflict():
    source = IssueSourceIndex.from_issues(_source_issues())
    records = [
        {
            "issue_key": "Contratos v2:10",
            "gitlab_repo": "Contratos v2",
            "gitlab_iid": 10,
            "titulo": "Issue v1 only",
        }
    ]
    kept, rejected = reject_cross_repo_title_conflicts(records, source)
    assert kept == []
    assert len(rejected) == 1


def test_legitimate_same_iid_different_titles_passes():
    source = IssueSourceIndex.from_issues(_source_issues())
    records = [
        {
            "issue_key": "Contratos v2:20",
            "gitlab_repo": "Contratos v2",
            "gitlab_iid": 20,
            "titulo": "Issue v2 A",
        },
        {
            "issue_key": "Contratos v1:20",
            "gitlab_repo": "Contratos v1",
            "gitlab_iid": 20,
            "titulo": "Issue v1 B",
        },
    ]
    kept, rejected = reject_cross_repo_title_conflicts(records, source)
    assert len(kept) == 2
    assert rejected == []


def test_find_phantom_issue_keys():
    source = IssueSourceIndex.from_issues(
        [{"id": "2671", "gitlab_repo": "contratos", "title": "Mesmo titulo"}]
    )
    db_rows = [
        {
            "issue_key": "Contratos v1:2671",
            "gitlab_repo": "Contratos v1",
            "gitlab_iid": 2671,
            "titulo": "Mesmo titulo",
        },
        {
            "issue_key": "Contratos v2:2671",
            "gitlab_repo": "Contratos v2",
            "gitlab_iid": 2671,
            "titulo": "Mesmo titulo",
        },
    ]
    assert find_phantom_issue_keys(db_rows, source) == ["Contratos v2:2671"]


def test_filter_records_by_source():
    source = IssueSourceIndex.from_issues(_source_issues())
    records = [
        {
            "issue_key": "Contratos v1:10",
            "gitlab_repo": "Contratos v1",
            "gitlab_iid": 10,
            "titulo": "Issue v1 only",
        },
        {
            "issue_key": "Contratos v2:10",
            "gitlab_repo": "Contratos v2",
            "gitlab_iid": 10,
            "titulo": "Issue v1 only",
        },
    ]
    kept, skipped = filter_records_by_source(records, source)
    assert len(kept) == 1
    assert kept[0]["issue_key"] == "Contratos v1:10"
    assert len(skipped) == 1
