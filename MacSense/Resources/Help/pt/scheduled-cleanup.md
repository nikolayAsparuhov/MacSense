# Limpeza agendada

Um escaneamento recorrente opcional que roda em segundo plano em uma cadência diária, semanal ou mensal e publica uma notificação de resumo.

## Detalhes

Quando ativado, o MacSense usa `NSBackgroundActivityScheduler` — a API de tarefas amigáveis à energia do macOS — para rodar um Smart Scan sobre as categorias que você marcou. O resultado é entregue como uma única notificação:

> Encontrado 4,7 GB recuperáveis em 4 categorias. Abra o MacSense para revisar.

Tocar a notificação abre o MacSense na seção Limpeza.

Restrições importantes:

- **Nada é excluído automaticamente.** O agendamento notifica; você decide o que (se algo) limpar.
- **Agendamentos rodam enquanto o MacSense está aberto ou recentemente ativo.** O macOS pode atrasar tarefas em segundo plano. Sem LaunchAgent, sem daemon — fechar o app pausa o agendamento até o próximo lançamento.

Permissão de notificação é pedida uma vez no primeiro lançamento. Se você negou antes, a seção Agenda mostra um aviso com atalho para Configurações do Sistema.
