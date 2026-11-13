# Crachá Provisório

Jogo de navegador sobre os 30 primeiros dias de uma estagiária de segurança da informação na fictícia **Tabajara Seguros S.A.**, longe do SOC.

Cada dia é uma área diferente da segurança, com uma mecânica própria. O humor é de escritório e as técnicas são de verdade: hash, HMAC, regex, CVSS 3.1, CIDR, Diffie-Hellman, JWT e first-match de firewall são todos calculados de fato, não encenados.

**Jogar:** https://marianabsctba.github.io/Cracha_Provisorio/

## Como se joga

Você anda pelo escritório em primeira pessoa e recebe a tarefa do dia de alguém da equipe:

- **Valdecir:** o gerente, que acha que firewall é antivírus caro.
- **Jurema:** a sênior cínica, com 22 anos de casa.
- **Kauã:** o dev que commita senha.
- **Dona Cida:** da copa, que sabe de tudo.
- **Seu Josias:** o vigia, que viu tudo desde 1987.

Na maioria dos dias o trabalho é no computador da sua mesa. Em quatro deles é no próprio andar.

Controles: clique para olhar com o mouse, WASD anda, Shift corre, E interage, Esc solta o mouse.

No fim dos 30 dias, o RH decide:

- **Promovida:** média 75 ou mais e nenhuma cagada grave.
- **Mandada embora:** média abaixo de 45 ou duas cagadas graves.
- **Estagiária por mais 15 anos:** todo o resto.

## Os 30 dias

| Dia | Tarefa | Área |
|---|---|---|
| 1 | Política de senhas | IAM |
| 2 | Inventário de ativos (3D) | Gestão de ativos |
| 3 | Revisão de acessos | IAM |
| 4 | SPF e DMARC | E-mail e DNS |
| 5 | Endurecendo o SSH | Hardening |
| 6 | Regras de firewall | Redes |
| 7 | Revisão de código | AppSec |
| 8 | Criptografia de base64 | Criptografia |
| 9 | Migração de senhas | Criptografia |
| 10 | LGPD na planilha | Privacidade |
| 11 | Pentest no portal | Pentest web |
| 12 | Regex de DLP | Prevenção de vazamento |
| 13 | Certificado vencido | PKI |
| 14 | Intrusão física (3D) | Red team físico |
| 15 | Bucket público | Nuvem |
| 16 | Simulado de ransomware | Continuidade |
| 17 | Priorizando CVEs | Gestão de vulnerabilidades |
| 18 | OSINT na Tabajara | OSINT |
| 19 | Ponto de acesso clandestino (3D) | Wi-Fi |
| 20 | Modelagem de ameaças | Arquitetura |
| 21 | Chave vazada no Git | DevSecOps |
| 22 | JWT do portal | Pentest web |
| 23 | Pendrive formatado | Forense |
| 24 | Dockerfile do Kauã | Contêineres |
| 25 | VPN com o parceiro | Criptografia |
| 26 | O CEO e o MFA | Governança |
| 27 | Segmentação de rede | Redes |
| 28 | Pendrive do estacionamento | Análise de ameaças |
| 29 | Auditoria ISO 27001 (3D) | Conformidade |
| 30 | Prova de efetivação | Pentest interno |

Tudo é fictício: empresa, pessoas, domínio, IPs (faixas de documentação e privadas) e chaves. As técnicas são reais e só devem ser usadas em ambiente autorizado.

## Desenvolvimento

Feito em Godot 4.7.2, com GDScript e o renderizador Compatibility. A exportação web é sem threads, para rodar no GitHub Pages.

```
fases/        uma fase de computador por dia (dia_NN.gd), todas sobre fases/fase.gd
missoes/      os dias jogados no escritório 3D
scripts/      fluxo, escritório, jogadora, catálogo dos dias, estilo e estado do jogo
tests/        testes das fases sem janela
```

Testar as fases (cada uma precisa dar nota abaixo de 50 sem interação e 90 ou mais resolvida):

```
godot --headless --path . --script res://tests/run_tests.gd
```

Abrir uma fase ou um dia do escritório direto:

```
godot --path . -- --dia=12
godot --path . -- --escritorio=14
```

Cada push na `main` roda os testes, exporta para web e publica no Pages.

## Licença

Código sob licença MIT. A fonte JetBrains Mono está sob a SIL Open Font License 1.1 (`fontes/OFL-JetBrainsMono.txt`).
