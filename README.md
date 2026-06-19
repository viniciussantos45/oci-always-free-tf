# OCI Always Free — Stack Terraform Maximizada (us-ashburn-1)

🇺🇸 [View in English](README.en.md)

Terraform para o **máximo de recursos Always Free** que a Oracle Cloud permite na região **US East
(Ashburn)**, centrado em um servidor Arm do maior tamanho possível, a um custo estrito de **US$0** (sem
upgrade para Pay-As-You-Go, sem créditos de trial, nada fora do envelope Always Free verificado).

## O que é provisionado

| Componente                   | Detalhe                                                                         |
| ---------------------------- | ------------------------------------------------------------------------------- |
| Rede                         | 1 VCN, Internet Gateway, route table padrão, security list, 1 sub-rede pública  |
| **Servidor Arm (no máximo)** | 1× `VM.Standard.A1.Flex` — **2 OCPU / 12 GB**, Ubuntu 22.04, boot de 100 GB     |
| Micros AMD                   | 2× `VM.Standard.E2.1.Micro` — 1/8 OCPU, 1 GB, Ubuntu 22.04 (boot padrão ~47 GB) |
| Bancos de dados              | 2× Autonomous Database, `is_free_tier = true` (1 ECPU / 20 GB cada, OLTP)       |
| Alertas                      | Tópico de Notifications + assinatura por e-mail + alarme de CPU no Monitoring   |

**Orçamento de block storage:** 100 GB (A1) + ~47 GB + ~47 GB ≈ **194 GB**, abaixo do pool de 200 GB do Always Free.

> **Atenção — limite Arm cortado pela metade em 15/06/2026.** O A1 Always Free agora é **2 OCPU / 12 GB**
> no total (era 4/24). Esta stack utiliza o teto atual ao máximo, garantido por validação de variáveis.

Excluídos por decisão de projeto: MySQL HeatWave, Object Storage, Load Balancer, NoSQL (só em Phoenix).

---

## Configuração inicial — faça uma única vez

### 1. Instale as ferramentas

```bash
brew install terraform jq oci-cli   # macOS
```

### 2. Tenha uma conta OCI no Always Free

Mantenha-a no **Always Free** — **não** faça upgrade para Pay-As-You-Go.

> ⚠️ **Escolha sua home region com cuidado no cadastro — ela é permanente.** A Oracle define sua home
> region quando você cria a conta e ela **nunca** pode ser alterada, e os **recursos Always Free
> (A1/micros/ADB) só existem nessa home region** (assinar outras regiões depois *não* estende o Always
> Free para elas). O Arm A1 é altamente disputado em regiões populares como Ashburn, então, se você está
> criando uma conta nova e quer uma chance real de provisionar o A1, escolha uma **home region menos
> concorrida que tenha capacidade de A1**. Este repositório está fixado em `us-ashburn-1`; para apontar
> para outra home region você também precisa atualizar a validação de `region` no `variables.tf`.

### 3. Crie sua chave de API + config

```bash
oci setup config
```

Responda aos prompts (user OCID, tenancy OCID, região `us-ashburn-1`). Ele gera um par de chaves em
`~/.oci/` e grava um profile em `~/.oci/config`. **Anote o nome do profile** criado (no histórico deste
repositório foi `Profile1-macos`) e se foi definida uma **passphrase** na chave — ambos são tratados
automaticamente pelo profile, então você nunca os coloca no Terraform.

### 4. Faça upload da chave pública no Console

O `oci setup config` **não** registra a chave na Oracle — você precisa fazer isso uma vez:

1. Acesse <https://cloud.oracle.com>
2. Canto superior direito **ícone de perfil → My profile → API keys → Add API key**
3. **Paste a public key** → cole o conteúdo completo de:

   ```bash
   cat ~/.oci/oci_api_key_public.pem
   ```

4. **Add**.

### 5. Verifique se a autenticação funciona

```bash
oci iam region list --profile Profile1-macos
```

Você deve receber uma **tabela de regiões**. Se receber `401 NotAuthenticated`, a chave pública ainda
não foi enviada/registrada — refaça o passo 4 (veja o FAQ).

### 6. Escolha um compartment

Use seu compartment **root** (o OCID da sua tenancy) ou crie um dedicado (recomendado):

```bash
oci iam compartment create \
  --compartment-id <tenancy_ocid> \
  --name always-free-lab \
  --description "Always Free Terraform stack" \
  --profile Profile1-macos --query 'data.id' --raw-output
```

O comando imprime o OCID do novo compartment — use-o como `compartment_id`.

### 7. Tenha uma chave SSH

```bash
cat ~/.ssh/id_ed25519.pub   # ou crie uma: ssh-keygen -t ed25519
```

---

## Configure o `terraform.tfvars`

```bash
cp terraform.tfvars.example terraform.tfvars
```

Preencha com **valores literais** (⚠️ arquivos `.tfvars` não podem referenciar outras variáveis — cole
as strings de OCID reais):

```hcl
config_file_profile = "Profile1-macos"                 # o profile do passo 3
tenancy_ocid        = "ocid1.tenancy.oc1..aaaa..."     # OCID da sua tenancy
region              = "us-ashburn-1"
compartment_id      = "ocid1.compartment.oc1..aaaa..." # ou o OCID da tenancy para usar o root

ssh_public_key      = "ssh-ed25519 AAAA... voce@host"
ssh_ingress_cidr    = "0.0.0.0/0"                       # restrinja para "<seu.ip>/32" e reduza ruído de scans

adb_admin_password  = "Str0ngPassw0rd!"                 # 12-30 caracteres, maiúscula+minúscula+número
notification_email  = "voce@exemplo.com"
```

Os segredos (user OCID, fingerprint, caminho da chave, passphrase) são **lidos de `~/.oci/config`** via
profile, então não vão neste arquivo.

---

## Deploy

```bash
terraform init
terraform validate
terraform plan -out=tfplan

# Guardrail: falha se o plano tocar em algo fora da allow-list do Always Free
terraform show -json tfplan > tfplan.json
./scripts/check-plan.sh tfplan.json

terraform apply tfplan
```

Esperado: **14 recursos a adicionar**. Se o A1/micros falharem com `Out of host capacity` ou
`404-NotAuthorizedOrNotFound`, isso é falta de capacidade da Oracle, não erro de configuração — veja o FAQ.

## Depois do apply

1. **Confirme o e-mail de alerta** — a OCI envia um link; a assinatura fica `PENDING` até você clicar:

   ```bash
   terraform refresh && terraform output notification_subscription_state   # esperado: ACTIVE
   ```

2. **Testes de fumaça (smoke test):**
   - `terraform output a1_ssh_command` → conecte via SSH como `ubuntu`.
   - Console/CLI: o A1 mostra **2 OCPU / 12 GB**; ambos os ADBs estão `AVAILABLE` com `is_free_tier = true`.
   - `terraform plan` de novo → **No changes** (sem drift).

## Acessar as instâncias

Pegue os IPs públicos e os comandos SSH prontos pelos outputs:

```bash
terraform output micro_public_ips     # os dois micros AMD
terraform output a1_ssh_command       # o A1 (quando existir)
```

A imagem é Ubuntu, então o **usuário de login é `ubuntu`** e a autenticação é sua `ssh_public_key`:

```bash
ssh ubuntu@<ip_publico>
ssh -i ~/.ssh/sua_chave ubuntu@<ip_publico>   # se a chave não for a padrão
```

### Abrir portas e por que o `ping` dá timeout

O tráfego de entrada passa por **dois** firewalls — **ambos** precisam permitir:

```
Internet ─▶ [security list OCI] ─▶ VM ─▶ [ufw / iptables] ─▶ sua aplicação
             (network.tf)                 (dentro da instância)
```

Por padrão a security list (`network.tf`) permite de entrada **apenas**:
- **TCP 22** (SSH) a partir de `ssh_ingress_cidr`
- **ICMP type 3 code 4** (path-MTU) — necessário para a rede funcionar bem

Todo o resto de entrada é bloqueado (a saída é totalmente liberada). Duas consequências importantes:

- **O `ping` dá timeout por design.** O `ping` envia **ICMP type 8 (echo request)**, que não tem regra —
  só type 3/4 é permitido. O SSH funciona porque o TCP 22 tem regra própria. Adicione uma regra de
  ingress type 8 no `network.tf` se quiser que a máquina responda ping.
- **Abrir uma porta (ex.: 80/443) exige editar o `network.tf`** + `terraform apply` — a security list da
  nuvem é **obrigatória**. Um firewall de host como o `ufw` **não substitui** isso: o `ufw` fica *atrás*
  da security list, então uma porta que a security list bloqueia nunca chega na VM. Depois de abrir na
  security list, talvez você *também* precise liberar a porta dentro da VM, já que as imagens Ubuntu da
  OCI vêm com iptables restritivo (`sudo ufw allow 443/tcp`, ou iptables + `netfilter-persistent save`).
  **Sempre libere o SSH antes de ativar o `ufw`**, ou você se tranca para fora.

## Destruir tudo

```bash
terraform destroy
```

Remove tudo (incl. os 2 ADBs). O tópico de Notifications pode levar ~5 min para ser excluído — é normal.

---

## Vencendo a falta de capacidade do A1 (a pegadinha nº 1)

O **Arm A1 do Always Free em Ashburn é muito disputado**. O apply pode falhar simplesmente porque a
Oracle não tem um host Arm gratuito disponível naquele momento. **Não há correção no código** — você
tenta de novo até surgir capacidade:

- **Alterne a availability domain do A1** com `a1_availability_domain_index` (0, 1, 2). Ela é separada de
  `availability_domain_index`, então você pode caçar capacidade do A1 **sem recriar os micros**:

  ```hcl
  a1_availability_domain_index = 1   # tente 0, depois 1, depois 2; rode apply a cada tentativa
  ```

- **Tente em horários de baixa demanda** (madrugada/manhã cedo no horário local) — a capacidade abre.
- Rodar `terraform apply` de novo só retenta as instâncias que falharam; o que já foi criado permanece.

### Loop de retry automático

O `scripts/retry-a1.sh` repete um apply **direcionado** (só o A1 — nunca mexe nos micros), alternando
AD-3 → AD-1 → AD-2 a cada rodada até surgir um host Arm livre:

```bash
./scripts/retry-a1.sh                          # 270s entre rodadas, indefinidamente
SLEEP_SECONDS=120 MAX_ROUNDS=50 ./scripts/retry-a1.sh
```

Ao ter sucesso, ele imprime o índice da AD vencedora — fixe-o em `a1_availability_domain_index` no
`terraform.tfvars`. Ctrl-C para parar. A capacidade em Ashburn pode levar horas/dias; o loop só garante
que você pegue assim que abrir. Continua nada depois de dias? Reduza para **1 OCPU / 6 GB**
(`a1_ocpus=1`, `a1_memory_gbs=6`) — capacidade parcial é bem mais fácil de conseguir que os 2/12 cheios.

---

## FAQ

**P: O `terraform apply` falha com `500-InternalError, Out of host capacity` no A1.**
A Oracle não tem host Arm gratuito no momento. Não é bug. Alterne `a1_availability_domain_index` entre
0/1/2 e tente de novo, de preferência fora do horário de pico. Persista — é a experiência normal do
Always Free em Ashburn.

**P: As instâncias falham com `404-NotAuthorizedOrNotFound` no `LaunchInstance`, mas o resto foi criado.**
Para shapes do Always Free, isso quase sempre é a **mesma falta de capacidade** aparecendo como o erro
ambíguo da Oracle — não é problema de permissão. Confirme verificando se o A1 reporta
`Out of host capacity` numa nova tentativa: se reportar, sua autorização de compute está ok e é só
capacidade. (Só seria problema de policy de verdade se **todos** os serviços — inclusive os ADBs —
falhassem com 404.)
Para os **micros AMD**, isso costuma ser **específico da availability domain**: um micro que dá 404 numa
AD sobe normalmente em outra. Se os micros derem 404, mude `availability_domain_index` (0/1/2) e rode
apply de novo — no histórico deste repositório eles falharam na AD-2 mas subiram limpos na AD-1.

**P: O SSH funciona mas o `ping` dá timeout.**
Esperado — a security list permite ICMP **type 3/4** (path-MTU), mas não **type 8** (echo request, o que
o `ping` usa). É uma escolha de configuração, não falha do servidor. Veja *Acessar as instâncias → Abrir
portas* para adicionar a regra type 8. Mesma lógica para qualquer outra porta: abra primeiro no
`network.tf`, depois (se necessário) dentro da VM.

**P: `oci iam region list` retorna `401 NotAuthenticated`.**
A chave pública de API não está registrada. Refaça o passo 4 da configuração (Console → My profile →
API keys → Add API key → cole `~/.oci/oci_api_key_public.pem`). Garanta que o fingerprint mostrado no
Console seja igual ao `fingerprint` do seu profile em `~/.oci/config`.

**P: `Error: Variables not allowed` / `Variables may not be used here` apontando para `terraform.tfvars`.**
Arquivos `.tfvars` só aceitam valores literais. Substitua qualquer `compartment_id = tenancy_ocid` pela
string de OCID real entre aspas, ex.: `compartment_id = "ocid1.tenancy.oc1..aaaa..."`.

**P: Minha chave privada tem passphrase. Onde coloco?**
Em lugar nenhum do Terraform. O provider autentica via `config_file_profile`, que lê o caminho da chave
**e** a passphrase direto de `~/.oci/config`. Continue usando autenticação por profile e você nunca
manipula a passphrase neste repositório.

**P: Posso autorizar mais de uma chave SSH?**
O metadado `ssh_authorized_keys` aceita várias chaves separadas por quebra de linha, então você pode
passar várias numa única string: `ssh_public_key = "ssh-ed25519 AAAA... eu\nssh-ed25519 BBBB... colega"`.
Prefere uma variável `list(string)` mais limpa? É só pedir, é uma mudança pequena.

**P: O e-mail de alerta nunca chega / a assinatura fica em `PENDING`.**
Abra o e-mail de confirmação que a OCI enviou para `notification_email` e clique no link. Até lá,
`notification_subscription_state` fica `PENDING` e os alertas não disparam.

**P: Isso vai gerar custo?**
Não — cada recurso corresponde a uma cota Always Free verificada, e os guardrails (`check-plan.sh` +
validação de variáveis + `guardrails.tf`) bloqueiam qualquer coisa fora disso. A única regra: **nunca
crie recursos pelo Console fora do Terraform** — mudanças manuais causam drift e podem gerar cobrança.

**P: Posso rodar em outra região?**
Não. Está fixado em `us-ashburn-1` (a validação força isso). Tenancies gratuitas são limitadas a uma
única região home, e algumas escolhas aqui (ex.: excluir o NoSQL exclusivo de Phoenix) assumem Ashburn.

**P: Posso trocar a região no Terraform para fugir do `Out of host capacity` do A1?**
Não. Sua **home region é permanente** (definida no cadastro, nunca alterável), e os **recursos Always
Free só existem na sua home region** — assinar outras regiões não estende o Always Free para lá (um A1
em outra região seria **cobrado**). Então mudar `region` não transforma falta de capacidade em
capacidade gratuita. Opções que continuam $0: continuar tentando na home region (`retry-a1.sh`, alternar
ADs, fora de pico), reduzir para **1 OCPU / 6 GB**, ou criar uma conta gratuita **nova** com uma home
region escolhida de forma mais estratégica — veja o passo 2 da configuração para escolher uma home region
com capacidade de A1.

**P: O apply foi parcial e eu mudei de ideia — como limpo?**
`terraform destroy`. Ele remove o que estiver no state, inclusive de um apply parcial.

---

## Estrutura

```
versions.tf      providers.tf     variables.tf     locals.tf
data.tf          network.tf       compute.tf       database.tf
observability.tf guardrails.tf    outputs.tf
scripts/check-plan.sh   scripts/retry-a1.sh   terraform.tfvars.example
```

## Notas

- Provider fixado em `oracle/oci ~> 8.18`. Revalide periodicamente a
  [página do Always Free da Oracle](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
  — o catálogo e os limites mudam (como mostrou o corte do A1 em 15/06/2026).
- `terraform.tfvars`, `*.pem` e arquivos de state estão no `.gitignore`. Nunca faça commit de segredos reais.
