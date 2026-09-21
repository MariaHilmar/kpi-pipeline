# Migrar contas para producao (Supabase + Vercel) e agendar os .bat

Este arquivo e o passo a passo para **passar o sistema da conta de testes para a conta de producao** e **agendar a atualizacao automatica dos dados** no Windows.

Nao copie tokens, chaves nem URLs reais neste arquivo. Use so o que aparecer no **seu** painel.

## Repositorios no Git

Sao **dois** repositorios. Clone os dois na **mesma pasta pai** (o `.env` do pipeline fica nessa pasta pai, nao dentro do Git).

| Papel | Repositorio |
|-------|-------------|
| Site (Vercel) | [https://github.com/MariaHilmar/kpi-dashboard](https://github.com/MariaHilmar/kpi-dashboard) |
| Pipeline e arquivos `.bat` | [https://github.com/MariaHilmar/kpi-pipeline](https://github.com/MariaHilmar/kpi-pipeline) |

```powershell
git clone https://github.com/MariaHilmar/kpi-dashboard.git
git clone https://github.com/MariaHilmar/kpi-pipeline.git
```

Depois do clone, a pasta deve ficar assim:

```
pasta-pai/
  kpi-dashboard/     <- clone do GitHub
  kpi-pipeline/      <- clone do GitHub
  .env               <- voce cria (nao vai para o Git)
  logs/              <- gerado pelo pipeline
```

Troque `pasta-pai` pelo caminho no **seu** computador. Os comandos abaixo usam `kpi-dashboard` e `kpi-pipeline` relativos a essa pasta.

Guia extra neste repositorio: [TUTORIAL-IMPLANTACAO.md](./TUTORIAL-IMPLANTACAO.md).

Ordem obrigatoria:

1. Conta e projeto **Supabase** de producao  
2. Conta e projeto **Vercel** de producao (apontando para esse Supabase)  
3. `.env` do pipeline neste computador  
4. Agendar os `.bat` que estao no repositorio [kpi-pipeline](https://github.com/MariaHilmar/kpi-pipeline)

---

## O que nao publicar

- Chaves `anon` e `service_role` do Supabase  
- `GITLAB_TOKEN`, senhas, `REVALIDATE_SECRET`  
- Arquivos `.env` e `kpi-dashboard/.env.local`  
- Prints com essas informacoes visiveis  

Esses valores ficam so no painel (Supabase / Vercel) e no `.env` local, **fora do Git**.

---

## Parte A - Migrar o Supabase para producao

Voce **nao move a conta antiga automaticamente**. O usual e: criar (ou usar) a **organizacao de producao**, criar um **projeto novo** la, aplicar o schema deste sistema e, se quiser, trazer dados. Depois a Vercel e o pipeline passam a usar as chaves **desse** projeto.

### A.1 Entrar na conta certa

1. Abra [supabase.com](https://supabase.com).  
2. Confirme que esta na **organizacao de producao** (canto superior esquerdo).  
   - Se a producao for outra empresa/pessoa: peca convite nessa organizacao, ou crie a organizacao nova e saia da de testes.  
3. Nao reutilize o projeto de desenvolvimento se a regra for isolar producao.

### A.2 Criar o projeto de producao

1. **New project**.  
2. Nome claro (ex.: `kpi-producao`).  
3. Defina uma **senha forte do banco** e anote em local seguro (nao no Git).  
4. Escolha a regiao mais proxima dos usuarios.  
5. Espere o status **Active**.

### A.3 Anotar as chaves do projeto novo

Em **Project Settings → API**, anote em um bloco de notas local:

| No painel | Para que serve |
|-----------|----------------|
| Project URL | Site (Vercel) e pipeline |
| anon public | So o site (`NEXT_PUBLIC_SUPABASE_ANON_KEY`) |
| service_role | Pipeline, admin e importacao. Trate como senha |

A `service_role` **nao** vai em variavel que comeca com `NEXT_PUBLIC_`.

O **Project Ref** (codigo curto) esta em **Project Settings → General**. Serve para o comando `supabase link`.

### A.4 Criar as tabelas deste sistema

As migrations estao no Git:

[https://github.com/MariaHilmar/kpi-dashboard/tree/main/supabase/migrations](https://github.com/MariaHilmar/kpi-dashboard/tree/main/supabase/migrations)

No computador, com Node.js 20+, na pasta do clone de **kpi-dashboard**:

```powershell
cd kpi-dashboard
npx supabase login
npx supabase link --project-ref SEU_PROJECT_REF
npx supabase db push
```

Use o Project Ref **do projeto de producao**.  
Alternativa: **SQL Editor** no site do Supabase e os arquivos `.sql` da pasta [supabase/migrations](https://github.com/MariaHilmar/kpi-dashboard/tree/main/supabase/migrations) em ordem numerica (`001_...`, `002_...`).

### A.5 Login (Auth) apontando para o site de producao

Ainda no Supabase de producao:

1. **Authentication → Providers:** Email ligado.  
2. **Authentication → URL Configuration:**

- **Site URL:** a URL do site na Vercel de producao (depois que existir). Enquanto isso, pode usar `http://localhost:3000`.  
- **Redirect URLs:**  
  - `http://localhost:3000/auth/callback`  
  - `https://SEU-PROJETO.vercel.app/auth/callback`  

Troque `SEU-PROJETO.vercel.app` pela URL **real** que a Vercel mostrar, so no painel, nao neste arquivo.

Ambiente interno: em Email, voce pode desligar **Confirm email**.

### A.6 Primeiro administrador

1. **Authentication → Users → Add user** (e-mail e senha de producao).  
2. **SQL Editor:**

```sql
update public.profiles
set role = 'admin', active = true, updated_at = now()
where lower(email) = lower('seu-email@exemplo.com');
```

Esse usuario cria as outras contas em **Admin → Usuarios** no site.

### A.7 Dados antigos (opcional)

| Situacao | O que fazer |
|----------|-------------|
| Producao comeca do zero | Nao copie o banco de teste. Rode o pipeline (carga inicial) contra o Supabase **novo**. |
| Precisa trazer tabelas do projeto antigo | No projeto antigo, use backup/export do Supabase (Dashboard ou CLI). Restaure **so** no projeto novo. Nao misture as chaves dos dois projetos. |

Depois da troca, o pipeline e a Vercel devem usar **somente** URL e chaves do projeto novo.

---

## Parte B - Migrar a Vercel para producao

O normal e a **conta/time de producao** importar o repositorio do GitHub e configurar variaveis novas. Transferir o projeto antigo e opcional (Settings → General → Transfer), se a Vercel oferecer isso no seu plano.

### B.1 Conta e repositorio

1. Abra [vercel.com](https://vercel.com) com a conta (ou time) de **producao**.  
2. **Add New → Project** e importe o repositorio **[MariaHilmar/kpi-dashboard](https://github.com/MariaHilmar/kpi-dashboard)** (nao o pipeline).  
3. **Root Directory:** deixe a raiz do repo (o codigo do site ja e esse repositorio).  
4. Framework: Next.js (detectado sozinho).

### B.2 Variaveis de ambiente (producao)

Modelo das variaveis no Git: [kpi-dashboard/.env.local.example](https://github.com/MariaHilmar/kpi-dashboard/blob/main/.env.local.example)

Em **Settings → Environment Variables**, cadastre para **Production** (e Preview, se usar):

| Variavel | De onde vem |
|----------|-------------|
| `NEXT_PUBLIC_SUPABASE_URL` | Project URL do Supabase **de producao** |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | chave **anon** de producao |
| `SUPABASE_SERVICE_ROLE_KEY` | chave **service_role** de producao |
| `REVALIDATE_SECRET` | texto longo gerado por voce (mesmo valor no pipeline) |
| `NEXT_PUBLIC_ALLOW_SIGNUP` | `false` (recomendado) |

Gerar o segredo no PowerShell (nao grave o resultado neste `.md`):

```powershell
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Depois de alterar variaveis `NEXT_PUBLIC_*`, faca **Redeploy**.

### B.3 Publicar e ligar no Supabase

1. **Deploy** e espere ficar verde.  
2. Copie a URL do projeto (Deployments). Compartilhe so com quem deve acessar.  
3. Volte ao Supabase de producao e atualize **Site URL** e **Redirect URLs** com essa URL.  
4. Teste o login do administrador.

Se o projeto antigo de testes ainda existir, pause ou apague o deploy de teste para ninguem entrar no ambiente errado.

### B.4 Transferir um projeto Vercel ja existente (opcional)

Se o site ja esta numa conta pessoal e a producao e um **team**:

1. No projeto: **Settings → General**.  
2. Procure **Transfer** (ou convide o time e transfira).  
3. Confirme que as **Environment Variables** continuam no destino.  
4. Se as chaves ainda forem do Supabase de teste, **troque** pelas de producao e faca Redeploy.

---

## Parte C - Ligar o pipeline deste computador ao Supabase de producao

Codigo e modelo de ambiente no Git:

- Repositorio: [https://github.com/MariaHilmar/kpi-pipeline](https://github.com/MariaHilmar/kpi-pipeline)  
- Exemplo de variaveis: [kpi-pipeline/.env.example](https://github.com/MariaHilmar/kpi-pipeline/blob/main/.env.example)  
- Dependencias: [kpi-pipeline/requirements.txt](https://github.com/MariaHilmar/kpi-pipeline/blob/main/requirements.txt)

1. Copie o modelo **para a pasta pai** (ao lado das pastas `kpi-pipeline` e `kpi-dashboard`), nao para dentro do Git:

```powershell
copy kpi-pipeline\.env.example .env
```

2. Edite o arquivo `.env` no Bloco de Notas e preencha com o **projeto de producao** (campos vazios de proposito):

```env
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
GITLAB_URL=
GITLAB_TOKEN=
DASHBOARD_URL=
REVALIDATE_SECRET=
```

`DASHBOARD_URL` = URL da Vercel de producao, sem barra no final.  
`REVALIDATE_SECRET` = **igual** ao da Vercel.

3. Instale dependencias uma vez, na pasta do clone:

```powershell
cd kpi-pipeline
python -m pip install -r requirements.txt
```

4. Primeira carga no banco **novo** - arquivo no Git: [executar_pipeline_carga_inicial.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/executar_pipeline_carga_inicial.bat)

- No Explorer, abra a pasta do clone `kpi-pipeline` e de duplo clique em **executar_pipeline_carga_inicial.bat**.  
- Espere a mensagem de sucesso.  
- No Supabase de producao, Table Editor: tabela `issues` com linhas; `sync_runs` com `success`.

Atualizacoes seguintes: [executar_pipeline.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/executar_pipeline.bat) (ou o agendamento abaixo).

---

## Parte D - Agendar os arquivos .bat (Windows)

Todos os `.bat` estao na **raiz** do repositorio [kpi-pipeline](https://github.com/MariaHilmar/kpi-pipeline).  
O computador precisa estar **ligado** (ou acordar) nos horarios. A tarefa usa a **sua conta** do Windows para ler o `.env` da pasta pai.

Peca permissao de administrador quando o Windows perguntar.

### D.1 O que cada .bat de agenda faz (links no Git)

| Arquivo no Git | Funcao |
|----------------|--------|
| [agendar.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/agendar.bat) | Cria a tarefa **KPI-Pipeline-Supabase**. Roda o silent todos os dias. Horarios padrao: **08:10, 10:00, 12:00, 14:00, 16:00, 18:00**. |
| [desagendar.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/desagendar.bat) | Remove essa tarefa. |
| [executar_pipeline_silent.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/executar_pipeline_silent.bat) | Pipeline incremental **sem menu**. E o que o agendador dispara. |
| [agendar_pull_repos.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/agendar_pull_repos.bat) | Agenda pull dos repositorios Git locais (tarefa **KPI-Pull-Repos-Main**). Padrao: dia 1 de cada mes as 09:00. So se houver clones Git/WSL neste PC. |
| [desagendar_pull_repos.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/desagendar_pull_repos.bat) | Remove o agendamento de pull. |
| [executar_pull_repos.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/executar_pull_repos.bat) | Roda o pull **agora**. |
| [verificar_pipeline.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/verificar_pipeline.bat) | Confere a ultima execucao e o caminho da tarefa. |
| [acompanhar_pipeline.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/acompanhar_pipeline.bat) | Acompanha ao vivo (Ctrl+C para sair). |

Atalhos manuais (nao sao o agendador):

- [executar_pipeline.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/executar_pipeline.bat)  
- [executar_pipeline_completo.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/executar_pipeline_completo.bat)  
- [executar_pipeline_todos_modulos.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/executar_pipeline_todos_modulos.bat)  
- [executar_pipeline_carga_inicial.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/executar_pipeline_carga_inicial.bat)  
- [diagnostico_pipeline.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/diagnostico_pipeline.bat)  
- [teste_pipeline.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/teste_pipeline.bat)  

Script PowerShell do agendador: [agendar_task_scheduler.ps1](https://github.com/MariaHilmar/kpi-pipeline/blob/main/agendar_task_scheduler.ps1)

### D.2 Agendar o pipeline

1. Confirme o `.env` de **producao** na pasta pai (ao lado de `kpi-pipeline`).  
2. Abra no Explorer a pasta do clone **kpi-pipeline**.  
3. Duplo clique em **agendar.bat**.  
4. Aceite o UAC (administrador).  
5. Se perguntar para testar, pode confirmar.

O que fica gravado no Windows:

- Tarefa: `KPI-Pipeline-Supabase`  
- Script: `executar_pipeline_silent.bat` (dentro do clone de kpi-pipeline)  
- Logs: pasta `logs` na **pasta pai** (ao lado dos dois clones)

### D.3 Conferir se agendou

1. `Win + R`, digite `taskschd.msc`, Enter.  
2. Procure `KPI-Pipeline-Supabase`.  
3. Veja **Next Run Time** e o historico.  
4. Ou duplo clique em **verificar_pipeline.bat** na pasta do clone.

### D.4 Mudar horarios

1. Duplo clique em **desagendar.bat** (admin).  
2. Duplo clique em **agendar.bat** de novo.  

Ou, PowerShell **como administrador**, na pasta do clone:

```powershell
cd kpi-pipeline
.\agendar_task_scheduler.ps1 -Force -Times "08:10","12:00","18:00"
```

Tambem e possivel editar os gatilhos em `taskschd.msc`.

### D.5 Agendar pull dos repositorios (opcional)

1. Duplo clique em **agendar_pull_repos.bat** (admin).  
2. Para cancelar: **desagendar_pull_repos.bat**.

Nao rode este agendamento se os clones Git dos sistemas de origem nao existirem neste PC.

### D.6 Se a pasta do clone mudar de nome ou de disco

Rode **agendar.bat** de novo (admin). O Windows guarda o caminho antigo; o `.bat` atualiza a tarefa.

---

## Checklist de producao

- [ ] Clones: [kpi-dashboard](https://github.com/MariaHilmar/kpi-dashboard) e [kpi-pipeline](https://github.com/MariaHilmar/kpi-pipeline) na mesma pasta pai  
- [ ] Organizacao/projeto Supabase e o de **producao** (nao o de teste)  
- [ ] Migrations aplicadas ([pasta no Git](https://github.com/MariaHilmar/kpi-dashboard/tree/main/supabase/migrations))  
- [ ] Auth com Site URL e Redirect da Vercel de producao  
- [ ] Admin criado; login funciona  
- [ ] Vercel no time/conta de producao, importando **kpi-dashboard**  
- [ ] Variaveis da Vercel com chaves do Supabase **novo**  
- [ ] `.env` na pasta pai, com as chaves de producao (arquivo **nao** vai para o Git)  
- [ ] Carga inicial com [executar_pipeline_carga_inicial.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/executar_pipeline_carga_inicial.bat)  
- [ ] [agendar.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/agendar.bat) executado; tarefa visivel no Agendador  
- [ ] [verificar_pipeline.bat](https://github.com/MariaHilmar/kpi-pipeline/blob/main/verificar_pipeline.bat) sem caminho invalido  
- [ ] Deploy de teste pausado ou removido, se nao for mais usado  

---

## Se algo falhar

| Problema | O que checar |
|----------|----------------|
| Login nao redireciona | Redirect URLs no Supabase iguais a URL da Vercel + `/auth/callback` |
| Site sem dados | Pipeline rodou no Supabase **certo**? Tabela `issues` |
| Dados de teste no ar | Vercel ainda com chaves do projeto antigo; troque e Redeploy |
| Tarefa nao roda | PC desligado; `agendar.bat` sem admin; `.env` ausente na pasta pai |
| Tarefa aponta pasta errada | `agendar.bat` de novo; `verificar_pipeline.bat` |
| Arquivo .bat nao aparece | `git pull` no clone de [kpi-pipeline](https://github.com/MariaHilmar/kpi-pipeline) |
