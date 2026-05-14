# Itens de login do usuário

Apps e helpers que iniciam automaticamente quando você faz login no Mac. Pertencem à sua conta de usuário, então desabilitar ou remover só afeta a sua sessão.

## Detalhes

Itens de login do usuário vêm de duas fontes:

- **Plists do launchd** em `~/Library/LaunchAgents` — geralmente instalados por apps de terceiros para sync em segundo plano, checagens de atualização ou itens da barra de menus.
- **Registros `SMAppService`** declarados dentro do bundle do app (macOS 13+). O MacSense mostra mas não pode alternar — use Configurações do Sistema → Geral → Itens de login.

A maioria é segura desabilitar: o app pai continua funcionando, só sem o comportamento de início automático. Se algo passar a se comportar mal, reativar o agente ou reabrir o app restaura.
