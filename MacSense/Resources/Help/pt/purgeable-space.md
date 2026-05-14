# Espaço purgável

Bytes que o macOS já considera recuperáveis mas ainda não removeu. Disparar uma purga diz ao sistema "preciso desse espaço agora" e força a liberação dessas dependências.

## Detalhes

O APFS mantém várias camadas de armazenamento de remoção suave:

- **Arquivos sincronizados com iCloud** que têm cópia local e cópia na nuvem.
- **Snapshots locais do Time Machine** (veja entrada dedicada).
- **Caches gerenciados pelo macOS** marcados como removíveis sob pressão de disco.

O Finder reporta bytes purgáveis em "Disponível" mas não em "Em uso" ou "Livre". Eles aparecem livres para o macOS mas em uso para apps que calculam espaço da forma antiga. Purgar libera de fato.

O MacSense chama os mesmos caminhos (`diskutil apfs deleteContainer`, `tmutil thinlocalsnapshots`) que o sistema usaria sob pressão. Sem perda — cada byte purgável tem outra cópia em outro lugar.
