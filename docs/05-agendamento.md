# Agendamento automatico (Windows Task Scheduler)

## Resumo

| Item | Valor |
|------|-------|
| Script agendado | `kpi-pipeline/executar_pipeline_silent.bat` |
| Horarios padrao | 08:10, 10:00, 12:00, 14:00, 16:00, 18:00 (diario) |
| Tarefa | `MGI-Pipeline-Supabase` |
| Logs | `logs/scheduled_YYYYMMDD_HHMMSS.log` e `logs/pipeline.log` |

O modo silencioso roda o fluxo incremental completo (atualizado com leitura de epicos via Parent):

1. **Sync incremental** de issues (`atualizar_gitlab_issues.py --incremental`)
   - Carrega `kpi-workspace/.env`
   - Usa `GITLAB_TOKEN` global para `contratos_v2` e `contratos`
   - Retry automatico em timeout da API GitLab
2. **Coleta Git + sync Supabase** (`pipeline_maestro.py`)
3. **Backfill de epicos** (`backfill_epicos_mergeadas.py --escopo filhas`)
   - Preenche `issues.epico` para todas as filhas de epicos do grupo no Supabase

Sem menu interativo, sem `--full`, sem pausa no final.

Pull condicional dos repos Git (ter/qui): `executar_pull_repos.bat` (tarefa `MGI-Pull-Repos-Main`).

## Configurar (uma vez)

1. Garanta `.env` na raiz do workspace com `GITLAB_TOKEN`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
2. Duplo-clique em **`kpi-pipeline\agendar.bat`** (pede admin).
3. Confirme horario e teste opcional.

Ou via PowerShell (admin):

```powershell
cd D:\kpi-workspace\kpi-pipeline
.\agendar_task_scheduler.ps1 -Force -Test
```

## Remover agendamento

Duplo-clique em **`kpi-pipeline\desagendar.bat`** ou:

```powershell
.\desagendar_task_scheduler.ps1
```

## Requisitos

- PC ligado no horario (ou `StartWhenAvailable` executa ao voltar).
- Usuario logado (tarefa roda com sua conta - necessario para `.env` e WSL).
- Rede disponivel (GitLab + Supabase).

## Verificar execucoes

- **Task Scheduler:** `taskschd.msc` -> `MGI-Pipeline-Supabase` -> Historico.
- **Logs:** pasta `D:\kpi-workspace\logs\`.
- **Diagnostico rapido:** `kpi-pipeline\verificar_pipeline.bat` (mostra status da ultima execucao e valida caminho da tarefa agendada).

Se o workspace foi movido/renomeado (ex.: `mgi-workspace` -> `kpi-workspace`), rode **`kpi-pipeline\agendar.bat`** novamente como administrador para atualizar o caminho no Task Scheduler.

## Ajustar horario

Remova e recrie com horarios customizados, por exemplo:

```powershell
.\agendar_task_scheduler.ps1 -Force -Times "08:10","10:00","12:00","14:00","16:00","18:00"
```

Ou edite os gatilhos em `taskschd.msc`.
