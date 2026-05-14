# Mapa de armazenamento

Um mapa pasta a pasta do seu disco, onde cada item é dimensionado pela alocação real em disco. Permite localizar o que está consumindo espaço sem chutar.

## Detalhes

A seção Armazenamento constrói uma árvore de cada pasta sob `/`, calcula tamanhos recursivos e apresenta duas vistas:

- **Aba Tamanho** — mapa de bolhas interativo. Círculos maiores = pastas maiores. Clique para entrar; o caminho de migalhas no topo segue sua trajetória.
- **Aba Tipo** — arquivos agrupados por tipo de mídia (vídeo, áudio, arquivos, capturas…) para você ver, por exemplo, que 30 GB são vídeos.

O primeiro escaneamento leva ~30 segundos porque cada byte sob sua pasta pessoal é percorrido. O MacSense salva um snapshot em disco para que visitas seguintes mostrem dados imediatamente enquanto um refresh roda em segundo plano.

Arquivos nunca são movidos ou excluídos da vista do mapa — é inspeção apenas leitura. Use as folhas de categoria de Limpeza quando quiser realmente jogar algo na lixeira.
