# Lixeiras

O conteúdo de `~/.Trash` e quaisquer lixeiras de volumes (drives externos). O MacSense as esvazia para que o espaço realmente volte ao sistema.

## Detalhes

Arrastar um arquivo para a Lixeira só o marca para exclusão — os bytes ficam no disco até a Lixeira ser esvaziada. O macOS mostra o espaço recuperado no Utilitário de Disco mas trata como em uso até a confirmação.

A varredura do MacSense:

- Lista cada arquivo em `~/.Trash` e em cada volume montado.
- Reporta o tamanho total recuperável.
- Ao limpar, remove os arquivos permanentemente.

É a única limpeza **não reversível** — uma vez esvaziada, os arquivos somem. Olhe a lista antes de confirmar.
