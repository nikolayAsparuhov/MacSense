# Item de login embutido

Um item de login registrado pelo próprio app via `SMAppService` (macOS 13+). Ferramentas de terceiros — incluindo o MacSense — não podem desabilitar, modificar ou excluir por motivos de segurança.

## Detalhes

A Apple introduziu o `SMAppService` para substituir as APIs antigas de itens de login. Os benefícios:

- Apps registram-se como agentes de login a partir de seu próprio bundle.
- O macOS garante que nada fora do app possa adulterar o registro.
- O usuário mantém controle total via Configurações do Sistema.

A contrapartida: ferramentas como o MacSense podem mostrar esses registros mas não alterná-los. A ação "Desabilitar" abre **Configurações do Sistema → Geral → Itens de login** no painel correto para você fazer o switch.

Itens legados registrados via APIs antigas (LSSharedFileList, plists do launchd em `~/Library/LaunchAgents`) continuam gerenciáveis pelo MacSense.
