# Lixo do sistema

Logs, arquivos temporários e relatórios de falha que o macOS ou apps instalados deixam fora da sua pasta pessoal. Seguro de remover — o sistema regenera o que ainda precisar.

## Detalhes

Cobre três grupos:

- **Relatórios de diagnóstico** em `/Library/Logs` e `/var/log`. O macOS faz rotação automaticamente.
- **Relatórios de falha** em `/Library/Application Support/CrashReporter`. Úteis logo após o crash, inúteis meses depois.
- **Restos de instalações** deixados por instaladores de pacote e atualizações de apps.

O MacSense move tudo para a Lixeira. Nada aqui contém seus documentos ou preferências — apenas artefatos gerados pelo sistema.
