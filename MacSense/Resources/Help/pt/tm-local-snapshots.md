# Snapshots locais do Time Machine

Snapshots de disco horários que o Time Machine tira mesmo quando seu drive de backup está desconectado. Vivem no seu disco interno e consomem espaço silenciosamente.

## Detalhes

O Time Machine mantém uma janela rotativa de snapshots locais para você restaurar mudanças recentes sem drive externo. Cada snapshot é uma referência copy-on-write, então criar um novo é barato — mas conforme você edita e exclui arquivos, eles fixam esses bytes no lugar.

Sintomas de acúmulo:

- Disco parece cheio mas o Finder mostra espaço livre.
- Bytes "purgáveis" são grandes.
- Após um download grande, excluí-lo não libera o espaço.

O MacSense executa `tmutil thinlocalsnapshots /` para liberá-los sob demanda. O macOS remove os mais antigos primeiro; backups Time Machine em destino externo não são afetados. Quando seu drive externo do Time Machine reconectar, novos snapshots voltam.
