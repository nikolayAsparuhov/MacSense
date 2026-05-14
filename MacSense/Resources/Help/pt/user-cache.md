# Cache do usuário

Dados gerados por apps que vivem em `~/Library/Caches`. Apps tratam isso como armazenamento descartável — perdê-los apenas desacelera o próximo lançamento, nada quebra.

## Detalhes

Cada app usa cache para:

- Imagens pré-renderizadas, miniaturas e mídia decodificada.
- Pacotes de assets baixados que o app pode buscar de novo.
- Índices de busca e histórico recente.

Macs modernos acumulam gigabytes ao longo do tempo, especialmente de navegadores, apps de mídia e ferramentas Electron. O primeiro lançamento após limpeza é levemente mais lento; os seguintes voltam ao normal.

O MacSense ignora caches em uso ativo (arquivos travados, bancos abertos) e move o resto para a Lixeira, nunca exclui direto.
