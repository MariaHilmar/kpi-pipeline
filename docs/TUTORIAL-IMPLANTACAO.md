# Tutorial de implantacao do sistema KPI

Este guia explica, passo a passo, como colocar o sistema no ar: banco (Supabase), site (Vercel) e atualizacao dos dados (pipeline no **Railway** ou no **Windows local**).

Voce nao precisa ser desenvolvedor. Siga na ordem: **1. Supabase → 2. Vercel → 3. Pipeline**. Sem o banco, o site nao tem dados. Sem o pipeline, os dados nao se atualizam.

---

## Como o sistema se encaixa

Imagine tres pecas:

1. **Supabase** - o arquivo digital (banco). Guarda issues, usuarios e metricas.
2. **Vercel** - o site que as pessoas abrem no navegador (dashboard).
3. **Pipeline** - o "robo" que busca dados no GitLab e grava no Supabase.

```
GitLab  -->  Pipeline (Railway ou PC Windows)  -->  Supabase  -->  Site na Vercel
```

**Acesso:** a URL do site e a que a **Vercel** mostra depois do deploy (aba Deployments). Compartilhe so com quem deve entrar. O login usa e-mail e senha; um administrador cria as contas. **Nunca** publique tokens, chaves `service_role`, senhas ou arquivos `.env`.

---

## Segredos (o que nunca publicar)

Nao coloque no Git, em print, issue, PR, chat ou neste tutorial preenchido:

- chaves Supabase (`anon`, `service_role`)
- `GITLAB_TOKEN` e qualquer outro token
- `REVALIDATE_SECRET` e senhas
- arquivos `.env` e `.env.local`
- URL real do projeto com credenciais juntas

Use so os arquivos de exemplo (`.env.example`, `.env.local.example`), com valores vazios ou `xxx`.

---

Crie contas gratuitas (ou o plano que sua organizacao usar):

| Onde | Para que | Site |
|------|----------|------|
| GitHub | Codigo do dashboard e do pipeline | [github.com](https://github.com) |
| Supabase | Banco de dados e login | [supabase.com](https://supabase.com) |
| Vercel | Publicar o site | [vercel.com](https://vercel.com) |
| Railway (opcional) | Rodar o pipeline na nuvem | [railway.app](https://railway.app) |
| GitLab | Token para o pipeline baixar issues | seu GitLab |

No computador Windows (so se for rodar o pipeline **localmente**):

- [Python 3.11 ou superior](https://www.python.org/downloads/) - na instalacao, marque **Add python.exe to PATH**
- [Git](https://git-scm.com/download/win)
- (Opcional) WSL Ubuntu, se quiser coleta de commits pelos repositorios Git locais

---

## Parte 1 - Supabase (banco + login)

### 1.1 Criar o projeto

1. Abra [supabase.com](https://supabase.com) e faca login.
2. Clique em **New project**.
3. Escolha a organizacao, um **nome** (ex.: `kpi-dashboard`) e uma **senha forte** do banco (guarde em local seguro).
4. Regiao: prefira uma proxima do Brasil (ex.: South America), se aparecer na lista.
5. Aguarde o projeto ficar **Active** (pode levar 1 a 2 minutos).

### 1.2 Copiar as chaves (guarde em um bloco de notas, sem enviar para ninguem)

1. No menu esquerdo: **Project Settings** (engrenagem) → **API**.
2. Copie e anote:

| Nome na tela | Como usamos | Onde vai |
|--------------|-------------|----------|
| **Project URL** | `SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_URL` | Pipeline e Vercel |
| **anon public** | `NEXT_PUBLIC_SUPABASE_ANON_KEY` | So o site (Vercel). Pode ir no navegador. |
| **service_role** | `SUPABASE_SERVICE_ROLE_KEY` | Pipeline, admin e importacao. **Nunca** coloque em codigo publico nem em variavel `NEXT_PUBLIC_*`. |

A chave `service_role` abre o banco por completo. Trate como senha.

### 1.3 Criar as tabelas (migrations)

As tabelas e funcoes do dashboard estao em arquivos SQL na pasta:

`kpi-dashboard/supabase/migrations/`

**Caminho recomendado** (menos erro, mesmo se voce nao programa no dia a dia):

1. Instale o [Node.js 20+](https://nodejs.org) (opcao LTS).
2. No computador, abra o **Prompt de Comando** ou o **PowerShell**.
3. Entre na pasta do dashboard (ajuste o caminho se o seu for outro):

```powershell
cd D:\kpi-workspace\kpi-dashboard
npx supabase login
npx supabase link --project-ref SEU_PROJECT_REF
npx supabase db push
```

O **Project Ref** e o codigo curto em **Project Settings → General**. Nao copie URL de projeto de outra pessoa nem cole chaves neste guia.

**Caminho alternativo (so SQL no site):**

1. No Supabase, abra **SQL Editor**.
2. Abra os arquivos `.sql` da pasta `migrations` **em ordem numerica** (`001_...`, `002_...`, ...).
3. Cole o conteudo e clique em **Run**, um arquivo de cada vez.

Nao pule arquivos. Se um deles falhar, pare e leia a mensagem de erro antes de continuar.

### 1.4 Ligar o login por e-mail

1. Menu **Authentication** → **Providers**.
2. Confirme que **Email** esta ligado.
3. Em **Authentication** → **URL Configuration**:

**Site URL** (depois do site na Vercel existir, volte aqui e atualize):

- Desenvolvimento: `http://localhost:3000`
- Producao: `https://SEU-PROJETO.vercel.app` (a URL que a **sua** Vercel gerar)

**Redirect URLs** (adicione as duas):

- `http://localhost:3000/auth/callback`
- `https://SEU-PROJETO.vercel.app/auth/callback`

Se a Vercel usar outro dominio, inclua `https://SEU-DOMINIO/auth/callback`.

Para um ambiente interno, em **Providers → Email** voce pode desligar **Confirm email**, para o usuario entrar sem clicar em link de confirmacao.

### 1.5 Primeiro administrador

1. Em **Authentication → Users**, clique em **Add user** e crie um e-mail + senha.
2. No **SQL Editor**, execute (troque o e-mail):

```sql
update public.profiles
set role = 'admin', active = true, updated_at = now()
where lower(email) = lower('seu-email@exemplo.com');
```

Esse usuario entra no site e cria as demais contas em **Admin → Usuarios**.

---

## Parte 2 - Vercel (site no ar)

O codigo do site e o repositorio **kpi-dashboard** (pasta `kpi-dashboard/` neste workspace).

### 2.1 Conectar o GitHub

1. Abra [vercel.com](https://vercel.com) e entre com a mesma conta GitHub do repositorio.
2. **Add New → Project**.
3. Importe **kpi-dashboard**.
4. Se o GitHub listar um monorepo (workspace inteiro), em **Root Directory** escolha a pasta **`kpi-dashboard`**.

### 2.2 Variaveis de ambiente na Vercel

Em **Environment Variables**, cadastre (Production e Preview):

| Variavel | Valor |
|----------|--------|
| `NEXT_PUBLIC_SUPABASE_URL` | Project URL do Supabase |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Chave **anon** |
| `SUPABASE_SERVICE_ROLE_KEY` | Chave **service_role** (admin e importar Excel/CSV) |
| `REVALIDATE_SECRET` | Segredo longo aleatorio (veja abaixo) |
| `NEXT_PUBLIC_ALLOW_SIGNUP` | `false` (recomendado) |

Como gerar o `REVALIDATE_SECRET` no PowerShell:

```powershell
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Copie o texto gerado. **O mesmo valor** sera usado no pipeline (`REVALIDATE_SECRET`), para o dashboard atualizar o cache depois de cada sync.

### 2.3 Publicar

1. Clique em **Deploy** e aguarde o build ficar verde.
2. Abra a URL que a Vercel mostrar (algo como `https://algo.vercel.app`).
3. Volte ao Supabase e coloque essa URL em **Site URL** e **Redirect URLs**, se ainda nao fez.
4. Teste o login com o usuario admin.

Se o site mostrar um aviso de configuracao (banner), as variaveis `NEXT_PUBLIC_SUPABASE_*` estao vazias ou o deploy nao foi refeito depois de altera-las. Em variaveis `NEXT_PUBLIC_*`, e preciso **Redeploy**.

A producao deste projeto usa a regiao **Sao Paulo (`gru1`)** ja definida em `kpi-dashboard/vercel.json`.

---

## Parte 3 - Pipeline: escolher Railway ou Windows

O site so mostra o que ja esta no Supabase. Alguem precisa rodar o pipeline com frequencia.

| Opcao | Quando usar | Limitacao |
|-------|-------------|-----------|
| **A - Railway** | Querer o robo na nuvem, sem deixar o PC ligado | Nao usa WSL. Commits/branches locais ficam desligados (`MGI_FAST_REPO_SYNC=1`). Issues e metadados via API GitLab funcionam. |
| **B - Windows local** | Ter um PC que fica ligado nos horarios, ou precisar da coleta Git via WSL | O computador precisa estar ligado (ou acordar) no horario da tarefa. |

Voce pode usar **so uma** das opcoes. Nao rode Railway e o agendamento local no mesmo horario, para nao gravar duas vezes o mesmo lote.

---

## Parte 3A - Pipeline no Railway

### 3A.1 Token do GitLab

1. No GitLab: avatar → **Preferences** (ou **Edit profile**) → **Access Tokens**.
2. Crie um token com permissao de **leitura** de API / projetos (o nome varia: `read_api` ou `api` somente leitura).
3. Copie o token **uma vez** e guarde. Ele nao aparece de novo.

### 3A.2 Criar o servico

1. Abra [railway.app](https://railway.app) e faca login (pode ser com GitHub).
2. **New Project** → **Deploy from GitHub repo**.
3. Escolha o repositorio **kpi-pipeline**.
4. Se o Railway perguntar a pasta raiz, use **`kpi-pipeline`** (ou o repo isolado, se for so esse codigo).

### 3A.3 Variaveis no Railway

Em **Variables** do servico, cadastre:

| Variavel | Valor |
|----------|--------|
| `SUPABASE_URL` | Mesma Project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Mesma service_role |
| `GITLAB_URL` | Ex.: `https://gitlab.com` ou a URL do seu GitLab |
| `GITLAB_TOKEN` | Token criado acima |
| `GITLAB_GROUP_PATH` | Grupo dos epicos no GitLab, se usar (o caminho do **seu** grupo) |
| `MGI_FAST_REPO_SYNC` | `1` |
| `MGI_ALL_MODULES` | `1` |
| `MGI_CLOSED_EXCLUDE_DAYS` | `0` (mantem historico) |
| `DASHBOARD_URL` | URL do **seu** site na Vercel, sem barra no final (ex.: `https://SEU-PROJETO.vercel.app`) |
| `REVALIDATE_SECRET` | **Igual** ao da Vercel |

Nao coloque clones Git locais (`MGI_REPOS` / WSL): no Railway isso nao existe.

### 3A.4 Comando de start (o que o Railway executa)

Em **Settings** do servico, defina o **Start Command** (ou Custom Start Command):

```bash
python atualizar_gitlab_issues.py --incremental; python pipeline_maestro.py; python backfill_epicos_mergeadas.py --escopo filhas
```

O Railway precisa instalar Python 3.11+ e o arquivo `requirements.txt` (so a biblioteca `requests`). Se o build falhar, em **Settings → Build** use Nixpacks e linguagem Python.

### 3A.5 Agendar (Cron)

O pipeline deve **rodar e encerrar**, nao ficar um site 24 h no ar.

1. No servico, abra a opcao de **Cron Job** (agendamento).
2. Use um horario em **UTC** (o Railway usa UTC, nao o relogio de Brasilia).

Exemplos (horario de Brasilia = UTC-3, sem horario de verao):

| Quero no Brasil | Cron (UTC) | Significado |
|-----------------|------------|-------------|
| Todo dia as 08:10 | `10 11 * * *` | 11:10 UTC |
| Varias vezes (8h, 10h, 12h, 14h, 16h, 18h) | `10 11,13,15,17,19,21 * * *` | 10 min apos cada hora listada em UTC |

3. Salve e rode **uma vez na mao** (Deploy / Run) para ver os logs.
4. No Supabase, **Table Editor** → tabela `sync_runs`: o ultimo registro deve estar com `status` = `success`.
5. Abra o dashboard na Vercel e atualize a pagina (os KPIs devem aparecer apos o primeiro sync bem-sucedido).

Se o GitLab estiver fora do ar, a etapa de issues pode falhar; o JSON antigo so existe se voce tiver gravado arquivos no servico. No Railway o fluxo normal e sempre buscar na API e gravar no Supabase.

**Carga inicial (primeira vez, historico completo):** rode uma vez com start command diferente, depois volte ao incremental:

```bash
python atualizar_gitlab_issues.py --full; python pipeline_maestro.py --all-modules --initial-load
```

Isso pode demorar varios minutos. Depois, volte o comando incremental da secao 3A.4.

---

## Parte 3B - Pipeline local no Windows (arquivos .bat)

Tudo acontece na pasta do workspace (exemplo: `D:\kpi-workspace`).

### 3B.1 Arquivo de senhas (`.env`)

1. Copie o modelo:

```powershell
copy D:\kpi-workspace\kpi-pipeline\.env.example D:\kpi-workspace\.env
```

2. Abra `.env` no Bloco de Notas e preencha pelo menos:

```env
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=
GITLAB_URL=https://gitlab.com
GITLAB_TOKEN=
DASHBOARD_URL=https://SEU-PROJETO.vercel.app
REVALIDATE_SECRET=
```

Preencha so na sua maquina. Nao envie este arquivo para o GitHub.

Nao envie `.env` para o GitHub.

3. Instale as bibliotecas Python uma vez:

```powershell
cd D:\kpi-workspace\kpi-pipeline
python -m pip install -r requirements.txt
```

### 3B.2 O que cada .bat faz (menu de atalhos)

Abra a pasta **`kpi-pipeline`** (nao a raiz do workspace) e use duplo clique. A janela preta e o console; leia as mensagens ate o final.

| Arquivo | Quando usar |
|---------|-------------|
| `executar_pipeline_carga_inicial.bat` | **Primeira carga.** Baixa o historico completo e envia ao Supabase. Demora mais. Use so no comeco (ou se precisar reprocessar tudo). |
| `executar_pipeline.bat` | **Dia a dia.** Menu: incremental (opcoes 1 ou 3), silencioso (2) ou execucao completa (4). |
| `executar_pipeline_silent.bat` | Mesmo fluxo incremental **sem perguntar nada**. E o arquivo que o agendador do Windows chama. |
| `executar_pipeline_completo.bat` | Recarrega issues no modo full e reprocessa metadados. Use se algo ficou inconsistente. |
| `executar_pipeline_todos_modulos.bat` | Incremental incluindo todos os modulos (`MGI_ALL_MODULES=1`). |
| `agendar.bat` | Cria a tarefa automatica **MGI-Pipeline-Supabase**. Pede permissao de administrador. Horarios padrao: **08:10, 10:00, 12:00, 14:00, 16:00 e 18:00** (horario do Windows). |
| `desagendar.bat` | Remove essa tarefa automatica. Tambem pede administrador. |
| `agendar_pull_repos.bat` | Agenda o pull dos repositorios Git locais (tarefa **MGI-Pull-Repos-Main**). Util se voce coleta commits via WSL. Padrao: dia 1 de cada mes as 09:00. |
| `desagendar_pull_repos.bat` | Remove o agendamento de pull. |
| `executar_pull_repos.bat` | Roda o pull **agora**, sem esperar o calendario. |
| `verificar_pipeline.bat` | Mostra se a ultima execucao deu certo e se a tarefa agendada aponta para a pasta certa. |
| `acompanhar_pipeline.bat` | Atualiza a tela a cada 5 segundos enquanto o pipeline agendado esta rodando. Encerrar: Ctrl+C. |
| `diagnostico_pipeline.bat` | Menu: checar ambiente, limpar logs, testar conexao Git/WSL/Supabase. |
| `teste_pipeline.bat` | Teste rapido do orquestrador (`pipeline_maestro.py`). |

Ordem sugerida na primeira vez:

1. Preencher `.env`
2. `diagnostico_pipeline.bat` (opcao de testar conexao)
3. `executar_pipeline_carga_inicial.bat` e esperar terminar com **SUCESSO**
4. Conferir `issues` no Supabase
5. Abrir o site na Vercel
6. Se quiser automatico neste PC: `agendar.bat`

### 3B.3 Agendar no Windows (passo a passo)

1. Feche outros programas se o Windows pedir UAC (tela de "Permitir que este aplicativo faca alteracoes").
2. Em `kpi-pipeline`, duplo clique em **`agendar.bat`**.
3. Aceite o pedido de administrador.
4. Uma janela PowerShell recria a tarefa. Se pedir teste, pode confirmar.

O que fica agendado:

- **Nome da tarefa:** `MGI-Pipeline-Supabase`
- **Script:** `kpi-pipeline\executar_pipeline_silent.bat`
- **Logs:** pasta `logs\` (arquivos `scheduled_AAAAAMMDD_HHMMSS.log`)

O PC precisa estar **ligado** (ou acordar) nesses horarios. A tarefa usa a **sua conta** do Windows, para ler o `.env`.

Para mudar os horarios depois: duplo clique em `desagendar.bat`, depois `agendar.bat` de novo, ou abra o Agendador (`Win + R`, digite `taskschd.msc`, Enter) e edite os gatilhos de `MGI-Pipeline-Supabase`.

Horarios customizados via PowerShell (como administrador):

```powershell
cd D:\kpi-workspace\kpi-pipeline
.\agendar_task_scheduler.ps1 -Force -Times "08:10","12:00","18:00"
```

### 3B.4 Agendar o pull dos repositorios (opcional)

So faz sentido se os clones Git existirem neste computador (e, no fluxo atual, em geral via WSL).

1. Duplo clique em **`agendar_pull_repos.bat`** (administrador).
2. Para rodar na hora: **`executar_pull_repos.bat`**.
3. Para cancelar: **`desagendar_pull_repos.bat`**.

### 3B.5 Acompanhar se deu certo

- Duplo clique em **`verificar_pipeline.bat`**.
- Ou pasta `D:\kpi-workspace\logs\`.
- Ou no Supabase, tabela `sync_runs`.

Se o workspace mudou de pasta ou de nome, rode **`agendar.bat`** de novo para atualizar o caminho da tarefa.

---

## Parte 4 - Dashboard so no seu PC (opcional)

Isso **nao substitui** a Vercel. Serve para testar antes de publicar.

1. Copie o modelo:

```powershell
copy D:\kpi-workspace\kpi-dashboard\.env.local.example D:\kpi-workspace\kpi-dashboard\.env.local
```

2. Preencha `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_ANON_KEY` (e a service_role se for testar admin/importacao).
3. No terminal:

```powershell
cd D:\kpi-workspace\kpi-dashboard
npm install
npm run dev
```

4. Navegador: [http://localhost:3000](http://localhost:3000)

---

## Checklist: "esta no ar?"

Marque na ordem:

- [ ] Projeto Supabase ativo e chaves copiadas
- [ ] Migrations aplicadas (`db push` ou SQL em ordem)
- [ ] Auth: Site URL e Redirect URLs com localhost e a URL da Vercel
- [ ] Primeiro usuario com `role = admin`
- [ ] Projeto Vercel implantado, variaveis preenchidas, site abre
- [ ] Login no site funciona
- [ ] Pipeline rodou pelo menos uma vez (Railway **ou** `executar_pipeline_carga_inicial.bat`)
- [ ] Tabela `issues` tem linhas; `sync_runs` com `success`
- [ ] KPIs aparecem no dashboard
- [ ] Pipeline recorrente: Cron no Railway **ou** `agendar.bat` no Windows
- [ ] `DASHBOARD_URL` + `REVALIDATE_SECRET` iguais nos dois lados (cache atualiza apos o sync)

---

## Problemas comuns

**Site pede login mas ninguem consegue entrar**  
Confira Redirect URLs no Supabase. O e-mail precisa existir em Authentication → Users e o perfil `active = true`.

**Graficos vazios**  
O pipeline ainda nao gravou issues, ou as migrations nao rodaram. Veja Table Editor → `issues`.

**Dados "atrasados" depois do pipeline**  
`REVALIDATE_SECRET` diferente entre Vercel e pipeline, ou `DASHBOARD_URL` errada. O sync mesmo assim grava no banco; o cache do site pode levar ate 24 h se a invalidacao falhar.

**`agendar.bat` nao cria a tarefa**  
Rode como administrador. Antivirus pode bloquear scripts. Use `verificar_pipeline.bat`.

**Railway termina rapido com erro de Python**  
Falta `requirements.txt` no root que o Railway constroi, ou o Start Command aponta para a pasta errada.

**Pipeline local: "python nao encontrado"**  
Reinstale o Python marcando PATH, feche e abra o console, teste `python --version`.

---

## Onde esta cada coisa neste workspace

| Pasta / arquivo | Papel |
|-----------------|--------|
| `kpi-dashboard/` | Codigo do site (Vercel) |
| `kpi-pipeline/` | Codigo do robo (Railway ou Windows) |
| `kpi-dashboard/supabase/migrations/` | Tabelas e regras do banco |
| `.env` (raiz) | Segredos do pipeline no PC - nao versionar |
| `kpi-dashboard/.env.local` | Segredos do site no PC - nao versionar |
| `kpi-pipeline\*.bat` | Atalhos Windows descritos neste tutorial |

Documentacao tecnica extra:

- Dashboard: `kpi-dashboard/docs/05-setup-deploy.md` e `kpi-dashboard/docs/08-autenticacao.md`
- Agendamento Windows (detalhe): `kpi-pipeline/docs/05-agendamento.md`
