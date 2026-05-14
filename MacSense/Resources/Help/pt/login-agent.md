# Agente de login

Um processo que o macOS inicia automaticamente quando você faz login. Alguns são essenciais (serviços do sistema, helpers de chaveiro), outros são companheiros de apps que talvez você não precise rodando o tempo todo.

## Detalhes

Agentes de login vêm de três fontes:

- **Sistema** — agentes do macOS em `/System/Library/LaunchAgents`. O MacSense nunca toca neles.
- **Por usuário** — plists do launchd em `~/Library/LaunchAgents`. Frequentemente instalados por apps de terceiros para sync em segundo plano, checagens de atualização ou itens da barra de menus.
- **Embutidos** — registrados via `SMAppService` (veja "Item de login embutido").

Agentes por usuário podem ser desabilitados ou removidos com segurança — o app pai continua funcionando mas perde qualquer comportamento em segundo plano. Se algo passar a se comportar mal, reativar o agente ou reinstalar o app restaura.
